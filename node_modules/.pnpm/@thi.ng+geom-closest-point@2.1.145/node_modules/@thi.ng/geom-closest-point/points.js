import { distSq } from "@thi.ng/vectors/distsq";
import { set } from "@thi.ng/vectors/set";
const closestPointArray = (p, pts, out = [], dist = distSq) => {
  let minD = Infinity;
  let closest;
  for (let i = pts.length; i-- > 0; ) {
    const d = dist(pts[i], p);
    if (d < minD) {
      minD = d;
      closest = pts[i];
    }
  }
  return closest ? set(out, closest) : void 0;
};
export {
  closestPointArray
};
