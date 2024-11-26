import FastNoiseLite from "fastnoise-lite";

const SketchCanvasHook = {
  mounted() {
    // Configure sketches
    this.sketches = [];
    this.maxSketches = 10;
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
      size: 200 * Math.random() + 300,
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
    const scale = Math.max(0.4, 1 - secondsElapsed * 0.01);
    this.ctx.translate(x, y);
    this.ctx.scale(
      scale + this.noise.GetNoise(x * 0.5, sketch.y + 100) * 0.1,
      scale + this.noise.GetNoise(x * 0.6, sketch.y - 100) * 0.1,
    );

    // Define rounded rectangle path
    const radius = 50; // Adjust the radius as needed
    const drawHeight = sketch.size;
    const drawX = -drawWidth / 2;
    const drawY = -drawHeight / 2;

    this.ctx.beginPath();
    this.ctx.moveTo(drawX + radius, drawY);
    this.ctx.lineTo(drawX + drawWidth - radius, drawY);
    this.ctx.quadraticCurveTo(
      drawX + drawWidth,
      drawY,
      drawX + drawWidth,
      drawY + radius,
    );
    this.ctx.lineTo(drawX + drawWidth, drawY + drawHeight - radius);
    this.ctx.quadraticCurveTo(
      drawX + drawWidth,
      drawY + drawHeight,
      drawX + drawWidth - radius,
      drawY + drawHeight,
    );
    this.ctx.lineTo(drawX + radius, drawY + drawHeight);
    this.ctx.quadraticCurveTo(
      drawX,
      drawY + drawHeight,
      drawX,
      drawY + drawHeight - radius,
    );
    this.ctx.lineTo(drawX, drawY + radius);
    this.ctx.quadraticCurveTo(drawX, drawY, drawX + radius, drawY);
    this.ctx.closePath();

    // Clip to the rounded rectangle path
    this.ctx.clip();

    // Draw the image
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
