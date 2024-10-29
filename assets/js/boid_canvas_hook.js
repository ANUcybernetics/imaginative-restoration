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
    // Initialize canvas dimensions
    this.width = this.el.clientWidth;
    this.height = this.el.clientHeight;
    this.pad = -40;
    this.bmin = [this.pad, this.pad];
    this.bmax = [this.width - this.pad, this.height - this.pad];

    // Set canvas size
    this.el.width = this.width;
    this.el.height = this.height;
    this.ctx = this.el.getContext("2d");

    // Configure boids
    this.numBoids = 50;
    this.accel = new HashGrid2((x) => x.pos.prev, 64, this.numBoids);
    this.maxRadius = 400;

    // Boid behavior options
    this.opts = {
      accel: this.accel,
      behaviors: [separation(40, 1.2), alignment(80, 0.5), cohesion(80, 0.8)],
      maxSpeed: 50,
      constrain: wrap2(this.bmin, this.bmax),
    };

    // Setup gradient
    this.gradient = multiCosineGradient({
      num: this.maxRadius + 1,
      stops: [
        [0.2, [0.8, 1, 1]],
        [0.4, [0.8, 1, 0.7]],
        [0.6, [1, 0.7, 0.1]],
        [1, [0.6, 0, 0.6]],
      ],
    });

    // Setup simulation
    this.sim = defTimeStep();

    // Initialize flock
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

    // Animation loop
    this.subscription = fromRAF({ timestamp: true }).subscribe({
      next: (t) => {
        // Update simulation
        this.sim.update(t, [this.flock]);

        // Clear canvas
        this.ctx.clearRect(0, 0, this.width, this.height);

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
  },
};

export default BoidCanvasHook;
