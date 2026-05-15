'use strict';
// fish_tunes NUI Script

let tuneState = {
  plate: '',
  vehicleNetId: 0,
  currentParts: {},
  categories: [],
  diagnostics: {},
  heat: 0,
  maxHeat: 100,
  totalBonuses: {},
  instability: 0,
  partCosts: {},
  drivetrain: 'FWD',
};

// ── Tabs ──
function switchTab(id, el) {
  document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
  document.querySelectorAll('.panel').forEach(p => p.classList.remove('active'));
  el.classList.add('active');
  document.getElementById('panel-' + id).classList.add('active');
}

// ── HEAT ──
function updateHeat(heat, max) {
  max = max || 100;
  const pct = Math.min(heat / max * 100, 100);
  const bar = document.getElementById('heatBar');
  const val = document.getElementById('heatVal');
  bar.style.width = pct + '%';
  if (pct < 30) { bar.style.background = 'var(--green)'; val.style.color = 'var(--green)'; }
  else if (pct < 60) { bar.style.background = 'var(--orange)'; val.style.color = 'var(--orange)'; }
  else { bar.style.background = 'var(--red)'; val.style.color = 'var(--red)'; }
  val.textContent = Math.round(heat) + '%';
}

// ── Parts Grid ──
function buildPartsGrid() {
  const grid = document.getElementById('partsGrid');
  grid.innerHTML = '';

  tuneState.categories.forEach(cat => {
    const current = tuneState.currentParts[cat.key] || 'stock';
    const card = document.createElement('div');
    card.className = 'part-card';
    card.innerHTML = `
      <div class="part-header">
        <div class="part-icon">
          <span class="material-symbols-sharp" style="font-size:16px!important">${cat.icon || 'settings'}</span>
        </div>
        <div>
          <div class="part-name">${cat.label}</div>
          <div style="font-family:var(--mono);font-size:9px;color:var(--muted)">${cat.description || ''}</div>
        </div>
        <div class="part-current">${current.toUpperCase()}</div>
      </div>
      <div class="level-pills" id="pills-${cat.key}"></div>
    `;
    grid.appendChild(card);

    // Level pills
    const pillsDiv = card.querySelector('#pills-' + cat.key);
    const levels = ['stock','l1','l2','l3','l4','l5'];
    levels.forEach(lv => {
      const lvInfo = (tuneState.partLevels || {})[lv] || {};
      const pill = document.createElement('div');
      const isActive = current === lv;
      const isIllegal = !lvInfo.legal && lv !== 'stock';
      const cost = (tuneState.partCosts || {})[lv] || 0;

      pill.className = `lv-pill ${isActive ? 'active-' + lv : ''} ${isIllegal ? 'illegal' : ''}`;
      pill.textContent = lv.toUpperCase();
      pill.title = cost > 0 ? `$${cost.toLocaleString()}` : 'Free';

      pill.onclick = () => installPart(cat.key, lv);
      pillsDiv.appendChild(pill);
    });
  });
}

function installPart(category, level) {
  fetch('https://fish_tunes/installPart', {
    method: 'POST',
    body: JSON.stringify({ category, level })
  });
}

// ── Diagnostics ──
function buildDiagnostics() {
  const grid = document.getElementById('diagGrid');
  const d = tuneState.diagnostics || {};

  const parts = [
    { key:'engine',       label:'Engine',       icon:'settings' },
    { key:'transmission', label:'Gearbox',       icon:'cached' },
    { key:'suspension',   label:'Suspension',    icon:'compress' },
    { key:'brakes',       label:'Brakes',        icon:'radio_button_checked' },
    { key:'tires',        label:'Tires',         icon:'tire_repair' },
    { key:'turbo',        label:'Turbo',         icon:'air' },
  ];

  grid.innerHTML = parts.map(p => {
    const h = d[p.key] || 100;
    const color = h >= 75 ? 'var(--green)' : h >= 50 ? 'var(--orange)' : h >= 25 ? 'var(--yellow)' : 'var(--red)';
    const label = h >= 90 ? 'Excellent' : h >= 75 ? 'Good' : h >= 50 ? 'Fair' : h >= 25 ? 'Poor' : 'Critical';
    return `<div class="diag-card">
      <div class="diag-header">
        <span class="diag-name">${p.label}</span>
        <span class="diag-pct" style="color:${color}">${Math.round(h)}%</span>
      </div>
      <div class="diag-bar-track">
        <div class="diag-bar-fill" style="width:${h}%;background:${color}"></div>
      </div>
      <div style="font-family:var(--mono);font-size:9px;color:${color};margin-top:4px">${label}</div>
    </div>`;
  }).join('');

  // Repair section
  const repairList = document.getElementById('repairList');
  repairList.innerHTML = `
    <div class="repair-row">
      <div class="repair-info">
        <div class="repair-label">Full Vehicle Repair</div>
        <div class="repair-hint">Restores all components to 100%</div>
      </div>
      <button class="btn-repair" onclick="repairVehicle('all')">Repair All — $2,500</button>
    </div>
  `;
  parts.forEach(p => {
    const h = d[p.key] || 100;
    if (h < 100) {
      repairList.innerHTML += `<div class="repair-row">
        <div class="repair-info">
          <div class="repair-label">${p.label}</div>
          <div class="repair-hint">Current: ${Math.round(h)}%</div>
        </div>
        <button class="btn-repair" onclick="repairVehicle('${p.key}')">Repair — $2,500</button>
      </div>`;
    }
  });
}

function repairVehicle(partType) {
  fetch('https://fish_tunes/repairVehicle', {
    method: 'POST',
    body: JSON.stringify({ partType })
  });
}

