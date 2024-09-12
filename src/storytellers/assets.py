from PIL import Image
import os


def read_image(folder, frame_index):
    file_path = f"assets/{folder}/frame-{frame_index:04d}.png"
    if os.path.exists(file_path):
        return Image.open(file_path)
    else:
        return None
