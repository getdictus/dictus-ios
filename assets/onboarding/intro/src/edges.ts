import type { Ctx, Env } from "./core";
import { FRAME } from "./theme";

// THE FRAME'S EDGE (issue #667). The video sits on the onboarding page and its edge must not
// show: the page colour has to come back out of the decoder exactly, all round the frame. Anything
// drawn close to the edge (a fade that ends exactly on it, a light band, a shadow) leaves a trace
// of a few percent there, and the encoder's noise around nearby content does the rest. So after
// a scene is drawn, a band round the frame is cleared: fully for the outer CLEAR pixels, then
// fading back in over RAMP more. Frame pixels; scenes keep what matters further in than that.
const CLEAR = 24, RAMP = 40;

export const clearEdges = (ctx: Ctx, env: Env) => {
  const s = env.scale, W = FRAME.w, H = FRAME.h, d = CLEAR + RAMP;
  ctx.save();
  ctx.setTransform(s, 0, 0, s, 0, 0);
  ctx.globalCompositeOperation = "destination-out";
  const side = (x0: number, y0: number, x1: number, y1: number, rx: number, ry: number, rw: number, rh: number) => {
    const g = ctx.createLinearGradient(x0, y0, x1, y1);
    g.addColorStop(0, "rgba(0,0,0,1)"); g.addColorStop(CLEAR / d, "rgba(0,0,0,1)"); g.addColorStop(1, "rgba(0,0,0,0)");
    ctx.fillStyle = g; ctx.fillRect(rx, ry, rw, rh);
  };
  side(0, 0, d, 0, 0, 0, d, H);
  side(W, 0, W - d, 0, W - d, 0, d, H);
  side(0, 0, 0, d, 0, 0, W, d);
  side(0, H, 0, H - d, 0, H - d, W, d);
  ctx.restore();
};
