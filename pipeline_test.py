import storytellers.gen_ai as gen_ai
import storytellers.utils as utils
from diffusers.utils import load_image

input_image = load_image("assets/nfsa/frame-0001.png")

canny_image = utils.canny_image(utils.get_camera_frame())
canny_image.save("assets/canny.png", format="PNG")

output_image = gen_ai.predict(canny_image, "a goldfish against a greenscreen background", "ugly, low-contrast")
output_image.save("assets/goldfish.png", format="PNG")

# a handy CLI invocation for development:
# docker build . --tag storytellers && docker run --rm -it --volume $(pwd)/assets:/app/assets --device=/dev/video0:/dev/video0 storytellers python3 pipeline_test.py
