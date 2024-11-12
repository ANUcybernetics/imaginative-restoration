import FastNoiseLite from "fastnoise-lite";

const SketchCanvasHook = {
  mounted() {
    // Configure sketches
    this.maxSketches = 50;
    this.sketchHPad = 100;
    this.noise = new FastNoiseLite();
    this.noise.SetNoiseType(FastNoiseLite.NoiseType.Perlin);

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
      "https://fly.storage.tigris.dev/imaginative-restoration-sketches/IMGRES_V2.0_29.10.24.mp4";
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
      x: -this.sketchHPad,
      y: Math.random() * this.height,
      xVel: Math.random() * 2 + 1,
      yRange: Math.random() * 200,
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
    const grayscaleAmount = Math.max(0, 100 - secondsElapsed);
    this.ctx.filter = `grayscale(${grayscaleAmount}%)`;

    // Draw the image
    this.ctx.drawImage(
      sketch.img,
      sketch.x,
      sketch.y,
      sketch.size,
      sketch.size,
    );
    // Restore the context state
    this.ctx.restore();
  },

  updateSketch(sketch) {
    // Get time component for noise
    const timeScale = 0.001; // Adjust this to change how quickly the movement pattern changes
    // const time = (Date.now() - sketch.addedAt) * timeScale;

    // Get position component for noise
    const positionScale = 0.005; // Adjust this to change how much position affects movement
    const noiseX = sketch.x * positionScale;
    const noiseY = sketch.y * positionScale;

    // Get noise value between -1 and 1
    const noiseValue = this.noise.GetNoise(noiseX, noiseY);

    // Update position
    sketch.x += sketch.xVel * (1 + noiseValue);

    // Reset position when off screen
    if (sketch.x > this.width + this.sketchHPad) {
      sketch.x = -this.sketchHPad;
      if (sketch.size > 100) {
        sketch.size *= 0.9;
      }
    }
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
        this.updateSketch(sketch);
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
  },
};

export default SketchCanvasHook;
