const SketchCanvasHook = {
  mounted() {
    // Configure sketches
    this.sketches = [];
    this.maxSketches = 10;
    this.sketchHPad = 150;
    this.noiseOffset = Math.random() * 1000;
    this.isAnimating = false;

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

    this.video.src = `https://fly.storage.tigris.dev/imaginative-restoration-sketches/IMGRES_V3.0_18.11.24.mp4?client=${Date.now()}`;
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

  getNoise(x, y) {
    return (
      (Math.sin(x * 0.01 + y * 0.005 + this.noiseOffset) * 0.3 +
        Math.sin(x * 0.02 - y * 0.01) * 0.2 +
        Math.sin(y * 0.01) * 0.5) *
      0.5
    );
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
      let newSketch = {
        id: id,
        dataurl: dataurl,
        img: new Image(),
        y: (0.6 + 0.1 * Math.random()) * this.height,
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
    const y = sketch.y * (1 + 0.3 * this.getNoise(x * 0.1, sketch.y));

    // set the filters
    const grayscaleAmount = Math.min(50, secondsElapsed / 3);
    const opacityAmount = 0.75 + 0.25 * this.getNoise(x, sketch.y + 200);
    this.ctx.filter = `grayscale(${grayscaleAmount}%) opacity(${opacityAmount})`;

    // Apply scale transform based on secondsElapsed
    const scale = Math.max(0.25, 1 - secondsElapsed * 0.01);
    this.ctx.translate(x, y);
    this.ctx.scale(
      scale + this.getNoise(x * 0.5, sketch.y + 100) * 0.1,
      scale + this.getNoise(x * 0.6, sketch.y - 100) * 0.1,
    );

    const drawHeight = sketch.size;
    const drawX = -drawWidth / 2;
    const drawY = -drawHeight / 2;

    // Draw the image without clipping (full rectangle)
    this.ctx.drawImage(sketch.img, drawX, drawY, drawWidth, drawHeight);

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
    // Prevent multiple animation loops
    if (this.isAnimating) return;
    this.isAnimating = true;

    const animate = () => {
      this.animateFrame();
      if (this.isAnimating) {
        // Only continue if still animating
        this.animationFrameId = requestAnimationFrame(animate);
      }
    };
    animate();
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
