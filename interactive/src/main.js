/* Wires the page together: globe + country panel, the two surfaces, the dot bars. */
const $ = id => document.getElementById(id);
const nT = D.months.length;
const TIER_KEY = [['steel_quartz', 'Steel quartz', '#737373'], ['steel_mech', 'Steel mechanical', '#f4f4f4'], ['precious_quartz', 'Precious quartz', '#9cc0ff'], ['precious_mech', 'Precious mechanical', BLUE]];

/* ------------------------------------------------------------------ globe + panel */
const METRIC_NOTE = {
  value: 'SPIKES SHOW EXPORT VALUE',
  units: 'SPIKES SHOW NUMBER OF WATCHES',
  price: 'SPIKES SHOW AVERAGE PRICE PER WATCH',
};
let panelSel = -1, panelPeriod = 'all', panelStamp = '';
const globe = makeGlobe($('globe'), D, { onSelect: k => { panelSel = k; renderPanel(true); } });
const gTime = makeTimeline($('gTime'), nT, nT - 1, 18, f => { globe.setTime(f); hud(); renderPanel(false); });
makeSeg($('metric'), m => { globe.setMetric(m); $('metricNote').textContent = METRIC_NOTE[m]; });
$('metricNote').textContent = METRIC_NOTE.value;
$('worldBtn').addEventListener('click', () => { globe.select(-1); panelSel = panelSel === -2 ? -1 : -2; renderPanel(true); });
(function tick(prev) { requestAnimationFrame(now => { gTime.tick(Math.min(0.05, (now - prev) / 1000)); tick(now); }); })(performance.now());

function hud() {
  const f = gTime.value, v = at(D.world.value, f) * 1e5, u = at(D.world.units, f);
  $('gDate').textContent = fMonth(D.months[Math.round(f)]);
  $('gTot').textContent = fCHF(v) + ' · ' + fNum(u) + ' WATCHES · CHF ' + fInt(v / u) + ' EACH';
}
hud();

/* dotted sparkline as an SVG string */
function spark(series, w, hgt, mark, color) {
  const pts = series.map((v, i) => [i, v]).filter(p => p[1] != null), max = Math.max(...pts.map(p => p[1])), min = Math.min(0, ...pts.map(p => p[1]));
  const n = series.length - 1, X = i => 3 + i / n * (w - 6), Y = v => hgt - 3 - (v - min) / ((max - min) || 1) * (hgt - 6);
  let s = `<svg viewBox="0 0 ${w} ${hgt}">`;
  for (const [i, v] of pts) s += `<circle cx="${X(i).toFixed(1)}" cy="${Y(v).toFixed(1)}" r="${n > 40 ? 1 : 1.5}" fill="${color || '#cfcfcf'}" opacity=".8"/>`;
  if (mark != null && series[Math.round(mark)] != null) {
    const v = at(series, mark);
    s += `<line x1="${X(mark)}" x2="${X(mark)}" y1="0" y2="${hgt}" stroke="#555" stroke-width=".6"/><circle cx="${X(mark)}" cy="${Y(v)}" r="3" fill="${BLUE}"/>`;
  }
  return s + '</svg>';
}
/* The volume / price / mix split in plain words. Each row is a multiplier on export value;
   dots run right of the line when it pushed value up, left when it pulled value down. */
