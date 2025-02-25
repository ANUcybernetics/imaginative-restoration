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

    // Create context with hardware acceleration hints
    this.ctx = this.el.getContext("2d", {
      alpha: false,
      desynchronized: true,
      powerPreference: "high-performance",
      antialias: false, // Disable antialiasing for better performance
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
    this.width = width;
    this.height = height;
    this.el.width = width;
    this.el.height = height;

    this.ctx = this.el.getContext("2d");
  },

  // Pre-compute grayscale version of the image
  createGrayscaleVersion(sketch) {
    // Create an offscreen canvas
    const offscreenCanvas = document.createElement("canvas");
    const offCtx = offscreenCanvas.getContext("2d");

    offscreenCanvas.width = sketch.img.width;
    offscreenCanvas.height = sketch.img.height;

    // Draw the original image
    offCtx.drawImage(sketch.img, 0, 0);

    // Get image data and apply grayscale manually (much faster than filter)
    const imageData = offCtx.getImageData(
      0,
      0,
      offscreenCanvas.width,
      offscreenCanvas.height,
    );
    const data = imageData.data;

    for (let i = 0; i < data.length; i += 4) {
      const gray = 0.3 * data[i] + 0.59 * data[i + 1] + 0.11 * data[i + 2];
      data[i] = gray;
      data[i + 1] = gray;
      data[i + 2] = gray;
      // data[i + 3] remains unchanged (alpha channel)
    }

    offCtx.putImageData(imageData, 0, 0);

    // Store the grayscale version
    sketch.grayscaleImg = new Image();
    sketch.grayscaleImg.src = offscreenCanvas.toDataURL();
  },

  addNewSketch(id, dataurl) {
    if (this.sketches.length >= this.maxSketches) {
      // Reuse the oldest sketch object
      const oldestSketch = this.sketches[0];
      oldestSketch.id = id;
      oldestSketch.dataurl = dataurl;
      oldestSketch.addedAt = Date.now();
      oldestSketch.grayscaleImg = null; // Reset grayscale image

      // Move it to the end of the array
      this.sketches.push(this.sketches.shift());

      // Update the image source
      oldestSketch.img.onload = () => {
        this.createGrayscaleVersion(oldestSketch);
        oldestSketch.img.onload = null;
      };
      oldestSketch.img.src = dataurl;
    } else {
      let newSketch = {
        id: id,
        dataurl: dataurl,
        img: new Image(),
        grayscaleImg: null, // Will hold pre-rendered grayscale version
        y: (0.6 + 0.1 * Math.random()) * this.height,
        xVel: 2 + Math.random() * 3,
        size: (0.4 + 0.3 * Math.random()) * this.height,
        addedAt: Date.now(),
      };

      newSketch.img.onload = () => {
        this.createGrayscaleVersion(newSketch);
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
    const y = this.height * (0.6 + 0.2 * this.getNoise(x * 0.2, sketch.y));

    // Set constant opacity of 90% (removing opacity fade effect)
    this.ctx.globalAlpha = 0.9;

    // Calculate grayscale amount to match original code (up to 50% grayscale)
    // Original: const grayscaleAmount = Math.min(50, secondsElapsed / 3);
    const grayscaleAmount = Math.min(0.5, secondsElapsed / 150);

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

    // Choose which image to draw based on grayscale amount
    if (sketch.grayscaleImg && sketch.grayscaleImg.complete) {
      if (grayscaleAmount < 0.01) {
        // Just use original if very little grayscale is needed
        this.ctx.drawImage(sketch.img, drawX, drawY, drawWidth, drawHeight);
      } else if (grayscaleAmount > 0.49) {
        // Just use grayscale if at max grayscale amount (50%)
        this.ctx.drawImage(
          sketch.grayscaleImg,
          drawX,
          drawY,
          drawWidth,
          drawHeight,
        );
      } else {
        // Draw original first
        this.ctx.drawImage(sketch.img, drawX, drawY, drawWidth, drawHeight);

        // Then overlay grayscale with appropriate blend factor
        const blendFactor = grayscaleAmount * 2; // Maps 0-0.5 to 0-1
        this.ctx.globalAlpha = 0.9 * blendFactor;
        this.ctx.drawImage(
          sketch.grayscaleImg,
          drawX,
          drawY,
          drawWidth,
          drawHeight,
        );
      }
    } else {
      // Fallback to original if grayscale not yet ready
      this.ctx.drawImage(sketch.img, drawX, drawY, drawWidth, drawHeight);
    }

    // Restore the context state
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
      if (sketch.grayscaleImg) {
        sketch.grayscaleImg.src = "";
      }
    });
    this.sketches = [];
  },
};

export default SketchCanvasHook;
