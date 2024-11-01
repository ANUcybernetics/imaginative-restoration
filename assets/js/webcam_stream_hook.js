const WebcamStreamHook = {
  mounted() {
    this.captureInterval = parseInt(this.el.dataset.captureInterval);
    this.captureBox = JSON.parse(this.el.dataset.captureBox);

    // Parse capture box from URL query params
    const urlParams = new URLSearchParams(window.location.search);
    const captureBoxParam = urlParams.get("capture_box");

    if (captureBoxParam) {
      // Parse comma-separated values into array of integers
      this.captureBox = captureBoxParam.split(",").map((num) => parseInt(num));
    } else {
      // Will be set to full dimensions once video metadata is loaded
      this.captureBox = null;
    }

    // Get references to existing SVG elements
    this.progressLine = document.getElementById("progress-line");
    this.flashOverlay = document.getElementById("flash-overlay");

    this.initWebcam();
  },

  destroyed() {
    if (this.currentAnimations) {
      this.currentAnimations.forEach((animation) => animation.cancel());
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

      // Store the stream
      video.srcObject = stream;

      // Wait for both play and metadata to be ready
      await Promise.all([
        new Promise((resolve) =>
          video.addEventListener("loadedmetadata", resolve, { once: true }),
        ),
        video.play(),
      ]);

      // If captureBox wasn't set from URL params, set it to full video dimensions
      if (!this.captureBox) {
        this.captureBox = [0, 0, video.videoWidth, video.videoHeight];
      }

      // Initialize frame capture
      this.canvas = document.createElement("canvas");
      this.context = this.canvas.getContext("2d");
      this.canvas.width = this.captureBox[2];
      this.canvas.height = this.captureBox[3];

      // Start frame capture (in 1s to give the auto-exposure time to adjust)
      setTimeout(() => this.captureFrame(), 1000);
      setInterval(() => this.captureFrame(), this.captureInterval);
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
    // Create wrapper div
    const wrapper = document.createElement("div");
    wrapper.style.position = "relative";
    this.el.parentElement.insertBefore(wrapper, this.el);
    wrapper.appendChild(this.el);

    // Create SVG container
    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.style.position = "absolute";
    svg.style.inset = "0";
    svg.style.width = "100%";
    svg.style.height = "100%";
    svg.style.pointerEvents = "none"; // Allow clicking through to video

    // Create progress line
    const line = document.createElementNS("http://www.w3.org/2000/svg", "line");
    line.setAttribute("x1", "0");
    line.setAttribute("y1", "5");
    line.setAttribute("x2", "100%");
    line.setAttribute("y2", "5");
    line.setAttribute("stroke-width", "10");
    line.setAttribute("stroke", "#00ff00");
    line.classList.add("progress-line");

    // Create flash rectangle
    const flash = document.createElementNS(
      "http://www.w3.org/2000/svg",
      "rect",
    );
    flash.setAttribute("x", "0");
    flash.setAttribute("y", "0");
    flash.setAttribute("width", "100%");
    flash.setAttribute("height", "100%");
    flash.setAttribute("fill", "#ffffff");
    flash.setAttribute("opacity", "0");
    flash.classList.add("flash-overlay");

    // Add elements to SVG container
    svg.appendChild(line);
    svg.appendChild(flash);
    wrapper.appendChild(svg);

    // Store references
    this.progressLine = line;
    this.flashOverlay = flash;
  },

  animateCaptureProgress() {
    // Cancel any existing animations
    if (this.currentAnimations) {
      this.currentAnimations.forEach((animation) => animation.cancel());
    }
    this.currentAnimations = [];

    // Define progress bar keyframes
    const progressKeyframes = [
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

    // Define flash keyframes
    const flashKeyframes = [{ opacity: 1 }, { opacity: 0, offset: 1 / 20 }];

    // Define animation options
    const animationOptions = {
      duration: this.captureInterval,
      easing: "linear",
      fill: "forwards",
    };

    // Start the animations using the stored references
    this.currentAnimations = [
      this.progressLine.animate(progressKeyframes, animationOptions),
      this.flashOverlay.animate(flashKeyframes, animationOptions),
    ];
  },
};

export default WebcamStreamHook;
