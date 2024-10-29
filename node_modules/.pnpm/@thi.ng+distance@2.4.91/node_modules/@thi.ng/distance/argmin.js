import { isFunction } from "@thi.ng/checks/is-function";
import { knearest } from "./knearest.js";
import { DIST_SQ, DIST_SQ1 } from "./squared.js";
const argmin = (p, samples, dist = DIST_SQ) => {
  const distFn = isFunction(dist) ? dist : dist.metric;
  let minD = Infinity;
  let minArg = -1;
  for (let i = 0, n = samples.length; i < n; i++) {
    const d = distFn(p, samples[i]);
    if (d < minD) {
      minD = d;
      minArg = i;
    }
  }
  return minArg;
};
const argminN = (p, samples, dist = DIST_SQ1) => {
  const distFn = isFunction(dist) ? dist : dist.metric;
  let minD = Infinity;
  let minArg = -1;
  for (let i = 0, n = samples.length; i < n; i++) {
    const d = distFn(p, samples[i]);
    if (d < minD) {
      minD = d;
      minArg = i;
    }
  }
  return minArg;
};
const argminT = (p, samples, key, dist) => argmin(key(p), samples.map(key), dist);
const argminK = (k, p, samples, dist = DIST_SQ) => {
  const neighborhood = knearest(p, k, Infinity, dist);
  for (let i = 0, n = samples.length; i < n; i++) {
    neighborhood.consider(samples[i], i);
  }
  return neighborhood.values();
};
const argminKT = (k, p, samples, key, dist) => argminK(k, key(p), samples.map(key), dist);
export {
  argmin,
  argminK,
  argminKT,
  argminN,
  argminT
};
