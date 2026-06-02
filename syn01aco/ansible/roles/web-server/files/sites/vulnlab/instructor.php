<?php
require __DIR__ . '/config.php';
init_lab();
$state = get_state();
?><!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>CYBERRANGE // VULNLAB CONFIG</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Exo+2:wght@400;700;900&family=Share+Tech+Mono&family=Rajdhani:wght@400;600;700&display=swap">
<style>
:root{
  --bg:      #050a12;
  --panel:   #080f1c;
  --panel2:  #0a1628;
  --border:  #0d2840;
  --border2: #1a3a5c;
  --accent:  #00c8ff;
  --accent2: #00ff9d;
  --warn:    #ff4560;
  --warn2:   #ff8c00;
  --text:    #c8e8ff;
  --text-dim:#4a7a9b;
  --muted:   #1a3a5c;
  --gold:    #ffd700;
}
*{box-sizing:border-box;margin:0;padding:0}
html,body{background:var(--bg);color:var(--text);font-family:'Rajdhani',sans-serif;min-height:100vh;-webkit-font-smoothing:antialiased}
body::before{content:"";position:fixed;inset:0;background:repeating-linear-gradient(0deg,transparent,transparent 2px,rgba(0,0,0,0.18) 2px,rgba(0,0,0,0.18) 4px);pointer-events:none;z-index:9999}
body::after{content:"";position:fixed;inset:0;background-image:linear-gradient(rgba(0,200,255,0.04) 1px,transparent 1px),linear-gradient(90deg,rgba(0,200,255,0.04) 1px,transparent 1px);background-size:40px 40px;pointer-events:none;z-index:0}

/* ── HEADER ── */
header{position:sticky;top:0;z-index:100;display:flex;align-items:center;justify-content:space-between;padding:14px 36px;border-bottom:1px solid var(--border);background:rgba(5,10,18,0.92);backdrop-filter:blur(12px)}
.hdr-left{display:flex;align-items:center;gap:20px}
.hdr-logo{font-family:'Exo 2',sans-serif;font-size:13px;font-weight:900;letter-spacing:4px;color:var(--accent);text-transform:uppercase}
.hdr-logo span{color:var(--warn)}
.hdr-sep{width:1px;height:24px;background:var(--border2)}
.hdr-title{font-family:'Share Tech Mono',monospace;font-size:10px;letter-spacing:3px;color:var(--text-dim);text-transform:uppercase}
.hdr-right{display:flex;align-items:center;gap:16px}
.pulse-dot{width:8px;height:8px;border-radius:50%;background:var(--accent2);box-shadow:0 0 8px var(--accent2);animation:pulse-anim 2s ease-in-out infinite;flex-shrink:0}
@keyframes pulse-anim{0%,100%{opacity:1;box-shadow:0 0 8px var(--accent2)}50%{opacity:0.4;box-shadow:0 0 2px var(--accent2)}}
.status-pill{display:flex;align-items:center;gap:7px;font-family:'Share Tech Mono',monospace;font-size:10px;letter-spacing:1px;color:var(--text-dim);border:1px solid var(--border2);border-radius:3px;padding:5px 12px}
.clock{font-family:'Share Tech Mono',monospace;font-size:13px;color:var(--accent);letter-spacing:2px}
.btn-sm{font-family:'Exo 2',sans-serif;font-weight:700;font-size:10px;letter-spacing:3px;text-transform:uppercase;padding:7px 16px;border:1px solid var(--border2);border-radius:3px;background:var(--panel);color:var(--text-dim);cursor:pointer;transition:all 0.2s;text-decoration:none;display:inline-block}
.btn-sm:hover{border-color:var(--accent);color:var(--accent)}

/* ── LAYOUT ── */
.layout{position:relative;z-index:1;display:grid;grid-template-columns:1fr 1fr;gap:0;min-height:calc(100vh - 57px)}
.left-pane{padding:36px;border-right:1px solid var(--border);display:flex;flex-direction:column;gap:28px}
.right-pane{padding:36px;display:flex;flex-direction:column;gap:24px}

