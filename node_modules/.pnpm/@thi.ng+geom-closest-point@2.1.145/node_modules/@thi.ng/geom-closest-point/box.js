import { clamp } from "@thi.ng/math/interval";
import { setC2, setC3 } from "@thi.ng/vectors/setc";
const closestPointRect = (p, bmin, bmax, out = []) => {
  const [minID, minW] = __closestBoxEdge(p, bmin, bmax, 4);
  return minID === 0 ? setC2(out, minW, clamp(p[1], bmin[1], bmax[1])) : setC2(out, clamp(p[0], bmin[0], bmax[0]), minW);
};
const closestPointAABB = (p, bmin, bmax, out = []) => {
  const [minID, minW] = __closestBoxEdge(p, bmin, bmax, 6);
  return minID === 0 ? setC3(
    out,
    minW,
    clamp(p[1], bmin[1], bmax[1]),
    clamp(p[2], bmin[2], bmax[2])
  ) : minID === 1 ? setC3(
    out,
    clamp(p[0], bmin[0], bmax[0]),
    minW,
    clamp(p[2], bmin[2], bmax[2])
  ) : setC3(
    out,
    clamp(p[0], bmin[0], bmax[0]),
    clamp(p[1], bmin[1], bmax[1]),
    minW
  );
};
const __closestBoxEdge = (p, bmin, bmax, n) => {
  let minD = Infinity;
  let minID;
  let minW;
  for (let i = 0; i < n; i++) {
    const j = i >> 1;
    const w = (i & 1 ? bmax : bmin)[j];
    const d = Math.abs(p[j] - w);
    if (d < minD) {
      minD = d;
      minID = j;
      minW = w;
    }
  }
  return [minID, minW];
};
export {
  closestPointAABB,
  closestPointRect
};
