import { maddN } from "@thi.ng/vectors/maddn";
import { IntersectionType, NONE } from "./api.js";
const { min, max } = Math;
const __rayRect = (rpos, dir, bmin, bmax) => {
  let p = rpos[0];
  let d = 1 / dir[0];
  let t1 = (bmin[0] - p) * d;
  let t2 = (bmax[0] - p) * d;
  let tmin = min(t1, t2);
  let tmax = max(t1, t2);
  p = rpos[1];
  d = 1 / dir[1];
  t1 = (bmin[1] - p) * d;
  t2 = (bmax[1] - p) * d;
  return [max(tmin, min(t1, t2)), min(tmax, max(t1, t2))];
};
const __rayBox = (rpos, dir, bmin, bmax) => {
  let p = rpos[0];
  let d = 1 / dir[0];
  let t1 = (bmin[0] - p) * d;
  let t2 = (bmax[0] - p) * d;
  let tmin = min(t1, t2);
  let tmax = max(t1, t2);
  p = rpos[1];
  d = 1 / dir[1];
  t1 = (bmin[1] - p) * d;
  t2 = (bmax[1] - p) * d;
  tmin = max(tmin, min(t1, t2));
  tmax = min(tmax, max(t1, t2));
  p = rpos[2];
  d = 1 / dir[2];
  t1 = (bmin[2] - p) * d;
  t2 = (bmax[2] - p) * d;
  return [max(tmin, min(t1, t2)), min(tmax, max(t1, t2))];
};
const __intersectWith = (fn) => (rpos, dir, bmin, bmax) => {
  const t = fn(rpos, dir, bmin, bmax);
  const tmin = t[0];
  const tmax = t[1];
  const inside = tmin < 0;
  return tmax > max(tmin, 0) ? inside ? {
    type: IntersectionType.INTERSECT,
    isec: [maddN([], dir, tmax, rpos)],
    alpha: tmax,
    inside
  } : {
    type: IntersectionType.INTERSECT,
    isec: [
      maddN([], dir, tmin, rpos),
      maddN([], dir, tmax, rpos)
    ],
    alpha: tmin,
    beta: tmax
  } : NONE;
};
const intersectRayRect = __intersectWith(__rayRect);
const intersectRayAABB = __intersectWith(__rayBox);
const testRayRect = (rpos, dir, bmin, bmax) => {
  const t = __rayRect(rpos, dir, bmin, bmax);
  return t[1] > max(t[0], 0);
};
const testRayAABB = (rpos, dir, bmin, bmax) => {
  const t = __rayBox(rpos, dir, bmin, bmax);
  return t[1] > max(t[0], 0);
};
export {
  intersectRayAABB,
  intersectRayRect,
  testRayAABB,
  testRayRect
};