/* ── SECTION LABELS ── */
.sec-label{font-family:'Share Tech Mono',monospace;font-size:9px;letter-spacing:3px;text-transform:uppercase;color:var(--text-dim);margin-bottom:14px;padding-bottom:8px;border-bottom:1px solid var(--border)}
.sec-title{font-family:'Exo 2',sans-serif;font-size:18px;font-weight:900;letter-spacing:2px;color:var(--text);margin-bottom:4px}
.sec-sub{font-family:'Share Tech Mono',monospace;font-size:10px;color:var(--text-dim);letter-spacing:1px;margin-bottom:20px}

/* ── LEVEL SELECTOR ── */
.level-seg{display:flex;border:1px solid var(--border2);border-radius:3px;overflow:hidden;margin-bottom:4px}
.level-btn{flex:1;background:transparent;border:none;color:var(--text-dim);font-family:'Exo 2',sans-serif;font-size:11px;font-weight:700;letter-spacing:3px;text-transform:uppercase;padding:11px 0;cursor:pointer;transition:all 0.2s;border-right:1px solid var(--border2)}
.level-btn:last-child{border-right:none}
.level-btn:hover{background:rgba(0,200,255,0.04);color:var(--text)}
.level-btn.sel-easy{background:rgba(0,255,157,0.1);color:var(--accent2);border-color:rgba(0,255,157,0.25)}
.level-btn.sel-medium{background:rgba(255,140,0,0.1);color:var(--warn2);border-color:rgba(255,140,0,0.25)}
.level-btn.sel-hard{background:rgba(255,69,96,0.1);color:var(--warn);border-color:rgba(255,69,96,0.25)}
.level-hint{font-family:'Share Tech Mono',monospace;font-size:9px;color:var(--text-dim);letter-spacing:1px;text-align:center;margin-top:6px;min-height:14px}

/* ── VULN CARDS ── */
.vuln-grid{display:flex;flex-direction:column;gap:8px}
.vuln-card{display:flex;align-items:center;gap:14px;padding:13px 16px;border:1px solid var(--border);border-radius:3px;cursor:pointer;transition:all 0.2s;background:var(--panel);position:relative;overflow:hidden}
.vuln-card::before{content:"";position:absolute;left:0;top:0;bottom:0;width:3px;background:transparent;transition:background 0.2s}
.vuln-card:hover{border-color:var(--border2);background:var(--panel2)}
.vuln-card.checked{border-color:rgba(255,69,96,0.35);background:rgba(255,69,96,0.05)}
.vuln-card.checked::before{background:var(--warn)}
.vuln-card input[type=checkbox]{width:14px;height:14px;accent-color:var(--warn);flex-shrink:0;cursor:pointer}
.vuln-name{font-family:'Exo 2',sans-serif;font-size:13px;font-weight:700;letter-spacing:2px;text-transform:uppercase;color:var(--text);min-width:50px}
.vuln-full{font-family:'Share Tech Mono',monospace;font-size:10px;color:var(--text-dim);flex:1;letter-spacing:0.5px}
.vuln-endpoint{font-family:'Share Tech Mono',monospace;font-size:9px;color:var(--text-dim);opacity:0.6;margin-left:auto;white-space:nowrap}
.sev-badge{font-family:'Share Tech Mono',monospace;font-size:8px;letter-spacing:2px;text-transform:uppercase;padding:2px 8px;border-radius:2px;flex-shrink:0}
.sev-critical{background:rgba(255,69,96,0.12);color:var(--warn);border:1px solid rgba(255,69,96,0.25)}
.sev-high{background:rgba(255,140,0,0.1);color:var(--warn2);border:1px solid rgba(255,140,0,0.2)}
.sev-medium{background:rgba(0,200,255,0.08);color:var(--accent);border:1px solid rgba(0,200,255,0.2)}

