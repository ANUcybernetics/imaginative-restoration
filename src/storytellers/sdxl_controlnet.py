import torch
from diffusers import (
    AutoencoderKL,
    ControlNetModel,
    StableDiffusionXLControlNetPipeline,
)

import storytellers.utils as utils

controlnet = ControlNetModel.from_pretrained(
    "diffusers/controlnet-canny-sdxl-1.0", torch_dtype=torch.float16
)
vae = AutoencoderKL.from_pretrained(
    "madebyollin/sdxl-vae-fp16-fix", torch_dtype=torch.float16
)
pipe = StableDiffusionXLControlNetPipeline.from_pretrained(
    "stabilityai/stable-diffusion-xl-base-1.0",
    controlnet=controlnet,
    vae=vae,
    torch_dtype=torch.float16,
)
pipe.enable_model_cpu_offload()
# pipe.to("mps")
pipe.set_progress_bar_config(disable=True)


def predict(init_image, prompt, size, strength, steps, seed=1231231):
    negative_prompt = "low quality, bad quality, sketches"

    # init_image = load_image(
    #     "https://huggingface.co/datasets/hf-internal-testing/diffusers-images/resolve/main/sd_controlnet/hf-logo.png"
    # )

    init_image = utils.resize_crop(init_image)
    controlnet_conditioning_scale = 0.5  # recommended for good generalization

    canny_image = utils.canny_image(init_image)

    results = pipe(
        prompt,
        negative_prompt=negative_prompt,
        image=canny_image,
        controlnet_conditioning_scale=controlnet_conditioning_scale,
    )

    return results.images[0]
