const SketchCanvasHook = {
  mounted() {
    // Configure sketches
    this.sketches = [];
    this.maxSketches = 10;
    this.sketchHPad = 150;
    this.noiseOffset = Math.random() * 1000;
    this.isAnimating = false;
    this.lastVideoTime = -1; // Track last video time for optimization

    // Add hardware acceleration hints for canvas
    this.el.style.transform = "translateZ(0)"; // Force GPU acceleration
    this.el.style.willChange = "transform"; // Hint to browser about future changes

    // Create and setup background video
    this.video = document.createElement("video");
    this.video.style.display = "none";
    this.video.autoplay = true;
    this.video.loop = true;
    this.video.muted = true;
    this.video.playsInline = true; // Add this for better mobile support

    // Add hardware acceleration hints for video
    this.video.style.transform = "translateZ(0)";
    this.video.preload = "auto";
    this.video.disablePictureInPicture = true;
    this.video.disableRemotePlayback = true;

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

    this.video.src = "https://fly.storage.tigris.dev/imaginative-restoration-sketches/IMGRES_V3.0_18.11.24.mp4";
    document.body.appendChild(this.video);

    // Setup resize observer
    this.resizeObserver = new ResizeObserver((entries) => {
      for (const entry of entries) {
        const { width, height } = entry.contentRect;
        this.updateCanvasSize(width, height);
      }
    });

    this.resizeObserver.observe(this.el);

    // alpha:false skips per-pixel alpha blend at composite time.
    // desynchronized:true measurably helped FPS on Pi 5 / V3D when tested
    // (removing it dropped screen2 from ~39 to ~24 fps).
    this.ctx = this.el.getContext("2d", {
      alpha: false,
      desynchronized: true,
    });

    // Add event handler for new sketches
    this.handleEvent("add_sketches", ({ sketches }) => {
      sketches.forEach(({ id, dataurl }) => {
        this.addNewSketch(id, dataurl);
      });
    });
  },

  getNoise(x, y) {
    return (
      Math.sin(x * 0.01 + y * 0.005 + this.noiseOffset) * 0.3 +
      Math.sin(x * 0.02 - y * 0.01) * 0.2 +
      Math.sin(y * 0.01) * 0.5
    );
  },

  // This LiveView lifecycle hook will fire after the DOM is updated
  updated() {
    const rect = this.el.getBoundingClientRect();
    this.updateCanvasSize(rect.width, rect.height);
  },

  updateCanvasSize(width, height) {
    // Cap the backing buffer at the source video resolution (1024x768). The
    // CSS box stays whatever layout decided; the browser GPU-upscales the
    // smaller buffer cheaply at composite. ~50% fewer pixels rastered per
    // frame -- enough headroom for the Pi 5 / V3D to hit vsync.
    const maxW = 1024, maxH = 768;
    const scale = Math.min(maxW / width, maxH / height, 1);
    this.width = Math.round(width * scale);
    this.height = Math.round(height * scale);
    this.el.width = this.width;
    this.el.height = this.height;
  },

  addNewSketch(id, dataurl) {
    if (this.sketches.length >= this.maxSketches) {
      // Reuse the oldest sketch object
      const oldestSketch = this.sketches[0];
      oldestSketch.id = id;
      oldestSketch.dataurl = dataurl;
      oldestSketch.addedAt = Date.now();

      // Move it to the end of the array
      this.sketches.push(this.sketches.shift());

      // Update the image source
      oldestSketch.img.src = dataurl;
    } else {
      const newSketch = {
        id: id,
        dataurl: dataurl,
        img: new Image(),
        y: 0.2 + Math.random() * 0.6, // Random base y between 20% and 80% of height
        xVel: 2 + Math.random() * 3,
        size: (0.4 + 0.3 * Math.random()) * this.height,
        addedAt: Date.now(),
      };

      newSketch.img.onload = () => {
        this.sketches.push(newSketch);
        newSketch.img.onload = null;
      };
      newSketch.img.src = dataurl;
    }
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

    // Calculate safe y bounds to prevent clipping
    const halfSize = sketch.size / 2;
    const minY = halfSize / this.height; // Minimum y as fraction to keep top edge on canvas
    const maxY = 1 - halfSize / this.height; // Maximum y as fraction to keep bottom edge on canvas
    const safeRange = maxY - minY;

    // Oscillate within safe bounds
    const baseY = minY + safeRange * sketch.y; // Use stored y as base position within safe range
    const oscillation =
      0.1 * safeRange * this.getNoise(x * 0.2, sketch.y * 1000);
    const y = this.height * (baseY + oscillation);

    // Set constant opacity of 90% (removing opacity fade effect)
    this.ctx.globalAlpha = 0.9;

    // Grayscale ramps from 0 → 50% over the sketch's first ~75s.
    const grayscaleAmount = Math.min(0.5, secondsElapsed / 150);

    // Apply scale transform based on secondsElapsed
    const scale = Math.max(0.25, 1 - secondsElapsed * 0.01);
    this.ctx.translate(x, y);
    this.ctx.scale(
      scale + this.getNoise(x * 0.5, sketch.y + 100) * 0.1,
      scale + this.getNoise(x * 0.6, sketch.y - 100) * 0.1,
    );

    if (grayscaleAmount > 0.01) {
      // Filter is part of context state, so the restore() below clears it.
      this.ctx.filter = `grayscale(${Math.round(grayscaleAmount * 100)}%)`;
    }

    const drawHeight = sketch.size;
    this.ctx.drawImage(sketch.img, -drawWidth / 2, -drawHeight / 2, drawWidth, drawHeight);

    this.ctx.restore();
  },

  animateFrame() {
    // Draw video frame to canvas - only when the video frame has changed
    if (this.ctx && this.video.readyState >= this.video.HAVE_CURRENT_DATA) {
      if (this.lastVideoTime !== this.video.currentTime) {
        this.ctx.drawImage(this.video, 0, 0, this.width, this.height);
        this.lastVideoTime = this.video.currentTime;
      }
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
    // Prevent multiple animation loops
    if (this.isAnimating) return;
    this.isAnimating = true;

    // Throttle to ~30fps so the Pi 5 has headroom for compositing.
    const targetFrameMs = 1000 / 30;
    let lastFrameTs = 0;

    const animate = (ts) => {
      if (ts - lastFrameTs >= targetFrameMs) {
        this.animateFrame();
        lastFrameTs = ts;
      }
      if (this.isAnimating) {
        this.animationFrameId = requestAnimationFrame(animate);
      }
    };
    this.animationFrameId = requestAnimationFrame(animate);
  },

  destroyed() {
    this.isAnimating = false;

    if (this.resizeObserver) {
      this.resizeObserver.disconnect();
    }
    if (this.video) {
      this.video.remove();
    }
    if (this.animationFrameId) {
      cancelAnimationFrame(this.animationFrameId);
    }

    // Clean up all remaining sketches
    this.sketches.forEach((sketch) => {
      if (sketch.img) {
        sketch.img.onload = null;
        sketch.img.src = "";
      }
    });
    this.sketches = [];
  },
};

export default SketchCanvasHook;
