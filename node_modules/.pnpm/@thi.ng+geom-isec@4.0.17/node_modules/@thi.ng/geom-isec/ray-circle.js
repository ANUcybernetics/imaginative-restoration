import { dot } from "@thi.ng/vectors/dot";
import { maddN } from "@thi.ng/vectors/maddn";
import { magSq } from "@thi.ng/vectors/magsq";
import { sub } from "@thi.ng/vectors/sub";
import { IntersectionType, NONE } from "./api.js";
const intersectRayCircle = (rpos, dir, spos, r) => {
  const delta = sub([], spos, rpos);
  const w = dot(delta, dir);
  let d = r * r + w * w - magSq(delta);
  if (d < 0) return NONE;
  d = Math.sqrt(d);
  const a = w + d;
  const b = w - d;
  const isec = a >= 0 ? b >= 0 ? a > b ? (
    // prettier-ignore
    [false, b, a, [maddN(delta, dir, b, rpos), maddN([], dir, a, rpos)]]
  ) : (
    // prettier-ignore
    [false, a, b, [maddN(delta, dir, a, rpos), maddN([], dir, b, rpos)]]
  ) : [true, a, void 0, [maddN(delta, dir, a, rpos)]] : b >= 0 ? [true, b, void 0, [maddN(delta, dir, b, rpos)]] : void 0;
  return isec ? {
    type: IntersectionType.INTERSECT,
    inside: isec[0],
    alpha: isec[1],
    beta: isec[2],
    isec: isec[3]
  } : NONE;
};
export {
  intersectRayCircle
};
