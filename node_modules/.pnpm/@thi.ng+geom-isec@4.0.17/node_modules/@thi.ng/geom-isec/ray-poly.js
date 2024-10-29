import { maddN2 } from "@thi.ng/vectors/maddn";
import { IntersectionType, NONE } from "./api.js";
import { checkPolyPair } from "./point.js";
import { intersectRayLine } from "./ray-line.js";
const __startPoints = (pts, closed) => closed ? [pts[pts.length - 1], pts[0]] : [pts[0], pts[1]];
const intersectRayPolyline = (rpos, dir, pts, closed = false, minD = 0, maxD = Infinity) => {
  const n = pts.length - 1;
  const [x, y] = rpos;
  let alpha = maxD;
  let cross = 0;
  let inside = 0;
  let [a, b] = __startPoints(pts, closed);
  for (let i = 0; i <= n; a = b, b = pts[++i]) {
    if (closed) {
      inside = checkPolyPair(x, y, a[0], a[1], b[0], b[1], inside);
    }
    const d = intersectRayLine(rpos, dir, a, b, minD, maxD).alpha;
    if (d !== void 0) {
      cross++;
      if (d < alpha) alpha = d;
    }
  }
  return cross > 0 ? {
    type: IntersectionType.INTERSECT,
    isec: [maddN2([], dir, alpha, rpos)],
    inside: !!inside,
    alpha
  } : NONE;
};
const intersectRayPolylineAll = (rpos, dir, pts, closed = false, minD = 0, maxD = Infinity) => {
  const n = pts.length - 1;
  const res = [];
  const [x, y] = rpos;
  let [a, b] = __startPoints(pts, closed);
  let inside = 0;
  for (let i = 0; i <= n; a = b, b = pts[++i]) {
    if (closed) {
      inside = checkPolyPair(x, y, a[0], a[1], b[0], b[1], inside);
    }
    const d = intersectRayLine(rpos, dir, a, b, minD, maxD).alpha;
    if (d !== void 0) {
      res.push([d, maddN2([], dir, d, rpos)]);
    }
  }
  if (res.length) {
    res.sort((a2, b2) => a2[0] - b2[0]);
    return {
      type: IntersectionType.INTERSECT,
      isec: res.map((x2) => x2[1]),
      alpha: res[0][0],
      beta: res[res.length - 1][0],
      inside: !!inside
    };
  }
  return NONE;
};
export {
  intersectRayPolyline,
  intersectRayPolylineAll
};
