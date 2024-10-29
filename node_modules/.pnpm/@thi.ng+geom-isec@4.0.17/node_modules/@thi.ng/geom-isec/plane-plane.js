import { eqDelta } from "@thi.ng/math/eqdelta";
import { add3 } from "@thi.ng/vectors/add";
import { cross3 } from "@thi.ng/vectors/cross";
import { dot3 } from "@thi.ng/vectors/dot";
import { mulN3 } from "@thi.ng/vectors/muln";
import { IntersectionType, NONE } from "./api.js";
const intersectPlanePlane = (na, wa, nb, wb) => {
  const dn = dot3(na, nb);
  if (eqDelta(dn, 1)) {
    return eqDelta(wa, wb) ? { type: IntersectionType.COINCIDENT } : NONE;
  }
  const det = 1 / (1 - dn * dn);
  const da = (wa - wb * dn) * det;
  const db = (wb - wa * dn) * det;
  return {
    type: IntersectionType.INTERSECT,
    isec: [
      add3(null, mulN3([], na, da), mulN3([], nb, db)),
      cross3([], na, nb)
    ]
  };
};
export {
  intersectPlanePlane
};