function decSvg(dec) {
  const sum = key => dec[key].reduce((s, v) => s + v, 0);
  const rows = [['NUMBER OF WATCHES', sum('volume')], ['PRICE OF EACH KIND OF WATCH', sum('price')], ['SHIFT TO PRICIER KINDS', sum('mix')]];
  const total = sum('value'), zero = 80, stepPx = 5.4, U = 0.05;
  const mult = v => { const m = Math.exp(v); return '×' + (m >= 100 ? m.toFixed(0) : m >= 10 ? m.toFixed(1) : m.toFixed(2)); };
  let s = `<svg viewBox="0 0 312 128"><line x1="${zero}" x2="${zero}" y1="12" y2="92" stroke="#444" stroke-width=".8"/>`;
  rows.forEach(([name, val], r) => {
    const y = 10 + r * 30, up = val >= 0, n = Math.min(up ? 36 : 13, Math.round(Math.abs(val) / U)), dir = up ? 1 : -1;
    s += `<text x="0" y="${y}" fill="${DIM}" font-size="10" letter-spacing=".8">${name}</text>`;
    s += `<text x="312" y="${y}" fill="${up ? BLUE : '#cfcfcf'}" font-size="12" text-anchor="end">${mult(val)}</text>`;
    for (let i = 0; i < n; i++) s += `<circle cx="${zero + dir * (i + 0.8) * stepPx}" cy="${y + 11}" r="1.9" fill="${up ? BLUE : '#8a8a8a'}"/>`;
  });
  s += `<line x1="0" x2="312" y1="103" y2="103" stroke="#2a2a2a" stroke-width=".8"/><text x="0" y="121" fill="#e8e8e8" font-size="10" letter-spacing=".8">EXPORT VALUE</text><text x="312" y="122" fill="#fff" font-size="14" text-anchor="end">${mult(total)}</text></svg>`;
  return { svg: s, text: 'Multiply the three and you get the change in export value. Blue pushed it up, grey pulled it down.' };
}
function mixSvg(tiers) {
  let s = '<svg viewBox="0 0 312 34">';
  ['2000', '2025'].forEach((yr, r) => {
    const tot = TIER_KEY.reduce((a, t) => a + tiers[yr][t[0]][0], 0), y = 8 + r * 17;
    s += `<text x="0" y="${y + 3}" fill="${DIM}" font-size="10">${yr}</text>`;
    if (!tot) { s += `<text x="34" y="${y + 3}" fill="${FAINT}" font-size="10">NO EXPORTS</text>`; return; }
    let i = 0, acc = 0;
    TIER_KEY.forEach(t => { acc += tiers[yr][t[0]][0] / tot * 50; for (; i < Math.round(acc); i++) s += `<circle cx="${36 + i * 5.5}" cy="${y}" r="2" fill="${t[2]}"/>`; });
  });
  return s + '</svg>';
}

function renderPanel(full) {
  const el = $('panel'), k = panelSel;
  if (k === -1) { el.classList.remove('open'); return; }
  const world = k === -2, d = world ? null : D.dest[k], f = gTime.value;
  const val = world ? D.world.value : d.value, uni = world ? D.world.units : d.units;
  const v = at(val, f) * 1e5, u = at(uni, f), share = v / (at(D.world.value, f) * 1e5) * 100;
  const stamp = k + '|' + panelPeriod;
  if (!full && stamp === panelStamp) {            // only time moved: update the numbers and markers in place
    $('pnWhen').textContent = '12 MONTHS TO ' + fMonth(D.months[Math.round(f)]);
    $('pnV').textContent = fCHF(v); $('pnU').textContent = fNum(u); $('pnP').textContent = u > 0 ? 'CHF ' + fInt(v / u) : 'n/a';
    $('pnS').textContent = world ? '100%' : share.toFixed(share < 1 ? 2 : 1) + '%';
    $('pnSpark').innerHTML = spark(val, 312, 54, f);
    return;
  }
  panelStamp = stamp;
  const dec = world ? D.dec : d.dec, tiers = world ? null : d.tiers;
  let html = `<button class="x" id="pnX" aria-label="Close">×</button>
    <div class="when" id="pnWhen">12 MONTHS TO ${fMonth(D.months[Math.round(f)])}</div>
    <h2>${world ? 'All destinations' : d.name}</h2>
    <div class="stats">
      <div class="blue"><b id="pnV">${fCHF(v)}</b><span>EXPORT VALUE</span></div>
      <div><b id="pnU">${fNum(u)}</b><span>WATCHES</span></div>
      <div><b id="pnP">${u > 0 ? 'CHF ' + fInt(v / u) : 'n/a'}</b><span>PER WATCH</span></div>
      <div><b id="pnS">${world ? '100%' : share.toFixed(share < 1 ? 2 : 1) + '%'}</b><span>OF ALL EXPORTS</span></div>
    </div>
    <div id="pnSpark">${spark(val, 312, 54, f)}</div>
    <h3><span>WHY EXPORT VALUE CHANGED</span><span>2000 → 2025</span></h3>`;
  if (dec) { const g = decSvg(dec); html += g.svg + `<p>${g.text}</p>`; }
  else html += '<p>Too few watches go here in some years to split the change.</p>';
  if (tiers) {
    html += `<h3><span>WHAT KIND OF WATCH</span><span>SHARE OF VALUE</span></h3>${mixSvg(tiers)}<div class="key">${TIER_KEY.map(t => `<span><i style="background:${t[2]}"></i>${t[1].toUpperCase()}</span>`).join('')}</div>`;
  }
  if (!world) {
    html += '<h3><span>THE BUYERS</span><span>2000 → 2024</span></h3>';
    if (d.top1) {
      const ends = s => { const x = s.filter(q => q != null); return [x[0], x[x.length - 1]]; };
      const row = (name, s, fmt, col) => { if (!s.some(q => q != null)) return ''; const [p, q] = ends(s); return `<div><div class="k">${name}</div><div class="v"><i>${fmt(p)} → </i>${fmt(q)}</div></div><div>${spark(s, 96, 26, null, col)}</div>`; };
      html += '<div class="mini">' + row('INCOME SHARE OF THE TOP 1%', d.top1, x => (x * 100).toFixed(1) + '%', BLUE) + row('INCOME PER PERSON', d.gdp_pc, x => '$' + fInt(x)) + '</div>';
    } else html += '<p>No income data for this destination.</p>';
  }
  el.innerHTML = html;
  el.classList.add('open');
  if (full) el.scrollTop = 0;
  $('pnX').addEventListener('click', () => { panelSel = -1; globe.select(-1); renderPanel(true); });
}

