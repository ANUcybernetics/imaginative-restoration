const WebcamStreamHook = {
  mounted() {
    this.initWebcam();
  },

  initWebcam() {
    const video = this.el;

    navigator.mediaDevices
      .getUserMedia({ video: true, audio: false })
      .then((stream) => {
        video.srcObject = stream;
        // flip video horizontally (useful for normal webcam use, not necessarily for overhead setup)
        video.style.transform = "scaleX(-1)";
        video.play();
      })
      .catch((error) => {
        console.error("Error accessing the webcam:", error);
      });
  },
};

export default WebcamStreamHook;
