import { closestPointSegment } from "@thi.ng/geom-closest-point/line";
import { EPS } from "@thi.ng/math/api";
import { eqDelta } from "@thi.ng/math/eqdelta";
import { mixN2 } from "@thi.ng/vectors/mixn";
import { IntersectionType } from "./api.js";
const intersectLineLine = (a, b, c, d, eps = EPS) => {
  const bax = b[0] - a[0];
  const bay = b[1] - a[1];
  const dcx = d[0] - c[0];
  const dcy = d[1] - c[1];
  const acx = a[0] - c[0];
  const acy = a[1] - c[1];
  const det = dcy * bax - dcx * bay;
  let alpha = dcx * acy - dcy * acx;
  let beta = bax * acy - bay * acx;
  if (eqDelta(det, 0, eps)) {
    if (eqDelta(alpha, 0, eps) && eqDelta(beta, 0, eps)) {
      let isec = closestPointSegment(c, a, b, void 0, true) || closestPointSegment(d, a, b, void 0, true);
      return {
        type: isec ? IntersectionType.COINCIDENT : IntersectionType.COINCIDENT_NO_INTERSECT,
        isec: isec ? [isec] : isec
      };
    }
    return { type: IntersectionType.PARALLEL };
  }
  alpha /= det;
  beta /= det;
  const ieps = 1 - eps;
  return {
    type: eps < alpha && alpha < ieps && eps < beta && beta < ieps ? IntersectionType.INTERSECT : IntersectionType.INTERSECT_OUTSIDE,
    isec: [mixN2([], a, b, alpha)],
    alpha,
    beta,
    det
  };
};
const isParallelLine = (a, b, c, d) => eqDelta((d[1] - c[1]) * (b[0] - a[0]) - (d[0] - c[0]) * (b[1] - a[1]), 0);
export {
  intersectLineLine,
  isParallelLine
};
