from PIL import Image
import os


def read_image(frame_index):
    file_path = f"assets/nfsa/frame-{frame_index:04d}.png"
    if os.path.exists(file_path):
        return Image.open(file_path)
    else:
        raise f"cannot find video frame {frame_index}: index out of bounds"


# NOTE: the last index needs to be greater than the max frame index in the video
FRAME_PROMPT_INDEX = [
    (0, "goldfish on a green screen background"),
    (10, "shark on a green screen background"),
    (100, " on a green screen background"),
    (5000, "goldfish on a green screen background"),
]


def read_prompt(frame_index):
    for index, prompt in FRAME_PROMPT_INDEX:
        if index >= frame_index:
            return prompt

    raise f"cannot find prompt for frame {frame_index}: index out of bounds"
