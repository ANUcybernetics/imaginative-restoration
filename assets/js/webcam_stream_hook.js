const WebcamStreamHook = {
  mounted() {
    this.captureInterval = parseInt(this.el.dataset.captureInterval);
    this.showFullFrame = this.el.hasAttribute("data-show-full-frame");

    // Parse capture box from URL query params
    const urlParams = new URLSearchParams(window.location.search);
    const captureBoxParam = urlParams.get("capture_box");

    if (captureBoxParam) {
      // Parse comma-separated values into array of integers
      this.captureBox = captureBoxParam.split(",").map((num) => parseInt(num));
    } else {
      // Will be set to full dimensions once video metadata is loaded
      this.captureBox = null;
    }

    // Get reference to flash overlay
    this.flashOverlay = document.getElementById("flash-overlay");
    
    // Listen for capture trigger events from server
    this.handleEvent("capture_triggered", () => {
      this.triggerFlash();
    });

    // Add resize handler for crop box overlay
    this.resizeHandler = () => this.drawCropBoxOverlay();
    window.addEventListener("resize", this.resizeHandler);

    this.initWebcam();
  },

  destroyed() {
    // Cancel animations
    if (this.currentAnimations) {
      this.currentAnimations.forEach((animation) => animation.cancel());
    }

    // Stop video stream
    if (this.el.srcObject) {
      const tracks = this.el.srcObject.getTracks();
      tracks.forEach((track) => track.stop());
      this.el.srcObject = null;
    }

    // Clear capture interval
    if (this.captureIntervalId) {
      clearInterval(this.captureIntervalId);
    }

    // Clean up canvas
    if (this.canvas) {
      this.context = null;
      this.canvas = null;
    }

    // Clean up display canvas
    if (this.displayCanvas) {
      this.displayContext = null;
      this.displayCanvas = null;
    }

    // Remove resize handler
    if (this.resizeHandler) {
      window.removeEventListener("resize", this.resizeHandler);
    }
  },

  logDevices() {
    navigator.mediaDevices
      .enumerateDevices()
      .then((devices) => {
        devices.forEach((device) => {
          if (device.kind === "videoinput") {
            console.log(device);
          }
        });
      })
      .catch((error) => {
        console.error("Error getting devices:", error);
      });
  },

  async initWebcam() {
    const video = this.el;

    try {
      const devices = await navigator.mediaDevices.enumerateDevices();
      const streamCam = devices.find(
        (device) =>
          device.kind === "videoinput" &&
          device.label.includes("Logitech StreamCam"),
      );

      const videoConstraints = streamCam
        ? { deviceId: { exact: streamCam.deviceId } }
        : true;

      const stream = await navigator.mediaDevices.getUserMedia({
        video: videoConstraints,
        audio: false,
      });

      // Store the stream
      video.srcObject = stream;

      // Wait for both play and metadata to be ready
      await Promise.all([
        new Promise((resolve) =>
          video.addEventListener("loadedmetadata", resolve, { once: true }),
        ),
        video.play(),
      ]);

      // If captureBox wasn't set from URL params, set it to full video dimensions
      if (!this.captureBox) {
        this.captureBox = [0, 0, video.videoWidth, video.videoHeight];
      }

      // Initialize frame capture
      this.canvas = document.createElement("canvas");
      this.context = this.canvas.getContext("2d");
      this.canvas.width = this.captureBox[2];
      this.canvas.height = this.captureBox[3];

      // Initialize display canvas for cropped view (only if not showing full frame)
      if (!this.showFullFrame) {
        this.displayCanvas = document.createElement("canvas");
        this.displayContext = this.displayCanvas.getContext("2d");
        this.displayCanvas.width = this.captureBox[2];
        this.displayCanvas.height = this.captureBox[3];
        this.displayCanvas.className = "w-full h-full object-contain";

        // Replace video element with display canvas
        video.style.display = "none";
        video.parentNode.insertBefore(this.displayCanvas, video);
      }

      // Update SVG overlay to reference the canvas instead of video
      const svg = video.parentNode.querySelector("svg");
      if (svg) {
        svg.style.position = "absolute";
        svg.style.top = "0";
        svg.style.left = "0";
        svg.style.width = "100%";
        svg.style.height = "100%";
        svg.style.pointerEvents = "none";
        svg.style.zIndex = "10";
      }

      // Start display update loop (for cropped view or to update overlay)
      this.updateDisplay();

      // Start frame capture (in 1s to give the auto-exposure time to adjust)
      setTimeout(() => this.captureFrame(), 1000);
      this.captureIntervalId = setInterval(
        () => this.captureFrame(),
        this.captureInterval,
      );
      
      // Notify LiveView that camera is working
      this.pushEvent("camera_status", { status: "ready" });
    } catch (error) {
      console.error("Error accessing the webcam:", error);
      
      // Determine the error type and send to LiveView
      let errorType = "unknown";
      let errorMessage = "Unable to access camera";
      
      if (error.name === "NotAllowedError" || error.name === "PermissionDeniedError") {
        errorType = "permission_denied";
        errorMessage = "Camera permission denied. Please allow camera access.";
      } else if (error.name === "NotFoundError" || error.name === "DevicesNotFoundError") {
        errorType = "no_camera";
        errorMessage = "No camera detected. Please connect a camera.";
      } else if (error.name === "NotReadableError" || error.name === "TrackStartError") {
        errorType = "camera_in_use";
        errorMessage = "Camera is already in use by another application.";
      } else if (error.name === "OverconstrainedError") {
        errorType = "constraint_error";
        errorMessage = "Camera does not support the requested settings.";
      }
      
      // Send error to LiveView
      this.pushEvent("camera_status", { 
        status: "error", 
        error_type: errorType,
        error_message: errorMessage 
      });
    }
  },

  isOperatingHours() {
    const now = new Date();
    const hour = now.getHours();
    const day = now.getDay();
    const month = now.getMonth();
    const date = now.getDate();

    // Check if in holiday period
    const isHolidayPeriod =
      (month === 11 && date >= 21) || // December
      (month === 0 && date <= 6); // January

    // Check if weekday (0 is Sunday, 6 is Saturday)
    const isWeekday = day > 0 && day < 6;

    // Check if within operating hours (9am-10pm)
    const isWorkingHours = hour >= 9 && hour < 22;

    return isWeekday && isWorkingHours && !isHolidayPeriod;
  },

  updateDisplay() {
    const video = this.el;
    
    // Update crop box overlay if we're in admin view
    if (this.showFullFrame) {
      this.drawCropBoxOverlay();
      // Continue updating for admin view
      requestAnimationFrame(() => this.updateDisplay());
      return;
    }
    
    // Only update display canvas if we're showing cropped view
    if (!this.displayContext || !this.displayCanvas) {
      return;
    }

    const captureBox = this.captureBox;

    if (video.readyState >= 2) {
      // Draw cropped video frame to display canvas
      this.displayContext.drawImage(
        video,
        captureBox[0],
        captureBox[1],
        captureBox[2],
        captureBox[3],
        0,
        0,
        captureBox[2],
        captureBox[3],
      );
    }

    // Continue updating display
    requestAnimationFrame(() => this.updateDisplay());
  },

  drawCropBoxOverlay() {
    // Only draw crop box in admin view
    const overlay = document.getElementById("crop-box-overlay");
    if (!overlay || !this.captureBox) return;

    const video = this.el;
    const captureBox = this.captureBox;

    // Wait for video to have dimensions
    if (!video.videoWidth || !video.videoHeight) {
      return;
    }
    
    // Ensure overlay is visible and has proper z-index
    overlay.style.zIndex = "20";
    overlay.style.pointerEvents = "none";

    // Get the element to measure (video if full frame, canvas if cropped)
    const displayElement = this.showFullFrame ? video : this.displayCanvas;
    if (!displayElement) return;

    // Calculate the scale and position of the crop box
    const container = displayElement.parentElement;
    const containerRect = container.getBoundingClientRect();
    const displayRect = displayElement.getBoundingClientRect();

    // For object-contain, we need to calculate the actual displayed video dimensions
    // The video maintains aspect ratio, so we need to find which dimension is constrained
    const videoAspectRatio = video.videoWidth / video.videoHeight;
    const containerAspectRatio = displayRect.width / displayRect.height;
    
    let actualVideoWidth, actualVideoHeight, offsetX, offsetY;
    
    if (videoAspectRatio > containerAspectRatio) {
      // Video is wider than container - width is constrained
      actualVideoWidth = displayRect.width;
      actualVideoHeight = displayRect.width / videoAspectRatio;
      offsetX = 0;
      offsetY = (displayRect.height - actualVideoHeight) / 2;
    } else {
      // Video is taller than container - height is constrained
      actualVideoHeight = displayRect.height;
      actualVideoWidth = displayRect.height * videoAspectRatio;
      offsetX = (displayRect.width - actualVideoWidth) / 2;
      offsetY = 0;
    }

    // Calculate the scale factors based on actual video display size
    const scaleX = actualVideoWidth / video.videoWidth;
    const scaleY = actualVideoHeight / video.videoHeight;

    // Calculate the position and size of the crop box in the display coordinates
    // Include the letterbox offset
    const cropLeft = captureBox[0] * scaleX + (displayRect.left - containerRect.left) + offsetX;
    const cropTop = captureBox[1] * scaleY + (displayRect.top - containerRect.top) + offsetY;
    const cropWidth = captureBox[2] * scaleX;
    const cropHeight = captureBox[3] * scaleY;

    // Check if we need to create or update the overlay
    if (!this.overlayInitialized) {
      // Generate grid lines once
      let gridLines = '';
      const gridSpacing = 100; // 100px spacing in video coordinates
      
      // Only show grid if we're showing full frame
      if (this.showFullFrame) {
        // Create container for grid lines
        gridLines = '<div id="grid-lines">';
        
        // Vertical lines
        for (let x = 0; x <= video.videoWidth; x += gridSpacing) {
          gridLines += `<div class="grid-line-v absolute h-full border-l border-gray-600 opacity-30" data-x="${x}"></div>`;
        }
        
        // Horizontal lines
        for (let y = 0; y <= video.videoHeight; y += gridSpacing) {
          gridLines += `<div class="grid-line-h absolute w-full border-t border-gray-600 opacity-30" data-y="${y}"></div>`;
        }
        
        gridLines += '</div>';
      }

      // Create the overlay structure once
      overlay.innerHTML = `
        ${gridLines}
        <div id="crop-box" class="absolute border-2 border-red-500">
          <span class="absolute -top-6 left-0 text-xs text-red-500 bg-black bg-opacity-50 px-1">Crop Area</span>
        </div>
      `;
      
      this.overlayInitialized = true;
    }

    // Update grid line positions
    const gridContainer = overlay.querySelector('#grid-lines');
    if (gridContainer) {
      // Update vertical lines
      gridContainer.querySelectorAll('.grid-line-v').forEach(line => {
        const x = parseInt(line.dataset.x);
        const scaledX = x * scaleX;
        line.style.left = `${scaledX}px`;
        // Only show lines that are within the video area
        line.style.display = (x <= video.videoWidth) ? 'block' : 'none';
      });
      
      // Update horizontal lines
      gridContainer.querySelectorAll('.grid-line-h').forEach(line => {
        const y = parseInt(line.dataset.y);
        const scaledY = y * scaleY;
        line.style.top = `${scaledY}px`;
        // Only show lines that are within the video area
        line.style.display = (y <= video.videoHeight) ? 'block' : 'none';
      });
      
      // Set the grid container to only cover the actual video area
      gridContainer.style.position = 'absolute';
      gridContainer.style.left = `${offsetX}px`;
      gridContainer.style.top = `${offsetY}px`;
      gridContainer.style.width = `${actualVideoWidth}px`;
      gridContainer.style.height = `${actualVideoHeight}px`;
      gridContainer.style.overflow = 'hidden';
    }

    // Update crop box position
    const cropBox = overlay.querySelector('#crop-box');
    if (cropBox) {
      cropBox.style.left = `${cropLeft}px`;
      cropBox.style.top = `${cropTop}px`;
      cropBox.style.width = `${cropWidth}px`;
      cropBox.style.height = `${cropHeight}px`;
    }
  },

  captureFrame() {
    // No longer automatically flash on every capture
    // Flash will be triggered by server when capture actually happens

    if (!this.isOperatingHours()) {
      return;
    }

    if (!this.context || !this.canvas) {
      console.warn("Canvas not initialized - skipping frame capture");
      return;
    }

    const video = this.el;
    const captureBox = this.captureBox;

    // Always capture cropped frame
    this.context.drawImage(
      video,
      captureBox[0],
      captureBox[1],
      captureBox[2],
      captureBox[3],
      0,
      0,
      captureBox[2],
      captureBox[3],
    );

    const dataUrl = this.canvas.toDataURL("image/jpeg");
    
    // For admin view, mark it as admin frame so server knows to handle it differently
    if (this.showFullFrame) {
      this.pushEvent("webcam_frame", { 
        frame: dataUrl,
        is_admin: true
      });
    } else {
      this.pushEvent("webcam_frame", { frame: dataUrl });
    }
  },
  animateCaptureProgress() {
    // This method is now a no-op, but kept for compatibility
    // Flash animation will be triggered by server events
  },

  triggerFlash() {
    // Cancel any existing flash animation
    if (this.flashAnimation) {
      this.flashAnimation.cancel();
    }

    // Define flash keyframes
    const flashKeyframes = [
      { opacity: 0 },
      { opacity: 1, offset: 0.1 },
      { opacity: 0, offset: 1 }
    ];

    // Start flash animation
    this.flashAnimation = this.flashOverlay.animate(flashKeyframes, {
      duration: 300,
      easing: "ease-out",
    });
  },
};

export default WebcamStreamHook;
