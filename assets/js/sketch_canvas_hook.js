import FastNoiseLite from "fastnoise-lite";
import { Howl } from "howler";

const SketchCanvasHook = {
  mounted() {
    // Configure sketches
    this.maxSketches = 30;
    this.sketchHPad = 100;
    this.noise = new FastNoiseLite();
    this.noise.SetNoiseType(FastNoiseLite.NoiseType.Perlin);

    // set up audio
    this.sound = new Howl({
      src: [
        "https://fly.storage.tigris.dev/imaginative-restoration-sketches/592086__soundflakes__soundflakes-horizon-of-the-unknown.mp3",
      ],
      loop: true,
      volume: 0.5, // adjust as needed
      autoplay: true,
    });

    // Create and setup background video
    this.video = document.createElement("video");
    this.video.style.display = "none";
    this.video.autoplay = true;
    this.video.loop = true;
    this.video.muted = true;
    this.video.playsInline = true; // Add this for better mobile support

    // Wait for video to be ready and playing
    this.video.addEventListener("canplay", () => {
      this.video
        .play()
        .then(() => {
          this.startAnimation();
        })
        .catch((error) => {
          console.error("Error playing video:", error);
        });
    });

    this.video.src =
      "https://fly.storage.tigris.dev/imaginative-restoration-sketches/IMGRES_V3.0_18.11.24.mp4";
    document.body.appendChild(this.video);

    // Setup resize observer
    this.resizeObserver = new ResizeObserver((entries) => {
      for (const entry of entries) {
        const { width, height } = entry.contentRect;
        this.updateCanvasSize(width, height);
      }
    });

    this.resizeObserver.observe(this.el);

    // Add event handler for new sketches
    this.handleEvent("add_sketches", ({ sketches }) => {
      sketches.forEach(({ id, dataurl }) => {
        this.addNewSketch(id, dataurl);
      });
    });
  },

  // This LiveView lifecycle hook will fire after the DOM is updated
  updated() {
    const rect = this.el.getBoundingClientRect();
    this.updateCanvasSize(rect.width, rect.height);
  },

  updateCanvasSize(width, height) {
    this.width = width;
    this.height = height;
    this.el.width = width;
    this.el.height = height;

    this.ctx = this.el.getContext("2d");

    // Only initialize flock if it doesn't exist yet
    if (!this.sketches) {
      this.sketches = [];
    }
  },

  addNewSketch(id, dataurl) {
    if (this.sketches.length >= this.maxSketches) {
      // remove the first (oldest) sketch; the new one will be pushed to the back soon
      this.sketches.shift();
    }

    let newSketch = {
      id: id,
      dataurl: dataurl,
      img: new Image(),
      y: (0.1 + 0.8 * Math.random()) * this.height,
      xVel: 2 + Math.random() * 3,
      size: 300 * Math.random() + 200,
      addedAt: Date.now(),
    };

    // Create image and wait for it to load
    newSketch.img.onload = () => {
      this.sketches.push(newSketch);
    };
    newSketch.img.src = dataurl;
  },

  drawSketch(sketch) {
    // Save the current context state
    this.ctx.save();

    // Apply grayscale filter - gradually reduce over 100 seconds
    const secondsElapsed = (Date.now() - sketch.addedAt) / 1000;

    // calculate image size params
    const aspectRatio = sketch.img.width / sketch.img.height;
    const drawWidth = sketch.size * aspectRatio;

    // calculate image position
    const wrapRange = this.width + 2 * this.sketchHPad;
    const x =
      ((secondsElapsed * sketch.xVel * 20) % wrapRange) - this.sketchHPad;
    const y = sketch.y + 300 * this.noise.GetNoise(x * 0.1, sketch.y);

    // set the filters
    const grayscaleAmount = Math.max(0, 100 - secondsElapsed);
    const opacityAmount = 0.75 + 0.25 * this.noise.GetNoise(x, sketch.y + 200);
    this.ctx.filter = `grayscale(${grayscaleAmount}%) opacity(${opacityAmount})`;

    // Apply scale transform based on secondsElapsed
    const scale = Math.max(0.2, 1 - secondsElapsed * 0.01);
    this.ctx.translate(x, y);
    this.ctx.scale(
      scale + this.noise.GetNoise(x * 0.5, sketch.y + 100) * 0.1,
      scale + this.noise.GetNoise(x * 0.6, sketch.y - 100) * 0.1,
    );
    // Draw the image
    this.ctx.drawImage(
      sketch.img,
      -drawWidth / 2,
      -(sketch.size / 2),
      drawWidth,
      sketch.size,
    );
    // Restore the context state
    this.ctx.restore();
  },

  animateFrame() {
    // Draw video frame to canvas
    if (this.ctx && this.video.readyState >= this.video.HAVE_CURRENT_DATA) {
      this.ctx.drawImage(this.video, 0, 0, this.width, this.height);
    }

    // draw loop
    this.sketches.forEach((sketch) => {
      // first, draw sketch onto the canvas (on top of video)
      if (sketch.img && sketch.img.complete) {
        this.drawSketch(sketch);
      }
    });
  },

  startAnimation() {
    const animate = () => {
      this.animateFrame();
      this.animationFrameId = requestAnimationFrame(animate);
    };
    animate();
  },

  destroyed() {
    if (this.resizeObserver) {
      this.resizeObserver.disconnect();
    }
    if (this.video) {
      this.video.remove();
    }
    if (this.animationFrameId) {
      cancelAnimationFrame(this.animationFrameId);
    }
    if (this.sound) {
      this.sound.stop();
    }
  },
};

export default SketchCanvasHook;
