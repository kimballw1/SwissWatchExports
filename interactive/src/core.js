/* Shared helpers: palette, formatting, the canvas stage (sizing, frame loop, pointer), timeline control. */
const FG = '#e8e8e8', DIM = '#9a9a9a', FAINT = '#5c5c5c', BLUE = '#4c8dff', BG = '#0a0a0a';
const MONO = 'ui-monospace, "SF Mono", Menlo, Consolas, monospace';
const MONTHS = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

const clamp = (v, a, b) => v < a ? a : v > b ? b : v;
const lerp = (a, b, t) => a + (b - a) * t;
const smooth = t => { t = clamp(t, 0, 1); return t * t * (3 - 2 * t); };

function fCHF(v) {            // v in francs
  if (v >= 1e9) return 'CHF ' + (v / 1e9).toFixed(v >= 1e10 ? 1 : 2) + 'B';
  if (v >= 1e6) return 'CHF ' + (v / 1e6).toFixed(v >= 1e8 ? 0 : 1) + 'M';
  if (v >= 1e3) return 'CHF ' + Math.round(v / 1e3) + 'K';
  return 'CHF ' + Math.round(v);
}
function fNum(u) {
  if (u >= 1e6) return (u / 1e6).toFixed(u >= 1e7 ? 1 : 2) + 'M';
  if (u >= 1e3) return (u / 1e3).toFixed(u >= 1e5 ? 0 : 1) + 'K';
  return String(Math.round(u));
}
const fInt = v => Math.round(v).toLocaleString('en-US');
const fMonth = s => MONTHS[+s.slice(5, 7) - 1] + ' ' + s.slice(0, 4);
const fLog = v => (v >= 0 ? '+' : '−') + Math.abs(v).toFixed(2);

function label(ctx, s, x, y, col, align, size, weight) {
  ctx.globalAlpha = 1;
  ctx.fillStyle = col || DIM;
  ctx.font = (weight || 400) + ' ' + ((size || 10) + 1) + 'px ' + MONO;
  ctx.textAlign = align || 'left';
  ctx.lineJoin = 'round'; ctx.lineWidth = 3.5; ctx.strokeStyle = 'rgba(10,10,10,0.82)';   // dark halo so text reads over dots
  ctx.strokeText(s, x, y);
  ctx.fillText(s, x, y);
}

/* A canvas that sizes itself, only animates while on screen, and reports pointer input.
   obj may define: frame(st, dt), resize(st), down(st), drag(st, dx, dy), up(st), click(st), move(st). */
function makeStage(canvas, obj) {
  const ctx = canvas.getContext('2d');
  const st = { canvas, ctx, W: 0, H: 0, dpr: 1, t: 0, ptr: { x: -1e4, y: -1e4, inside: false, down: false, speed: 0, moved: 0 } };
  function resize() {
    const r = canvas.getBoundingClientRect();
    st.dpr = Math.min(2, window.devicePixelRatio || 1);
    canvas.width = Math.max(1, Math.round(r.width * st.dpr));
    canvas.height = Math.max(1, Math.round(r.height * st.dpr));
    st.W = r.width; st.H = r.height;
    if (obj.resize) obj.resize(st);
  }
  new ResizeObserver(resize).observe(canvas);
  resize();

  let visible = false, raf = 0, last = 0;
  function loop(now) {
    raf = 0;
    if (!visible) return;
    const dt = clamp((now - last) / 1000 || 0.016, 0.001, 0.034);
    last = now; st.t += dt;
    st.ptr.speed *= Math.exp(-dt * 9);
    ctx.setTransform(st.dpr, 0, 0, st.dpr, 0, 0);
    obj.frame(st, dt);
    raf = requestAnimationFrame(loop);
  }
  new IntersectionObserver(es => {
    visible = es[0].isIntersecting;
    if (visible && !raf) { last = performance.now(); raf = requestAnimationFrame(loop); }
  }, { threshold: 0.02 }).observe(canvas);

  st.step = dt => { st.t += dt; ctx.setTransform(st.dpr, 0, 0, st.dpr, 0, 0); obj.frame(st, dt); };   // advance one frame by hand (used for testing)
  (window.__stages = window.__stages || {})[canvas.id] = st;
  const P = st.ptr;
  function pos(e) { const r = canvas.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; }
  canvas.addEventListener('pointerdown', e => {
    const [x, y] = pos(e);
    P.x = x; P.y = y; P.down = true; P.inside = true; P.moved = 0;
    canvas.setPointerCapture(e.pointerId);
    if (obj.down) obj.down(st);
  });
  canvas.addEventListener('pointermove', e => {
    const [x, y] = pos(e), dx = x - P.x, dy = y - P.y;
    P.x = x; P.y = y; P.inside = true;
    P.speed = Math.min(60, P.speed + Math.hypot(dx, dy));
    if (P.down) { P.moved += Math.abs(dx) + Math.abs(dy); if (obj.drag) obj.drag(st, dx, dy); }
    else if (obj.move) obj.move(st, dx, dy);
  });
  function release(e) {
    if (!P.down) return;
    P.down = false;
    if (obj.up) obj.up(st);
    if (P.moved < 5 && obj.click) obj.click(st);
    if (e.pointerType !== 'mouse') { P.inside = false; P.x = P.y = -1e4; }
  }
  canvas.addEventListener('pointerup', release);
  canvas.addEventListener('pointercancel', release);
  canvas.addEventListener('pointerleave', () => { if (!P.down) { P.inside = false; P.x = P.y = -1e4; } });
  return st;
}

/* Play button + scrubber. Returns { value } where value is a float position in [0, n-1]. */
function makeTimeline(root, n, start, secondsForFullRun, onChange) {
  const btn = root.querySelector('.play'), range = root.querySelector('input[type=range]');
  const tl = { value: start, playing: false };
  range.min = 0; range.max = n - 1; range.step = 0.01; range.value = start;
  function set(v, fromRange) { tl.value = clamp(v, 0, n - 1); if (!fromRange) range.value = tl.value; if (onChange) onChange(tl.value); }
  range.addEventListener('input', () => { tl.playing = false; btn.textContent = '▶'; set(+range.value, true); });
  btn.addEventListener('click', () => {
    tl.playing = !tl.playing; btn.textContent = tl.playing ? '❚❚' : '▶';
    if (tl.playing && tl.value >= n - 1.01) set(0);
  });
  tl.tick = dt => {
    if (!tl.playing) return;
    set(tl.value + dt * (n - 1) / secondsForFullRun);
    if (tl.value >= n - 1) { tl.playing = false; btn.textContent = '▶'; }
  };
  tl.set = set;
  tl.play = () => { if (!tl.playing) btn.click(); };
  return tl;
}

/* Segmented buttons: <div class="seg"><button data-v="a">…</button>…</div> */
function makeSeg(root, onPick) {
  const bs = [...root.querySelectorAll('button')];
  bs.forEach(b => b.addEventListener('click', () => { bs.forEach(o => o.classList.toggle('on', o === b)); onPick(b.dataset.v); }));
}

/* value of series s at float index f */
function at(s, f) { const i = Math.floor(f), j = Math.min(s.length - 1, i + 1); return s[i] + (s[j] - s[i]) * (f - i); }
