/* A dotted 3D surface you can orbit. The heights sit on springs joined to their neighbours, so the
   surface carries waves: moving the cursor across it leaves a wake, a click makes a splash, and
   switching layers sends the change across as a front.

   cfg = { R, C, layers: {name: Float32Array(R*C) in 0..1}, layer, band: Int16Array(R), center: [row per band],
           rowTicks: [{r, text}], colTicks: [{c, text}], callout(band, col, layer) -> [title, blue, dim],
           size: [x, z, y], yaw, pitch } */
function makeSurface(canvas, cfg) {
  const { R, C } = cfg, N = R * C;
  const [SX, SZ, SY] = cfg.size || [2.1, 1.5, 0.8];
  const h = new Float32Array(N), v = new Float32Array(N), tg = new Float32Array(N), E = new Float32Array(N);
  const from = new Float32Array(N); let to = cfg.layers[cfg.layer];
  const px = new Float32Array(N), py = new Float32Array(N), pb = new Uint8Array(N);
  const S = { layer: cfg.layer, sweep: 0, yaw: cfg.yaw == null ? -0.62 : cfg.yaw, pitch: cfg.pitch == null ? 0.52 : cfg.pitch, yawV: 0, pitchV: 0, idle: 9, near: -1, band: -1 };

  function kick(node, amount, radius) {
    const r0 = (node / C) | 0, c0 = node % C, sr = radius * R / 110, sc = radius * C / 200, rr = Math.ceil(sr * 2.5), rc = Math.ceil(sc * 2.5);
    for (let r = Math.max(0, r0 - rr); r <= Math.min(R - 1, r0 + rr); r++) for (let c = Math.max(0, c0 - rc); c <= Math.min(C - 1, c0 + rc); c++) {
      const dr = (r - r0) / sr, dc = (c - c0) / sc;
      v[r * C + c] += amount * Math.exp(-(dr * dr + dc * dc));
    }
  }
  function step(dt) {
    for (let i = 0; i < N; i++) E[i] = h[i] - tg[i];
    for (let r = 0; r < R; r++) {
      const up = r > 0 ? -C : 0, dn = r < R - 1 ? C : 0;
      for (let c = 0; c < C; c++) {
        const i = r * C + c, e = E[i];
        const lap = E[i + up] + E[i + dn] + E[c > 0 ? i - 1 : i] + E[c < C - 1 ? i + 1 : i] - 4 * e;
        v[i] += (-42 * e + 400 * lap - 3.2 * v[i]) * dt;
      }
    }
    for (let i = 0; i < N; i++) h[i] += v[i] * dt;
  }

  const ALPHA = [0.16, 0.3, 0.46, 0.64, 0.82, 1];
  const obj = {
    down() { S.yawV = S.pitchV = 0; S.idle = 0; },
    drag(st, dx, dy) { S.yaw += dx * 0.0055; S.pitch = clamp(S.pitch + dy * 0.004, 0.16, 1.3); S.yawV = dx * 0.0055 * 60; S.pitchV = dy * 0.004 * 60; S.idle = 0; },
    click() { if (S.near >= 0) kick(S.near, 3.4, 5); },
    frame(st, dt) {
      const { ctx, W, H } = st, P = st.ptr;
      ctx.clearRect(0, 0, W, H);

      /* layer change travels across the columns */
      if (S.sweep < 1) {
        S.sweep = Math.min(1, S.sweep + dt / 1.3);
        for (let c = 0; c < C; c++) {
          const w = smooth(S.sweep * 1.7 - c / (C - 1) * 0.7);
          for (let r = 0; r < R; r++) { const i = r * C + c; tg[i] = from[i] + (to[i] - from[i]) * w; }
        }
      }
      if (P.inside && !P.down && S.near >= 0 && P.speed > 0.5) kick(S.near, -0.011 * Math.min(P.speed, 45), 3.2);
      step(dt / 2); step(dt / 2);

      S.idle += dt;
      if (!P.down) {
        S.yaw += S.yawV * dt; S.pitch = clamp(S.pitch + S.pitchV * dt, 0.16, 1.3);
        const f = Math.exp(-2.6 * dt); S.yawV *= f; S.pitchV *= f;
      }
      const yaw = S.yaw + 0.07 * Math.sin(st.t * 0.23) * smooth((S.idle - 1) / 3), pitch = S.pitch;
      const cy_ = Math.cos(yaw), sy_ = Math.sin(yaw), cp = Math.cos(pitch), sp = Math.sin(pitch);
      const F = 4.2, scale = Math.min(W / 3.3, H / 2.05), cx = W / 2, cy = H * 0.5 + scale * 0.2;
      const proj = (x, y, z) => {
        const xr = x * cy_ - z * sy_, zr = x * sy_ + z * cy_, yv = y * cp + zr * sp, dv = zr * cp - y * sp, s = F / (F + dv) * scale;
        return [cx + xr * s, cy - yv * s, dv];
      };

      /* project every node, find the one under the cursor, sort into brightness buckets */
      const mx = P.inside ? P.x : -1e4, my = P.y, hb = S.band;
      let near = -1, nd = 1600;
      for (let r = 0; r < R; r++) {
        const z = (r / (R - 1) - 0.5) * SZ, blue = cfg.band[r] === hb;
        for (let c = 0; c < C; c++) {
          const i = r * C + c, x = (c / (C - 1) - 0.5) * SX, y = h[i] * SY;
          const xr = x * cy_ - z * sy_, zr = x * sy_ + z * cy_, yv = y * cp + zr * sp, dv = zr * cp - y * sp, s = F / (F + dv) * scale;
          const X = px[i] = cx + xr * s, Y = py[i] = cy - yv * s;
          const d2 = (X - mx) * (X - mx) + (Y - my) * (Y - my);
          if (d2 < nd) { nd = d2; near = i; }
          const fog = clamp(1.05 - (dv + 1) * 0.3, 0.45, 1), a = (0.1 + 1.25 * Math.max(0, h[i])) * fog + Math.min(0.5, Math.abs(v[i]) * 0.35);
          pb[i] = blue ? 5 : a < 0.2 ? 0 : a < 0.36 ? 1 : a < 0.54 ? 2 : a < 0.74 ? 3 : 4;
        }
      }
      if (!P.down) { S.near = near; S.band = near >= 0 ? cfg.band[(near / C) | 0] : -1; }

      /* back to front, each line hiding what is behind it */
      const byRow = Math.abs(cy_) >= Math.abs(sy_);
      const nL = byRow ? R : C, nP = byRow ? C : R, farFirst = byRow ? cy_ > 0 : sy_ > 0;
      const idx = byRow ? (l, p) => l * C + p : (l, p) => p * C + l;
      for (let q = 0; q < nL; q++) {
        const l = farFirst ? nL - 1 - q : q;
        const a0 = byRow ? proj(-SX / 2, 0, (l / (R - 1) - 0.5) * SZ) : proj((l / (C - 1) - 0.5) * SX, 0, -SZ / 2);
        const a1 = byRow ? proj(SX / 2, 0, (l / (R - 1) - 0.5) * SZ) : proj((l / (C - 1) - 0.5) * SX, 0, SZ / 2);
        ctx.globalAlpha = 0.94; ctx.fillStyle = BG; ctx.beginPath(); ctx.moveTo(a0[0], a0[1] + 1.5);
        for (let p = 0; p < nP; p++) { const i = idx(l, p); ctx.lineTo(px[i], py[i] + 1.5); }
        ctx.lineTo(a1[0], a1[1] + 1.5); ctx.closePath(); ctx.fill();
        for (let b = 0; b < 6; b++) {
          let any = false;
          for (let p = 0; p < nP; p++) {
            const i = idx(l, p); if (pb[i] !== b) continue;
            if (!any) { ctx.beginPath(); any = true; }
            const s = b === 5 ? 1.7 : 1.25; ctx.rect(px[i] - s / 2, py[i] - s / 2, s, s);
          }
          if (any) { ctx.fillStyle = b === 5 ? BLUE : FG; ctx.globalAlpha = ALPHA[b]; ctx.fill(); }
        }
      }

      /* axis ticks on the two edges nearest the camera */
      const zEdge = (cy_ > 0 ? -1 : 1) * (SZ / 2 + 0.07), xEdge = (sy_ > 0 ? -1 : 1) * (SX / 2 + 0.06);
      for (const t of cfg.colTicks) { const p = proj((t.c / (C - 1) - 0.5) * SX, 0, zEdge); label(ctx, t.text, p[0], p[1] + 12, DIM, 'center', 10); }
      for (const t of cfg.rowTicks) {
        const p = proj(xEdge, 0, (t.r / (R - 1) - 0.5) * SZ), right = p[0] > cx, on = cfg.band[t.r] === S.band;
        label(ctx, t.text, p[0] + (right ? 8 : -8), p[1] + 3, on ? BLUE : DIM, right ? 'left' : 'right', 10);
      }

      /* callout */
      if (S.band >= 0 && S.near >= 0 && P.inside) {
        const c = S.near % C, i = cfg.center[S.band] * C + c, x = px[i], y = py[i], top = Math.max(44, y - 70);
        const lines = cfg.callout(S.band, c, S.layer);
        ctx.globalAlpha = 1; ctx.strokeStyle = '#aaa'; ctx.lineWidth = 0.8; ctx.beginPath(); ctx.moveTo(x, y - 3); ctx.lineTo(x, top + 6); ctx.stroke();
        ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(x, y, 2.6, 0, 6.2832); ctx.fill();
        const right = x < W - 250, tx = x + (right ? 7 : -7), al = right ? 'left' : 'right';
        label(ctx, lines[0], tx, top - 14, '#fff', al, 12, 600);
        label(ctx, lines[1], tx, top, BLUE, al, 10);
        label(ctx, lines[2], tx, top + 13, DIM, al, 10);
      }
    },
  };

  canvas.style.cursor = 'grab';
  canvas.style.touchAction = 'pan-y';
  const api = {
    S,
    setLayer(name) { if (name === S.layer) return; S.layer = name; from.set(tg); to = cfg.layers[name]; S.sweep = 0; },
  };
  api.stage = makeStage(canvas, obj);
  return api;
}
