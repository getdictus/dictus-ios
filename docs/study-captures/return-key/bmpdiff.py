# Usage: bmpdiff.py a.bmp b.bmp -> bounding box of differing pixels (24/32-bit BMP)
import struct, sys
def load(p):
    d = open(p, 'rb').read()
    off = struct.unpack_from('<I', d, 10)[0]
    w, h = struct.unpack_from('<ii', d, 18)
    bpp = struct.unpack_from('<H', d, 28)[0] // 8
    row = (w * bpp + 3) & ~3
    return d, off, w, h, bpp, row
def px(img, x, y):
    d, off, w, h, bpp, row = img
    yy = (h - 1 - y) if h > 0 else y
    i = off + yy * row + x * bpp
    return d[i + 2], d[i + 1], d[i]
a, b = load(sys.argv[1]), load(sys.argv[2])
w, h = a[2], abs(a[3])
xs, ys = [], []
for y in range(0, h, 2):
    for x in range(0, w, 2):
        pa, pb = px(a, x, y), px(b, x, y)
        if max(abs(pa[k] - pb[k]) for k in range(3)) > 24:
            xs.append(x); ys.append(y)
print("no difference" if not xs else f"diff bbox x {min(xs)}-{max(xs)} y {min(ys)}-{max(ys)} ({len(xs)} samples)")
