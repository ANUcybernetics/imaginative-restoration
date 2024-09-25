import storytellers.viewer as viewer
import storytellers.gen_ai as gen_ai

# import storytellers.sdxl_controlnet as sdxl_controlnet
import storytellers.utils as utils
import storytellers.assets as assets

import asyncio

from asyncio import Task

import time
from typing import Tuple, Any

IMAGE_SIZE: int = 256
NEGATIVE_PROMPT: str = "detailed background, colorful background"
AI_STRENGTH: float = 0.8
PRINT_TIMINGS: bool = True


# NOTE this function has the same name as the one in utils, but also crops & resizes
def get_webcam_frame() -> Any:
    start_time: float = time.time()
    webcam_frame: Any = utils.resize_crop(utils.get_camera_frame(), IMAGE_SIZE)
    # webcam_frame = utils.canny_image(webcam_frame)
    if PRINT_TIMINGS:
        print(f"Webcam frame processing time: {time.time() - start_time:.4f} seconds")
    return webcam_frame


def get_film_frame(frame_index: int) -> Tuple[Any, int]:
    start_time: float = time.time()
    film_frame: Any = assets.read_image(frame_index)
    if film_frame is None:
        frame_index = 1
        film_frame = assets.read_image(frame_index)
    else:
        frame_index += 1

    film_frame = utils.resize_crop(film_frame, IMAGE_SIZE)
    if PRINT_TIMINGS:
        print(f"Video frame processing time: {time.time() - start_time:.4f} seconds")
    return film_frame, frame_index


def chroma_key_compose(background_image: Any, foreground_image: Any) -> Any:
    start_time: float = time.time()
    image: Any = utils.chroma_key(background_image, foreground_image)
    if PRINT_TIMINGS:
        print(f"Chroma key processing time: {time.time() - start_time:.4f} seconds")
    return image


def img2img(prompt: str, input_image: Any) -> Any:
    start_time: float = time.time()
    output_image = gen_ai.predict(
        input_image, prompt, NEGATIVE_PROMPT, IMAGE_SIZE, AI_STRENGTH, 1
    )

    if PRINT_TIMINGS:
        print(f"AI prediction time: {time.time() - start_time:.4f} seconds")
    return output_image


def display_image(image: Any) -> None:
    start_time: float = time.time()
    viewer.show_image(image)
    if PRINT_TIMINGS:
        print(f"Image display time: {time.time() - start_time:.4f} seconds")


async def get_ai_frame(frame_index: int):
    webcam_frame: Any = get_webcam_frame()
    ai_frame: Any = await asyncio.to_thread(
        img2img, assets.read_prompt(frame_index), webcam_frame
    )
    return ai_frame


async def main_loop() -> int:
    frame_index: int = 1
    try:
        # initial tasks & a placeholder image
        ai_task: Task = asyncio.create_task(get_ai_frame(frame_index))
        ai_frame = utils.green_image(IMAGE_SIZE)
        while True:
            if ai_task.done():
                ai_frame = await ai_task
                # TODO do I need to finalise? the old task in some way
                ai_task = asyncio.create_task(get_ai_frame(frame_index))

            film_frame, next_frame_index = get_film_frame(frame_index)

            display_frame = chroma_key_compose(film_frame, ai_frame)
            display_image(display_frame)
            frame_index = next_frame_index
    except KeyboardInterrupt:
        pass
    finally:
        if ai_task:
            ai_task.cancel()
        viewer.close_viewer()
        utils.cleanup()
    return 0


def main():
    asyncio.run(main_loop())
