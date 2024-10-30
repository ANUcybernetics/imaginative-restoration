// assets/js/hooks/boid_canvas.js
// code based on example code at https://github.com/thi-ng/umbrella/blob/develop/examples/boid-basics/src/index.ts (Apache 2.0 License)
import {
  alignment,
  cohesion,
  defBoid2,
  defFlock,
  separation,
  wrap2,
} from "@thi.ng/boids";
import { multiCosineGradient } from "@thi.ng/color";
import { HashGrid2 } from "@thi.ng/geom-accel/hash-grid";
import { weightedRandom } from "@thi.ng/random";
import { fromRAF } from "@thi.ng/rstream";
import { defTimeStep } from "@thi.ng/timestep";
import { repeatedly } from "@thi.ng/transducers";
import { distSq2, randMinMax2, randNorm2 } from "@thi.ng/vectors";

const BoidCanvasHook = {
  mounted() {
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
      "https://fly.storage.tigris.dev/imaginative-restoration-sketches/IMGRES_FirstRoughEdit_V1.0_DH_11.09.24.mp4";
    document.body.appendChild(this.video);

    // Configure boids
    this.numBoids = 50;
    this.accel = new HashGrid2((x) => x.pos.prev, 64, this.numBoids);
    this.maxRadius = 400;

    // Setup other configurations that don't depend on size
    this.setupBoidConfigs();

    // Setup resize observer
    this.resizeObserver = new ResizeObserver((entries) => {
      for (const entry of entries) {
        const { width, height } = entry.contentRect;
        this.updateCanvasSize(width, height);
      }
    });

    this.resizeObserver.observe(this.el);
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

    // Update size-dependent configurations
    this.pad = -40;
    this.bmin = [this.pad, this.pad];
    this.bmax = [this.width - this.pad, this.height - this.pad];

    // Update boid constraints
    this.opts.constrain = wrap2(this.bmin, this.bmax);

    // Reinitialize flock with new boundaries if needed
    this.initializeFlock();
  },

  setupBoidConfigs() {
    // Setup configurations that don't depend on size
    this.opts = {
      accel: this.accel,
      behaviors: [separation(40, 1.2), alignment(80, 0.5), cohesion(80, 0.8)],
      maxSpeed: 50,
      // constrain will be set in updateCanvasSize
    };

    this.gradient = multiCosineGradient({
      num: this.maxRadius + 1,
      stops: [
        [0.2, [0.8, 1, 1]],
        [0.4, [0.8, 1, 0.7]],
        [0.6, [1, 0.7, 0.1]],
        [1, [0.6, 0, 0.6]],
      ],
    });

    this.sim = defTimeStep();
  },

  initializeFlock() {
    this.flock = defFlock(this.accel, [
      ...repeatedly(
        () =>
          defBoid2(
            randMinMax2([], this.bmin, this.bmax),
            randNorm2([], this.opts.maxSpeed),
            {
              ...this.opts,
              maxSpeed: weightedRandom([20, 50, 100], [1, 4, 2])(),
            },
          ),
        this.numBoids,
      ),
    ]);
  },

  startAnimation() {
    // Animation loop
    this.subscription = fromRAF({ timestamp: true }).subscribe({
      next: (t) => {
        // Update simulation
        this.sim.update(t, [this.flock]);

        // Draw video frame to canvas
        this.ctx.drawImage(this.video, 0, 0, this.width, this.height);

        // Draw boids
        this.flock.boids.forEach((boid) => {
          const pos = boid.pos.value;
          let radius = this.maxRadius;

          // Find neighbors
          const neighbors = boid.neighbors(radius, pos);
          if (neighbors.length > 1) {
            let closest = null;
            let minD = this.maxRadius ** 2;
            for (let n of neighbors) {
              if (n === boid) continue;
              const d = distSq2(pos, n.pos.value);
              if (d < minD) {
                closest = n;
                minD = d;
              }
            }
            if (closest) radius = Math.sqrt(minD);
          }

          // Draw boid
          const img = new Image();
          img.src =
            "https://cdn.pixabay.com/photo/2016/09/01/08/24/smiley-1635449__180.png";
          const size = radius / 2;
          this.ctx.drawImage(
            img,
            pos[0] - size / 2,
            pos[1] - size / 2,
            size,
            size,
          );
        });
      },
    });
  },

  destroyed() {
    if (this.subscription) {
      this.subscription.unsubscribe();
    }
    if (this.resizeObserver) {
      this.resizeObserver.disconnect();
    }
    if (this.video) {
      this.video.remove();
    }
  },
};

export default BoidCanvasHook;