/* ── COUNTER ── */
.counter-row{display:flex;align-items:center;justify-content:space-between;padding:10px 16px;background:var(--panel2);border:1px solid var(--border2);border-radius:3px}
.counter-label{font-family:'Share Tech Mono',monospace;font-size:9px;letter-spacing:2px;text-transform:uppercase;color:var(--text-dim)}
.counter-val{font-family:'Exo 2',sans-serif;font-size:16px;font-weight:900;letter-spacing:2px}
.counter-val .n{color:var(--warn)}
.counter-val .d{color:var(--text-dim)}

/* ── LAUNCH BUTTON ── */
.launch-btn{width:100%;padding:14px;font-family:'Exo 2',sans-serif;font-weight:900;font-size:13px;letter-spacing:4px;text-transform:uppercase;border:1px solid rgba(0,255,157,0.4);border-radius:3px;background:linear-gradient(135deg,rgba(0,102,51,0.6),rgba(0,204,102,0.25));color:var(--accent2);cursor:pointer;transition:all 0.2s;position:relative;overflow:hidden}
.launch-btn:hover:not(:disabled){box-shadow:0 0 24px rgba(0,255,157,0.25);border-color:var(--accent2)}
.launch-btn:disabled{opacity:0.4;cursor:not-allowed}
.launch-btn.launching{animation:launch-pulse 0.8s ease-in-out infinite}
@keyframes launch-pulse{0%,100%{box-shadow:0 0 8px rgba(0,255,157,0.2)}50%{box-shadow:0 0 28px rgba(0,255,157,0.5)}}

/* ── TOAST ── */
.toast{padding:10px 16px;border-radius:3px;font-family:'Share Tech Mono',monospace;font-size:10px;letter-spacing:1px;display:none;margin-top:8px}
.toast.ok{display:block;background:rgba(0,255,157,0.08);color:var(--accent2);border:1px solid rgba(0,255,157,0.2)}
.toast.error{display:block;background:rgba(255,69,96,0.08);color:var(--warn);border:1px solid rgba(255,69,96,0.2)}

/* ── LIVE STATE CARD ── */
.state-card{background:var(--panel);border:1px solid var(--border);border-radius:4px;overflow:hidden}
.state-card-hdr{display:flex;align-items:center;justify-content:space-between;padding:12px 18px;border-bottom:1px solid var(--border);background:var(--panel2)}
.state-card-title{font-family:'Share Tech Mono',monospace;font-size:9px;letter-spacing:3px;text-transform:uppercase;color:var(--text-dim)}
.state-card-body{padding:18px}
.live-level-row{display:flex;align-items:center;gap:12px;margin-bottom:16px}
.live-label{font-family:'Share Tech Mono',monospace;font-size:9px;letter-spacing:2px;text-transform:uppercase;color:var(--text-dim)}
.live-badge{font-family:'Exo 2',sans-serif;font-size:11px;font-weight:700;letter-spacing:2px;text-transform:uppercase;padding:3px 12px;border-radius:2px}
.live-badge.easy{background:rgba(0,255,157,0.1);color:var(--accent2);border:1px solid rgba(0,255,157,0.2)}
.live-badge.medium{background:rgba(255,140,0,0.1);color:var(--warn2);border:1px solid rgba(255,140,0,0.2)}
.live-badge.hard{background:rgba(255,69,96,0.1);color:var(--warn);border:1px solid rgba(255,69,96,0.2)}
.active-vulns-grid{display:grid;grid-template-columns:1fr 1fr;gap:8px}
.active-vuln-chip{background:rgba(255,69,96,0.05);border:1px solid rgba(255,69,96,0.25);border-radius:3px;padding:10px 12px}
.avc-name{font-family:'Exo 2',sans-serif;font-size:12px;font-weight:700;letter-spacing:2px;color:var(--warn);margin-bottom:2px}
.avc-mode{font-family:'Share Tech Mono',monospace;font-size:9px;color:var(--text-dim);letter-spacing:1px}
.avc-ep{font-family:'Share Tech Mono',monospace;font-size:9px;color:var(--text-dim);opacity:0.5;margin-top:4px}
.no-vulns{font-family:'Share Tech Mono',monospace;font-size:10px;color:var(--text-dim);letter-spacing:2px;text-align:center;padding:24px;border:1px dashed var(--border2);border-radius:3px}

