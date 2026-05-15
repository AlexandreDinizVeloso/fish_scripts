'use strict';
// fish_remaps NUI Script

let remapState = {
  plate: '',
  vehicleNetId: 0,
  originalArchetype: 'esportivo',
  currentArchetype: 'esportivo',
  targetArchetype: 'esportivo',
  subArchetype: null,
  stage: 0,
  statAdjustments: { top_speed: 0, acceleration: 0, handling: 0, braking: 0 },
  costs: {},
  existingData: null,
};

const ARCHETYPES = [
  { key: 'esportivo', label: 'Esportivo', icon: '🏎️' },
  { key: 'possante', label: 'Possante', icon: '💪' },
  { key: 'exotico', label: 'Exótico', icon: '🚀' },
  { key: 'supercarro', label: 'Supercarro', icon: '⚡' },
  { key: 'moto', label: 'Moto', icon: '🏍️' },
  { key: 'utilitario', label: 'Utilitário', icon: '🚛' },
  { key: 'especial', label: 'Especial', icon: '🌟' },
];

const SUB_ARCHETYPES = [
  'None', 'drifter', 'dragster', 'late_surger', 'curve_king', 'grip_master',
  'street_racer', 'rally_spec', 'drift_king', 'time_attack', 'sleeper'
];

const STAGE_LIMITS = { 0: 2, 1: 2, 2: 4, 3: 6 };

const STAT_LABELS = {
  top_speed: 'Top Speed',
  acceleration: 'Acceleration',
  handling: 'Handling',
  braking: 'Braking',
};

// ── Build Archetype Grid ──
function buildArchGrid() {
  const grid = document.getElementById('archGrid');
  grid.innerHTML = '';
  ARCHETYPES.forEach(a => {
    const card = document.createElement('div');
    card.className = 'arch-card' + (remapState.targetArchetype === a.key ? ' selected' : '');
    card.innerHTML = `<div class="icon">${a.icon}</div><div class="name">${a.label}</div>`;
    card.onclick = () => {
      remapState.targetArchetype = a.key;
      buildArchGrid();
      updateDNABar();
      updateSummary();
      calcCost();
    };
    grid.appendChild(card);
  });
}

// ── Build Sub-archetype ──
function buildSubPills() {
  const container = document.getElementById('subPills');
  container.innerHTML = '';
  SUB_ARCHETYPES.forEach(s => {
    const key = s === 'None' ? null : s;
    const pill = document.createElement('div');
    pill.className = 'sub-pill' + (remapState.subArchetype === key ? ' selected' : '');
    pill.textContent = s === 'None' ? 'None' : s.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
    pill.onclick = () => { remapState.subArchetype = key; buildSubPills(); updateSummary(); calcCost(); };
    container.appendChild(pill);
  });
}

// ── Build Sliders ──
function buildSliders() {
  const container = document.getElementById('sliderGroup');
  container.innerHTML = '';
  const limit = STAGE_LIMITS[remapState.stage] || 2;
  const stats = ['top_speed', 'acceleration', 'handling', 'braking'];
  stats.forEach(key => {
    const val = remapState.statAdjustments[key] || 0;
    const row = document.createElement('div');
    row.className = 'slider-row';
    row.innerHTML = `
      <div class="slider-label">${STAT_LABELS[key]}</div>
      <input class="slider-input" type="range" min="${-limit}" max="${limit}" step="1" value="${val}"
             oninput="updateSlider('${key}',this.value,document.getElementById('sv-${key}'))">
      <span class="slider-val ${val > 0 ? 'pos' : val < 0 ? 'neg' : 'zero'}" id="sv-${key}">${val >= 0 ? '+' + val : val}</span>
    `;
    container.appendChild(row);
  });
}

function updateSlider(key, rawVal, labelEl) {
  const val = parseInt(rawVal);
  remapState.statAdjustments[key] = val;
  labelEl.textContent = val >= 0 ? '+' + val : val;
  labelEl.className = 'slider-val ' + (val > 0 ? 'pos' : val < 0 ? 'neg' : 'zero');
  updateSummary();
  calcCost();
}

// ── DNA Bar ──
function updateDNABar() {
  document.getElementById('dnaOriginal').textContent = remapState.originalArchetype || '?';
  document.getElementById('dnaCurrent').textContent = remapState.targetArchetype || '?';
  document.getElementById('stageBadge').textContent = 'Stage ' + remapState.stage;
  buildDNAViz();
}

// ── DNA Visualization ──
const ARCH_STAT_PROFILES = {
  esportivo: { top_speed: 62, acceleration: 65, handling: 88, braking: 80 },
  possante: { top_speed: 55, acceleration: 95, handling: 48, braking: 60 },
  exotico: { top_speed: 95, acceleration: 72, handling: 60, braking: 70 },
  supercarro: { top_speed: 80, acceleration: 80, handling: 78, braking: 82 },
  moto: { top_speed: 68, acceleration: 75, handling: 85, braking: 78 },
  utilitario: { top_speed: 38, acceleration: 40, handling: 45, braking: 55 },
  especial: { top_speed: 70, acceleration: 65, handling: 65, braking: 65 },
};

