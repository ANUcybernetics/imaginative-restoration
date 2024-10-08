import math

import torch
from diffusers import AutoPipelineForImage2Image, StableDiffusionXLAdapterPipeline, T2IAdapter, EulerAncestralDiscreteScheduler, AutoencoderKL

import storytellers.utils as utils
from storytellers.utils import get_best_device

# load adapter
adapter = T2IAdapter.from_pretrained(
    "TencentARC/t2i-adapter-canny-sdxl-1.0",
    torch_dtype=torch.float16,
    variant="fp16",
).to(get_best_device())

# load euler_a scheduler
model_id = 'stabilityai/sdxl-turbo'
euler_a = EulerAncestralDiscreteScheduler.from_pretrained(model_id, subfolder="scheduler")
vae=AutoencoderKL.from_pretrained("madebyollin/sdxl-vae-fp16-fix", torch_dtype=torch.float16)
pipe = StableDiffusionXLAdapterPipeline.from_pretrained(
    model_id, vae=vae, adapter=adapter, scheduler=euler_a, torch_dtype=torch.float16, variant="fp16",
).to(get_best_device())
# pipe.enable_xformers_memory_efficient_attention()
pipe.set_progress_bar_config(disable=True)

# there's an openCV-powered canny detector in utils, but this one is recommended in the t2i
# example page so it'll live in this file

def predict(init_image, prompt, negative_prompt):
    init_image = utils.resize_crop(init_image)
    canny = utils.canny_image(init_image)

    # if int(steps * strength) < 1:
    #     steps = math.ceil(1 / max(0.10, strength))
    steps = 1

    results = pipe(
        prompt=prompt,
        negative_prompt=negative_prompt,
        image=canny,
        num_inference_steps=steps,
        guidance_scale=0.0,
        # strength=strength,
        adapter_conditioning_scale=0.8,
        adapter_conditioning_factor=1,
        width=init_image.width,
        height=int(init_image.height),
        output_type="pil",
    )
    nsfw_content_detected = (
        results.nsfw_content_detected[0]
        if "nsfw_content_detected" in results
        else False
    )
    if nsfw_content_detected:
        return utils.green_image(init_image.size)
    return results.images[0]
