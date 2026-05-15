// ============================================================
// fish_telemetry: NUI Script
// ============================================================
'use strict';

// State
let state = {
  isRecording: false,
  versions: [],
  activeVersionIdx: 0,
  vehicleName: '',
  plate: '',
};

// ── Telemetry rows config ──
const ROWS = [
  { key: 'time0_100', label: '0 → 100 km/h',   unit: 's',  decimals: 2 },
  { key: 'time0_200', label: '0 → 200 km/h',   unit: 's',  decimals: 2 },
  { key: 'time100_0', label: '100 → 0 km/h',   unit: 's',  decimals: 2 },
  { key: 'dist100_0', label: '↳ Braking Dist',  unit: 'm',  decimals: 0 },
  { key: 'time200_0', label: '200 → 0 km/h',   unit: 's',  decimals: 2 },
  { key: 'dist200_0', label: '↳ Braking Dist',  unit: 'm',  decimals: 0 },
  { key: 'maxSpeed',  label: 'Max Speed',       unit: 'km/h', decimals: 1 },
  { key: 'bestGForce',label: 'Best Lat G',      unit: 'G',  decimals: 2 },
];

// Version colours
const VER_COLORS = ['#00d4ff', '#ff6b00', '#a855f7', '#00ff88', '#ffd600'];
const VER_CLASS  = ['', 'v2', 'v3', 'v4', 'v5'];

// ── DOM refs ──
const speedVal    = document.getElementById('speedVal');
const speedoArc   = document.getElementById('speedoArc');
const gforceVal   = document.getElementById('gforceVal');
const gforceBar   = document.getElementById('gforceBar');
const maxSpeedVal = document.getElementById('maxSpeedVal');
const bestGVal    = document.getElementById('bestGVal');
const recBadge    = document.getElementById('recBadge');
const vehName     = document.getElementById('vehName');
const vehPlate    = document.getElementById('vehPlate');
const vehPi       = document.getElementById('vehPi');
const versionPills = document.getElementById('versionPills');
const idleScreen  = document.getElementById('idleScreen');
const liveResults = document.getElementById('liveResults');
const tableHead   = document.getElementById('tableHead');
const tableBody   = document.getElementById('tableBody');
const btnStart    = document.getElementById('btnStart');
const btnStop     = document.getElementById('btnStop');

// ── Arc Speedometer Math ──
// Arc path length = ~258 units (semicircle)
const ARC_LENGTH = 258;
const MAX_SPEED  = 340; // km/h max displayed

function updateArc(speed) {
  const pct = Math.min(speed / MAX_SPEED, 1);
  const offset = ARC_LENGTH * (1 - pct);
  speedoArc.style.strokeDashoffset = offset;
  // Color shift: cyan → orange → red
  if (pct < 0.6) {
    speedoArc.style.stroke = '#00d4ff';
  } else if (pct < 0.85) {
    speedoArc.style.stroke = '#ff6b00';
  } else {
    speedoArc.style.stroke = '#ff1744';
  }
}

// ── Live Telemetry Update ──
function onLiveTelemetry(data) {
  const spd = Math.round(data.speed || 0);
  speedVal.textContent  = spd;
  speedVal.style.color  = spd > 200 ? '#ff1744' : spd > 100 ? '#ff6b00' : '#00d4ff';
  updateArc(spd);

  const g = data.gForce || 0;
  gforceVal.textContent = g.toFixed(2) + 'G';
  gforceBar.style.width = Math.min(g / 4 * 100, 100) + '%';

  maxSpeedVal.textContent = data.maxSpeed ? Math.round(data.maxSpeed) + '' : '—';
  bestGVal.textContent    = data.bestGForce ? data.bestGForce.toFixed(2) + 'G' : '—';

  // Update active version cells
  if (state.versions.length > 0) {
    const ver = state.versions[state.activeVersionIdx];
    if (ver) {
      Object.assign(ver, {
        time0_100:  data.time0_100,
        time0_200:  data.time0_200,
        time100_0:  data.time100_0,
        dist100_0:  data.dist100_0,
        time200_0:  data.time200_0,
        dist200_0:  data.dist200_0,
        maxSpeed:   data.maxSpeed,
        bestGForce: data.bestGForce,
      });
      refreshTable();
    }
  }
}

// ── Version Pill Rendering ──
function renderVersionPills() {
  versionPills.innerHTML = '';
  state.versions.forEach((ver, idx) => {
    const pill = document.createElement('div');
    pill.className = `version-pill ${VER_CLASS[idx]} ${idx === state.activeVersionIdx ? 'active' : ''}`;
    pill.textContent = ver.label;
    pill.style.setProperty('--vc', VER_COLORS[idx]);
    pill.onclick = () => {
      state.activeVersionIdx = idx;
      renderVersionPills();
      refreshTable();
      vehPi.textContent = 'PI: ' + (ver.score || '—');
    };
    versionPills.appendChild(pill);
  });
}

// ── Table Rendering ──
function buildTableHeader() {
  let html = '<tr><th>METRIC</th>';
  state.versions.forEach((ver, idx) => {
    html += `<th class="ver-col" style="color:${VER_COLORS[idx]}">${ver.label}</th>`;
  });
  html += '</tr>';
  tableHead.innerHTML = html;
}

