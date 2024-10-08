import math
import os

import cv2
import numpy as np
import torch
from PIL import Image, ImageDraw


def get_film_frame(frame_index):
    file_path = f"assets/nfsa/frame-{frame_index:04d}.png"
    if os.path.exists(file_path):
        image = Image.open(file_path)
        return (image, frame_index + 1)
    else:
        # loop back to the beginning
        file_path = "assets/nfsa/frame-0001.png"
        image = Image.open(file_path)
        return (image, 2)


# a few other config params
FRAME_TIME: int = 1.0 / 10
PRINT_TIMINGS: bool = False

def get_best_device():
    if torch.cuda.is_available():
        return torch.device("cuda")
    elif torch.backends.mps.is_available():
        return torch.device("mps")
    else:
        return torch.device("cpu")


## camera

# camera & draw surface alignment
CAMERA_RESOLUTION = (1920, 1080)
# film is 4:3 aspect ratio, so make sure the cropped area is the same
CAMERA_CROP_RECT = (930, 440, 400, 300)
# get the image width from the first frame
IMAGE_WIDTH, IMAGE_HEIGHT = get_film_frame(1)[0].size

# Check if the image aspect ratio matches the camera crop rect
crop_ratio = CAMERA_CROP_RECT[2] / CAMERA_CROP_RECT[3]
image_ratio = IMAGE_WIDTH / IMAGE_HEIGHT
if abs(crop_ratio - image_ratio) > 0.01:  # Allow for small floating-point differences
    print(f"Error: Image aspect ratio ({image_ratio:.2f}) does not match camera crop ratio ({crop_ratio:.2f}).")
    print("Please adjust the CAMERA_CROP_RECT or the film frame dimensions.")
    exit(1)

# One-off initialization
camera = cv2.VideoCapture(0)
camera.set(cv2.CAP_PROP_FRAME_WIDTH, CAMERA_RESOLUTION[0])
camera.set(cv2.CAP_PROP_FRAME_HEIGHT, CAMERA_RESOLUTION[1])


def get_camera_frame(crop = True):
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
    image = Image.fromarray(rgb_frame).transpose(Image.FLIP_LEFT_RIGHT)

    # Crop the image to the specified rectangle
    if crop:
        x, y, w, h = CAMERA_CROP_RECT
        image = image.crop((x, y, x+w, y+h))

    return image


def camera_calibration_image():
    # Create a transparent overlay
    camera_image = get_camera_frame(False)
    overlay = Image.new('RGBA', camera_image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    # Unpack the box coordinates
    x, y, w, h = CAMERA_CROP_RECT

    # Draw the red box with transparent center
    draw.rectangle([x, y, x+w, y+h], outline=(255, 0, 0, 255), width=2)

    # Combine the original image with the overlay
    return Image.alpha_composite(camera_image.convert('RGBA'), overlay).convert('RGB')


def resize_crop(image):
    target_ratio = 4 / 3
    img_width, img_height = image.size
    img_ratio = img_width / img_height

    if img_ratio > target_ratio:
        # Image is wider than target, crop width
        new_width = int(img_height * target_ratio)
        left = (img_width - new_width) // 2
        image = image.crop((left, 0, left + new_width, img_height))
    elif img_ratio < target_ratio:
        # Image is taller than target, crop height
        new_height = int(img_width / target_ratio)
        top = (img_height - new_height) // 2
        image = image.crop((0, top, img_width, top + new_height))

    # Resize to target width
    height = int(IMAGE_WIDTH / target_ratio)
    return image.resize((IMAGE_WIDTH, height), Image.LANCZOS)


def canny_image(image):
    image = np.array(image)
    image = cv2.Canny(image, 100, 200)
    image = image[:, :, None]
    image = np.concatenate([image, image, image], axis=2)
    image = Image.fromarray(image)
    return image


def green_image(size):
    return Image.new("RGB", size, color=(40, 255, 40))


def chroma_key(background_image, foreground_image):
    # Convert images to numpy arrays
    background_array = np.array(background_image)
    foreground_array = np.array(foreground_image)

    # Define the green-screen colour range
    lower_green = np.array([0, 100, 0])
    upper_green = np.array([255, 255, 255])

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
