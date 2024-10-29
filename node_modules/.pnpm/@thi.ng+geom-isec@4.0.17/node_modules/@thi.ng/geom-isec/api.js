var IntersectionType = /* @__PURE__ */ ((IntersectionType2) => {
  IntersectionType2[IntersectionType2["NONE"] = 0] = "NONE";
  IntersectionType2[IntersectionType2["PARALLEL"] = 1] = "PARALLEL";
  IntersectionType2[IntersectionType2["COINCIDENT"] = 2] = "COINCIDENT";
  IntersectionType2[IntersectionType2["COINCIDENT_NO_INTERSECT"] = 3] = "COINCIDENT_NO_INTERSECT";
  IntersectionType2[IntersectionType2["INTERSECT"] = 4] = "INTERSECT";
  IntersectionType2[IntersectionType2["INTERSECT_OUTSIDE"] = 5] = "INTERSECT_OUTSIDE";
  return IntersectionType2;
})(IntersectionType || {});
const NONE = Object.freeze({
  type: 0 /* NONE */
});
export {
  IntersectionType,
  NONE
};
