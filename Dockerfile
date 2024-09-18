FROM python:slim
RUN pip install uv
RUN --mount=source=dist,target=/dist uv pip install --system --no-cache /dist/*.whl
CMD python -m storytellers

# rye build --wheel --clean
# docker build . --tag storytellers
