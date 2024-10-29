import { dot } from "@thi.ng/vectors/dot";
import { normalize } from "@thi.ng/vectors/normalize";
import { sub } from "@thi.ng/vectors/sub";
const distToPlane = (p, n, w) => dot(n, p) - w;
const closestPointPlane = (p, normal, w, out = []) => sub(out, p, normalize(out, normal, distToPlane(p, normal, w)));
export {
  closestPointPlane,
  distToPlane
};
