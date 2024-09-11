import storytellers.viewer as viewer
import storytellers.gen_ai as gen_ai
import storytellers.image as image_utils
import storytellers.assets as assets
# from diffusers.utils import load_image

IMAGE_SIZE = 256
# IMAGE_PROMPT = "cubism meets pointillism"
IMAGE_PROMPT = "a cool, comfortable cave, moss growing on the walls"


def main() -> int:
    frame_index = 1
    try:
        while True:
            import time

            start_time = time.time()

            webcam_frame = image_utils.resize_crop(
                image_utils.get_camera_frame(), IMAGE_SIZE
            )
            print(
                f"Webcam frame processing time: {time.time() - start_time:.4f} seconds"
            )

            video_frame_start = time.time()
            video_frame = assets.read_image("nggyu", frame_index)
            if video_frame is None:
                frame_index = 1
                video_frame = assets.read_image("nggyu", frame_index)
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
            image = gen_ai.predict(image, IMAGE_PROMPT, IMAGE_SIZE, 0.4, 2)
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
