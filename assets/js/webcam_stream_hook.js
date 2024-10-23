const WebcamStreamHook = {
  mounted() {
    this.initWebcam();
  },
  initWebcam() {
    // TODO this should bomb out if the element isn't a <video>
    const video = this.el;

    navigator.mediaDevices
      .getUserMedia({
        video: true,
        // video: {
        //   deviceId: { exact: "D55838D7F3DC4AACF5F73181A02463CB04516D77" },
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
          setInterval(() => this.captureFrame(), 60_000); // Capture every 60 seconds
        });
      })
      .catch((error) => {
        console.error("Error accessing the webcam:", error);
      });
  },
  captureFrame() {
    const video = this.el;
    const captureSize = this.canvas.width;

    // Calculate the size and position for cropping
    const videoSize = Math.min(video.videoWidth, video.videoHeight);
    const startX = (video.videoWidth - videoSize) / 2;
    const startY = (video.videoHeight - videoSize) / 2;

    // Draw the current video frame to the canvas, cropping to square and resizing
    this.context.drawImage(
      video,
      startX,
      startY,
      videoSize,
      videoSize,
      0,
      0,
      captureSize,
      captureSize,
    );

    const dataUrl = this.canvas.toDataURL("image/jpeg");
    this.pushEvent("webcam_frame", { frame: dataUrl });
  },
};

export default WebcamStreamHook;
