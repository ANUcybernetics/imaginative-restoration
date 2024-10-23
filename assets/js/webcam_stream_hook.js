const WebcamStreamHook = {
  mounted() {
    this.initWebcam();
  },

  initWebcam() {
    // TODO this should bomb out if the element isn't a <video>
    const video = this.el;

    navigator.mediaDevices
      .getUserMedia({ video: true, audio: false })
      .then((stream) => {
        video.srcObject = stream;
        // flip video horizontally (useful for normal webcam use, not necessarily for overhead setup)
        video.style.transform = "scaleX(-1)";
        video.play();
        this.startFrameCapture(video);
      })
      .catch((error) => {
        console.error("Error accessing the webcam:", error);
      });
  },

  startFrameCapture(video) {
    const canvas = document.createElement("canvas");
    const context = canvas.getContext("2d");

    setInterval(() => {
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
      context.drawImage(video, 0, 0, canvas.width, canvas.height);

      const dataUrl = canvas.toDataURL("image/jpeg");
      this.pushEvent("webcam_frame", { frame: dataUrl });
    }, 30_000); // 30 seconds
  },
};

export default WebcamStreamHook;
