'use strict';
// fish_hub NUI Script

let hubState = {
  playerName: '',
  chips: { v1: false, v2: false },
  currentPanel: 'market-legal',
  listings: [],
  illegalListings: [],
  messages: { global: [], illegal: [] },
  activeChannel: 'global',
  heatRanking: [],
  myIdentifier: '',
};

// ── Panel Switcher ──
const PANEL_TITLES = {
  'market-legal':   ['Marketplace', 'Legal Parts & Services'],
  'market-illegal': ['Black Market', 'Underground Parts — V2 Required'],
  'chat':           ['Community Chat', 'Global Channel'],
  'chat-illegal':   ['Underground Chat', 'V2 Encrypted Channel'],
  'heat':           ['HEAT Ranking', 'Top Active Vehicles by Illegal Mods'],
};

function switchPanel(id, el) {
  hubState.currentPanel = id;

  // V2 gate
  if ((id === 'market-illegal' || id === 'chat-illegal') && !hubState.chips.v2) {
    showToast('V2 chip required for underground access.', 'error');
    return;
  }

  document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
  el.classList.add('active');

  const titles = PANEL_TITLES[id] || ['Hub', ''];
  document.getElementById('panelTitle').innerHTML =
    `${titles[0]} <span>${titles[1]}</span>`;

  renderCurrentPanel();
  updateFooterAction(id);
}

function updateFooterAction(id) {
  const btn = document.getElementById('footerAction');
  if (id === 'market-legal' || id === 'market-illegal') {
    btn.style.display = 'flex';
    btn.innerHTML = '<span class="material-symbols-sharp">add</span>Post Listing';
    btn.onclick = () => showPostListing(id === 'market-illegal');
  } else if (id === 'chat' || id === 'chat-illegal') {
    btn.style.display = 'none';
  } else if (id === 'heat') {
    btn.style.display = 'flex';
    btn.innerHTML = '<span class="material-symbols-sharp">refresh</span>Refresh';
    btn.onclick = () => {
      fetch('https://fish_hub/getHeatRanking', { method: 'POST', body: '{}' });
    };
  }
}

function renderCurrentPanel() {
  const content = document.getElementById('mainContent');
  const id = hubState.currentPanel;

  if (id === 'market-legal')   renderMarket(content, false);
  else if (id === 'market-illegal') renderMarket(content, true);
  else if (id === 'chat')      renderChat(content, 'global');
  else if (id === 'chat-illegal') renderChat(content, 'illegal');
  else if (id === 'heat')      renderHeat(content);
}

// ── Marketplace ──
const LEVEL_COLORS = {
  stock: '#607d8b', l1: '#00d4ff', l2: '#4fc3f7', l3: '#ff9800', l4: '#ff1744', l5: '#a855f7'
};

function renderMarket(container, isIllegal) {
  const listings = isIllegal ? hubState.illegalListings : hubState.listings;
  let html = `<div class="listings-grid">`;

  if (listings.length === 0) {
    html += `<div class="empty-state">
      <span class="material-symbols-sharp">storefront</span>
      <h3>NO LISTINGS</h3>
      <p style="font-size:11px;color:var(--muted)">Be the first to post a listing.</p>
    </div>`;
  } else {
    listings.forEach(l => {
      const lvColor = LEVEL_COLORS[l.level] || '#ccc';
      html += `<div class="listing-card ${isIllegal ? 'illegal' : ''}" onclick="viewListing(${l.id})">
        <div class="listing-top">
          <span class="listing-level" style="border:1px solid ${lvColor};color:${lvColor};background:${lvColor}20">${(l.level || '?').toUpperCase()}</span>
          <span class="listing-price">$${Number(l.price || 0).toLocaleString()}</span>
        </div>
        <div class="listing-name">${l.category || 'Part'}</div>
        <div class="listing-desc">${l.description || '—'}</div>
        <div class="listing-seller">by ${l.seller_name || 'Unknown'}</div>
      </div>`;
    });
  }

  html += '</div>';
  container.innerHTML = html;

  // Request fresh listings
  fetch('https://fish_hub/getListings', {
    method: 'POST',
    body: JSON.stringify({ isIllegal })
  });
}