/* ── ATTACK REF TABLE ── */
.attack-table{width:100%;border-collapse:collapse;font-family:'Share Tech Mono',monospace;font-size:10px}
.attack-table th{text-align:left;font-size:8px;letter-spacing:2px;text-transform:uppercase;color:var(--text-dim);padding:8px 10px;border-bottom:1px solid var(--border)}
.attack-table td{padding:8px 10px;border-bottom:1px solid var(--border);color:var(--text-dim);vertical-align:top;line-height:1.5}
.attack-table td:first-child{color:var(--warn);font-weight:500;letter-spacing:1px}
.attack-table tr:last-child td{border-bottom:none}
.payload{color:rgba(0,200,255,0.7);font-size:9px}

/* ── STUDENT LINK ── */
.student-link{display:flex;align-items:center;justify-content:space-between;padding:11px 16px;background:var(--panel2);border:1px solid var(--border2);border-radius:3px}
.student-url{font-family:'Share Tech Mono',monospace;font-size:10px;color:var(--accent);letter-spacing:0.5px}
.copy-btn{font-family:'Share Tech Mono',monospace;font-size:9px;letter-spacing:2px;text-transform:uppercase;padding:5px 12px;border:1px solid rgba(0,200,255,0.25);border-radius:2px;background:rgba(0,200,255,0.06);color:var(--accent);cursor:pointer;transition:all 0.2s}
.copy-btn:hover{background:rgba(0,200,255,0.12)}

/* ── RESET ZONE ── */
.reset-zone{border:1px solid rgba(255,69,96,0.2);border-radius:3px;padding:14px 16px;background:rgba(255,69,96,0.04)}
.reset-zone p{font-family:'Share Tech Mono',monospace;font-size:10px;color:var(--text-dim);letter-spacing:0.5px;margin-bottom:12px;line-height:1.6}
.reset-btn{font-family:'Exo 2',sans-serif;font-weight:700;font-size:10px;letter-spacing:3px;text-transform:uppercase;padding:8px 18px;border:1px solid rgba(255,69,96,0.35);border-radius:3px;background:transparent;color:var(--warn);cursor:pointer;transition:all 0.2s}
.reset-btn:hover{background:rgba(255,69,96,0.1)}

.updated-at{font-family:'Share Tech Mono',monospace;font-size:9px;color:var(--text-dim);letter-spacing:1px}
</style>
</head>
<body>

<header>
  <div class="hdr-left">
    <div class="hdr-logo">CYBER<span>RANGE</span> // <span style="color:var(--accent)">VULNLAB</span></div>
    <div class="hdr-sep"></div>
    <div class="hdr-title">Instructor Configuration Panel</div>
  </div>
  <div class="hdr-right">
    <div class="status-pill">
      <div class="pulse-dot" id="status-dot" style="background:var(--text-dim);box-shadow:none"></div>
      <span id="status-text">connecting…</span>
    </div>
    <div class="clock" id="clock">--:--:--</div>
    <a href="index.php" target="_blank" class="btn-sm">Student Site ↗</a>
  </div>
</header>

