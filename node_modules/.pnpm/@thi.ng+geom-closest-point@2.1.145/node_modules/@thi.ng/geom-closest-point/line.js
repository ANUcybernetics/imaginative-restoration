import { dist } from "@thi.ng/vectors/dist";
import { distSq } from "@thi.ng/vectors/distsq";
import { dot } from "@thi.ng/vectors/dot";
import { empty } from "@thi.ng/vectors/empty";
import { magSq } from "@thi.ng/vectors/magsq";
import { mixN } from "@thi.ng/vectors/mixn";
import { set } from "@thi.ng/vectors/set";
import { sub } from "@thi.ng/vectors/sub";
const closestT = (p, a, b) => {
  const d = sub([], b, a);
  const l = magSq(d);
  return l > 1e-6 ? dot(sub([], p, a), d) / l : void 0;
};
const closestPointLine = (p, a, b) => mixN([], a, b, closestT(p, a, b) || 0);
const distToLine = (p, a, b) => dist(p, closestPointLine(p, a, b) || a);
const closestPointSegment = (p, a, b, out, insideOnly = false, eps = 0) => {
  const t = closestT(p, a, b);
  if (t !== void 0 && (!insideOnly || t >= eps && t <= 1 - eps)) {
    out = out || empty(p);
    return t <= 0 ? set(out, a) : t >= 1 ? set(out, b) : mixN(out, a, b, t);
  }
};
const distToSegment = (p, a, b) => dist(p, closestPointSegment(p, a, b) || a);
const closestPointPolyline = (p, pts, closed = false, out = []) => {
  if (!pts.length) return;
  const tmp = [];
  const n = pts.length - 1;
  let minD = Infinity, i, j;
  if (closed) {
    i = n;
    j = 0;
  } else {
    i = 0;
    j = 1;
  }
  for (; j <= n; i = j, j++) {
    if (closestPointSegment(p, pts[i], pts[j], tmp)) {
      const d = distSq(p, tmp);
      if (d < minD) {
        minD = d;
        set(out, tmp);
      }
    }
  }
  return minD < Infinity ? out : void 0;
};
const farthestPointSegment = (a, b, points, from = 0, to = points.length) => {
  let maxD = -1;
  let maxIdx = -1;
  const tmp = empty(a);
  for (let i = from; i < to; i++) {
    const p = points[i];
    const d = distSq(p, closestPointSegment(p, a, b, tmp) || a);
    if (d > maxD) {
      maxD = d;
      maxIdx = i;
    }
  }
  return [maxIdx, Math.sqrt(maxD)];
};
export {
  closestPointLine,
  closestPointPolyline,
  closestPointSegment,
  closestT,
  distToLine,
  distToSegment,
  farthestPointSegment
};