function showPostListing(isIllegal) {
  const container = document.getElementById('mainContent');
  container.innerHTML = `
    <div style="max-width:480px;margin:0 auto">
      <div style="font-family:var(--mono);font-size:9px;text-transform:uppercase;letter-spacing:2px;color:var(--muted);margin-bottom:16px">
        ${isIllegal ? '🔴 BLACK MARKET' : '🟢 LEGAL'} LISTING
      </div>
      <div style="display:flex;flex-direction:column;gap:10px">
        <div>
          <label style="font-size:11px;color:var(--muted);display:block;margin-bottom:4px">Category</label>
          <input id="lst-cat" class="chat-input" placeholder="e.g. motor, turbo, pneus..." style="width:100%">
        </div>
        <div>
          <label style="font-size:11px;color:var(--muted);display:block;margin-bottom:4px">Level</label>
          <select id="lst-lv" class="chat-input" style="width:100%">
            <option value="stock">Stock</option>
            <option value="l1">L1</option>
            <option value="l2">L2</option>
            <option value="l3">L3</option>
            ${isIllegal ? '<option value="l4">L4 🔥</option><option value="l5">L5 🔥</option>' : ''}
          </select>
        </div>
        <div>
          <label style="font-size:11px;color:var(--muted);display:block;margin-bottom:4px">Price ($)</label>
          <input id="lst-price" class="chat-input" type="number" placeholder="0" style="width:100%">
        </div>
        <div>
          <label style="font-size:11px;color:var(--muted);display:block;margin-bottom:4px">Description</label>
          <textarea id="lst-desc" class="chat-input" placeholder="Describe your listing..." style="width:100%;height:80px;resize:none"></textarea>
        </div>
        <div style="display:flex;gap:8px">
          <button class="btn btn-ghost" onclick="renderCurrentPanel()">Cancel</button>
          <button class="btn btn-purple" onclick="submitListing(${isIllegal})">
            <span class="material-symbols-sharp">upload</span>Post
          </button>
        </div>
      </div>
    </div>
  `;
}

function submitListing(isIllegal) {
  const data = {
    category:    document.getElementById('lst-cat').value,
    level:       document.getElementById('lst-lv').value,
    price:       parseInt(document.getElementById('lst-price').value) || 0,
    description: document.getElementById('lst-desc').value,
    is_illegal:  isIllegal,
    type:        'part'
  };
  if (!data.category || data.price < 0) { showToast('Please fill all fields.', 'error'); return; }
  fetch('https://fish_hub/createListing', { method: 'POST', body: JSON.stringify(data) });
  showToast('Listing posted!', 'success');

  // Show "posted" state — the server will broadcast listingCreated which will refresh the list
  const content = document.getElementById('mainContent');
  content.innerHTML = '<div style="color:var(--muted);font-family:var(--mono);font-size:12px;text-align:center;padding:40px 20px"><span class="material-symbols-sharp" style="font-size:32px;display:block;margin-bottom:12px;color:var(--green)">check_circle</span>Listing posted! Loading updated market...</div>';
  hubState.currentPanel = isIllegal ? 'market-illegal' : 'market-legal';

  // Request fresh listings to populate after short delay
  setTimeout(() => {
    fetch('https://fish_hub/getListings', { method: 'POST', body: JSON.stringify({ isIllegal }) });
  }, 800);
}


function viewListing(id) {
  // Placeholder: could open a detail modal
}

// ── Chat ──
function renderChat(container, channel) {
  hubState.activeChannel = channel;
  const isIllegal = channel === 'illegal';
  const msgs = hubState.messages[channel] || [];

  container.innerHTML = `
    <div class="chat-wrap">
      <div class="chat-channels">
        <div class="channel-btn ${channel === 'global' ? 'active' : ''}" onclick="switchChannel('global')">📢 Global</div>
        ${hubState.chips.v2 ? `<div class="channel-btn illegal ${channel === 'illegal' ? 'active' : ''}" onclick="switchChannel('illegal')">🔴 Underground</div>` : ''}
      </div>
      <div class="chat-messages" id="chatMessages">
        ${msgs.length ? msgs.map(m => formatMessage(m)).join('') : '<div style="color:var(--muted);font-size:11px;text-align:center;padding:20px">No messages yet...</div>'}
      </div>
      <div class="chat-input-row">
        <input class="chat-input" id="chatInput" placeholder="Message ${isIllegal ? '[encrypted]' : ''} — Press Enter" onkeydown="if(event.key==='Enter')sendMessage()">
        <button class="btn-send" onclick="sendMessage()">Send</button>
      </div>
    </div>
  `;

  // Scroll to bottom
  setTimeout(() => {
    const div = document.getElementById('chatMessages');
    if (div) div.scrollTop = div.scrollHeight;
  }, 50);

  // Request messages
  fetch('https://fish_hub/getMessages', {
    method: 'POST',
    body: JSON.stringify({ channel })
  });
}

function switchChannel(ch) {
  renderChat(document.getElementById('mainContent'), ch);
}

