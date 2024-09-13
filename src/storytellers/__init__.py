import storytellers.viewer as viewer
import storytellers.gen_ai as gen_ai
import storytellers.image as image_utils
import storytellers.assets as assets
import math
import time

IMAGE_SIZE = 256
# IMAGE_PROMPT = "cubism meets pointillism"
IMAGE_PROMPT = "the world is made of moss and rocks, but the humans are chuds"
AI_STRENGTH = 0.2


def breathe(frame_index):
    normalized = (frame_index % 5) * (2 * math.pi / 5)
    sin_value = math.sin(normalized)
    scaled_value = 0.5 + sin_value * 0.4

    return scaled_value


def process_webcam_frame(print_timings: bool) -> tuple:
    start_time = time.time()
    webcam_frame = image_utils.resize_crop(image_utils.get_camera_frame(), IMAGE_SIZE)
    if print_timings:
        print(f"Webcam frame processing time: {time.time() - start_time:.4f} seconds")
    return webcam_frame


def process_video_frame(frame_index: int, print_timings: bool) -> tuple:
    start_time = time.time()
    video_frame = assets.read_image("nfsa-cut-1", frame_index)
    if video_frame is None:
        frame_index = 1
        video_frame = assets.read_image("nfsa-cut-1", frame_index)
    else:
        frame_index += 1

    video_frame = image_utils.resize_crop(video_frame, IMAGE_SIZE)
    if print_timings:
        print(f"Video frame processing time: {time.time() - start_time:.4f} seconds")
    return video_frame, frame_index


def apply_chroma_key(source_image, key_image, print_timings: bool) -> tuple:
    start_time = time.time()
    image = image_utils.chroma_key(source_image, key_image)
    if print_timings:
        print(f"Chroma key processing time: {time.time() - start_time:.4f} seconds")
    return image


def apply_ai_prediction(image, print_timings: bool) -> tuple:
    start_time = time.time()
    image = gen_ai.predict(image, IMAGE_PROMPT, IMAGE_SIZE, AI_STRENGTH, 1)
    if print_timings:
        print(f"AI prediction time: {time.time() - start_time:.4f} seconds")
    return image


def display_image(image, print_timings: bool) -> None:
    start_time = time.time()
    viewer.show_image(image)
    if print_timings:
        print(f"Image display time: {time.time() - start_time:.4f} seconds")


def main() -> int:
    frame_index = 1
    print_timings = True
    try:
        while True:
            start_time = time.time()

            webcam_frame = process_webcam_frame(print_timings)
            video_frame, frame_index = process_video_frame(frame_index, print_timings)
            image = apply_chroma_key(video_frame, webcam_frame, print_timings)
            image = apply_ai_prediction(image, print_timings)
            display_image(image, print_timings)

            if print_timings:
                print(f"Total loop time: {time.time() - start_time:.4f} seconds\n")
    except KeyboardInterrupt:
        pass
    finally:
        viewer.close_viewer()
        image_utils.cleanup()
    return 0