// ── Drivetrain ──
function buildDrivetrain() {
  const panel = document.getElementById('drivetrainPanel');
  const options = ['FWD', 'RWD', 'AWD'];
  panel.innerHTML = `
    <div class="section-label" style="font-family:var(--mono);font-size:9px;text-transform:uppercase;letter-spacing:2px;color:var(--muted);margin-bottom:10px">Drivetrain Layout — $5,000</div>
    <div style="display:flex;gap:8px;margin-bottom:16px">
      ${options.map(dt => `
        <div style="flex:1;padding:14px;text-align:center;border-radius:10px;border:1px solid ${tuneState.drivetrain === dt ? 'var(--cyan)' : 'var(--border)'};background:${tuneState.drivetrain === dt ? 'rgba(0,212,255,0.08)' : 'rgba(255,255,255,0.02)'};cursor:pointer;transition:all 0.2s"
             onclick="convertDrivetrain('${dt}')">
          <div style="font-family:var(--orb);font-size:16px;font-weight:700;color:${tuneState.drivetrain === dt ? 'var(--cyan)' : 'var(--muted)'}">${dt}</div>
          <div style="font-family:var(--mono);font-size:9px;color:var(--muted);margin-top:4px">
            ${dt === 'FWD' ? 'Front Drive' : dt === 'RWD' ? 'Rear Drive' : 'All-Wheel'}
          </div>
        </div>
      `).join('')}
    </div>
    <div style="font-family:var(--mono);font-size:10px;color:var(--muted);padding:10px;background:rgba(255,255,255,0.02);border-radius:8px;border:1px solid var(--border)">
      <strong style="color:var(--orange)">FWD:</strong> Understeer, stable, poor launch &nbsp;·&nbsp;
      <strong style="color:var(--cyan)">RWD:</strong> Oversteer, drifts, best launch &nbsp;·&nbsp;
      <strong style="color:var(--green)">AWD:</strong> All-weather, best traction, heavy
    </div>
  `;
}

function convertDrivetrain(dt) {
  fetch('https://fish_tunes/convertDrivetrain', {
    method: 'POST',
    body: JSON.stringify({ drivetrain: dt })
  });
  tuneState.drivetrain = dt;
  buildDrivetrain();
}

// ── Instability Warning ──
function updateInstabilityWarning(instab) {
  const warn = document.getElementById('instabWarn');
  const txt  = document.getElementById('instabText');
  if (instab > 0) {
    warn.style.display = 'flex';
    txt.textContent = `⚡ Instability ${instab}/10 — Illegal parts reduce traction & handling predictability.`;
  } else {
    warn.style.display = 'none';
  }
}

// ── Bonus Display ──
function updateBonusDisplay() {
  const b = tuneState.totalBonuses || {};
  const parts = [
    b.top_speed    ? `+${b.top_speed}% Speed` : null,
    b.acceleration ? `+${b.acceleration}% Accel` : null,
    b.handling     ? `+${b.handling}% Handling` : null,
    b.braking      ? `+${b.braking}% Braking` : null,
  ].filter(Boolean);
  document.getElementById('totalBonusDisplay').textContent =
    parts.length ? parts.join('  ·  ') : 'No active bonuses';
}

function closeNUI() {
  fetch('https://fish_tunes/close', { method: 'POST', body: '{}' });
  document.body.classList.remove('visible');
}

// ── NUI Messages ──
window.addEventListener('message', e => {
  const msg = e.data;
  if (!msg || !msg.action) return;

  if (msg.action === 'openAdvancedTunes') {
    tuneState.plate         = msg.plate || '';
    tuneState.vehicleNetId  = msg.vehicleNetId || 0;
    tuneState.currentParts  = msg.currentParts || {};
    tuneState.categories    = msg.categories || [];
    tuneState.diagnostics   = msg.diagnostics || {};
    tuneState.heat          = msg.currentHeat || 0;
    tuneState.maxHeat       = msg.maxHeat || 100;
    tuneState.totalBonuses  = msg.totalBonuses || {};
    tuneState.instability   = msg.instability || 0;
    tuneState.partCosts     = msg.partCosts || {};
    tuneState.partLevels    = msg.partLevels || {};
    tuneState.drivetrain    = (msg.drivetrain && msg.drivetrain.current) || 'FWD';

    document.getElementById('vehName').textContent  = msg.vehicleName || '—';
    document.getElementById('vehPlate').textContent = tuneState.plate;
    document.getElementById('piChip').textContent   = `PI: ${(msg.classData && msg.classData.score) || '—'}`;

    updateHeat(tuneState.heat, tuneState.maxHeat);
    buildPartsGrid();
    buildDiagnostics();
    buildDrivetrain();
    updateBonusDisplay();
    updateInstabilityWarning(tuneState.instability);
    document.body.classList.add('visible');
  }

  if (msg.action === 'partInstalled') {
    tuneState.currentParts[msg.category] = msg.level;
    if (msg.totalBonuses) tuneState.totalBonuses = msg.totalBonuses;
    if (msg.instability !== undefined) tuneState.instability = msg.instability;
    buildPartsGrid();
    updateBonusDisplay();
    updateInstabilityWarning(tuneState.instability);
  }

  if (msg.action === 'updateHeat') {
    tuneState.heat = msg.heat || 0;
    updateHeat(tuneState.heat, tuneState.maxHeat);
  }

  if (msg.action === 'updateHealth') {
    tuneState.diagnostics = msg.health || {};
    buildDiagnostics();
  }
});

document.addEventListener('keydown', e => {
  if (e.key === 'Escape') closeNUI();
});
