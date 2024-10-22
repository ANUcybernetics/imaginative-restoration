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
        video.play();
      })
      .catch((error) => {
        console.error("Error accessing the webcam:", error);
      });
  },
};

export default WebcamStreamHook;
