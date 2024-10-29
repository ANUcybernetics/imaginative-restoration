const testRectRect = ([ax, ay], [aw, ah], [bx, by], [bw, bh]) => !(ax > bx + bw || bx > ax + aw || ay > by + bh || by > ay + ah);
const testAabbAabb = ([ax, ay, az], [aw, ah, ad], [bx, by, bz], [bw, bh, bd]) => !(ax > bx + bw || bx > ax + aw || ay > by + bh || by > ay + ah || az > bz + bd || bz > az + ad);
export {
  testAabbAabb,
  testRectRect
};
