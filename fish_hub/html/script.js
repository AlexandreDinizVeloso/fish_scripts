// Fish Hub - NUI Script
(function() {
    'use strict';

    let hubData = {};
    let currentChannel = 'general';
    let currentFilter = 'all';

    // ============================================================
    // NUI Message Handler
    // ============================================================
    window.addEventListener('message', function(e) {
        const data = e.data;
        if (!data || !data.action) return;

        switch (data.action) {
            case 'openHub': handleOpenHub(data.data); break;
            case 'updateHub': handleUpdateHub(data.data); break;
            case 'newMessage': handleNewMessage(data.data); break;
            case 'updateMarketplace': handleUpdateMarketplace(data.data); break;
            case 'updateHeat': handleUpdateHeat(data.data); break;
            case 'notification': handleNotification(data.data); break;
            case 'closeHub': handleCloseHub(); break;
        }
    });

    // ============================================================
    // Open / Close
    // ============================================================
    function handleOpenHub(data) {
        hubData = data || {};
        document.getElementById('app').classList.remove('hidden');
        renderAll();
    }

    function handleUpdateHub(data) {
        hubData = data || {};
        renderAll();
    }

    function handleCloseHub() {
        document.getElementById('app').classList.add('hidden');
    }

    function renderAll() {
        renderChipStatus();
        renderDashboard();
        renderMarketplace();
        renderServices();
        renderChat();
        renderHeat();
    }

    // ============================================================
    // Navigation
    // ============================================================
    document.addEventListener('DOMContentLoaded', function() {
        // Nav items
        document.querySelectorAll('.nav-item').forEach(item => {
            item.addEventListener('click', function() {
                const view = this.dataset.view;
                switchView(view);
            });
        });

        // Close button
        document.getElementById('btnClose').addEventListener('click', function() {
            fetch('https://fish_hub/close', { method: 'POST', body: '{}' });
        });

        // Install chip buttons
        document.getElementById('btnInstallV1').addEventListener('click', function() {
            fetch('https://fish_hub/installChip', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ chipType: 'v1' })
            });
        });
        document.getElementById('btnInstallV2').addEventListener('click', function() {
            fetch('https://fish_hub/installChip', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ chipType: 'v2' })
            });
        });

        // Marketplace filters
        document.getElementById('marketplaceFilters').addEventListener('click', function(e) {
            if (e.target.classList.contains('filter-tab')) {
                currentFilter = e.target.dataset.filter;
                document.querySelectorAll('#marketplaceFilters .filter-tab').forEach(t => t.classList.remove('active'));
                e.target.classList.add('active');
                renderMarketplace();
            }
        });

        // Create listing
        document.getElementById('btnCreateListing').addEventListener('click', function() {
            document.getElementById('createListingModal').classList.remove('hidden');
        });
        document.getElementById('closeListingModal').addEventListener('click', function() {
            document.getElementById('createListingModal').classList.add('hidden');
        });
        document.getElementById('submitListing').addEventListener('click', function() {
            const name = document.getElementById('listingName').value.trim();
            const price = parseInt(document.getElementById('listingPrice').value) || 0;
            const type = document.getElementById('listingType').value;
            const desc = document.getElementById('listingDesc').value.trim();
            if (!name || !price) return;
            fetch('https://fish_hub/createListing', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ name, price, type, description: desc })
            });
            document.getElementById('createListingModal').classList.add('hidden');
            document.getElementById('listingName').value = '';
            document.getElementById('listingPrice').value = '';
            document.getElementById('listingDesc').value = '';
        });

        // Chat
        document.getElementById('btnSend').addEventListener('click', sendMessage);
        document.getElementById('chatInput').addEventListener('keydown', function(e) {
            if (e.key === 'Enter') sendMessage();
        });

        // ESC to close (only if hub is visible)
        document.addEventListener('keydown', function(e) {
            const app = document.getElementById('app');
            if (e.key === 'Escape' && app && !app.classList.contains('hidden')) {
                fetch('https://fish_hub/close', { method: 'POST', body: '{}' });
            }
        });
    });

    function switchView(viewName) {
        document.querySelectorAll('.view').forEach(v => v.classList.remove('active'));
        document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
        const target = document.getElementById('view-' + viewName);
        if (target) target.classList.add('active');
        const nav = document.querySelector(`.nav-item[data-view="${viewName}"]`);
        if (nav) nav.classList.add('active');
    }

    // ============================================================
    // Chip Status
    // ============================================================
    function renderChipStatus() {
        const status = document.getElementById('chipStatus');
        const hasV1 = hubData.hasV1;
        const hasV2 = hubData.hasV2;
        const text = status.querySelector('.chip-text');

        if (hasV1 || hasV2) {
            status.classList.add('active');
            let label = [];
            if (hasV1) label.push('V1');
            if (hasV2) label.push('V2');
            text.textContent = label.join(' + ');
        } else {
            status.classList.remove('active');
            text.textContent = 'NO CHIP';
        }
    }

    // ============================================================
    // Dashboard
    // ============================================================
    function renderDashboard() {
        // Chip slots
        const slots = document.getElementById('chipSlots');
        const chips = hubData.chips || [];
        let slotsHTML = '';
        for (let i = 0; i < (hubData.maxChips || 2); i++) {
            const chip = chips[i];
            if (chip) {
                const cfg = (hubData.chipTypes || {})[chip.type] || {};
                slotsHTML += `<div class="chip-slot installed ${chip.type}">
                    <div class="slot-icon">💳</div>
                    <div class="slot-label">${cfg.label || chip.type.toUpperCase()}</div>
                    <button class="btn-remove-chip" data-chip="${chip.type}" style="font-size:8px;color:var(--accent-red);background:none;border:none;cursor:pointer;margin-top:4px;">REMOVE</button>
                </div>`;
            } else {
                slotsHTML += `<div class="chip-slot empty"><div class="slot-icon">💳</div><div class="slot-label">EMPTY</div></div>`;
            }
        }
        slots.innerHTML = slotsHTML;

        // Remove chip buttons
        slots.querySelectorAll('.btn-remove-chip').forEach(btn => {
            btn.addEventListener('click', function() {
                fetch('https://fish_hub/removeChip', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ chipType: this.dataset.chip })
                });
            });
        });

        // Quick stats
        const marketplace = hubData.marketplace || { legal: [], illegal: [] };
        const totalListings = (marketplace.legal || []).length + (marketplace.illegal || []).length;
        const heat = hubData.heat || {};
        document.getElementById('statListings').textContent = totalListings;
        document.getElementById('statMessages').textContent = (hubData.chat ? Object.values(hubData.chat).reduce((s, c) => s + (c.messages || []).length, 0) : 0);
        document.getElementById('statHeat').textContent = heat.totalHeat || 0;

        // Find rank
        const ranking = heat.ranking || [];
        let rank = '--';
        const serverId = hubData.serverId;
        for (let i = 0; i < ranking.length; i++) {
            if (ranking[i].playerId === serverId) { rank = '#' + (i + 1); break; }
        }
        document.getElementById('statRank').textContent = rank;

        // Player ID
        document.getElementById('playerId').textContent = 'ID: ' + (serverId || '---');

        // HEAT in header
        document.getElementById('headerHeat').textContent = heat.totalHeat || 0;

        // Activity (recent messages as activity)
        const activityList = document.getElementById('activityList');
        const allMsgs = [];
        if (hubData.chat) {
            Object.values(hubData.chat).forEach(ch => {
                (ch.messages || []).slice(-3).forEach(m => allMsgs.push(m));
            });
        }
        allMsgs.sort((a, b) => (b.timestamp || 0) - (a.timestamp || 0));
        if (allMsgs.length === 0) {
            activityList.innerHTML = '<div class="activity-empty">No recent activity</div>';
        } else {
            activityList.innerHTML = allMsgs.slice(0, 5).map(m => `
                <div class="activity-item">
                    <span class="activity-icon">💬</span>
                    <span class="activity-text"><strong>${esc(m.sender || 'Unknown')}:</strong> ${esc((m.text || '').substring(0, 50))}</span>
                    <span class="activity-time">${formatTime(m.timestamp)}</span>
                </div>
            `).join('');
        }
    }

    // ============================================================
    // Marketplace
    // ============================================================
    function renderMarketplace() {
        const grid = document.getElementById('listingsGrid');
        const marketplace = hubData.marketplace || { legal: [], illegal: [] };
        let listings = [];

        if (currentFilter === 'all') {
            listings = [...(marketplace.legal || []), ...(marketplace.illegal || [])];
        } else if (currentFilter === 'legal') {
            listings = marketplace.legal || [];
        } else {
            listings = marketplace.illegal || [];
        }

        if (listings.length === 0) {
            grid.innerHTML = '<div class="activity-empty">No listings available</div>';
            return;
        }

        grid.innerHTML = listings.map(l => `
            <div class="listing-card ${l.type || 'legal'}">
                <div class="listing-header">
                    <div class="listing-name">${esc(l.name || 'Unknown')}</div>
                    <div class="listing-price">$${formatNum(l.price || 0)}</div>
                </div>
                <div class="listing-desc">${esc(l.description || 'No description')}</div>
                <div class="listing-footer">
                    <span class="listing-type ${l.type || 'legal'}">${(l.type || 'legal').toUpperCase()}</span>
                    <span class="listing-seller">${esc(l.seller || 'Anonymous')}</span>
                </div>
                <button class="btn-accept" data-id="${l.id || ''}">CONTACT SELLER</button>
            </div>
        `).join('');

        grid.querySelectorAll('.btn-accept').forEach(btn => {
            btn.addEventListener('click', function() {
                fetch('https://fish_hub/acceptListing', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ listingId: this.dataset.id })
                });
            });
        });
    }

    function handleUpdateMarketplace(data) {
        hubData.marketplace = data;
        renderMarketplace();
        renderDashboard();
    }

    // ============================================================
    // Services
    // ============================================================
    function renderServices() {
        const grid = document.getElementById('servicesGrid');
        const services = hubData.services || [];

        if (services.length === 0) {
            grid.innerHTML = '<div class="activity-empty">No services available. Install V2 chip for more.</div>';
            return;
        }

        grid.innerHTML = services.map(s => `
            <div class="service-card">
                <div class="service-icon">${s.icon || '🔧'}</div>
                <div class="service-name">${esc(s.label || s.id)}</div>
                <div class="service-desc">${esc(s.description || '')}</div>
                ${s.requiresV2 ? '<span class="service-badge illegal">REQUIRES V2</span>' : ''}
                <button class="btn-request" data-service="${s.id}">REQUEST SERVICE</button>
            </div>
        `).join('');

        grid.querySelectorAll('.btn-request').forEach(btn => {
            btn.addEventListener('click', function() {
                const svcId = this.dataset.service;
                const details = prompt('Describe what you need:');
                if (!details) return;
                fetch('https://fish_hub/requestPart', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ serviceType: svcId, details })
                });
            });
        });
    }

    // ============================================================
    // Chat
    // ============================================================
    function renderChat() {
        const channelList = document.getElementById('channelList');
        const chat = hubData.chat || {};
        const hasV2 = hubData.hasV2;

        let channelsHTML = '';
        for (const [key, ch] of Object.entries(chat)) {
            if (ch.requiresV2 && !hasV2) {
                channelsHTML += `<div class="channel-item locked" data-channel="${key}">
                    <span class="ch-icon">🔒</span>
                    <span class="ch-name">${esc(ch.label)}</span>
                </div>`;
            } else {
                const isActive = key === currentChannel;
                const unread = 0; // could track
                channelsHTML += `<div class="channel-item ${isActive ? 'active' : ''}" data-channel="${key}">
                    <span class="ch-icon">${ch.icon || '💬'}</span>
                    <span class="ch-name">${esc(ch.label)}</span>
                    ${unread > 0 ? `<span class="ch-unread">${unread}</span>` : ''}
                </div>`;
            }
        }
        channelList.innerHTML = channelsHTML;

        channelList.querySelectorAll('.channel-item:not(.locked)').forEach(item => {
            item.addEventListener('click', function() {
                currentChannel = this.dataset.channel;
                document.querySelectorAll('.channel-item').forEach(c => c.classList.remove('active'));
                this.classList.add('active');
                renderChatMessages();
                updateChatHeader();
            });
        });

        renderChatMessages();
        updateChatHeader();
    }

    function renderChatMessages() {
        const container = document.getElementById('chatMessages');
        const chat = hubData.chat || {};
        const channel = chat[currentChannel];
        if (!channel || !channel.messages || channel.messages.length === 0) {
            container.innerHTML = '<div class="activity-empty">No messages yet</div>';
            return;
        }

        const serverId = hubData.serverId;
        container.innerHTML = channel.messages.map(m => {
            const isSelf = m.playerId === serverId;
            return `<div class="chat-msg ${isSelf ? 'self' : 'other'}">
                ${!isSelf ? `<div class="msg-sender">${esc(m.playerName || 'Unknown')}</div>` : ''}
                <div class="msg-text">${esc(m.message || '')}</div>
                <div class="msg-time">${formatTime(m.timestamp)}</div>
            </div>`;
        }).join('');

        container.scrollTop = container.scrollHeight;
    }

    function updateChatHeader() {
        const chat = hubData.chat || {};
        const channel = chat[currentChannel];
        if (channel) {
            document.querySelector('.chat-channel-icon').textContent = channel.icon || '💬';
            document.querySelector('.chat-channel-name').textContent = channel.label || currentChannel;
        }
    }

    function sendMessage() {
        const input = document.getElementById('chatInput');
        const msg = input.value.trim();
        if (!msg) return;
        fetch('https://fish_hub/sendMessage', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ channel: currentChannel, message: msg })
        });
        input.value = '';
    }

    function handleNewMessage(msg) {
        if (!hubData.chat) hubData.chat = {};
        const ch = hubData.chat[msg.channel];
        if (ch && ch.messages) {
            ch.messages.push(msg);
            if (ch.messages.length > 100) ch.messages.shift();
        }
        if (msg.channel === currentChannel) {
            renderChatMessages();
        }
    }

    // ============================================================
    // HEAT
    // ============================================================
    function renderHeat() {
        const heat = hubData.heat || {};
        const vehicles = heat.vehicles || [];
        const ranking = heat.ranking || [];

        // Personal vehicles
        const vContainer = document.getElementById('heatVehicles');
        if (vehicles.length === 0) {
            vContainer.innerHTML = '<div class="activity-empty">No HEAT data on your vehicles</div>';
        } else {
            vContainer.innerHTML = vehicles.map(v => `
                <div class="heat-vehicle-row">
                    <span class="heat-v-name">${esc(v.vehicleName || v.plate || 'Unknown')}</span>
                    <div class="heat-v-bar"><div class="heat-v-fill" style="width:${v.heatLevel || 0}%"></div></div>
                    <span class="heat-v-val">${v.heatLevel || 0}</span>
                </div>
            `).join('');
        }

        // Global ranking
        const rContainer = document.getElementById('rankingList');
        if (ranking.length === 0) {
            rContainer.innerHTML = '<div class="activity-empty">No HEAT ranking data</div>';
        } else {
            const maxHeat = Math.max(...ranking.map(r => r.totalHeat || 0), 1);
            rContainer.innerHTML = ranking.slice(0, 20).map((r, i) => {
                const posClass = i === 0 ? 'top1' : i === 1 ? 'top2' : i === 2 ? 'top3' : '';
                return `<div class="ranking-row">
                    <span class="ranking-pos ${posClass}">${i + 1}</span>
                    <span class="ranking-name">${esc(r.playerName || 'Unknown')}</span>
                    <div class="ranking-bar"><div class="ranking-bar-fill" style="width:${((r.totalHeat || 0) / maxHeat) * 100}%"></div></div>
                    <span class="ranking-val">${r.totalHeat || 0}</span>
                </div>`;
            }).join('');
        }
    }

    function handleUpdateHeat(data) {
        hubData.heat = data;
        renderHeat();
        renderDashboard();
    }

    // ============================================================
    // Notifications
    // ============================================================
    function handleNotification(data) {
        const div = document.createElement('div');
        div.className = 'hub-notification ' + (data.type || 'info');
        div.textContent = data.message || '';
        document.body.appendChild(div);
        setTimeout(() => div.remove(), 4000);
    }

    // ============================================================
    // Helpers
    // ============================================================
    function esc(str) {
        const div = document.createElement('div');
        div.textContent = str;
        return div.innerHTML;
    }

    function formatNum(n) {
        return n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    }

    function formatTime(ts) {
        if (!ts) return '';
        const d = new Date(ts * 1000);
        const h = d.getHours().toString().padStart(2, '0');
        const m = d.getMinutes().toString().padStart(2, '0');
        return h + ':' + m;
    }
})();
