FROM stjet:r36.4.0

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libgl1-mesa-dev \
    libxkbcommon-x11-0 \
    libdbus-1-3 \
    libxcb-cursor0 \
    libxcb-icccm4 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-randr0 \
    libxcb-render-util0 \
    libxcb-xinerama0 \
    libxcb-xfixes0 \
    x11-utils \
    libqt6gui6 \
    libqt6widgets6 \
    libqt6core6 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir PySide6 opencv-python-headless huggingface_hub[hf_transfer]

COPY . /app
WORKDIR /app

# Download model files
ENV HF_HUB_ENABLE_HF_TRANSFER=1
RUN python3 download_models.py

ENV QT_QPA_PLATFORM=xcb
ENV PYTHONUNBUFFERED=1

ENV PYTHONPATH="/app/src"
CMD ["python3", "-u", "-m", "storytellers"]
