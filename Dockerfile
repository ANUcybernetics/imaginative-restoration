# TODO: should pull from a https://github.com/dusty-nv/jetson-containers/ container
FROM python:slim

# these commands recommended by rye
# https://rye.astral.sh/guide/docker/#container-from-a-python-package
#
# then,
#
# rye build --wheel --clean && docker build . --tag storytellers
RUN pip install uv
RUN --mount=source=dist,target=/dist uv pip install --system --no-cache /dist/*.whl
CMD python -m storytellers