function formatMessage(m) {
  const isMine = m.sender_identifier === hubState.myIdentifier;
  const isSystem = m.sender_identifier === 'system';
  // sent_at may be a string "YYYY-MM-DD HH:MM:SS" or a Date/timestamp object
  let time = '';
  if (m.sent_at) {
    if (typeof m.sent_at === 'string') {
      time = m.sent_at.length >= 16 ? m.sent_at.substring(11, 16) : m.sent_at;
    } else if (m.sent_at instanceof Date) {
      time = m.sent_at.toTimeString().substring(0, 5);
    } else {
      time = String(m.sent_at).substring(0, 5);
    }
  }
  return `<div class="chat-msg ${isMine ? 'mine' : ''} ${isSystem ? 'system' : ''}">
    <div class="chat-msg-header">
      <span class="chat-sender">${isSystem ? 'SYSTEM' : m.sender_name}</span>
      <span class="chat-time">${time}</span>
    </div>
    <div class="chat-text">${escapeHtml(m.message)}</div>
  </div>`;
}

function sendMessage() {
  const input = document.getElementById('chatInput');
  const msg = (input.value || '').trim();
  if (!msg) return;
  input.value = '';
  fetch('https://fish_hub/sendMessage', {
    method: 'POST',
    body: JSON.stringify({ channel: hubState.activeChannel, message: msg })
  });
}

// ── HEAT Ranking ──
function renderHeat(container) {
  const ranking = hubState.heatRanking;
  if (!ranking.length) {
    container.innerHTML = `<div class="empty-state">
      <span class="material-symbols-sharp">local_fire_department</span>
      <h3>NO HEAT DATA</h3>
      <p style="font-size:11px">No vehicles with illegal modifications detected.</p>
    </div>`;
    return;
  }
  let html = `<table class="heat-table">
    <thead><tr><th>#</th><th>Plate</th><th>Rank</th><th>Archetype</th><th>HEAT</th><th></th></tr></thead>
    <tbody>`;
  ranking.forEach((v, i) => {
    const heatColor = v.heat >= 70 ? 'var(--red)' : v.heat >= 40 ? 'var(--orange)' : 'var(--green)';
    html += `<tr>
      <td class="heat-rank-num" style="color:${i===0?'var(--yellow)':i===1?'var(--muted)':i===2?'var(--orange)':'var(--muted)'}">${i+1}</td>
      <td style="font-family:var(--mono)">${v.plate}</td>
      <td>${v.rank || '?'}</td>
      <td style="font-size:10px;color:var(--muted)">${v.archetype || '?'}</td>
      <td>
        <div style="display:flex;align-items:center;gap:8px">
          <div class="heat-bar-mini" style="width:${v.heat}px;max-width:80px;background:${heatColor}"></div>
          <span style="font-family:var(--mono);font-size:12px;color:${heatColor}">${v.heat}%</span>
        </div>
      </td>
      <td style="color:var(--muted);font-size:10px">${v.heat >= 70 ? '🔴 HOT' : v.heat >= 40 ? '🟠 WARM' : '🟢 COOL'}</td>
    </tr>`;
  });
  html += '</tbody></table>';
  container.innerHTML = html;
}

// ── Chip Installer ──
function showChipInstaller() {
  const container = document.getElementById('mainContent');
  container.innerHTML = `
    <div style="max-width:400px;margin:0 auto;text-align:center">
      <div style="font-size:40px;margin-bottom:12px">💾</div>
      <div style="font-family:var(--orb);font-size:16px;letter-spacing:2px;margin-bottom:8px;color:var(--purple)">CHIP INSTALLER</div>
      <p style="font-size:11px;color:var(--muted);margin-bottom:20px;line-height:1.6">
        V1 grants access to the legal marketplace and community chat.<br>
        V2 unlocks the underground market and encrypted channels.
      </p>
      <div style="display:flex;gap:8px;justify-content:center">
        <button class="btn ${hubState.chips.v1 ? 'btn-ghost' : 'btn-purple'}" onclick="installChip('v1')" ${hubState.chips.v1 ? 'disabled' : ''}>
          <span class="material-symbols-sharp">memory</span>
          ${hubState.chips.v1 ? '✓ V1 Installed' : 'Install V1'}
        </button>
        <button class="btn ${hubState.chips.v2 ? 'btn-ghost' : 'btn-red'}" onclick="installChip('v2')" ${hubState.chips.v2 ? 'disabled' : ''}>
          <span class="material-symbols-sharp">memory</span>
          ${hubState.chips.v2 ? '✓ V2 Installed' : 'Install V2'}
        </button>
      </div>
    </div>
  `;
}

function installChip(type) {
  fetch('https://fish_hub/installChip', {
    method: 'POST',
    body: JSON.stringify({ chipType: type })
  });
}

