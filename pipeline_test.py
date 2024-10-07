from storytellers.gen_ai import predict
from diffusers.utils import load_image

input_image = load_image("assets/nfsa/frame-0001.png")
output_image = predict(input_image, "a goldfish against a greenscreen background", "ugly, low-contrast")
output_image.save("assets/output.png", format="PNG")

print(output_image)

# a handy CLI invocation for development:
# docker build . --tag storytellers && docker run --rm -it -v $(pwd)/assets:/app/assets storytellers python3 pipeline_test.py
