import storytellers.viewer as viewer
import storytellers.gen_ai as gen_ai

# import storytellers.sdxl_controlnet as sdxl_controlnet
import storytellers.image as image_utils
import storytellers.assets as assets
import math
import time
from typing import Tuple, Any

IMAGE_SIZE: int = 256
NEGATIVE_PROMPT: str = "detailed background, colorful background"
AI_STRENGTH: float = 0.8


def breathe(frame_index: int) -> float:
    normalized: float = (frame_index % 5) * (2 * math.pi / 5)
    sin_value: float = math.sin(normalized)
    scaled_value: float = 0.5 + sin_value * 0.4

    return scaled_value


def process_webcam_frame(print_timings: bool) -> Any:
    start_time: float = time.time()
    webcam_frame: Any = image_utils.resize_crop(
        image_utils.get_camera_frame(), IMAGE_SIZE
    )
    # webcam_frame = image_utils.canny_image(webcam_frame)
    if print_timings:
        print(f"Webcam frame processing time: {time.time() - start_time:.4f} seconds")
    return webcam_frame


def process_video_frame(frame_index: int, print_timings: bool) -> Tuple[Any, int]:
    start_time: float = time.time()
    video_frame: Any = assets.read_image("nfsa-cut-1", frame_index)
    if video_frame is None:
        frame_index = 1
        video_frame = assets.read_image("nfsa-cut-1", frame_index)
    else:
        frame_index += 1

    video_frame = image_utils.resize_crop(video_frame, IMAGE_SIZE)
    if print_timings:
        print(f"Video frame processing time: {time.time() - start_time:.4f} seconds")
    return video_frame, frame_index


def apply_chroma_key(source_image: Any, key_image: Any, print_timings: bool) -> Any:
    start_time: float = time.time()
    image: Any = image_utils.chroma_key(source_image, key_image)
    if print_timings:
        print(f"Chroma key processing time: {time.time() - start_time:.4f} seconds")
    return image


def apply_ai_prediction(frame_index: int, image: Any, print_timings: bool) -> Any:
    start_time: float = time.time()
    prompt: str = assets.read_prompt(frame_index)
    image = gen_ai.predict(image, prompt, NEGATIVE_PROMPT, IMAGE_SIZE, AI_STRENGTH, 1)

    if print_timings:
        print(f"AI prediction time: {time.time() - start_time:.4f} seconds")
    return image


def display_image(image: Any, print_timings: bool) -> None:
    start_time: float = time.time()
    viewer.show_image(image)
    if print_timings:
        print(f"Image display time: {time.time() - start_time:.4f} seconds")


def main() -> int:
    frame_index: int = 1
    print_timings: bool = False
    try:
        while True:
            start_time: float = time.time()

            image: Any = process_webcam_frame(print_timings)
            image = apply_ai_prediction(frame_index, image, print_timings)
            video_frame: Any
            video_frame, frame_index = process_video_frame(frame_index, print_timings)
            image = apply_chroma_key(video_frame, image, print_timings)
            display_image(image, print_timings)

            if print_timings:
                print(f"Total loop time: {time.time() - start_time:.4f} seconds\n")
    except KeyboardInterrupt:
        pass
    finally:
        viewer.close_viewer()
        image_utils.cleanup()
    return 0
