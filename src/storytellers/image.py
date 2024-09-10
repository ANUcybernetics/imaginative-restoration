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


def chroma_key(source_image, key_image):
    # Convert images to numpy arrays
    source_array = np.array(source_image)
    key_array = np.array(key_image)

    # Define the white-ish color range
    lower_white = np.array([150, 150, 150])
    upper_white = np.array([255, 255, 255])

    # Create a mask for white-ish pixels
    mask = np.all((key_array >= lower_white) & (key_array <= upper_white), axis=-1)

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