function refreshTable() {
  if (state.versions.length === 0) return;
  buildTableHeader();

  tableBody.innerHTML = '';
  ROWS.forEach(row => {
    const tr = document.createElement('tr');
    let bestVal = null;
    let bestIdx = -1;

    // Find best value for this metric
    state.versions.forEach((ver, idx) => {
      const val = ver[row.key];
      if (val !== null && val !== undefined) {
        if (bestVal === null || val < bestVal) {
          bestVal = val;
          bestIdx = idx;
        }
      }
    });

    // For speed/gforce, higher is better
    if (row.key === 'maxSpeed' || row.key === 'bestGForce') {
      bestVal = null; bestIdx = -1;
      state.versions.forEach((ver, idx) => {
        const val = ver[row.key];
        if (val !== null && val !== undefined) {
          if (bestVal === null || val > bestVal) {
            bestVal = val;
            bestIdx = idx;
          }
        }
      });
    }

    let html = `<td>${row.label}</td>`;
    state.versions.forEach((ver, idx) => {
      const val = ver[row.key];
      if (val === null || val === undefined) {
        // Is currently measuring?
        const isActive = state.isRecording && idx === state.activeVersionIdx;
        const needs = {
          time0_100: ver.sm_measuring_0_100,
          time0_200: ver.sm_measuring_0_200,
          time100_0: ver.sm_measuring_100_0,
          dist100_0: ver.sm_measuring_100_0,
          time200_0: ver.sm_measuring_200_0,
          dist200_0: ver.sm_measuring_200_0,
          maxSpeed:  true,
          bestGForce: true,
        };
        if (isActive && needs[row.key]) {
          html += `<td class="measuring">●</td>`;
        } else {
          html += `<td class="cell-na">—</td>`;
        }
      } else {
        const isBest = idx === bestIdx && state.versions.length > 1;
        const formatted = val.toFixed(row.decimals) + ' ' + row.unit;
        html += `<td ${isBest ? 'class="cell-best"' : ''} style="color:${isBest ? '' : VER_COLORS[idx]}">${formatted}</td>`;
      }
    });
    tr.innerHTML = html;
    tableBody.appendChild(tr);
  });
}

// ── Start Recording ──
function startRecording() {
  fetch('https://fish_telemetry/startRecording', { method: 'POST', body: JSON.stringify({}) });
}

// ── Stop Recording ──
function stopRecording() {
  fetch('https://fish_telemetry/stopRecording', { method: 'POST', body: JSON.stringify({}) });
}

// ── Copy Clipboard ──
function copyClipboard() {
  fetch('https://fish_telemetry/copyClipboard', { method: 'POST', body: JSON.stringify({}) });
  document.getElementById('btnCopy').innerHTML = '<span class="material-symbols-sharp">check</span> Copied!';
  setTimeout(() => {
    document.getElementById('btnCopy').innerHTML = '<span class="material-symbols-sharp">content_copy</span> Copy Results';
  }, 2000);
}

// ── Close ──
function closeNUI() {
  fetch('https://fish_telemetry/close', { method: 'POST', body: JSON.stringify({}) });
  document.body.classList.remove('visible');
}

// ── NUI Message Handler ──
window.addEventListener('message', e => {
  const msg = e.data;
  if (!msg || !msg.action) return;

  switch (msg.action) {

    case 'startRecording':
      state.isRecording = true;
      state.versions = [];
      state.activeVersionIdx = 0;
      vehName.textContent   = msg.vehicleName || '—';
      vehPlate.textContent  = msg.plate || '——————';
      recBadge.classList.add('active');
      idleScreen.style.display = 'none';
      liveResults.style.display = 'block';
      btnStart.style.display = 'none';
      btnStop.style.display = 'flex';
      document.body.classList.add('visible');
      break;

    case 'newVersion': {
      const ver = {
        label: msg.label,
        score: msg.score || 0,
        archetype: msg.archetype || '?',
        time0_100: null, time0_200: null,
        time100_0: null, dist100_0: null,
        time200_0: null, dist200_0: null,
        maxSpeed: null, bestGForce: null,
      };
      state.versions.push(ver);
      state.activeVersionIdx = state.versions.length - 1;
      renderVersionPills();
      refreshTable();
      break;
    }

    case 'liveTelemetry':
      // Ensure active version exists
      if (state.versions.length === 0) {
        state.versions.push({
          label: msg.versionLabel || 'Stock',
          score: 0, archetype: '?',
          time0_100: null, time0_200: null,
          time100_0: null, dist100_0: null,
          time200_0: null, dist200_0: null,
          maxSpeed: null, bestGForce: null,
        });
        renderVersionPills();
      }
      onLiveTelemetry(msg);
      break;

    case 'stopRecording':
      state.isRecording = false;
      recBadge.classList.remove('active');
      btnStart.style.display = 'flex';
      btnStop.style.display  = 'none';
      if (msg.versions) {
        state.versions = msg.versions;
        renderVersionPills();
        refreshTable();
      }
      break;
  }
});

// Escape key
document.addEventListener('keydown', e => {
  if (e.key === 'Escape') closeNUI();
});

// Initial arc
updateArc(0);