<div class="layout">

  <!-- ══ LEFT: CONFIGURE ══════════════════════════════════════════════════ -->
  <div class="left-pane">

    <div>
      <div class="sec-label">Exercise Setup</div>
      <div class="sec-title">Configure Vulnerability Lab</div>
      <div class="sec-sub">Select difficulty and open vulnerabilities · Students see only what you enable</div>
    </div>

    <div>
      <div class="sec-label">Difficulty Level</div>
      <div class="level-seg" id="level-seg">
        <button class="level-btn" data-level="easy">Easy</button>
        <button class="level-btn" data-level="medium">Medium</button>
        <button class="level-btn" data-level="hard">Hard</button>
      </div>
      <div class="level-hint" id="level-hint"></div>
    </div>

    <div>
      <div class="sec-label">Vulnerabilities — Select to Open</div>
      <div class="vuln-grid">
        <label class="vuln-card" data-vuln="sqli">
          <input type="checkbox" value="sqli">
          <span class="vuln-name">SQLi</span>
          <span class="vuln-full">SQL Injection · Booking search</span>
          <span class="sev-badge sev-critical">Critical</span>
        </label>
        <label class="vuln-card" data-vuln="xss">
          <input type="checkbox" value="xss">
          <span class="vuln-name">XSS</span>
          <span class="vuln-full">Reflected XSS · Guest reviews</span>
          <span class="sev-badge sev-high">High</span>
        </label>
        <label class="vuln-card" data-vuln="idor">
          <input type="checkbox" value="idor">
          <span class="vuln-name">IDOR</span>
          <span class="vuln-full">Broken Access · Traveller profile</span>
          <span class="sev-badge sev-high">High</span>
        </label>
        <label class="vuln-card" data-vuln="cmdi">
          <input type="checkbox" value="cmdi">
          <span class="vuln-name">CMDi</span>
          <span class="vuln-full">Command Injection · Server ping</span>
          <span class="sev-badge sev-critical">Critical</span>
        </label>
        <label class="vuln-card" data-vuln="lfi">
          <input type="checkbox" value="lfi">
          <span class="vuln-name">LFI</span>
          <span class="vuln-full">File Inclusion · Travel guides</span>
          <span class="sev-badge sev-medium">Medium</span>
        </label>
      </div>
    </div>

    <div class="counter-row">
      <span class="counter-label">Vulnerabilities selected</span>
      <span class="counter-val"><span class="n" id="open-count">0</span><span class="d"> / 5</span></span>
    </div>

    <div>
      <button class="launch-btn" id="launch-btn">⚡ Launch Lab</button>
      <div class="toast" id="toast"></div>
    </div>

    <div>
      <div class="sec-label">Student Access URL</div>
      <div class="student-link">
        <span class="student-url" id="student-url">http://<?= htmlspecialchars($_SERVER['HTTP_HOST'] ?? '10.0.20.20:9001') ?>/</span>
        <button class="copy-btn" onclick="copyUrl()">Copy</button>
      </div>
    </div>

    <div>
      <div class="sec-label">Reset Lab</div>
      <div class="reset-zone">
        <p>Wipes the SQLite database and state file. Reseeds fresh data. Redirects students back to this panel. Use between training sessions.</p>
        <button class="reset-btn" id="reset-btn">⚠ Reset Lab</button>
      </div>
    </div>

  </div>

  <!-- ══ RIGHT: LIVE STATE + REFERENCE ════════════════════════════════════ -->
  <div class="right-pane">

    <div class="state-card">
      <div class="state-card-hdr">
        <span class="state-card-title">Live Lab State</span>
        <span class="updated-at" id="updated-at">—</span>
      </div>
      <div class="state-card-body">
        <div class="live-level-row">
          <span class="live-label">Current Level</span>
          <span class="live-badge" id="live-level">—</span>
        </div>
        <div id="active-vulns-wrap">
          <div class="no-vulns" id="no-vulns-msg">No vulnerabilities open — all endpoints patched</div>
          <div class="active-vulns-grid" id="active-vulns-grid" style="display:none"></div>
        </div>
      </div>
    </div>

    <div class="state-card">
      <div class="state-card-hdr">
        <span class="state-card-title">Attack Reference — Instructor Only</span>
        <span class="updated-at">Easy → Medium → Hard</span>
      </div>
      <div class="state-card-body" style="padding:0">
        <table class="attack-table">
          <thead>
            <tr>
              <th>Vuln</th>
              <th>Easy</th>
              <th>Medium</th>
              <th>Hard</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>SQLi</td>
              <td class="payload">%' UNION SELECT id,username,content FROM users JOIN secrets ON 1=1--</td>
              <td class="payload">UnIoN SeLeCt… (mixed case)</td>
              <td class="payload">' OR (SELECT substr(content,1,1) FROM secrets WHERE id=3)='F'--</td>
            </tr>
            <tr>
              <td>XSS</td>
              <td class="payload">&lt;script&gt;alert(1)&lt;/script&gt;</td>
              <td class="payload">&lt;img src=x onerror=alert(1)&gt;</td>
              <td class="payload">&lt;scrSCRIPTipt&gt;alert(1)&lt;/scrSCRIPTipt&gt;</td>
            </tr>
            <tr>
              <td>IDOR</td>
              <td class="payload">id=3</td>
              <td class="payload">id=Mw== (base64)</td>
              <td class="payload">md5(salt+id) token</td>
            </tr>
            <tr>
              <td>CMDi</td>
              <td class="payload">127.0.0.1; cat /var/lib/vulnlab/.flag</td>
              <td class="payload">127.0.0.1`cat /var/lib/vulnlab/.flag`</td>
              <td class="payload">1.1.1.1$(cat /var/lib/vulnlab/.flag)</td>
            </tr>
            <tr>
              <td>LFI</td>
              <td class="payload">/var/lib/vulnlab/.flag</td>
              <td class="payload">php://filter/convert.base64-encode/resource=config</td>
              <td class="payload">....//....//var/lib/vulnlab/.flag</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

  </div>
