/* The globe: dotted land, country outlines, arcs out of Switzerland with flowing dots, one spike per destination.
   Drag to spin it any direction (it keeps its momentum), click a country, spike or arc to select it,
   click open water to send a pulse through the dots. */
function makeGlobe(canvas, D, opts) {
  const RAD = Math.PI / 180;
  const vec = (lat, lon) => { const a = lat * RAD, b = lon * RAD; return [Math.cos(a) * Math.sin(b), Math.sin(a), Math.cos(a) * Math.cos(b)]; };
  const dot3 = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
  const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
  const norm = a => { const l = Math.hypot(a[0], a[1], a[2]) || 1; return [a[0] / l, a[1] / l, a[2] / l]; };

  const dest = D.dest, nK = dest.length, nT = D.months.length;
  const A = dest.map(d => vec(d.lat, d.lon));
  const CH = vec(46.8, 8.2);

  /* ---- geometry, built once ---- */
  const raw = D.globe.dots, nD = raw.length / 3;
  const PX = new Float32Array(nD), PY = new Float32Array(nD), PZ = new Float32Array(nD), PG = new Float32Array(nD), PC = new Int16Array(nD);
  const rad = new Float32Array(nK);
  for (let i = 0; i < nD; i++) {
    const v = vec(raw[3 * i] / 100, raw[3 * i + 1] / 100), c = raw[3 * i + 2];
    PX[i] = v[0]; PY[i] = v[1]; PZ[i] = v[2]; PC[i] = c;
    if (c >= 0) { const a = Math.acos(clamp(dot3(v, A[c]), -1, 1)); PG[i] = a; if (a > rad[c]) rad[c] = a; }
  }
  for (let i = 0; i < nD; i++) if (PC[i] >= 0) { const s = Math.max(0.05, rad[PC[i]] * 0.7); PG[i] = Math.exp(-(PG[i] / s) * (PG[i] / s)); }

  const nO = 3600, OX = new Float32Array(nO), OY = new Float32Array(nO), OZ = new Float32Array(nO);
  for (let i = 0; i < nO; i++) { const y = 1 - 2 * (i + 0.5) / nO, r = Math.sqrt(1 - y * y), a = i * 2.399963; OX[i] = r * Math.cos(a); OY[i] = y; OZ[i] = r * Math.sin(a); }

  const rings = D.globe.borders.map(r => {
    const n = r.length / 2, f = new Float32Array(n * 3);
    for (let i = 0; i < n; i++) { const v = vec(r[2 * i + 1] / 10, r[2 * i] / 10); f[3 * i] = v[0]; f[3 * i + 1] = v[1]; f[3 * i + 2] = v[2]; }
    return f;
  });

  const NA = 56, arcs = new Float32Array(nK * NA * 3), arcOK = new Uint8Array(nK);
  for (let k = 0; k < nK; k++) {
    const b = A[k], om = Math.acos(clamp(dot3(CH, b), -1, 1));
    if (om < 0.015) continue;
    arcOK[k] = 1;
    const so = Math.sin(om), lift = 0.05 + 0.30 * Math.min(1, om / 1.7);
    for (let j = 0; j < NA; j++) {
      const u = j / (NA - 1), wa = Math.sin((1 - u) * om) / so, wb = Math.sin(u * om) / so, L = 1 + lift * Math.sin(Math.PI * u);
      const o = (k * NA + j) * 3;
      arcs[o] = (wa * CH[0] + wb * b[0]) * L; arcs[o + 1] = (wa * CH[1] + wb * b[1]) * L; arcs[o + 2] = (wa * CH[2] + wb * b[2]) * L;
    }
  }

  let vmax = 0, umax = 0;
  for (const d of dest) for (let i = 0; i < nT; i++) { if (d.value[i] > vmax) vmax = d.value[i]; if (d.units[i] > umax) umax = d.units[i]; }

  /* ---- state ---- */
  const S = { time: nT - 1, metric: 'value', sel: -1, hov: -1, off: 0, idle: 9, wAxis: [0, 1, 0], wSpeed: 0, dragAng: 0, fly: null, ripples: [], tip: null, quiet: 1 };
  const h = new Float32Array(nK), hv = new Float32Array(nK), tgt = new Float32Array(nK), flow = new Float32Array(nK);
  const tipX = new Float32Array(nK), tipY = new Float32Array(nK), tipVis = new Uint8Array(nK);

  function rotM(axis, ang) {
    const [x, y, z] = axis, c = Math.cos(ang), s = Math.sin(ang), t = 1 - c;
    return [t * x * x + c, t * x * y - s * z, t * x * z + s * y, t * x * y + s * z, t * y * y + c, t * y * z - s * x, t * x * z - s * y, t * y * z + s * x, t * z * z + c];
  }
  function mul(a, b) {
    const o = new Array(9);
    for (let r = 0; r < 3; r++) for (let c = 0; c < 3; c++) o[r * 3 + c] = a[r * 3] * b[c] + a[r * 3 + 1] * b[3 + c] + a[r * 3 + 2] * b[6 + c];
    return o;
  }
  let M = mul(rotM([1, 0, 0], 24 * RAD), rotM([0, 1, 0], -52 * RAD));
  const spin = (axis, ang) => { if (ang) M = mul(rotM(axis, ang), M); };
  const view = v => [M[0] * v[0] + M[1] * v[1] + M[2] * v[2], M[3] * v[0] + M[4] * v[1] + M[5] * v[2], M[6] * v[0] + M[7] * v[1] + M[8] * v[2]];
  const unview = v => [M[0] * v[0] + M[3] * v[1] + M[6] * v[2], M[1] * v[0] + M[4] * v[1] + M[7] * v[2], M[2] * v[0] + M[5] * v[1] + M[8] * v[2]];

  let cx = 0, cy = 0, R = 1;
  function ball(x, y) {        // screen point to a point on the trackball
    const px = (x - cx) / R, py = (cy - y) / R, d2 = px * px + py * py;
    return norm(d2 <= 0.5 ? [px, py, Math.sqrt(1 - d2)] : [px, py, 0.5 / Math.sqrt(d2)]);
  }

  /* current value of the chosen metric for destination k, scaled 0..1 */
  function current(k) {
    const d = dest[k], v = at(d.value, S.time) * 1e5, u = at(d.units, S.time);
    return { v, u, p: u > 0 ? v / u : 0 };
  }
  function scaled(k) {
    const c = current(k);
    if (S.metric === 'value') return c.v / (vmax * 1e5);
    if (S.metric === 'units') return c.u / umax;
    if (S.metric === 'price') return c.v < 2e7 ? 0 : clamp((Math.log10(c.p) - 2) / 2.5, 0, 1);   // markets under CHF 20M a year are too thin for a stable price
    const yr = +D.months[Math.round(S.time)].slice(0, 4), s = dest[k].top1 && dest[k].top1[Math.min(24, yr - 2000)];
    return s ? clamp((s - 0.05) / 0.2, 0, 1) : 0;
  }

  const NB = 7, bx = [], bn = new Int32Array(NB + 1);
  for (let b = 0; b <= NB; b++) bx.push(new Float32Array(nD * 2));
  const ALPHA = [0.2, 0.3, 0.42, 0.55, 0.68, 0.82, 0.96];

  const obj = {
    down() { S.wSpeed = 0; S.dragAng = 0; S.fly = null; S.idle = 0; },
    drag(st, dx, dy) {
      const P = st.ptr, a = ball(P.x - dx, P.y - dy), b = ball(P.x, P.y), ax = cross(a, b), l = Math.hypot(ax[0], ax[1], ax[2]);
      if (l < 1e-6) return;
      const ang = Math.asin(Math.min(1, l)) * 1.15;
      S.wAxis = [ax[0] / l, ax[1] / l, ax[2] / l]; S.dragAng += ang; spin(S.wAxis, ang); S.idle = 0;
    },
    click(st) {
      const P = st.ptr;
      if (S.hov >= 0) { api.select(S.hov === S.sel ? -1 : S.hov); S.ripples.push({ c: A[S.hov], age: 0 }); }
      else if (Math.hypot(P.x - cx, P.y - cy) < R) { S.ripples.push({ c: unview(ball(P.x, P.y)), age: 0 }); }
      else api.select(-1);
      if (S.ripples.length > 4) S.ripples.shift();
    },
    frame(st, dt) {
      const { ctx, W, H } = st, P = st.ptr;
      ctx.clearRect(0, 0, W, H);
      const offT = S.sel >= 0 && W > 900 ? -Math.min(210, W * 0.15) : 0;
      S.off += (offT - S.off) * (1 - Math.exp(-5 * dt));
      cx = W / 2 + S.off; cy = H * 0.5; R = Math.min(W * 0.36, H * 0.335);

      /* rotation: momentum, fly-to, idle drift */
      S.idle += dt;
      if (P.down) { S.wSpeed = lerp(S.wSpeed, S.dragAng / dt, 0.45); S.dragAng = 0; }
      else {
        spin(S.wAxis, S.wSpeed * dt); S.wSpeed *= Math.exp(-1.9 * dt);
        if (S.fly) {
          const cur = view(S.fly), to = norm([-0.12, 0.16, 1]), ax = cross(cur, to), l = Math.hypot(ax[0], ax[1], ax[2]);
          const rem = Math.atan2(l, dot3(cur, to));
          if (rem < 0.01 || l < 1e-6) S.fly = null; else spin([ax[0] / l, ax[1] / l, ax[2] / l], rem * (1 - Math.exp(-4 * dt)));
        } else if (S.sel < 0 && !P.inside) spin([0, 1, 0], 0.07 * dt * smooth((S.idle - 1.2) / 2));
      }
      const m0 = M[0], m1 = M[1], m2 = M[2], m3 = M[3], m4 = M[4], m5 = M[5], m6 = M[6], m7 = M[7], m8 = M[8];

      /* springs on the per-country heights */
      for (let k = 0; k < nK; k++) {
        tgt[k] = scaled(k); flow[k] = at(dest[k].value, S.time) / vmax;
        hv[k] += (170 * (tgt[k] - h[k]) - 15 * hv[k]) * dt; h[k] += hv[k] * dt;
      }
      /* with a country selected (or hovered) everything else steps back */
      const focus = S.sel >= 0 ? S.sel : S.hov;
      S.quiet += ((S.sel >= 0 ? 0.14 : S.hov >= 0 ? 0.45 : 1) - S.quiet) * (1 - Math.exp(-7 * dt));
      const quiet = S.quiet;
      /* only the biggest flows get a line unless you point at one */
      const sorted = Array.from(flow).sort((a, b) => b - a), cut = Math.max(0.004, sorted[Math.min(21, nK - 1)]);
      for (const r of S.ripples) r.age += dt;
      while (S.ripples.length && S.ripples[0].age > 3.4) S.ripples.shift();
      const nR = S.ripples.length;

      /* sphere body */
      const g = ctx.createRadialGradient(cx - R * 0.3, cy - R * 0.35, R * 0.1, cx, cy, R * 1.02);
      g.addColorStop(0, '#15171c'); g.addColorStop(0.75, '#0d0e11'); g.addColorStop(1, '#0a0a0c');
      ctx.globalAlpha = 1; ctx.fillStyle = g; ctx.beginPath(); ctx.arc(cx, cy, R, 0, 6.2832); ctx.fill();
      const halo = ctx.createRadialGradient(cx, cy, R * 0.98, cx, cy, R * 1.22);
      halo.addColorStop(0, 'rgba(76,141,255,0.10)'); halo.addColorStop(1, 'rgba(76,141,255,0)');
      ctx.fillStyle = halo; ctx.beginPath(); ctx.arc(cx, cy, R * 1.22, 0, 6.2832); ctx.arc(cx, cy, R, 0, 6.2832, true); ctx.fill();
      ctx.strokeStyle = 'rgba(140,175,255,0.28)'; ctx.lineWidth = 1; ctx.beginPath(); ctx.arc(cx, cy, R, 0, 6.2832); ctx.stroke();

      /* ocean dots, front only */
      ctx.fillStyle = FG; ctx.globalAlpha = 0.06; ctx.beginPath();
      for (let i = 0; i < nO; i++) {
        const z = m6 * OX[i] + m7 * OY[i] + m8 * OZ[i]; if (z < 0.05) continue;
        const x = cx + (m0 * OX[i] + m1 * OY[i] + m2 * OZ[i]) * R, y = cy - (m3 * OX[i] + m4 * OY[i] + m5 * OZ[i]) * R;
        ctx.rect(x - 0.5, y - 0.5, 1, 1);
      }
      ctx.fill();

      /* land dots: far side faint, near side in brightness buckets */
      bn.fill(0);
      const px = P.inside ? P.x : -1e4, py = P.y, hot = S.hov, sel = S.sel;
      let pick = -1, pickD = 64;
      ctx.globalAlpha = 0.07; ctx.beginPath();
      for (let i = 0; i < nD; i++) {
        const x0 = PX[i], y0 = PY[i], z0 = PZ[i], Z = m6 * x0 + m7 * y0 + m8 * z0;
        let X = m0 * x0 + m1 * y0 + m2 * z0, Y = m3 * x0 + m4 * y0 + m5 * z0;
        if (Z < 0) { ctx.rect(cx + X * R - 0.5, cy - Y * R - 0.5, 1, 1); continue; }
        const c = PC[i];
        let lift = 0, lum = 0.9;
        if (c >= 0) { const hc = h[c] > 0 ? h[c] : 0; lift = hc * PG[i] * 0.17; lum += Math.sqrt(hc) * 6.2 * (0.35 + 0.65 * PG[i]) * (c === hot || c === sel ? 1 : quiet); }
        for (let r = 0; r < nR; r++) {
          const rp = S.ripples[r], d = Math.acos(clamp(x0 * rp.c[0] + y0 * rp.c[1] + z0 * rp.c[2], -1, 1)), ph = (d - rp.age * 1.25) / 0.13;
          if (ph > -3 && ph < 3) { const a = Math.exp(-ph * ph) * Math.exp(-rp.age * 0.75); lift += a * 0.07; lum += a * 4; }
        }
        let sx = cx + X * R * (1 + lift), sy = cy - Y * R * (1 + lift);
        const dx = sx - px, dy = sy - py, d2 = dx * dx + dy * dy;
        if (d2 < 9000) { const b = Math.exp(-d2 / 2600); sx += (sx - cx) * b * 0.045; sy += (sy - cy) * b * 0.045; lum += b * 1.6; if (c >= 0 && d2 < pickD) { pickD = d2; pick = c; } }
        const fade = Z < 0.25 ? 0.45 + Z * 2.2 : 1;
        let b = c >= 0 && (c === hot || c === sel) ? NB : Math.min(NB - 1, (lum * fade) | 0);
        const o = bn[b]++ * 2; bx[b][o] = sx; bx[b][o + 1] = sy;
      }
      ctx.fill();

      /* country outlines on the near side */
      ctx.globalAlpha = 1; ctx.strokeStyle = 'rgba(255,255,255,0.2)'; ctx.lineWidth = 0.6; ctx.beginPath();
      for (const f of rings) {
        let pen = false;
        for (let i = 0; i < f.length; i += 3) {
          const x0 = f[i], y0 = f[i + 1], z0 = f[i + 2], Z = m6 * x0 + m7 * y0 + m8 * z0;
          if (Z < 0.02) { pen = false; continue; }
          const x = cx + (m0 * x0 + m1 * y0 + m2 * z0) * R, y = cy - (m3 * x0 + m4 * y0 + m5 * z0) * R;
          if (pen) ctx.lineTo(x, y); else { ctx.moveTo(x, y); pen = true; }
        }
      }
      ctx.stroke();

      for (let b = 0; b <= NB; b++) {
        const n = bn[b], a = bx[b], s = b === NB ? 1.7 : 1.15 + b * 0.07, hs = s / 2;
        ctx.fillStyle = b === NB ? BLUE : FG; ctx.globalAlpha = b === NB ? 1 : ALPHA[b]; ctx.beginPath();
        for (let i = 0; i < n; i++) ctx.rect(a[2 * i] - hs, a[2 * i + 1] - hs, s, s);
        ctx.fill();
      }

      /* arcs: thin lines, weight by value, one soft highlight travelling out from Switzerland.
         A point shows if it faces us or sticks out past the limb. */
      const R2 = R * R, ax = new Float32Array(NA), ay = new Float32Array(NA), av = new Uint8Array(NA);
      let arcPick = -1, arcD = 70;
      ctx.lineCap = 'round'; ctx.lineJoin = 'round';
      for (let k = 0; k < nK; k++) {
        if (!arcOK[k]) continue;
        const f = flow[k], hi = k === hot || k === sel;
        if (f < cut && !hi) continue;
        const base = k * NA * 3;
        for (let j = 0; j < NA; j++) {
          const o = base + j * 3, x0 = arcs[o], y0 = arcs[o + 1], z0 = arcs[o + 2];
          const x = ax[j] = cx + (m0 * x0 + m1 * y0 + m2 * z0) * R, y = ay[j] = cy - (m3 * x0 + m4 * y0 + m5 * z0) * R, Z = m6 * x0 + m7 * y0 + m8 * z0;
          av[j] = Z > 0 || (x - cx) * (x - cx) + (y - cy) * (y - cy) > R2 ? 1 : 0;
          if (av[j] && P.inside && !P.down) { const d2 = (x - px) * (x - px) + (y - py) * (y - py); if (d2 < arcD) { arcD = d2; arcPick = k; } }
        }
        const line = (j0, j1) => { let pen = false; ctx.beginPath(); for (let j = j0; j <= j1; j++) { if (!av[j]) { pen = false; continue; } if (pen) ctx.lineTo(ax[j], ay[j]); else { ctx.moveTo(ax[j], ay[j]); pen = true; } } ctx.stroke(); };
        const wgt = Math.sqrt(f);
        ctx.strokeStyle = hi ? BLUE : '#8fb0f0'; ctx.lineWidth = hi ? 1.6 : 0.5 + 1.1 * wgt; ctx.globalAlpha = hi ? 1 : (0.16 + 0.5 * wgt) * quiet;
        line(0, NA - 1);
        const head = ((st.t * 0.22 + k * 0.137) % 1.25) * (NA - 1), j1 = Math.min(NA - 1, Math.floor(head)), j0 = Math.max(0, j1 - 7);
        if (head < NA - 1 + 7 && (hi || quiet > 0.6)) { ctx.strokeStyle = hi ? '#dce8ff' : '#cfdcff'; ctx.lineWidth = (hi ? 1.6 : 0.5 + 1.1 * wgt) + 0.5; ctx.globalAlpha = hi ? 0.95 : 0.55 * quiet; line(j0, j1); }
      }

      /* spikes */
      let tipPick = -1, tipD = 170;
      for (let k = 0; k < nK; k++) {
        const a = A[k], X = m0 * a[0] + m1 * a[1] + m2 * a[2], Y = m3 * a[0] + m4 * a[1] + m5 * a[2], Z = m6 * a[0] + m7 * a[1] + m8 * a[2];
        const hk = Math.max(0, h[k]), len = hk * 0.44, n = Math.ceil(len / 0.0115), hi = k === hot || k === sel;
        const tx = cx + X * R * (1 + len), ty = cy - Y * R * (1 + len);
        const vis = Z > 0 || (tx - cx) * (tx - cx) + (ty - cy) * (ty - cy) > R2;
        tipX[k] = tx; tipY[k] = ty; tipVis[k] = vis ? 1 : 0;
        if (len * R < 3 && !hi) continue;
        ctx.fillStyle = hi ? BLUE : '#fff';
        for (let j = 0; j <= n; j++) {
          const L = 1 + Math.min(len, j * 0.0115), x = cx + X * R * L, y = cy - Y * R * L;
          const v = Z > 0 || (x - cx) * (x - cx) + (y - cy) * (y - cy) > R2;
          ctx.globalAlpha = v ? (hi ? 1 : 0.25 + 0.67 * quiet) : 0.08; ctx.beginPath(); ctx.arc(x, y, hi ? 1.7 : 1.35, 0, 6.2832); ctx.fill();
        }
        if (vis && P.inside && !P.down) {
          const bxs = cx + X * R, bys = cy - Y * R;
          const d2 = Math.min((tx - px) * (tx - px) + (ty - py) * (ty - py), (bxs - px) * (bxs - px) + (bys - py) * (bys - py));
          if (d2 < tipD && (tgt[k] > 0.004 || flow[k] > 0.002)) { tipD = d2; tipPick = k; }
        }
      }
      const cz = view(CH);
      if (cz[2] > 0) { ctx.globalAlpha = 1; ctx.strokeStyle = BLUE; ctx.lineWidth = 1.2; ctx.beginPath(); ctx.arc(cx + cz[0] * R, cy - cz[1] * R, 4.5, 0, 6.2832); ctx.stroke(); label(ctx, 'CH', cx + cz[0] * R - 8, cy - cz[1] * R + 3, BLUE, 'right', 9); }

      if (!P.down) {
        const was = S.hov;
        S.hov = P.inside ? (tipPick >= 0 ? tipPick : arcPick >= 0 ? arcPick : pick) : -1;
        if (S.hov !== was) canvas.style.cursor = S.hov >= 0 ? 'pointer' : 'grab';
      }

      /* labels on the tallest visible spikes, then the callout */
      const order = [];
      for (let k = 0; k < nK; k++) if (tipVis[k] && h[k] > 0.05 && k !== S.hov && S.sel < 0) order.push(k);   // the panel carries the numbers once a country is selected
      order.sort((a, b) => h[b] - h[a]);
      const placed = [];
      for (const k of order.slice(0, 14)) {
        if (placed.length >= 6) break;
        const x = tipX[k], y = tipY[k];
        if (placed.some(p => Math.abs(p[0] - x) < 78 && Math.abs(p[1] - y) < 18)) continue;
        placed.push([x, y]);
        const c = current(k), right = x >= cx;
        const s = S.metric === 'value' ? (c.v / 1e9).toFixed(1) + 'B' : S.metric === 'units' ? fNum(c.u) : S.metric === 'price' ? fInt(c.p) : (dest[k].top1 ? (dest[k].top1[Math.min(24, +D.months[Math.round(S.time)].slice(0, 4) - 2000)] * 100).toFixed(1) + '%' : '');
        label(ctx, right ? dest[k].iso + ' ' + s : s + ' ' + dest[k].iso, x + (right ? 7 : -7), y + 3, k === sel ? BLUE : '#e2e2e2', right ? 'left' : 'right', 11);
      }
      const k = S.hov >= 0 ? S.hov : -1;
      if (k >= 0 && tipVis[k]) {
        const c = current(k), x = tipX[k], y = tipY[k], right = x < W - 260, lx = x + (right ? 46 : -46), ly = Math.max(58, y - 54);
        ctx.globalAlpha = 1; ctx.strokeStyle = '#bbb'; ctx.lineWidth = 0.8; ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(lx, ly + 4); ctx.stroke();
        ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(x, y, 2.6, 0, 6.2832); ctx.fill();
        const al = right ? 'left' : 'right', tx = lx + (right ? 6 : -6), wshare = c.v / (at(D.world.value, S.time) * 1e5) * 100;
        label(ctx, dest[k].name.toUpperCase(), tx, ly - 14, '#fff', al, 12, 600);
        label(ctx, S.metric === 'units' ? fNum(c.u) + ' WATCHES' : S.metric === 'price' ? 'CHF ' + fInt(c.p) + ' PER WATCH' : fCHF(c.v), tx, ly + 1, BLUE, al, 11);
      }
    },
  };

  const api = {
    S, dest, current,
    setTime(f) { S.time = clamp(f, 0, nT - 1); },
    setMetric(m) { S.metric = m; },
    select(k) {
      if (k === S.sel) return;
      S.sel = k;
      if (k >= 0) { S.fly = A[k]; S.wSpeed = 0; }
      if (opts.onSelect) opts.onSelect(k);
    },
  };
  canvas.style.cursor = 'grab';
  canvas.style.touchAction = 'none';
  api.stage = makeStage(canvas, obj);
  return api;
}
