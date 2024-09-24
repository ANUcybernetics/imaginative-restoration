import numpy as np
import PIL.Image
import torch
from diffusers import AutoencoderTiny, StableDiffusionPipeline
from streamdiffusion import StreamDiffusion

# You can load any models using diffuser's StableDiffusionPipeline
pipe = StableDiffusionPipeline.from_pretrained("stabilityai/sdxl-turbo").to(
    device=torch.device("mps"),
    dtype=torch.float16,
)

# Wrap the pipeline in StreamDiffusion
stream = StreamDiffusion(
    pipe,
    t_index_list=[32, 45],
    torch_dtype=torch.float16,
)

# If the loaded model is not LCM, merge LCM
# stream.load_lcm_lora()
# stream.fuse_lora()
# Use Tiny VAE for further acceleration
stream.vae = AutoencoderTiny.from_pretrained("madebyollin/taesd").to(
    device=pipe.device, dtype=pipe.dtype
)
# Enable acceleration
pipe.enable_xformers_memory_efficient_attention()


# these utility functions from utils.py in StreamDiffusion repo
def denormalize(images) -> torch.Tensor:
    """
    Denormalize an image array to [0,1].
    """
    return (images / 2 + 0.5).clamp(0, 1)


def pt_to_numpy(images: torch.Tensor) -> np.ndarray:
    """
    Convert a PyTorch tensor to a NumPy image.
    """
    images = images.cpu().permute(0, 2, 3, 1).float().numpy()
    return images


def numpy_to_pil(images: np.ndarray) -> PIL.Image.Image:
    """
    Convert a NumPy image or a batch of images to a PIL image.
    """
    if images.ndim == 3:
        images = images[None, ...]
    images = (images * 255).round().astype("uint8")
    if images.shape[-1] == 1:
        # special case for grayscale (single channel) images
        pil_images = [
            PIL.Image.fromarray(image.squeeze(), mode="L") for image in images
        ]
    else:
        pil_images = [PIL.Image.fromarray(image) for image in images]

    return pil_images


def postprocess_image(image, output_type="pil", do_denormalize=None):
    if not isinstance(image, torch.Tensor):
        raise ValueError(
            f"Input for postprocessing is in incorrect format: {type(image)}. We only support pytorch tensor"
        )

    if output_type == "latent":
        return image

    do_normalize_flg = True
    if do_denormalize is None:
        do_denormalize = [do_normalize_flg] * image.shape[0]

    image = torch.stack(
        [
            denormalize(image[i]) if do_denormalize[i] else image[i]
            for i in range(image.shape[0])
        ]
    )

    if output_type == "pt":
        return image

    image = pt_to_numpy(image)

    if output_type == "np":
        return image

    if output_type == "pil":
        return numpy_to_pil(image)


def predict(init_image, prompt):
    # Prepare the stream (TODO hoist this out of the loop)
    stream.prepare(prompt)

    # Warmup >= len(t_index_list) x frame_buffer_size
    for _ in range(2):
        stream(init_image)

    x_output = stream(init_image)
    # postprocess_image(x_output, output_type="pil")[0].show()
    return x_output