// ── Toasts ──
function showToast(msg, type) {
  const toast = document.createElement('div');
  toast.style.cssText = `position:fixed;bottom:20px;right:20px;padding:10px 16px;border-radius:8px;font-size:12px;z-index:9999;transition:opacity 0.3s;backdrop-filter:blur(10px);border:1px solid;font-family:var(--sans);color:${type==='error'?'var(--red)':type==='success'?'var(--green)':'var(--cyan)'};background:${type==='error'?'rgba(255,23,68,0.15)':type==='success'?'rgba(0,255,136,0.15)':'rgba(0,212,255,0.15)'};border-color:${type==='error'?'rgba(255,23,68,0.4)':type==='success'?'rgba(0,255,136,0.4)':'rgba(0,212,255,0.4)'}`;
  toast.textContent = msg;
  document.body.appendChild(toast);
  setTimeout(() => { toast.style.opacity = '0'; setTimeout(() => toast.remove(), 300); }, 3000);
}

function escapeHtml(str) {
  return String(str).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}

function closeNUI() {
  fetch('https://fish_hub/close', { method: 'POST', body: '{}' });
  document.body.classList.remove('visible');
}

// ── NUI Messages ──
window.addEventListener('message', e => {
  const msg = e.data;
  if (!msg || !msg.action) return;

  if (msg.action === 'opened') {
    hubState.playerName    = msg.name || '—';
    hubState.chips         = msg.chips || { v1: false, v2: false };
    hubState.myIdentifier  = msg.identifier || '';

    document.getElementById('playerName').textContent = hubState.playerName;
    updateChipBadges();
    renderCurrentPanel();
    document.body.classList.add('visible');

    // Pre-load listings
    fetch('https://fish_hub/getListings', { method:'POST', body: JSON.stringify({ isIllegal: false }) });
    fetch('https://fish_hub/getHeatRanking', { method: 'POST', body: '{}' });
  }

  if (msg.action === 'receiveListings') {
    if (msg.isIllegal) hubState.illegalListings = msg.listings || [];
    else hubState.listings = msg.listings || [];
    if ((hubState.currentPanel === 'market-legal' && !msg.isIllegal) ||
        (hubState.currentPanel === 'market-illegal' && msg.isIllegal)) {
      renderCurrentPanel();
    }
  }

  if (msg.action === 'receiveMessages') {
    hubState.messages[msg.channel] = msg.messages || [];
    if (hubState.activeChannel === msg.channel) {
      const div = document.getElementById('chatMessages');
      if (div) {
        div.innerHTML = (msg.messages||[]).map(m => formatMessage(m)).join('');
        div.scrollTop = div.scrollHeight;
      }
    }
  }

  if (msg.action === 'newMessage') {
    const ch = msg.channel;
    if (!hubState.messages[ch]) hubState.messages[ch] = [];
    hubState.messages[ch].push(msg);
    if (hubState.activeChannel === ch) {
      const div = document.getElementById('chatMessages');
      if (div) {
        div.innerHTML += formatMessage(msg);
        div.scrollTop = div.scrollHeight;
      }
    }
  }

  if (msg.action === 'receiveHeatRanking') {
    hubState.heatRanking = msg.ranking || [];
    if (hubState.currentPanel === 'heat') renderCurrentPanel();
  }

  if (msg.action === 'chipInstalled') {
    hubState.chips[msg.chipType] = true;
    updateChipBadges();
    showToast(`Chip ${msg.chipType.toUpperCase()} installed!`, 'success');
    showChipInstaller();
  }

  if (msg.action === 'listingCreated') {
    const listing = msg.listing || msg;
    if (listing.is_illegal) hubState.illegalListings.unshift(listing);
    else hubState.listings.unshift(listing);
    // Re-render market if currently viewing it
    if (hubState.currentPanel === 'market-legal' && !listing.is_illegal ||
        hubState.currentPanel === 'market-illegal' && listing.is_illegal) {
      renderCurrentPanel();
    }
  }

  if (msg.action === 'listingDeleted') {
    const id = msg.listingId;
    hubState.listings = hubState.listings.filter(l => l.id !== id);
    hubState.illegalListings = hubState.illegalListings.filter(l => l.id !== id);
    renderCurrentPanel();
  }
});

function updateChipBadges() {
  const row = document.getElementById('chipRow');
  let html = '';
  if (!hubState.chips.v1 && !hubState.chips.v2) html = '<span class="chip-badge chip-none">No Chip</span>';
  if (hubState.chips.v1) html += '<span class="chip-badge chip-v1">V1</span>';
  if (hubState.chips.v2) html += '<span class="chip-badge chip-v2">V2</span>';
  row.innerHTML = html;
}

document.addEventListener('keydown', e => {
  if (e.key === 'Escape') closeNUI();
});
