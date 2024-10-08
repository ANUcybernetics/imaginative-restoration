import storytellers.gen_ai as gen_ai
import storytellers.utils as utils
from diffusers.utils import load_image

film_image = load_image("assets/nfsa/frame-0001.png")

import time

start_time = time.time()
calibration_image = utils.camera_calibration_image()
calibration_image.save("assets/calibration.png", format="PNG")
print(f"Calibration image time: {time.time() - start_time:.2f} seconds")

start_time = time.time()
canny_image = utils.canny_image(utils.get_camera_frame())
canny_image.save("assets/canny.png", format="PNG")
print(f"Canny image time: {time.time() - start_time:.2f} seconds")

start_time = time.time()
genai_image = gen_ai.predict(canny_image, "a goldfish against a greenscreen background", "ugly, low-contrast")
genai_image.save("assets/goldfish.png", format="PNG")
print(f"genAI image time: {time.time() - start_time:.2f} seconds")

# a handy CLI invocation for development:
# docker build . --tag storytellers && docker run --rm -it --volume $(pwd)/assets:/app/assets --device=/dev/video0:/dev/video0 storytellers python3 pipeline_test.py
