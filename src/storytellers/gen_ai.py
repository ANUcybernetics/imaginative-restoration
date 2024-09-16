import storytellers.image as image
from diffusers import AutoPipelineForImage2Image
import torch
from PIL import Image
import math

# code adapted from https://huggingface.co/spaces/diffusers/unofficial-SDXL-Turbo-i2i-t2i

pipe = AutoPipelineForImage2Image.from_pretrained(
    "stabilityai/sdxl-turbo",
    torch_dtype=torch.float16,
    variant="fp16",
)

# this doesn't work on mps
# pipe.unet = torch.compile(pipe.unet, mode="reduce-overhead", fullgraph=True)

pipe.to("mps")
pipe.set_progress_bar_config(disable=True)


def predict(init_image, prompt, negative_prompt, size, strength, steps, seed=1231231):
    generator = torch.manual_seed(seed)
    init_image = image.resize_crop(init_image, size)

    if int(steps * strength) < 1:
        steps = math.ceil(1 / max(0.10, strength))

    results = pipe(
        prompt=prompt,
        negative_prompt=negative_prompt,
        image=init_image,
        generator=generator,
        num_inference_steps=steps,
        guidance_scale=0.0,
        strength=strength,
        width=size,
        height=size,
        output_type="pil",
    )
    nsfw_content_detected = (
        results.nsfw_content_detected[0]
        if "nsfw_content_detected" in results
        else False
    )
    if nsfw_content_detected:
        return Image.new("RGB", (size, size))
    return results.images[0]
