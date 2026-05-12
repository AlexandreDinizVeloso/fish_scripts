// Fish Normalizer - NUI Script
(function() {
    'use strict';

    const app = document.getElementById('app');
    const vehicleNameEl = document.getElementById('vehicleName');
    const plateEl = document.getElementById('plateDisplay');
    const scoreValueEl = document.getElementById('scoreValue');
    const scoreRingFill = document.getElementById('scoreRingFill');
    const rankBadgeEl = document.getElementById('rankBadge');
    const archetypeGrid = document.getElementById('archetypeGrid');
    const subArchGrid = document.getElementById('subArchGrid');
    const btnClose = document.getElementById('btnClose');
    const btnConfirm = document.getElementById('btnConfirm');
    const archetypeDetail = document.getElementById('archetypeDetail');

    let currentData = null;
    let selectedArchetype = null;
    let selectedSubArchetype = null;

    // Rank colors map
    const rankColors = {
        'C': '#8B8B8B',
        'B': '#4FC3F7',
        'A': '#66BB6A',
        'S': '#FFD54F',
        'X': '#FF1744'
    };

    // Listen for messages from Lua
    window.addEventListener('message', function(event) {
        const data = event.data;

        if (data.action === 'openNormalizer') {
            openNormalizer(data);
        }
    });

    // Open normalizer
    function openNormalizer(data) {
        currentData = data;
        selectedArchetype = data.currentArchetype;
        selectedSubArchetype = data.currentSubArchetype;

        vehicleNameEl.textContent = data.vehicleName || 'UNKNOWN';
        plateEl.textContent = 'PLATE: ' + (data.plate || 'N/A');

        // Build archetype cards
        buildArchetypeCards(data.archetypes);
        buildSubArchetypeCards(data.subArchetypes);

        // Update stats
        updateStats(data.stats, data.baseScore);

        app.classList.remove('hidden');

        // Notify Lua that NUI is ready
        fetch('https://fish_normalizer/nuiReady', { method: 'POST' });
    }

    // Build archetype cards
    function buildArchetypeCards(archetypes) {
        archetypeGrid.innerHTML = '';
        archetypes.forEach(function(arch) {
            const card = document.createElement('div');
            card.className = 'arch-card' + (arch.key === selectedArchetype ? ' selected' : '');
            card.dataset.key = arch.key;
            card.innerHTML =
                '<div class="arch-card-icon">' + arch.icon + '</div>' +
                '<div class="arch-card-name">' + arch.label + '</div>' +
                '<div class="arch-card-desc">' + arch.description + '</div>';

            card.addEventListener('click', function() {
                selectArchetype(arch.key);
            });

            card.addEventListener('mouseenter', function() {
                showArchetypeDetail(arch);
            });

            card.addEventListener('mouseleave', function() {
                hideArchetypeDetail();
            });

            archetypeGrid.appendChild(card);
        });
    }

    // Build sub-archetype cards
    function buildSubArchetypeCards(subArchetypes) {
        subArchGrid.innerHTML = '';
        subArchetypes.forEach(function(sub) {
            const card = document.createElement('div');
            card.className = 'subarch-card' + (sub.key === selectedSubArchetype ? ' selected' : '');
            card.dataset.key = sub.key;

            let bonusText = '';
            if (sub.statBonus) {
                const bonuses = [];
                for (const [stat, val] of Object.entries(sub.statBonus)) {
                    bonuses.push((val > 0 ? '+' : '') + val + ' ' + stat.replace('_', ' '));
                }
                bonusText = bonuses.join(', ');
            }

            card.innerHTML =
                '<div class="subarch-icon">' + sub.icon + '</div>' +
                '<div class="subarch-name">' + sub.label + '</div>' +
                (bonusText ? '<div class="subarch-bonus">' + bonusText + '</div>' : '');

            card.addEventListener('click', function() {
                selectSubArchetype(sub.key);
            });

            subArchGrid.appendChild(card);
        });
    }

    // Select archetype
    function selectArchetype(key) {
        selectedArchetype = key;

        // Update UI
        document.querySelectorAll('.arch-card').forEach(function(card) {
            card.classList.toggle('selected', card.dataset.key === key);
        });

        // Request recalculation from Lua
        fetch('https://fish_normalizer/selectArchetype', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ archetype: key })
        }).then(function(resp) { return resp.json(); })
          .then(function(result) {
              if (result && typeof result === 'string') {
                  result = JSON.parse(result);
              }
              if (result) {
                  updateStats(result.stats, result.score);
              }
          });
    }

    // Select sub-archetype
    function selectSubArchetype(key) {
        selectedSubArchetype = key;

        document.querySelectorAll('.subarch-card').forEach(function(card) {
            card.classList.toggle('selected', card.dataset.key === key);
        });

        fetch('https://fish_normalizer/selectSubArchetype', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ subArchetype: key })
        }).then(function(resp) { return resp.json(); })
          .then(function(result) {
              if (result && typeof result === 'string') {
                  result = JSON.parse(result);
              }
              if (result) {
                  updateStats(result.stats, result.score);
              }
          });
    }

    // Update stats display
    function updateStats(stats, score) {
        if (!stats) return;

        const scoreClamped = Math.max(0, Math.min(1000, score || 0));

        // Update score ring
        const circumference = 2 * Math.PI * 54;
        const offset = circumference - (scoreClamped / 1000) * circumference;
        scoreRingFill.style.strokeDashoffset = offset;

        // Update score value
        scoreValueEl.textContent = scoreClamped;

        // Update rank
        let rank = 'C';
        let rankColor = '#8B8B8B';
        if (scoreClamped >= 1000) { rank = 'X'; rankColor = '#FF1744'; }
        else if (scoreClamped >= 900) { rank = 'S'; rankColor = '#FFD54F'; }
        else if (scoreClamped >= 750) { rank = 'A'; rankColor = '#66BB6A'; }
        else if (scoreClamped >= 500) { rank = 'B'; rankColor = '#4FC3F7'; }

        rankBadgeEl.textContent = rank;
        rankBadgeEl.style.color = rankColor;
        rankBadgeEl.style.textShadow = '0 0 20px ' + rankColor + '80';
        scoreRingFill.style.stroke = rankColor;

        // Update stat bars
        const topSpeed = stats.top_speed || 0;
        const accel = stats.acceleration || 0;
        const handling = stats.handling || 0;
        const braking = stats.braking || 0;

        document.getElementById('barTopSpeed').style.width = topSpeed + '%';
        document.getElementById('valTopSpeed').textContent = Math.round(topSpeed);
        document.getElementById('barAccel').style.width = accel + '%';
        document.getElementById('valAccel').textContent = Math.round(accel);
        document.getElementById('barHandling').style.width = handling + '%';
        document.getElementById('valHandling').textContent = Math.round(handling);
        document.getElementById('barBraking').style.width = braking + '%';
        document.getElementById('valBraking').textContent = Math.round(braking);

        // Update radar chart
        drawRadarChart(topSpeed, accel, handling, braking);
    }

    // Draw radar chart
    function drawRadarChart(topSpeed, accel, handling, braking) {
        const canvas = document.getElementById('radarChart');
        const ctx = canvas.getContext('2d');
        const w = canvas.width;
        const h = canvas.height;
        const cx = w / 2;
        const cy = h / 2;
        const radius = Math.min(cx, cy) - 30;

        ctx.clearRect(0, 0, w, h);

        const labels = ['TOP SPD', 'ACCEL', 'HANDLING', 'BRAKING'];
        const values = [topSpeed / 100, accel / 100, handling / 100, braking / 100];
        const numAxes = 4;
        const angleStep = (Math.PI * 2) / numAxes;

        // Draw grid circles
        for (let i = 1; i <= 4; i++) {
            const r = (radius / 4) * i;
            ctx.beginPath();
            for (let j = 0; j <= numAxes; j++) {
                const angle = j * angleStep - Math.PI / 2;
                const x = cx + Math.cos(angle) * r;
                const y = cy + Math.sin(angle) * r;
                if (j === 0) ctx.moveTo(x, y);
                else ctx.lineTo(x, y);
            }
            ctx.closePath();
            ctx.strokeStyle = 'rgba(0, 212, 255, 0.1)';
            ctx.lineWidth = 1;
            ctx.stroke();
        }

        // Draw axes
        for (let i = 0; i < numAxes; i++) {
            const angle = i * angleStep - Math.PI / 2;
            ctx.beginPath();
            ctx.moveTo(cx, cy);
            ctx.lineTo(cx + Math.cos(angle) * radius, cy + Math.sin(angle) * radius);
            ctx.strokeStyle = 'rgba(0, 212, 255, 0.2)';
            ctx.lineWidth = 1;
            ctx.stroke();

            // Labels
            const labelR = radius + 18;
            const lx = cx + Math.cos(angle) * labelR;
            const ly = cy + Math.sin(angle) * labelR;
            ctx.fillStyle = '#8888aa';
            ctx.font = '9px Orbitron';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText(labels[i], lx, ly);
        }

        // Draw data polygon
        ctx.beginPath();
        for (let i = 0; i <= numAxes; i++) {
            const idx = i % numAxes;
            const angle = idx * angleStep - Math.PI / 2;
            const val = Math.max(0.05, Math.min(1, values[idx]));
            const x = cx + Math.cos(angle) * radius * val;
            const y = cy + Math.sin(angle) * radius * val;
            if (i === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
        }
        ctx.closePath();
        ctx.fillStyle = 'rgba(0, 212, 255, 0.15)';
        ctx.fill();
        ctx.strokeStyle = 'rgba(0, 212, 255, 0.8)';
        ctx.lineWidth = 2;
        ctx.stroke();

        // Draw data points
        for (let i = 0; i < numAxes; i++) {
            const angle = i * angleStep - Math.PI / 2;
            const val = Math.max(0.05, Math.min(1, values[i]));
            const x = cx + Math.cos(angle) * radius * val;
            const y = cy + Math.sin(angle) * radius * val;
            ctx.beginPath();
            ctx.arc(x, y, 4, 0, Math.PI * 2);
            ctx.fillStyle = '#00d4ff';
            ctx.fill();
            ctx.strokeStyle = '#ffffff';
            ctx.lineWidth = 1;
            ctx.stroke();
        }
    }

    // Show archetype detail
    function showArchetypeDetail(arch) {
        document.getElementById('detailIcon').textContent = arch.icon;
        document.getElementById('detailTitle').textContent = arch.label;
        document.getElementById('detailDesc').textContent = arch.description;

        const prosList = document.getElementById('detailPros');
        const consList = document.getElementById('detailCons');
        prosList.innerHTML = '';
        consList.innerHTML = '';

        arch.pros.forEach(function(p) {
            const li = document.createElement('li');
            li.textContent = p;
            prosList.appendChild(li);
        });

        arch.cons.forEach(function(c) {
            const li = document.createElement('li');
            li.textContent = c;
            consList.appendChild(li);
        });

        archetypeDetail.classList.remove('hidden');
    }

    // Hide archetype detail
    function hideArchetypeDetail() {
        archetypeDetail.classList.add('hidden');
    }

    // Close button
    btnClose.addEventListener('click', function() {
        closeNui();
    });

    // Confirm button
    btnConfirm.addEventListener('click', function() {
        fetch('https://fish_normalizer/confirmNormalization', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                archetype: selectedArchetype,
                subArchetype: selectedSubArchetype
            })
        });
        closeNui();
    });

    // Close NUI
    function closeNui() {
        app.classList.add('hidden');
        fetch('https://fish_normalizer/close', { method: 'POST' });
    }

    // ESC key to close
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') {
            closeNui();
        }
    });

    // Initial notification
    fetch('https://fish_normalizer/nuiReady', { method: 'POST' });
})();