</div>

<script>
const API = window.location.origin + '/api';

const LEVEL_HINTS = {
  easy:   'Payloads work as-is · Good for beginners',
  medium: 'Basic filters applied · Requires simple bypasses',
  hard:   'Strong filters active · Advanced techniques needed'
};

const VULN_EP = {
  sqli: '?vuln=sqli&q=…',
  xss:  '?vuln=xss&name=…',
  idor: '?vuln=idor&id=…',
  cmdi: '?vuln=cmdi&host=…',
  lfi:  '?vuln=lfi&page=…'
};

let currentLevel = 'easy';

// ── Clock ────────────────────────────────────────────────
function updateClock(){
  const now = new Date();
  document.getElementById('clock').textContent =
    now.toTimeString().slice(0,8);
}
setInterval(updateClock, 1000);
updateClock();

// ── Level buttons ─────────────────────────────────────────
function setLevel(level){
  currentLevel = level;
  document.querySelectorAll('.level-btn').forEach(b => {
    b.className = 'level-btn';
    if(b.dataset.level === level) b.classList.add('sel-' + level);
  });
  document.getElementById('level-hint').textContent = LEVEL_HINTS[level] || '';
}

document.querySelectorAll('.level-btn').forEach(b => {
  b.onclick = () => setLevel(b.dataset.level);
});

// ── Vuln checkboxes ───────────────────────────────────────
document.querySelectorAll('.vuln-card').forEach(card => {
  const cb = card.querySelector('input');
  cb.addEventListener('change', () => {
    card.classList.toggle('checked', cb.checked);
    updateCount();
  });
  card.addEventListener('click', e => {
    if(e.target !== cb){ cb.checked = !cb.checked; cb.dispatchEvent(new Event('change')); }
  });
});

function updateCount(){
  const n = document.querySelectorAll('.vuln-card input:checked').length;
  document.getElementById('open-count').textContent = n;
}

// ── Load live state ───────────────────────────────────────
async function loadState(){
  try{
    const r = await fetch(API + '/state');
    const s = await r.json();
    renderState(s);
    setOnline(true);
  } catch(e){ setOnline(false); }
}

