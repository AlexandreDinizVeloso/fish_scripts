'use strict';
// fish_normalizer NUI script

let nData = {
  plate: '',
  vehicleNetId: 0,
  archetype: 'esportivo',
  subArchetype: null,
  rank: 'C',
  score: 0,
  stats: {},
  config: null,
};

const ARCHETYPES = [
  { key:'esportivo', label:'Esportivo', icon:'🏎️', desc:'Grip & Corners' },
  { key:'possante',  label:'Possante',  icon:'💪', desc:'Raw Power' },
  { key:'exotico',   label:'Exótico',   icon:'🚀', desc:'Top Speed' },
  { key:'supercarro',label:'Supercarro',icon:'⚡', desc:'All-Around' },
  { key:'moto',      label:'Moto',      icon:'🏍️', desc:'Ultra-Light' },
  { key:'utilitario',label:'Utilitário',icon:'🚛', desc:'Work Horse' },
  { key:'especial',  label:'Especial',  icon:'🌟', desc:'Unique' },
];

const SUB_ARCHETYPES = [
  'drifter','dragster','late_surger','curve_king','grip_master',
  'street_racer','rally_spec','drift_king','time_attack','sleeper'
];

const RANKS = [
  { name:'C', color:'#607d8b', bg:'rgba(96,125,139,0.12)' },
  { name:'B', color:'#4caf50', bg:'rgba(76,175,80,0.12)' },
  { name:'A', color:'#ff9800', bg:'rgba(255,152,0,0.12)' },
  { name:'S', color:'#e91e63', bg:'rgba(233,30,99,0.12)' },
];

function buildArchetypeGrid() {
  const grid = document.getElementById('archetypeGrid');
  grid.innerHTML = '';
  ARCHETYPES.forEach(a => {
    const card = document.createElement('div');
    card.className = 'arch-card' + (nData.archetype === a.key ? ' selected' : '');
    card.innerHTML = `<div class="icon">${a.icon}</div><div class="name">${a.label}</div><div class="desc">${a.desc}</div>`;
    card.onclick = () => {
      nData.archetype = a.key;
      buildArchetypeGrid();
      recalcScore();
    };
    grid.appendChild(card);
  });
}

function buildSubGrid() {
  const grid = document.getElementById('subGrid');
  grid.innerHTML = '';
  // None option
  const none = document.createElement('div');
  none.className = 'sub-card' + (!nData.subArchetype ? ' selected' : '');
  none.textContent = 'None';
  none.onclick = () => { nData.subArchetype = null; buildSubGrid(); };
  grid.appendChild(none);

  SUB_ARCHETYPES.forEach(s => {
    const card = document.createElement('div');
    card.className = 'sub-card' + (nData.subArchetype === s ? ' selected' : '');
    card.textContent = s.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
    card.onclick = () => { nData.subArchetype = s; buildSubGrid(); };
    grid.appendChild(card);
  });
}

function buildRankSelector() {
  const sel = document.getElementById('rankSelector');
  sel.innerHTML = '';
  RANKS.forEach(r => {
    const btn = document.createElement('div');
    const isSel = nData.rank === r.name;
    btn.className = 'rank-btn' + (isSel ? ' sel-' + r.name : '');
    btn.textContent = r.name;
    btn.style.borderColor = isSel ? r.color : '';
    btn.onclick = () => { nData.rank = r.name; buildRankSelector(); updateRankBadge(); };
    sel.appendChild(btn);
  });
}

function updateRankBadge() {
  const badge = document.getElementById('rankBadge');
  const r = RANKS.find(x => x.name === nData.rank) || RANKS[0];
  badge.textContent = nData.rank;
  badge.style.borderColor = r.color;
  badge.style.color = r.color;
  badge.style.background = r.bg;
}

function buildStatsPanel() {
  const panel = document.getElementById('statsPanel');
  const stats = nData.stats || {};
  const entries = [
    { key:'top_speed',    label:'Top Speed',    max:340 },
    { key:'acceleration', label:'Acceleration', max:100 },
    { key:'handling',     label:'Handling',     max:100 },
    { key:'braking',      label:'Braking',      max:100 },
  ];
  panel.innerHTML = entries.map(e => {
    const val = stats[e.key] || 0;
    const pct = Math.min(val / e.max * 100, 100);
    return `<div class="stat-row">
      <div>
        <div style="display:flex;justify-content:space-between">
          <span class="stat-label">${e.label}</span>
          <span class="stat-val">${val.toFixed ? val.toFixed(0) : val}</span>
        </div>
        <div class="stat-bar-wrap"><div class="stat-bar" style="width:${pct}%"></div></div>
      </div>
    </div>`;
  }).join('');
}

function recalcScore() {
  // Simple preview: sum of weighted stats with archetype modifier
  const stats = nData.stats || {};
  const topSpeed = stats.top_speed || 0;
  const accel    = stats.acceleration || 0;
  const handling = stats.handling || 0;
  const braking  = stats.braking || 0;
  const base = (topSpeed * 0.35) + (accel * 0.25) + (handling * 0.25) + (braking * 0.15);
  nData.score = Math.min(999, Math.round(base));
  document.getElementById('scorePreview').textContent = nData.score;
}

function saveNormalization() {
  fetch('https://fish_normalizer/saveData', {
    method: 'POST',
    body: JSON.stringify({
      plate:        nData.plate,
      vehicleNetId: nData.vehicleNetId,
      archetype:    nData.archetype,
      subArchetype: nData.subArchetype,
      rank:         nData.rank,
      score:        nData.score,
      normalized:   true,
    })
  });
  closeNUI();
}

function closeNUI() {
  fetch('https://fish_normalizer/close', { method:'POST', body:'{}' });
  document.body.classList.remove('visible');
}

window.addEventListener('message', e => {
  const msg = e.data;
  if (!msg || !msg.action) return;

  if (msg.action === 'openNormalizer') {
    nData.plate        = msg.plate || '';
    nData.vehicleNetId = msg.vehicleNetId || 0;
    nData.archetype    = (msg.existing && msg.existing.archetype) || 'esportivo';
    nData.subArchetype = (msg.existing && msg.existing.sub_archetype) || null;
    nData.rank         = (msg.existing && msg.existing.rank) || 'C';
    nData.score        = (msg.existing && msg.existing.score) || 0;
    nData.stats        = (msg.existing && msg.existing.stats) || {};

    document.getElementById('vehName').textContent  = msg.vehicleName || '—';
    document.getElementById('vehPlate').textContent = nData.plate || '———————';
    document.getElementById('scorePreview').textContent = nData.score;

    buildArchetypeGrid();
    buildSubGrid();
    buildRankSelector();
    buildStatsPanel();
    updateRankBadge();
    document.body.classList.add('visible');
  }

  if (msg.action === 'updateStats') {
    nData.stats = msg.stats || {};
    buildStatsPanel();
    recalcScore();
  }
});

document.addEventListener('keydown', e => {
  if (e.key === 'Escape') closeNUI();
});
