import math

import cv2
import numpy as np
from PIL import Image

# One-off initialization
camera = cv2.VideoCapture(0)


def get_camera_frame():
    """
    Captures and returns the current webcam image as a PIL Image.

    Returns:
    - PIL.Image: The captured image.
    - None: If the capture fails.
    """
    if not camera.isOpened():
        print("Error: Could not open camera.")
        return None

    # Set camera parameters for brightness (not working yet)
    # camera.set(cv2.CAP_PROP_BRIGHTNESS, 255)  # Adjust brightness (0-255)
    # this is a *gross* way to set a hex value
    # camera.set(cv2.CAP_PROP_AUTO_EXPOSURE, 0.25)
    # camera.set(cv2.CAP_PROP_EXPOSURE, -7)  # Adjust exposure (-7 to -1 for manual mode)

    ret, frame = camera.read()
    if not ret:
        print("Error: Could not read frame.")
        return None

    # Convert BGR to RGB
    rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

    # Convert to PIL Image
    image = Image.fromarray(rgb_frame)

    # flipped feels more natural
    return image.transpose(Image.FLIP_LEFT_RIGHT)


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


def chroma_key(background_image, foreground_image):
    # Convert images to numpy arrays
    source_array = np.array(background_image)
    key_array = np.array(foreground_image)

    # Define the green-screen colour range
    lower_green = np.array([40, 40, 40])
    upper_green = np.array([80, 255, 80])

    # Create a mask for green-ish pixels
    mask = np.all((key_array >= lower_green) & (key_array <= upper_green), axis=-1)

    # Use the mask to combine the images
    result = np.where(mask[:, :, np.newaxis], source_array, key_array)

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