function renderState(s){
  const lvlEl = document.getElementById('live-level');
  lvlEl.textContent = s.level || '—';
  lvlEl.className = 'live-badge ' + (s.level || '');

  if(s.updated_at){
    const d = new Date(s.updated_at);
    document.getElementById('updated-at').textContent =
      'Updated ' + d.toLocaleTimeString([],{hour:'2-digit',minute:'2-digit'});
  }

  const grid = document.getElementById('active-vulns-grid');
  const none = document.getElementById('no-vulns-msg');
  grid.innerHTML = '';

  if(!s.open_vulns || s.open_vulns.length === 0){
    grid.style.display = 'none';
    none.style.display = 'block';
  } else {
    none.style.display = 'none';
    grid.style.display = 'grid';
    s.open_vulns.forEach(v => {
      const el = document.createElement('div');
      el.className = 'active-vuln-chip';
      el.innerHTML = `<div class="avc-name">${v.toUpperCase()}</div>
        <div class="avc-mode">${s.level} · vuln mode</div>
        <div class="avc-ep">${VULN_EP[v] || ''}</div>`;
      grid.appendChild(el);
    });
  }

  // Sync sidebar controls only on first load, not on every poll
  if (!window._stateLoaded) {
    window._stateLoaded = true;
    setLevel(s.level || 'easy');
    document.querySelectorAll('.vuln-card input').forEach(cb => {
      const checked = s.open_vulns && s.open_vulns.includes(cb.value);
      cb.checked = checked;
      cb.closest('.vuln-card').classList.toggle('checked', checked);
    });
    updateCount();
  }
}

function setOnline(online){
  const dot  = document.getElementById('status-dot');
  const text = document.getElementById('status-text');
  if(online){
    dot.style.background = 'var(--accent2)';
    dot.style.boxShadow  = '0 0 8px var(--accent2)';
    dot.style.animation  = 'pulse-anim 2s ease-in-out infinite';
    text.textContent = 'Lab Online';
  } else {
    dot.style.background = 'var(--text-dim)';
    dot.style.boxShadow  = 'none';
    dot.style.animation  = 'none';
    text.textContent = 'Unreachable';
  }
}

// ── Launch ────────────────────────────────────────────────
document.getElementById('launch-btn').onclick = async function(){
  const open_vulns = [...document.querySelectorAll('.vuln-card input:checked')].map(i => i.value);
  const toast = document.getElementById('toast');
  toast.className = 'toast';
  this.disabled = true;
  this.classList.add('launching');
  this.textContent = '⟳ Applying…';

  try{
    const res = await fetch(API + '/configure', {
      method: 'POST',
      headers: {'Content-Type':'application/json'},
      body: JSON.stringify({level: currentLevel, open_vulns})
    });
    const data = await res.json();
    if(!res.ok || !data.ok) throw new Error(data.error || 'request failed');

    toast.textContent = `✔ Lab configured — ${open_vulns.length} vuln${open_vulns.length!==1?'s':''} open · Redirecting students…`;
    toast.className = 'toast ok';
    renderState(data.state);

    // After 1.5s open the student site in a new tab as confirmation
    setTimeout(() => window.open('/', '_blank'), 1500);
  } catch(e){
    toast.textContent = '✘ Error: ' + e.message;
    toast.className = 'toast error';
  } finally {
    this.disabled = false;
    this.classList.remove('launching');
    this.textContent = '⚡ Launch Lab';
  }
};

// ── Reset ─────────────────────────────────────────────────
document.getElementById('reset-btn').onclick = async function(){
  if(!confirm('Reset the lab? This wipes the database and state — students will be redirected to this panel.')) return;
  try{
    const res = await fetch(API + '/reset', {method:'POST'});
    const data = await res.json();
    if(data.ok){
      const toast = document.getElementById('toast');
      toast.textContent = '✔ Lab reset — fresh seed data loaded';
      toast.className = 'toast ok';
      setTimeout(loadState, 500);
    }
  } catch(e){}
};

// ── Copy URL ──────────────────────────────────────────────
function copyUrl(){
  const url = document.getElementById('student-url').textContent;
  navigator.clipboard.writeText(url).then(() => {
    const btn = document.querySelector('.copy-btn');
    const orig = btn.textContent;
    btn.textContent = 'Copied!';
    setTimeout(() => btn.textContent = orig, 1500);
  });
}

// ── Init ──────────────────────────────────────────────────
loadState();
setInterval(loadState, 8000);
</script>
</body>
</html>