/* ------------------------------------------------------------------ helpers for the surfaces */
function upsample(s) {         // one extra point between each pair, Catmull-Rom
  const n = s.length, o = new Float32Array(2 * n - 1);
  for (let i = 0; i < n; i++) {
    o[2 * i] = s[i];
    if (i < n - 1) { const p0 = s[Math.max(0, i - 1)], p3 = s[Math.min(n - 1, i + 2)]; o[2 * i + 1] = Math.max(0, (-p0 + 9 * s[i] + 9 * s[i + 1] - p3) / 16); }
  }
  return o;
}

/* ------------------------------------------------------------------ 01 terrain */
(function () {
  const NC = 8, SUB = 12, top = D.dest.slice(0, NC), R = NC * SUB, C = 2 * nT - 1;
  const band = new Int16Array(R), center = [];
  for (let b = 0; b < NC; b++) { center.push(b * SUB + SUB / 2); for (let s = 0; s < SUB; s++) band[b * SUB + s] = b; }
  const country = b => top[NC - 1 - b];          // biggest destination at the back
  function grid(key) {
    const rows = top.map(d => upsample(d[key])), max = Math.max(...rows.map(r => Math.max(...r))), g = new Float32Array(R * C);
    for (let b = 0; b < NC; b++) for (let s = 0; s < SUB; s++) {
      const f = (s + 0.5) / SUB - 0.5, nb = clamp(b + (f < 0 ? -1 : 1), 0, NC - 1), w = 0.3 + 0.7 * Math.cos(Math.PI * f) ** 2;
      const A = rows[NC - 1 - b], B = rows[NC - 1 - nb], r = b * SUB + s;
      for (let c = 0; c < C; c++) g[r * C + c] = lerp(A[c], B[c], Math.abs(f)) * w / max;
    }
    return g;
  }
  const colTicks = [];
  D.months.forEach((m, j) => { if (m.endsWith('-12') && +m.slice(0, 4) % 5 === 0) colTicks.push({ c: 2 * j, text: m.slice(0, 4) }); });
  const surf = makeSurface($('terrain'), {
    R, C, layers: { value: grid('value'), units: grid('units') }, layer: 'value', band, center,
    rowTicks: center.map((r, b) => ({ r, text: country(b).name.toUpperCase() })), colTicks,
    callout(b, c, layer) {
      const d = country(b), f = c / 2;
      return [d.name.toUpperCase(), layer === 'value' ? fCHF(at(d.value, f) * 1e5) + ' A YEAR' : fNum(at(d.units, f)) + ' WATCHES A YEAR', fMonth(D.months[Math.round(f)])];
    },
    size: [2.15, 1.55, 0.82], yaw: -0.6, pitch: 0.5,
  });
  makeSeg($('terrainSeg'), surf.setLayer);
})();

