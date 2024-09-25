import math
import os

import cv2
import numpy as np
from PIL import Image

# One-off initialization
camera = cv2.VideoCapture(0)

# some constants, might refactor this stuff later (perhaps CLI args?)
IMAGE_SIZE: int = 256
FRAME_TIME: int = 1.0 / 15
NEGATIVE_PROMPT: str = "detailed background, colorful background"
AI_STRENGTH: float = 0.8
PRINT_TIMINGS: bool = False

## archival-film related assets

def get_film_frame(frame_index):
    file_path = f"assets/nfsa/frame-{frame_index:04d}.png"
    if os.path.exists(file_path):
        image = resize_crop(Image.open(file_path), IMAGE_SIZE)
        return (image, frame_index + 1)
    else:
        image = resize_crop(Image.open(file_path), IMAGE_SIZE)
        return (Image.open("assets/nfsa/frame-0001.png"), 1)


# NOTE: the last index needs to be greater than the max frame index in the video
FRAME_PROMPT_INDEX = [
    (0, "goldfish on a green screen background"),
    (10, "shark on a green screen background"),
    (100, " on a green screen background"),
    (5000, "goldfish on a green screen background"),
]


def get_prompt_for_frame(frame_index):
    for index, prompt in FRAME_PROMPT_INDEX:
        if index >= frame_index:
            return prompt

    raise f"cannot find prompt for frame {frame_index}: index out of bounds"


## camera

def get_camera_frame():
    """
    Captures and returns the current webcam image as a PIL Image.

    Returns:
    - PIL.Image: The captured image.
    - None: If the capture fails.
    """
    if not camera.isOpened():
        raise "could not open camera"

    # Set camera parameters for brightness (not working yet)
    # camera.set(cv2.CAP_PROP_BRIGHTNESS, 255)  # Adjust brightness (0-255)
    # this is a *gross* way to set a hex value
    # camera.set(cv2.CAP_PROP_AUTO_EXPOSURE, 0.25)
    # camera.set(cv2.CAP_PROP_EXPOSURE, -7)  # Adjust exposure (-7 to -1 for manual mode)

    ret, frame = camera.read()
    if not ret:
        raise "could not read camera frame"

    # Convert BGR to RGB
    rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

    # Convert to PIL Image
    image = Image.fromarray(rgb_frame)
    image = resize_crop(image, IMAGE_SIZE)
    # flipped feels more natural
    image = image.transpose(Image.FLIP_LEFT_RIGHT)
    return image


def resize_crop(image, width):
    image = image.convert("RGB")
    w, h = image.size
    # assume w > h
    left = (w - h) // 2
    top = 0
    right = left + h
    bottom = h
    image = image.crop((left, top, right, bottom))
    image = image.resize((width, width), Image.NEAREST)
    return image


def canny_image(image):
    image = np.array(image)
    image = cv2.Canny(image, 100, 200)
    image = 255 - image  # Invert the image
    image = image[:, :, None]
    image = np.concatenate([image, image, image], axis=2)
    image = Image.fromarray(image)
    return image


def green_image(size):
    return Image.new("RGB", (size, size), color=(40, 255, 40))


def chroma_key(background_image, foreground_image):
    # Convert images to numpy arrays
    background_array = np.array(background_image)
    foreground_array = np.array(foreground_image)

    # Define the green-screen colour range
    lower_green = np.array([40, 40, 40])
    upper_green = np.array([80, 255, 80])

    # Create a mask for green-ish pixels
    mask = np.all((foreground_array >= lower_green) & (foreground_array <= upper_green), axis=-1)

    # Use the mask to combine the images
    result = np.where(mask[:, :, np.newaxis], background_array, foreground_array)

    # Convert back to PIL Image
    return Image.fromarray(result)


def cleanup():
    """
    Releases the camera resource.
    Should be called when the application is closing.
    """
    global camera
    if camera.isOpened():
        camera.release()


def breathe(frame_index: int) -> float:
    normalized: float = (frame_index % 5) * (2 * math.pi / 5)
    sin_value: float = math.sin(normalized)
    scaled_value: float = 0.5 + sin_value * 0.4

    return scaled_value
