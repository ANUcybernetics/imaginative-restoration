const WebcamStreamHook = {
  mounted() {
    this.captureInterval = parseInt(this.el.dataset.captureInterval) || 60000;

    this.logDevices();
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
            console.log(
              `Camera Name: ${device.label}, Device ID: ${device.deviceId}`,
            );
          }
        });
      })
      .catch((error) => {
        console.error("Error getting devices:", error);
      });
  },

  initWebcam() {
    // TODO this should bomb out if the element isn't a <video>
    const video = this.el;

    navigator.mediaDevices
      .getUserMedia({
        video: true,
        // video: {
        //   deviceId: { exact: "FEE05D276A4E5EE14B285F75B41830FE1F5BEB7A" },
        // },
        audio: false,
      })
      .then((stream) => {
        video.srcObject = stream;
        // flip video horizontally (useful for normal webcam use, not necessarily for overhead setup)
        // video.style.transform = "scaleX(-1)";
        video.play();

        video.addEventListener("loadedmetadata", () => {
          // init "frame capture" canvas
          this.canvas = document.createElement("canvas");
          this.context = this.canvas.getContext("2d");
          this.canvas.width = video.videoWidth;
          this.canvas.height = video.videoHeight;

          // Start frame capture
          this.captureFrame();
          setInterval(() => this.captureFrame(), this.captureInterval); // Capture every 60 seconds
        });
      })
      .catch((error) => {
        console.error("Error accessing the webcam:", error);
      });
  },

  captureFrame() {
    const video = this.el;
    const captureSize = this.canvas.width;

    // assume portrait mode, i.e. w > h
    const videoSize = video.videoHeight;
    const startX = (video.videoWidth - videoSize) / 2;

    // Draw the current video frame to the canvas, cropping to square and resizing
    this.context.drawImage(
      video,
      startX,
      0,
      videoSize,
      videoSize,
      0,
      0,
      captureSize,
      captureSize,
    );

    const dataUrl = this.canvas.toDataURL("image/jpeg");
    this.pushEvent("webcam_frame", { frame: dataUrl });

    // Start the progress animation
    this.animateCaptureProgress();
  },

  animateCaptureProgress() {
    // Cancel any existing animation
    if (this.currentAnimation) {
      this.currentAnimation.cancel();
    }

    // Create keyframes for the border animation
    const keyframes = [
      {
        borderTop: "5px solid #00ff00",
        clipPath: "inset(0 0% 0 0)", // Show full width
      },
      {
        borderTop: "5px solid #80ff00",
        clipPath: "inset(0 0% 0 50%)", // Show right half
      },
      {
        borderTop: "5px solid #ff0000",
        clipPath: "inset(0 0% 0 100%)", // Hide completely
      },
    ];

    const timing = {
      duration: this.captureInterval,
      easing: "linear",
      fill: "forwards",
    };

    // Start the animation
    this.currentAnimation = this.el.animate(keyframes, timing);
  },
};

export default WebcamStreamHook;