/* ------------------------------------------------------------------ 02 price ridges */
(function () {
  const nY = D.years.length, SUB = 4, R = (nY - 1) * SUB + 1, nB = D.uv.money[0].length, C = 2 * nB - 1;
  const band = new Int16Array(R), center = [];
  for (let r = 0; r < R; r++) band[r] = Math.round(nY - 1 - r / SUB);     // 2025 in front
  for (let b = 0; b < nY; b++) center.push((nY - 1 - b) * SUB);
  const soft = row => row.map((v, i) => (row[Math.max(0, i - 1)] + 2 * v + row[Math.min(row.length - 1, i + 1)]) / 4);
  function grid(key) {
    const rows = D.uv[key].map(r => upsample(soft(soft(soft(r))))), max = Math.max(...rows.map(r => Math.max(...r))), g = new Float32Array(R * C);
    for (let r = 0; r < R; r++) {
      const y = nY - 1 - r / SUB, y0 = Math.floor(y), y1 = Math.min(nY - 1, y0 + 1), t = y - y0;
      for (let c = 0; c < C; c++) g[r * C + c] = lerp(rows[y0][c], rows[y1][c], t) / max;
    }
    return g;
  }
  const { lo, hi } = D.uv, colOf = lv => (lv - lo) / (hi - lo) * nB * 2;
  const surf = makeSurface($('ridges'), {
    R, C, layers: { money: grid('money'), pieces: grid('pieces') }, layer: 'money', band, center,
    rowTicks: center.map((r, b) => ({ r, text: String(D.years[b]) })).filter((_, b) => D.years[b] % 5 === 0),
    colTicks: [[2, 'CHF 100'], [3, 'CHF 1,000'], [4, 'CHF 10,000']].map(([lv, text]) => ({ c: colOf(lv), text })),
    callout(b, c, layer) {
      const bin = Math.min(nB - 1, Math.round(c / 2)), price = Math.pow(10, lo + (bin + 0.5) / nB * (hi - lo));
      const above = D.uv[layer][b].slice(bin).reduce((s, x) => s + x, 0) * 100;
      const p = price >= 1000 ? Math.round(price / 100) * 100 : Math.round(price / 10) * 10;
      return [String(D.years[b]), above.toFixed(0) + '% OF THE ' + (layer === 'money' ? 'MONEY' : 'WATCHES'), 'IS IN WATCHES ABOVE CHF ' + fInt(p)];
    },
    size: [1.95, 1.3, 0.7], yaw: -0.5, pitch: 0.56,
  });
  makeSeg($('ridgeSeg'), surf.setLayer);
})();

/* ------------------------------------------------------------------ 03 dots */
(function () {
  const nY = D.years.length;
  let tl;
  const dots = makeParticles($('dots'), D, { tick: dt => tl && tl.tick(dt) });
  function read() {
    const f = tl ? tl.value : 0, key = dots.S.mode;
    $('pYear').textContent = D.years[Math.round(f)];
    $('pTot').textContent = key === 'units' ? fNum(at(D.tot.units, f)) + ' WATCHES' : fCHF(at(D.tot.value, f));
    $('pUnit').textContent = key === 'units' ? 'ONE DOT = ' + fInt(Math.round(dots.unit.units / 100) * 100) + ' WATCHES' : 'ONE DOT = ' + fCHF(dots.unit.value);
  }
  tl = makeTimeline($('pTime'), nY, 0, 14, f => { dots.setYear(f); read(); });
  makeSeg($('dotSeg'), m => { dots.setMode(m); read(); });
  read();
})();

if (!D.paper) $('paper').style.display = 'none';
