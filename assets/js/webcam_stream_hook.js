const WebcamStreamHook = {
  mounted() {
    this.captureInterval = parseInt(this.el.dataset.captureInterval);

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
    // Cancel animations
    if (this.currentAnimations) {
      this.currentAnimations.forEach((animation) => animation.cancel());
    }

    // Stop video stream
    if (this.el.srcObject) {
      const tracks = this.el.srcObject.getTracks();
      tracks.forEach((track) => track.stop());
      this.el.srcObject = null;
    }

    // Clear capture interval
    if (this.captureIntervalId) {
      clearInterval(this.captureIntervalId);
    }

    // Clean up canvas
    if (this.canvas) {
      this.context = null;
      this.canvas = null;
    }

    // Clean up display canvas
    if (this.displayCanvas) {
      this.displayContext = null;
      this.displayCanvas = null;
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
          device.kind === "videoinput" &&
          device.label.includes("Logitech StreamCam"),
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

      // Initialize display canvas for cropped view
      this.displayCanvas = document.createElement("canvas");
      this.displayContext = this.displayCanvas.getContext("2d");
      this.displayCanvas.width = this.captureBox[2];
      this.displayCanvas.height = this.captureBox[3];
      this.displayCanvas.className = "w-full h-full object-contain";

      // Replace video element with display canvas
      video.style.display = "none";
      video.parentNode.insertBefore(this.displayCanvas, video);

      // Update SVG overlay to reference the canvas instead of video
      const svg = video.parentNode.querySelector("svg");
      if (svg) {
        svg.style.position = "absolute";
        svg.style.top = "0";
        svg.style.left = "0";
        svg.style.width = "100%";
        svg.style.height = "100%";
        svg.style.pointerEvents = "none";
        svg.style.zIndex = "10";
      }

      // Start display update loop
      this.updateDisplay();

      // Start frame capture (in 1s to give the auto-exposure time to adjust)
      setTimeout(() => this.captureFrame(), 1000);
      this.captureIntervalId = setInterval(
        () => this.captureFrame(),
        this.captureInterval,
      );
    } catch (error) {
      console.error("Error accessing the webcam:", error);
    }
  },

  isOperatingHours() {
    const now = new Date();
    const hour = now.getHours();
    const day = now.getDay();
    const month = now.getMonth();
    const date = now.getDate();

    // Check if in holiday period
    const isHolidayPeriod =
      (month === 11 && date >= 21) || // December
      (month === 0 && date <= 6); // January

    // Check if weekday (0 is Sunday, 6 is Saturday)
    const isWeekday = day > 0 && day < 6;

    // Check if within operating hours (9am-10pm)
    const isWorkingHours = hour >= 9 && hour < 22;

    return isWeekday && isWorkingHours && !isHolidayPeriod;
  },

  updateDisplay() {
    if (!this.displayContext || !this.displayCanvas) {
      return;
    }

    const video = this.el;
    const captureBox = this.captureBox;

    if (video.readyState >= 2) {
      // Draw cropped video frame to display canvas
      this.displayContext.drawImage(
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
    }

    // Continue updating display
    requestAnimationFrame(() => this.updateDisplay());
  },

  captureFrame() {
    // Always run the flash animation
    this.animateCaptureProgress();

    if (!this.isOperatingHours()) {
      return;
    }

    if (!this.context || !this.canvas) {
      console.warn("Canvas not initialized - skipping frame capture");
      return;
    }

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
        stroke: "#a07003",
      },
      {
        transform: "scaleX(0)",
        stroke: "#006e33",
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
