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
    const WIDTH = this.el.clientWidth;
    const HEIGHT = this.el.clientHeight;
    const PAD = -40;
    const BMIN = [PAD, PAD];
    const BMAX = [WIDTH - PAD, HEIGHT - PAD];

    // Set canvas size
    this.el.width = WIDTH;
    this.el.height = HEIGHT;
    const ctx = this.el.getContext("2d");

    // Configure boids
    const NUM = 100;
    const ACCEL = new HashGrid2((x) => x.pos.prev, 64, NUM);
    const MAX_RADIUS = 50;

    // Boid behavior options
    const OPTS = {
      accel: ACCEL,
      behaviors: [separation(40, 1.2), alignment(80, 0.5), cohesion(80, 0.8)],
      maxSpeed: 50,
      constrain: wrap2(BMIN, BMAX),
    };

    // Setup gradient
    const gradient = multiCosineGradient({
      num: MAX_RADIUS + 1,
      stops: [
        [0.2, [0.8, 1, 1]],
        [0.4, [0.8, 1, 0.7]],
        [0.6, [1, 0.7, 0.1]],
        [1, [0.6, 0, 0.6]],
      ],
    });

    // Setup simulation
    const sim = defTimeStep();

    // Initialize flock
    const flock = defFlock(ACCEL, [
      ...repeatedly(
        () =>
          defBoid2(randMinMax2([], BMIN, BMAX), randNorm2([], OPTS.maxSpeed), {
            ...OPTS,
            maxSpeed: weightedRandom([20, 50, 100], [1, 4, 2])(),
          }),
        NUM,
      ),
    ]);

    // Animation loop
    const subscription = fromRAF({ timestamp: true }).subscribe({
      next: (t) => {
        // Update simulation
        sim.update(t, [flock]);

        // Clear canvas
        ctx.clearRect(0, 0, WIDTH, HEIGHT);

        // Draw boids
        flock.boids.forEach((boid) => {
          const pos = boid.pos.value;
          let radius = MAX_RADIUS;

          // Find neighbors
          const neighbors = boid.neighbors(radius, pos);
          if (neighbors.length > 1) {
            let closest = null;
            let minD = MAX_RADIUS ** 2;
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
          ctx.drawImage(img, pos[0] - size / 2, pos[1] - size / 2, size, size);
        });
      },
    });

    // Cleanup on destroy
    this.subscription = subscription;
  },

  destroyed() {
    if (this.subscription) {
      this.subscription.unsubscribe();
    }
  },
};

export default BoidCanvasHook;
