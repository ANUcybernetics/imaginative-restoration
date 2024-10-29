import { SQRT2_2 } from "@thi.ng/math/api";
import { clamp01 } from "@thi.ng/math/interval";
const closestPointEllipse = ([px, py], [ex, ey], [rx, ry], n = 3) => {
  const apx = Math.abs(px - ex);
  const apy = Math.abs(py - ey);
  const ab = (rx * rx - ry * ry) / rx;
  const ba = (ry * ry - rx * rx) / ry;
  let tx = SQRT2_2;
  let ty = tx;
  for (; n-- > 0; ) {
    const _ex = ab * tx * tx * tx;
    const _ey = ba * ty * ty * ty;
    const qx = apx - _ex;
    const qy = apy - _ey;
    const q = Math.hypot(rx * tx - _ex, ry * ty - _ey) / Math.hypot(qx, qy);
    tx = clamp01((qx * q + _ex) / rx);
    ty = clamp01((qy * q + _ey) / ry);
    const t = Math.hypot(tx, ty);
    tx /= t;
    ty /= t;
  }
  return [rx * (px < ex ? -tx : tx) + ex, ry * (py < ey ? -ty : ty) + ey];
};
export {
  closestPointEllipse
};