function buildDNAViz() {
  const container = document.getElementById('dnaViz');
  const orig = ARCH_STAT_PROFILES[remapState.originalArchetype] || ARCH_STAT_PROFILES.esportivo;
  const newP = ARCH_STAT_PROFILES[remapState.targetArchetype] || ARCH_STAT_PROFILES.esportivo;
  const stats = ['top_speed', 'acceleration', 'handling', 'braking'];
  container.innerHTML = stats.map(s => {
    const origPct = orig[s] || 50;
    const newPct = (newP[s] * 0.75 + origPct * 0.25); // 75/25 blend
    return `<div class="dna-segment">
      <div class="dna-seg-label"><span>${STAT_LABELS[s]}</span><span style="color:var(--cyan)">${newPct.toFixed(0)}</span></div>
      <div class="dna-seg-bar">
        <div class="dna-seg-orig" style="width:${origPct}%"></div>
        <div class="dna-seg-new" style="width:${newPct}%"></div>
      </div>
    </div>`;
  }).join('');
}

// ── Summary ──
function updateSummary() {
  const card = document.getElementById('summaryCard');
  const adjs = remapState.statAdjustments;
  const rows = [
    { key: 'Archetype Change', val: remapState.targetArchetype !== remapState.currentArchetype ? `${remapState.currentArchetype} → ${remapState.targetArchetype}` : 'None', color: 'var(--cyan)' },
    { key: 'Sub-Archetype', val: remapState.subArchetype ? remapState.subArchetype.replace(/_/g, ' ') : 'None', color: 'var(--purple)' },
    { key: 'Stat Trade-offs', val: Object.entries(adjs).filter(([, v]) => v !== 0).map(([k, v]) => `${STAT_LABELS[k]} ${v > 0 ? '+' + v : v}`).join(', ') || 'None', color: 'var(--text)' },
    { key: 'Stage', val: 'Stage ' + remapState.stage + ' (±' + (STAGE_LIMITS[remapState.stage] || 2) + ' limit)', color: 'var(--muted)' },
  ];
  card.innerHTML = rows.map(r => `<div class="summary-row">
    <span class="summary-key">${r.key}</span>
    <span class="summary-val" style="color:${r.color}">${r.val || '—'}</span>
  </div>`).join('');
}

// ── Cost Calculation ──
function calcCost() {
  const costs = remapState.costs;
  let total = 0;
  if (remapState.targetArchetype !== remapState.currentArchetype) {
    total += costs.archetype_change || 15000;
  }
  if (remapState.subArchetype !== (remapState.existingData && remapState.existingData.sub_archetype)) {
    total += costs.subarchetype_change || 5000;
  }
  const pts = Object.values(remapState.statAdjustments).reduce((s, v) => s + Math.abs(v || 0), 0);
  if (pts > 0) total += pts * (costs.adjustment_per_point || 1000);
  document.getElementById('costPreview').textContent = '$' + total.toLocaleString();
  document.getElementById('ftrCost').textContent = '$' + total.toLocaleString();
}

// ── Apply Remap ──
function applyRemap() {
  const data = {
    current_archetype: remapState.targetArchetype,
    sub_archetype: remapState.subArchetype,
    stat_adjustments: remapState.statAdjustments,
    original_archetype: remapState.originalArchetype,
    stage: remapState.stage,
  };
  fetch('https://fish_remaps/confirmRemap', {
    method: 'POST',
    body: JSON.stringify({
      plate: remapState.plate,
      vehicleNetId: remapState.vehicleNetId,
      data: data,
    })
  });
  closeNUI();
}

function closeNUI() {
  fetch('https://fish_remaps/close', { method: 'POST', body: '{}' });
  document.body.classList.remove('visible');
}

// ── NUI Messages ──
window.addEventListener('message', e => {
  const msg = e.data;
  if (!msg || !msg.action) return;

  if (msg.action === 'openRemap') {
    remapState.plate = msg.plate || '';
    remapState.vehicleNetId = msg.vehicleNetId || 0;
    remapState.originalArchetype = msg.originalArchetype || 'esportivo';
    remapState.currentArchetype = msg.currentArchetype || 'esportivo';
    remapState.targetArchetype = msg.currentArchetype || 'esportivo';
    remapState.subArchetype = msg.subArchetype || null;
    remapState.stage = msg.stage || 0;
    remapState.costs = msg.costs || {};
    remapState.existingData = msg.existingData || null;
    // Load existing adjustments if remap was previously applied
    if (msg.adjustments && typeof msg.adjustments === 'object' && Object.keys(msg.adjustments).length > 0) {
      remapState.statAdjustments = {
        top_speed: msg.adjustments.top_speed || 0,
        acceleration: msg.adjustments.acceleration || 0,
        handling: msg.adjustments.handling || 0,
        braking: msg.adjustments.braking || 0,
      };
    } else {
      remapState.statAdjustments = { top_speed: 0, acceleration: 0, handling: 0, braking: 0 };
    }

    buildArchGrid();
    buildSubPills();
    buildSliders();
    updateDNABar();
    updateSummary();
    calcCost();
    document.body.classList.add('visible');
  }

  if (msg.action === 'remapApplied') {
    // Could show success toast
  }
});

document.addEventListener('keydown', e => {
  if (e.key === 'Escape') closeNUI();
});
