// ============================================================
// FISH HUB — NUI Script
// ============================================================
(function () {
    'use strict';

    let hubData = {};
    let currentChannel = 'general';
    let currentFilter = 'all';

    // ── Icon map (Material Symbols names) ─────────────────
    const ICON = {
        dashboard:    'dashboard',
        storefront:   'storefront',
        build:        'build',
        chat:         'chat',
        fire:         'local_fire_department',
        person:       'person',
        close:        'close',
        add:          'add',
        addCircle:    'add_circle',
        send:         'send',
        save:         'save',
        memory:       'memory',
        verified:     'verified_user',
        warning:      'gpp_maybe',
        analytics:    'analytics',
        list:         'list_alt',
        mail:         'mail',
        trophy:       'emoji_events',
        update:       'update',
        car:          'directions_car',
        camera:       'photo_camera',
        personAdd:    'person_add',
        forum:        'forum',
        chatBubble:   'chat',
        info:         'info',
        check:        'check_circle',
        error:        'error',
        wrench:       'build',
        bolt:         'bolt',
        box:          'inventory_2',
        lock:         'lock',
        tag:          'sell',
        shoppingCart: 'shopping_cart',
    };

    // ── NUI Message Handler ───────────────────────────────
    window.addEventListener('message', function (e) {
        const d = e.data;
        if (!d || !d.action) return;
        switch (d.action) {
            case 'openHub':          handleOpenHub(d.data);       break;
            case 'updateHub':        handleUpdateHub(d.data);     break;
            case 'newMessage':       handleNewMessage(d.data);    break;
            case 'updateMarketplace':handleUpdateMarketplace(d.data); break;
            case 'updateHeat':       handleUpdateHeat(d.data);    break;
            case 'updateChats':      handleUpdateChats(d.data);   break;
            case 'notification':     handleNotification(d.data);  break;
            case 'closeHub':         handleCloseHub();            break;
            case 'openChatChannel':  handleOpenChatChannel(d.data); break;
        }
    });

    // ── Open / Close ──────────────────────────────────────
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
    function handleOpenChatChannel(data) {
        if (data && data.channelId) {
            currentChannel = data.channelId;
            switchView('chat');
            renderChat();
        }
    }
    function handleUpdateChats(data) {
        if (data) hubData.channels = data;
        renderChat();
    }
    function handleUpdateMarketplace(data) {
        hubData.listings = data || [];
        renderMarketplace();
        renderDashboard();
    }
    function handleUpdateHeat(data) {
        hubData.heat = data || {};
        renderHeat();
        renderDashboard();
    }

    function renderAll() {
        renderChipStatus();
        renderDashboard();
        renderMarketplace();
        renderServices();
        renderChat();
        renderHeat();
        renderProfile();
    }

    // ── DOMContentLoaded ──────────────────────────────────
    document.addEventListener('DOMContentLoaded', function () {
        // Nav
        document.querySelectorAll('.nav-item').forEach(function (item) {
            item.addEventListener('click', function () {
                switchView(this.dataset.view);
            });
        });

        // Close
        document.getElementById('btnClose').addEventListener('click', function () {
            nui('close');
        });

        // Chip install
        document.getElementById('btnInstallV1').addEventListener('click', function () {
            nui('installChip', { chipType: 'v1' });
        });
        document.getElementById('btnInstallV2').addEventListener('click', function () {
            nui('installChip', { chipType: 'v2' });
        });

        // Marketplace filters
        document.getElementById('marketplaceFilters').addEventListener('click', function (e) {
            if (e.target.classList.contains('filter-tab')) {
                currentFilter = e.target.dataset.filter;
                document.querySelectorAll('#marketplaceFilters .filter-tab').forEach(function (t) {
                    t.classList.remove('active');
                });
                e.target.classList.add('active');
                renderMarketplace();
            }
        });

        // Create listing
        document.getElementById('btnCreateListing').addEventListener('click', function () {
            document.getElementById('createListingModal').classList.remove('hidden');
        });
        document.getElementById('closeListingModal').addEventListener('click', function () {
            document.getElementById('createListingModal').classList.add('hidden');
        });
        document.getElementById('submitListing').addEventListener('click', function () {
            var name = el('listingName').value.trim();
            var price = parseInt(el('listingPrice').value) || 0;
            var tag = el('listingTag').value;
            var desc = el('listingDesc').value.trim();
            if (!name || !price) return;
            nui('createListing', { name: name, price: price, tag: tag, description: desc });
            document.getElementById('createListingModal').classList.add('hidden');
            el('listingName').value = '';
            el('listingPrice').value = '';
            el('listingDesc').value = '';
        });

        // Chat send
        document.getElementById('btnSend').addEventListener('click', sendMessage);
        document.getElementById('chatInput').addEventListener('keydown', function (e) {
            if (e.key === 'Enter') sendMessage();
        });

        // Create channel
        document.getElementById('btnCreateChannel').addEventListener('click', function () {
            document.getElementById('createChannelModal').classList.remove('hidden');
        });
        document.getElementById('closeChannelModal').addEventListener('click', function () {
            document.getElementById('createChannelModal').classList.add('hidden');
        });
        document.getElementById('submitChannel').addEventListener('click', function () {
            var name = el('channelName').value.trim();
            if (!name) return;
            nui('createChannel', { name: name });
            document.getElementById('createChannelModal').classList.add('hidden');
            el('channelName').value = '';
        });

        // Invite
        document.getElementById('btnInvite').addEventListener('click', function () {
            document.getElementById('inviteModal').classList.remove('hidden');
        });
        document.getElementById('closeInviteModal').addEventListener('click', function () {
            document.getElementById('inviteModal').classList.add('hidden');
        });
        document.getElementById('submitInvite').addEventListener('click', function () {
            var targetId = parseInt(el('inviteTargetId').value);
            if (!targetId) return;
            nui('inviteToChannel', { channelId: currentChannel, targetId: targetId });
            document.getElementById('inviteModal').classList.add('hidden');
            el('inviteTargetId').value = '';
        });

        // Photo upload
        document.getElementById('closePhotoModal').addEventListener('click', function () {
            document.getElementById('photoModal').classList.add('hidden');
        });
        document.getElementById('submitPhoto').addEventListener('click', function () {
            var model = el('photoVehicleModel').value;
            var url = el('photoUrl').value.trim();
            if (!model) return;
            nui('uploadCarPhoto', { vehicleModel: model, photoUrl: url });
            document.getElementById('photoModal').classList.add('hidden');
            el('photoUrl').value = '';
        });

        // Profile save
        document.getElementById('btnSaveProfile').addEventListener('click', function () {
            var username = el('profileUsername').value.trim();
            var pic = el('profilePicUrl').value.trim();
            nui('updateProfile', { username: username, profilePic: pic });
        });

        // ESC
        document.addEventListener('keydown', function (e) {
            if (e.key === 'Escape' && !document.getElementById('app').classList.contains('hidden')) {
                nui('close');
            }
        });
    });

    // ── Navigation ────────────────────────────────────────
    function switchView(name) {
        document.querySelectorAll('.view').forEach(function (v) { v.classList.remove('active'); });
        document.querySelectorAll('.nav-item').forEach(function (n) { n.classList.remove('active'); });
        var target = document.getElementById('view-' + name);
        if (target) target.classList.add('active');
        var nav = document.querySelector('.nav-item[data-view="' + name + '"]');
        if (nav) nav.classList.add('active');
    }

    // ── NUI Helper ────────────────────────────────────────
    function nui(endpoint, data) {
        fetch('https://fish_hub/' + endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data || {})
        });
    }

    function el(id) { return document.getElementById(id); }
    function esc(str) {
        var d = document.createElement('div');
        d.textContent = str || '';
        return d.innerHTML;
    }
    function fmtNum(n) {
        return (n || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    }
    function fmtTime(ts) {
        if (!ts) return '';
        var d = new Date(ts * 1000);
        return pad(d.getHours()) + ':' + pad(d.getMinutes());
    }
    function pad(n) { return n.toString().padStart(2, '0'); }

    function getIcon(name) {
        return '<span class="material-symbols-outlined">' + (ICON[name] || name) + '</span>';
    }

    // ── Chip Status ───────────────────────────────────────
    function renderChipStatus() {
        var status = el('chipStatus');
        var hasV1 = hubData.hasV1;
        var hasV2 = hubData.hasV2;
        var text = status.querySelector('.chip-text');

        if (hasV1 || hasV2) {
            status.classList.add('active');
            var label = [];
            if (hasV1) label.push('V1');
            if (hasV2) label.push('V2');
            text.textContent = label.join(' + ');
        } else {
            status.classList.remove('active');
            text.textContent = 'NO CHIP';
        }
    }

    // ── Dashboard ─────────────────────────────────────────
    function renderDashboard() {
        // Chip slots
        var slots = el('chipSlots');
        var chips = hubData.chips || [];
        var max = hubData.maxChips || 2;
        var html = '';

        for (var i = 0; i < max; i++) {
            var chip = chips[i];
            if (chip) {
                var cfg = (hubData.chipTypes || {})[chip.type] || {};
                html += '<div class="chip-slot installed ' + chip.type + '">' +
                    '<div class="slot-icon">' + getIcon('memory') + '</div>' +
                    '<div class="slot-label">' + esc(cfg.label || chip.type.toUpperCase()) + '</div>' +
                    '<button class="btn-remove-chip" data-chip="' + chip.type + '">REMOVE</button>' +
                    '</div>';
            } else {
                html += '<div class="chip-slot empty">' +
                    '<div class="slot-icon">' + getIcon('memory') + '</div>' +
                    '<div class="slot-label">EMPTY</div></div>';
            }
        }
        slots.innerHTML = html;

        slots.querySelectorAll('.btn-remove-chip').forEach(function (btn) {
            btn.addEventListener('click', function () {
                nui('removeChip', { chipType: this.dataset.chip });
            });
        });

        // Stats
        var listings = hubData.listings || [];
        var activeListings = listings.filter(function (l) { return l.status === 'active'; }).length;
        var channels = hubData.channels || {};
        var totalMsgs = 0;
        Object.values(channels).forEach(function (ch) {
            totalMsgs += (ch.messages || []).length;
        });
        var heat = hubData.heat || {};

        el('statListings').textContent = activeListings;
        el('statMessages').textContent = totalMsgs;
        el('statHeat').textContent = heat.totalHeat || 0;

        // Rank
        var ranking = heat.ranking || [];
        var rank = '--';
        var serverId = hubData.serverId;
        for (var j = 0; j < ranking.length; j++) {
            if (String(ranking[j].playerId) === String(serverId)) {
                rank = '#' + (j + 1);
                break;
            }
        }
        el('statRank').textContent = rank;
        el('playerId').textContent = 'ID: ' + (serverId || '---');
        el('headerHeat').textContent = heat.totalHeat || 0;

        // Activity
        var allMsgs = [];
        Object.values(channels).forEach(function (ch) {
            (ch.messages || []).slice(-3).forEach(function (m) { allMsgs.push(m); });
        });
        allMsgs.sort(function (a, b) { return (b.timestamp || 0) - (a.timestamp || 0); });
        var actList = el('activityList');
        if (allMsgs.length === 0) {
            actList.innerHTML = '<div class="activity-empty">No recent activity</div>';
        } else {
            actList.innerHTML = allMsgs.slice(0, 5).map(function (m) {
                return '<div class="activity-item">' +
                    '<span class="activity-icon">' + getIcon('chat') + '</span>' +
                    '<span class="activity-text"><strong>' + esc(m.playerName || 'Unknown') + ':</strong> ' + esc((m.message || '').substring(0, 50)) + '</span>' +
                    '<span class="activity-time">' + fmtTime(m.timestamp) + '</span></div>';
            }).join('');
        }
    }

    // ── Marketplace ───────────────────────────────────────
    function renderMarketplace() {
        var grid = el('listingsGrid');
        var listings = hubData.listings || [];

        // Filter active + by tag
        var filtered = listings.filter(function (l) {
            if (l.status !== 'active') return false;
            if (currentFilter !== 'all' && l.tag !== currentFilter) return false;
            return true;
        });

        if (filtered.length === 0) {
            grid.innerHTML = '<div class="activity-empty">No listings available</div>';
            return;
        }

        var hasV1 = hubData.hasV1;

        grid.innerHTML = filtered.map(function (l) {
            var tagClass = l.tag || 'selling';
            var canContact = hasV1;
            var contactBtn;
            if (canContact) {
                contactBtn = '<button class="btn-contact-seller" data-id="' + l.id + '" data-seller="' + l.sellerId + '">' +
                    getIcon('chat') + ' CONTACT SELLER</button>';
            } else {
                contactBtn = '<div class="tooltip-wrap"><button class="btn-contact-seller disabled">' +
                    getIcon('lock') + ' REQUIRES V1</button>' +
                    '<span class="tooltip-text">Requires V1 chip to contact sellers</span></div>';
            }

            return '<div class="listing-card ' + tagClass + '">' +
                '<div class="listing-header">' +
                '<div class="listing-name">' + esc(l.name || 'Unknown') + '</div>' +
                '<div class="listing-price">$' + fmtNum(l.price) + '</div></div>' +
                '<div class="listing-desc">' + esc(l.description || 'No description') + '</div>' +
                '<div class="listing-footer">' +
                '<span class="listing-tag ' + tagClass + '">' + (tagClass === 'buying' ? 'BUYING' : 'SELLING') + '</span>' +
                '<span class="listing-seller">' + esc(l.sellerName || 'Anonymous') + '</span></div>' +
                contactBtn + '</div>';
        }).join('');

        // Contact seller click
        grid.querySelectorAll('.btn-contact-seller:not(.disabled)').forEach(function (btn) {
            btn.addEventListener('click', function () {
                nui('contactSeller', {
                    listingId: this.dataset.id,
                    sellerId: parseInt(this.dataset.seller)
                });
            });
        });
    }

    // ── Services ──────────────────────────────────────────
    function renderServices() {
        var grid = el('servicesGrid');
        var services = hubData.services || [];
        var hasV1 = hubData.hasV1;

        if (services.length === 0) {
            grid.innerHTML = '<div class="activity-empty">No services available</div>';
            return;
        }

        var iconMap = {
            part_installation: ICON.wrench,
            remap_service: ICON.bolt,
            part_delivery: ICON.box
        };

        grid.innerHTML = services.map(function (s) {
            var needsV1 = s.requiresV1;
            var locked = needsV1 && !hasV1;
            var icon = iconMap[s.id] || ICON.build;
            var badge = needsV1 ? '<span class="service-badge v1-required">' + getIcon('verified') + ' V1 REQUIRED</span>' : '';
            var btn;
            if (locked) {
                btn = '<button class="btn-request disabled">' + getIcon('lock') + ' REQUIRES V1</button>';
            } else {
                btn = '<button class="btn-request" data-service="' + s.id + '">' + getIcon('send') + ' REQUEST SERVICE</button>';
            }
            return '<div class="service-card">' +
                '<div class="service-icon"><span class="material-symbols-outlined">' + icon + '</span></div>' +
                '<div class="service-name">' + esc(s.label || s.id) + '</div>' +
                '<div class="service-desc">' + esc(s.description || '') + '</div>' +
                badge + btn + '</div>';
        }).join('');

        grid.querySelectorAll('.btn-request:not(.disabled)').forEach(function (btn) {
            btn.addEventListener('click', function () {
                var svcId = this.dataset.service;
                var details = prompt('Describe what you need:');
                if (!details) return;
                nui('requestPart', { serviceType: svcId, details: details });
            });
        });
    }

    // ── Chat ──────────────────────────────────────────────
    function renderChat() {
        var channelList = el('channelList');
        var channels = hubData.channels || {};
        var hasV2 = hubData.hasV2;
        var html = '';

        var sortedKeys = Object.keys(channels).sort(function (a, b) {
            var ca = channels[a], cb = channels[b];
            if (ca.type === 'general') return -1;
            if (cb.type === 'general') return 1;
            return (ca.name || '').localeCompare(cb.name || '');
        });

        sortedKeys.forEach(function (key) {
            var ch = channels[key];
            var isActive = key === currentChannel;
            var typeBadge = '';
            if (ch.type === 'dm') typeBadge = '<span class="ch-type-badge">DM</span>';
            else if (ch.type === 'custom') typeBadge = '<span class="ch-type-badge">CH</span>';

            var iconName = 'chat';
            if (ch.type === 'dm') iconName = 'mail';
            else if (ch.type === 'custom') iconName = 'forum';

            html += '<div class="channel-item' + (isActive ? ' active' : '') + '" data-channel="' + key + '">' +
                '<span class="ch-icon"><span class="material-symbols-outlined">' + iconName + '</span></span>' +
                '<span class="ch-name">' + esc(ch.name || key) + '</span>' +
                typeBadge + '</div>';
        });

        channelList.innerHTML = html;

        channelList.querySelectorAll('.channel-item').forEach(function (item) {
            item.addEventListener('click', function () {
                currentChannel = this.dataset.channel;
                renderChat();
            });
        });

        renderChatMessages();
        updateChatHeader();
    }

    function renderChatMessages() {
        var container = el('chatMessages');
        var channels = hubData.channels || {};
        var channel = channels[currentChannel];

        if (!channel || !channel.messages || channel.messages.length === 0) {
            container.innerHTML = '<div class="activity-empty">No messages yet</div>';
            return;
        }

        var serverId = hubData.serverId;
        container.innerHTML = channel.messages.map(function (m) {
            var isSelf = String(m.playerId) === String(serverId);
            var avatarHtml = '';
            if (!isSelf && m.profilePic) {
                avatarHtml = '<img class="msg-avatar" src="' + esc(m.profilePic) + '" onerror="this.style.display=\'none\'">';
            }
            return '<div class="chat-msg ' + (isSelf ? 'self' : 'other') + '">' +
                (!isSelf ? '<div class="msg-header">' + avatarHtml +
                    '<span class="msg-sender">' + esc(m.playerName || 'Unknown') + '</span></div>' : '') +
                '<div class="msg-text">' + esc(m.message || '') + '</div>' +
                '<div class="msg-time">' + fmtTime(m.timestamp) + '</div></div>';
        }).join('');

        container.scrollTop = container.scrollHeight;
    }

    function updateChatHeader() {
        var channels = hubData.channels || {};
        var ch = channels[currentChannel];
        if (!ch) return;

        var iconName = 'chat';
        if (ch.type === 'dm') iconName = 'mail';
        else if (ch.type === 'custom') iconName = 'forum';

        el('chatHeader').querySelector('.chat-channel-icon').innerHTML =
            '<span class="material-symbols-outlined">' + iconName + '</span>';
        el('chatHeader').querySelector('.chat-channel-name').textContent = ch.name || currentChannel;

        // Show invite button only for custom channels
        var inviteBtn = el('btnInvite');
        if (ch.type === 'custom') {
            inviteBtn.classList.remove('hidden');
        } else {
            inviteBtn.classList.add('hidden');
        }
    }

    function sendMessage() {
        var input = el('chatInput');
        var msg = input.value.trim();
        if (!msg) return;
        nui('sendMessage', { channel: currentChannel, message: msg });
        input.value = '';
    }

    function handleNewMessage(msg) {
        if (!hubData.channels) hubData.channels = {};
        var ch = hubData.channels[msg.channel];
        if (ch) {
            if (!ch.messages) ch.messages = [];
            ch.messages.push(msg);
            if (ch.messages.length > 200) ch.messages.shift();
        }
        if (msg.channel === currentChannel) {
            renderChatMessages();
        }
    }

    // ── HEAT ──────────────────────────────────────────────
    function renderHeat() {
        var heat = hubData.heat || {};
        var vehicles = heat.vehicles || [];
        var ranking = heat.ranking || [];

        // Personal vehicles
        var vContainer = el('heatVehicles');
        if (vehicles.length === 0) {
            vContainer.innerHTML = '<div class="activity-empty">No HEAT data on your vehicles</div>';
        } else {
            vContainer.innerHTML = vehicles.map(function (v) {
                return '<div class="heat-vehicle-row">' +
                    '<span class="heat-v-name">' + esc(v.vehicleName || v.plate || 'Unknown') + '</span>' +
                    '<div class="heat-v-bar"><div class="heat-v-fill" style="width:' + (v.heatLevel || 0) + '%"></div></div>' +
                    '<span class="heat-v-val">' + (v.heatLevel || 0) + '</span>' +
                    '<button class="btn-photo-upload" data-model="' + esc(v.vehicleModel) + '" title="Upload Photo">' +
                    '<span class="material-symbols-outlined">photo_camera</span></button></div>';
            }).join('');

            vContainer.querySelectorAll('.btn-photo-upload').forEach(function (btn) {
                btn.addEventListener('click', function () {
                    el('photoVehicleModel').value = this.dataset.model;
                    el('photoUrl').value = '';
                    document.getElementById('photoModal').classList.remove('hidden');
                });
            });
        }

        // Ranking
        var rContainer = el('rankingList');
        if (ranking.length === 0) {
            rContainer.innerHTML = '<div class="activity-empty">No HEAT ranking data</div>';
        } else {
            var maxHeat = Math.max.apply(null, ranking.map(function (r) { return r.heatLevel || 0; }).concat([1]));
            rContainer.innerHTML = ranking.map(function (r, i) {
                var posClass = i === 0 ? 'top1' : i === 1 ? 'top2' : i === 2 ? 'top3' : '';
                var photoHtml = '';
                if (r.photoUrl) {
                    photoHtml = '<img class="ranking-photo" src="' + esc(r.photoUrl) + '" onerror="this.style.display=\'none\'">';
                } else {
                    photoHtml = '<div class="ranking-photo" style="display:flex;align-items:center;justify-content:center;background:var(--bg-primary);">' +
                        '<span class="material-symbols-outlined" style="font-size:14px;color:var(--text-muted)">directions_car</span></div>';
                }
                return '<div class="ranking-row">' +
                    '<span class="ranking-pos ' + posClass + '">' + (i + 1) + '</span>' +
                    photoHtml +
                    '<div class="ranking-info">' +
                    '<span class="ranking-name">' + esc(r.playerName || 'Unknown') + '</span>' +
                    '<span class="ranking-car">' + esc(r.vehicleName || '') + '</span></div>' +
                    '<div class="ranking-bar"><div class="ranking-bar-fill" style="width:' + ((r.heatLevel / maxHeat) * 100) + '%"></div></div>' +
                    '<span class="ranking-val">' + (r.heatLevel || 0) + '</span></div>';
            }).join('');
        }
    }

    // ── Profile ───────────────────────────────────────────
    function renderProfile() {
        var profile = hubData.profile || {};
        var avatar = el('profileAvatar');
        var nameEl = el('profileDisplayName');

        if (profile.profilePic) {
            avatar.innerHTML = '<img src="' + esc(profile.profilePic) + '" onerror="this.parentElement.innerHTML=\'<span class=\\\'material-symbols-outlined avatar-placeholder\\\'>person</span>\'">';
        } else {
            avatar.innerHTML = '<span class="material-symbols-outlined avatar-placeholder">person</span>';
        }

        nameEl.textContent = profile.username || 'Not Set';
        el('profileUsername').value = profile.username || '';
        el('profilePicUrl').value = profile.profilePic || '';
    }

    // ── Notifications ─────────────────────────────────────
    function handleNotification(data) {
        var iconMap = { info: ICON.info, success: ICON.check, error: ICON.error };
        var div = document.createElement('div');
        div.className = 'hub-notification ' + (data.type || 'info');
        div.innerHTML = '<span class="material-symbols-outlined">' + (iconMap[data.type] || 'info') + '</span>' +
            '<span>' + esc(data.message || '') + '</span>';
        document.body.appendChild(div);
        setTimeout(function () { div.remove(); }, 4000);
    }

})();
