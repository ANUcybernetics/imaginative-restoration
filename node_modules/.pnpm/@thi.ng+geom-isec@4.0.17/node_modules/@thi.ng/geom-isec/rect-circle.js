import { vop } from "@thi.ng/vectors/vop";
const testBoxSphere = vop(0);
const testRectCircle = testBoxSphere.add(
  2,
  (boxMinPos, boxSize, circlePos, r) => __axis(circlePos[0], boxMinPos[0], boxSize[0]) + __axis(circlePos[1], boxMinPos[1], boxSize[1]) <= r * r
);
const testAABBSphere = testBoxSphere.add(
  3,
  (boxMinPos, boxSize, spherePos, r) => __axis(spherePos[0], boxMinPos[0], boxSize[0]) + __axis(spherePos[1], boxMinPos[1], boxSize[1]) + __axis(spherePos[2], boxMinPos[2], boxSize[2]) <= r * r
);
testBoxSphere.default((boxPos, boxSize, spherePos, r) => {
  let sum = 0;
  for (let i = boxPos.length; i-- > 0; ) {
    sum += __axis(spherePos[i], boxPos[i], boxSize[i]);
  }
  return sum <= r * r;
});
const testCenteredBoxSphere = vop(0);
const testCenteredRectCircle = testCenteredBoxSphere.add(
  2,
  (boxPos, { 0: w, 1: h }, circlePos, r) => __axis(circlePos[0], boxPos[0] - w, w * 2) + __axis(circlePos[1], boxPos[1] - h, h * 2) <= r * r
);
const testCenteredAABBSphere = testCenteredBoxSphere.add(
  3,
  (boxPos, { 0: w, 1: h, 2: d }, spherePos, r) => __axis(spherePos[0], boxPos[0] - w, w * 2) + __axis(spherePos[1], boxPos[1] - h, h * 2) + __axis(spherePos[2], boxPos[2] - d, d * 2) <= r * r
);
testCenteredBoxSphere.default((boxPos, boxExtent, spherePos, r) => {
  let sum = 0;
  for (let i = boxPos.length; i-- > 0; ) {
    sum += __axis(spherePos[i], boxPos[i] - boxExtent[i], boxExtent[i] * 2);
  }
  return sum <= r * r;
});
const __axis = (a, b, c) => (a < b ? a - b : a > b + c ? a - b - c : 0) ** 2;
export {
  testAABBSphere,
  testBoxSphere,
  testCenteredAABBSphere,
  testCenteredBoxSphere,
  testCenteredRectCircle,
  testRectCircle
};
