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


def main() -> int:
    frame_index = 1
    try:
        while True:
            start_time = time.time()

            webcam_frame = image_utils.resize_crop(
                image_utils.get_camera_frame(), IMAGE_SIZE
            )
            print(
                f"Webcam frame processing time: {time.time() - start_time:.4f} seconds"
            )

            video_frame_start = time.time()
            video_frame = assets.read_image("nfsa-cut-1", frame_index)
            if video_frame is None:
                frame_index = 1
                video_frame = assets.read_image("nfsa-cut-1", frame_index)
            else:
                frame_index += 1

            video_frame = image_utils.resize_crop(video_frame, IMAGE_SIZE)
            print(
                f"Video frame processing time: {time.time() - video_frame_start:.4f} seconds"
            )

            chroma_key_start = time.time()
            image = image_utils.chroma_key(video_frame, webcam_frame)
            print(
                f"Chroma key processing time: {time.time() - chroma_key_start:.4f} seconds"
            )

            predict_start = time.time()
            image = gen_ai.predict(image, IMAGE_PROMPT, IMAGE_SIZE, AI_STRENGTH, 1)
            print(f"AI prediction time: {time.time() - predict_start:.4f} seconds")

            viewer_start = time.time()
            viewer.show_image(image)
            print(f"Image display time: {time.time() - viewer_start:.4f} seconds")

            print(f"Total loop time: {time.time() - start_time:.4f} seconds\n")
    except KeyboardInterrupt:
        pass
    finally:
        viewer.close_viewer()
        image_utils.cleanup()
    return 0
