# SVG → PNG（librsvg，不開瀏覽器，幾乎不吃記憶體）。用法：python3 harness/svg2png.py in.svg out.png [scale]
import sys
import gi
gi.require_version('Rsvg', '2.0')
from gi.repository import Rsvg
import cairo

src, dst = sys.argv[1], sys.argv[2]
scale = float(sys.argv[3]) if len(sys.argv) > 3 else 2.0
h = Rsvg.Handle.new_from_file(src)
ok, w, hh = h.get_intrinsic_size_in_pixels()
surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, int(w * scale), int(hh * scale))
ctx = cairo.Context(surf)
ctx.scale(scale, scale)
vp = Rsvg.Rectangle()
vp.x, vp.y, vp.width, vp.height = 0, 0, w, hh
h.render_document(ctx, vp)
surf.write_to_png(dst)
