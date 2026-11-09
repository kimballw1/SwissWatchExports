/* Every dot is a fixed number of watches (or francs). The dots in play stack into four bars, one per
   kind of watch, each dot held in place by a spring. Dots that drop out of a year fall to the floor
   under gravity. The cursor pushes dots away; a click throws them. */
function makeParticles(canvas, D, opts) {
  const TIERS = [
    ['steel_quartz', 'STEEL QUARTZ', '#737373'],
    ['steel_mech', 'STEEL MECHANICAL', '#f4f4f4'],
    ['precious_quartz', 'PRECIOUS QUARTZ', '#9cc0ff'],
    ['precious_mech', 'PRECIOUS MECHANICAL', BLUE],
  ];
  const NDOT = 2000, COLS = 34, nY = D.years.length;
  const maxOf = key => Math.max(...D.years.map((_, i) => TIERS.reduce((s, t) => s + D.tiers[t[0]][key][i], 0)));
  const unit = { units: maxOf('units') / NDOT, value: maxOf('value') / NDOT };
  const NP = NDOT + 40;

  const x = new Float32Array(NP), y = new Float32Array(NP), vx = new Float32Array(NP), vy = new Float32Array(NP);
  const tier = new Int8Array(NP).fill(-1), was = new Int8Array(NP), slot = new Int16Array(NP), k = new Float32Array(NP), rest = new Float32Array(NP);
  const lists = [[], [], [], []], free = [];
  const S = { mode: 'units', year: 0, started: false, counts: [0, 0, 0, 0] };
  let W = 0, H = 0, cell = 6, base = 0, floor = 0, barX = [0, 0, 0, 0];

  function layout(st) {
    W = st.W; H = st.H;
    const gap = Math.max(14, W * 0.035);
    cell = Math.min(6.4, (W - 40 - gap * 3) / (COLS * 4));
    const total = COLS * cell * 4 + gap * 3, x0 = (W - total) / 2;
    for (let t = 0; t < 4; t++) barX[t] = x0 + t * (COLS * cell + gap);
    floor = H - 16; base = H - 92;
  }
  function seed() {
    for (let i = 0; i < NP; i++) {
      x[i] = Math.random() * W; y[i] = floor - Math.random() * 6; rest[i] = Math.random() * 7; k[i] = 55 + Math.random() * 70;
      was[i] = (Math.random() * 4) | 0; free.push(i);
    }
  }
  function assign() {
    const yi = S.year, key = S.mode;
    for (let t = 0; t < 4; t++) {
      const need = Math.round(at(D.tiers[TIERS[t][0]][key], yi) / unit[key]), L = lists[t];
      S.counts[t] = need;
      while (L.length > need) { const i = L.pop(); was[i] = tier[i]; tier[i] = -1; vx[i] += (Math.random() - 0.5) * 160; vy[i] -= Math.random() * 60; free.push(i); }
    }
    for (let t = 0; t < 4; t++) {
      const L = lists[t];
      while (L.length < S.counts[t] && free.length) {
        // take the nearest of a few random floor dots so they rise from under their own bar
        let bi = free.length - 1, bd = 1e9; const tx = barX[t] + COLS * cell / 2;
        for (let q = 0; q < 6; q++) { const j = (Math.random() * free.length) | 0, dd = Math.abs(x[free[j]] - tx); if (dd < bd) { bd = dd; bi = j; } }
        const i = free[bi]; free[bi] = free[free.length - 1]; free.pop();
        tier[i] = t; slot[i] = L.length; L.push(i);
      }
    }
  }

  const obj = {
    resize(st) { layout(st); },
    click(st) {
      const P = st.ptr;
      for (let i = 0; i < NP; i++) {
        const dx = x[i] - P.x, dy = y[i] - P.y, d = Math.hypot(dx, dy);
        if (d < 190) { const f = (1 - d / 190) * 950 / (d + 8); vx[i] += dx * f; vy[i] += dy * f - 120 * (1 - d / 190); }
      }
    },
    frame(st, dt) {
      const { ctx } = st, P = st.ptr;
      if (!S.started) { layout(st); seed(); S.started = true; }
      if (opts.tick) opts.tick(dt);
      assign();
      ctx.clearRect(0, 0, W, H);

      const mx = P.inside ? P.x : -1e4, my = P.y, RR = 95, push = 5200 + Math.min(P.speed, 40) * 160;
      for (let i = 0; i < NP; i++) {
        let ax = 0, ay = 0;
        const t = tier[i];
        if (t >= 0) {
          const s = slot[i], tx = barX[t] + (s % COLS + 0.5) * cell, ty = base - (((s / COLS) | 0) + 0.5) * cell, c = 2 * Math.sqrt(k[i]) * 0.62;
          ax = k[i] * (tx - x[i]) - c * vx[i]; ay = k[i] * (ty - y[i]) - c * vy[i];
        } else { ay = 1500; ax = -0.9 * vx[i]; }
        const dx = x[i] - mx, dy = y[i] - my, d2 = dx * dx + dy * dy;
        if (d2 < RR * RR) { const d = Math.sqrt(d2) + 0.01, f = (1 - d / RR); ax += dx / d * f * f * push; ay += dy / d * f * f * push; }
        vx[i] += ax * dt; vy[i] += ay * dt; x[i] += vx[i] * dt; y[i] += vy[i] * dt;
        if (t < 0) {
          const fl = floor - rest[i];
          if (y[i] > fl) { y[i] = fl; vy[i] = Math.abs(vy[i]) > 60 ? -vy[i] * 0.34 : 0; vx[i] *= 0.86; }
          if (x[i] < 6) { x[i] = 6; vx[i] = Math.abs(vx[i]) * 0.5; } else if (x[i] > W - 6) { x[i] = W - 6; vx[i] = -Math.abs(vx[i]) * 0.5; }
        }
      }

      /* floor dots first, then the live ones by colour */
      const r = cell * 0.31;
      for (let t = 0; t < 4; t++) {
        ctx.fillStyle = TIERS[t][2]; ctx.globalAlpha = 0.2; ctx.beginPath();
        for (let i = 0; i < NP; i++) if (tier[i] < 0 && was[i] === t) { ctx.moveTo(x[i] + r * 0.8, y[i]); ctx.arc(x[i], y[i], r * 0.8, 0, 6.2832); }
        ctx.fill();
      }
      for (let t = 0; t < 4; t++) {
        ctx.fillStyle = TIERS[t][2]; ctx.globalAlpha = 1; ctx.beginPath();
        for (const i of lists[t]) { ctx.moveTo(x[i] + r, y[i]); ctx.arc(x[i], y[i], r, 0, 6.2832); }
        ctx.fill();
      }

      /* labels */
      const yi = S.year, key = S.mode, bw = COLS * cell, small = W < 720;
      ctx.globalAlpha = 1; ctx.strokeStyle = '#2c2c2c'; ctx.lineWidth = 1;
      for (let t = 0; t < 4; t++) {
        const name = TIERS[t][0], val = at(D.tiers[name].value, yi), un = at(D.tiers[name].units, yi), cxb = barX[t] + bw / 2;
        ctx.beginPath(); ctx.moveTo(barX[t], base + 5.5); ctx.lineTo(barX[t] + bw, base + 5.5); ctx.stroke();
        label(ctx, small ? TIERS[t][1].replace('MECHANICAL', 'MECH') : TIERS[t][1], cxb, base + 22, TIERS[t][2], 'center', small ? 9 : 10, 600);
        label(ctx, key === 'units' ? fNum(un) : fCHF(val), cxb, base + 38, FG, 'center', 11);
      }
      
    },
  };

  canvas.style.touchAction = 'pan-y';
  const api = {
    S, unit,
    setYear(f) { S.year = clamp(f, 0, nY - 1); },
    setMode(m) { S.mode = m; },
  };
  api.stage = makeStage(canvas, obj);
  return api;
}
