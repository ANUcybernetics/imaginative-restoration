const WebcamStreamHook = {
  mounted() {
    this.captureInterval = parseInt(this.el.dataset.captureInterval) || 60000;
    this.captureBox = JSON.parse(this.el.dataset.captureBox);

    this.initWebcam();
  },

  destroyed() {
    if (this.currentAnimation) {
      this.currentAnimation.cancel();
    }
  },

  logDevices() {
    navigator.mediaDevices
      .enumerateDevices()
      .then((devices) => {
        devices.forEach((device) => {
          if (device.kind === "videoinput") {
            console.log(device);
          }
        });
      })
      .catch((error) => {
        console.error("Error getting devices:", error);
      });
  },

  async initWebcam() {
    const video = this.el;

    try {
      const devices = await navigator.mediaDevices.enumerateDevices();
      const streamCam = devices.find(
        (device) =>
          device.kind === "videoinput" && device.label === "Logitech StreamCam",
      );

      const videoConstraints = streamCam
        ? { deviceId: { exact: streamCam.deviceId } }
        : true;

      const stream = await navigator.mediaDevices.getUserMedia({
        video: videoConstraints,
        audio: false,
      });

      video.srcObject = stream;
      video.play();

      video.addEventListener("loadedmetadata", () => {
        // init "frame capture" canvas
        this.canvas = document.createElement("canvas");
        this.context = this.canvas.getContext("2d");
        this.canvas.width = this.captureBox[2];
        this.canvas.height = this.captureBox[3];

        // Start frame capture
        this.captureFrame();
        setInterval(() => this.captureFrame(), this.captureInterval);
      });
    } catch (error) {
      console.error("Error accessing the webcam:", error);
    }
  },

  captureFrame() {
    const video = this.el;
    const captureBox = this.captureBox;

    // crop the current video frame based on captureBox, send to server as data URL
    this.context.drawImage(
      video,
      captureBox[0],
      captureBox[1],
      captureBox[2],
      captureBox[3],
      0,
      0,
      captureBox[2],
      captureBox[3],
    );

    const dataUrl = this.canvas.toDataURL("image/jpeg");
    this.pushEvent("webcam_frame", { frame: dataUrl });

    // Start the progress animation
    this.animateCaptureProgress();
  },

  createProgressOverlay() {
    // Create SVG container
    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");

    // Position SVG based on video element's position
    const videoRect = this.el.getBoundingClientRect();
    svg.style.position = "absolute";
    svg.style.top = `${videoRect.top}px`;
    svg.style.left = `${videoRect.left}px`;
    svg.style.width = `${videoRect.width}px`;
    svg.style.height = "10px";
    svg.style.zIndex = "1000";

    // Create progress line
    const line = document.createElementNS("http://www.w3.org/2000/svg", "line");
    line.setAttribute("x1", "0");
    line.setAttribute("y1", "2");
    line.setAttribute("x2", "100%");
    line.setAttribute("y2", "2");
    line.setAttribute("stroke-width", "10");
    line.setAttribute("stroke", "#00ff00");
    line.style.transformOrigin = "center";
    line.classList.add("progress-line");

    svg.appendChild(line);

    // Add to body
    this.progressOverlay = svg;
    document.body.appendChild(svg);

    return line;
  },

  animateCaptureProgress() {
    // Cancel any existing animation
    if (this.currentAnimation) {
      this.currentAnimation.cancel();
    }

    // Create or get the progress line if it doesn't exist
    const line =
      this.progressOverlay?.querySelector(".progress-line") ||
      this.createProgressOverlay();

    // Define keyframes
    const keyframes = [
      {
        transform: "scaleX(1)",
        stroke: "#00ff00",
      },
      {
        transform: "scaleX(0.5)",
        stroke: "#ffff00",
        offset: 0.5,
      },
      {
        transform: "scaleX(0)",
        stroke: "#ff0000",
      },
    ];

    // Define animation options
    const options = {
      duration: this.captureInterval,
      easing: "linear",
      fill: "forwards",
    };

    // Start the animation
    this.currentAnimation = line.animate(keyframes, options);
  },
};

export default WebcamStreamHook;
