import { Heap } from "./heap.js";
const defDHeap = (values, opts) => new DHeap(values, opts);
class DHeap extends Heap {
  /**
   * Returns index of parent node or -1 if `idx < 1`.
   *
   * @param idx - index
   * @param d - branch factor
   */
  static parentIndex(idx, d = 4) {
    return idx > 0 ? (idx - 1) / d | 0 : -1;
  }
  /**
   * Returns index of 1st child or -1 if `idx < 0`.
   *
   * @param idx - index
   * @param d - branch factor
   */
  static childIndex(idx, d = 4) {
    return idx >= 0 ? idx * d + 1 : -1;
  }
  d;
  constructor(values, opts) {
    super(void 0, opts);
    this.d = opts && opts.d || 4;
    this.values = [];
    values && this.into(values);
  }
  copy() {
    return super.copy();
  }
  empty() {
    return new DHeap(null, { compare: this.compare, d: this.d });
  }
  parent(n) {
    n = DHeap.parentIndex(n, this.d);
    return n >= 0 ? this.values[n] : void 0;
  }
  children(n) {
    n = DHeap.childIndex(n, this.d);
    const vals = this.values;
    if (n >= vals.length) return;
    return vals.slice(n, n + this.d);
  }
  leaves() {
    const vals = this.values;
    if (!vals.length) {
      return [];
    }
    return vals.slice(DHeap.parentIndex(vals.length - 1, this.d) + 1);
  }
  heapify(vals = this.values) {
    for (let i = (vals.length - 1) / this.d | 0; i >= 0; i--) {
      this.percolateDown(i, vals);
    }
  }
  percolateUp(i, vals = this.values) {
    const node = vals[i];
    const { d, compare } = this;
    while (i > 0) {
      const pi = (i - 1) / d | 0;
      const parent = vals[pi];
      if (compare(node, parent) >= 0) {
        break;
      }
      vals[pi] = node;
      vals[i] = parent;
      i = pi;
    }
  }
  percolateDown(i, vals = this.values) {
    const n = vals.length;
    const d = this.d;
    const node = vals[i];
    const cmp = this.compare;
    let child = i * d + 1, minChild;
    while (child < n) {
      minChild = child;
      for (let j = child + 1, k = child + d; j < k; j++) {
        if (j < n && cmp(vals[j], vals[minChild]) < 0) {
          minChild = j;
        }
      }
      if (cmp(vals[minChild], node) < 0) {
        vals[i] = vals[minChild];
      } else {
        break;
      }
      i = minChild;
      child = i * d + 1;
    }
    vals[i] = node;
  }
}
export {
  DHeap,
  defDHeap
};
