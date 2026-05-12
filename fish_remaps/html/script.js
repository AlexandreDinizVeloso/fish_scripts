// Fish Remaps - NUI Script
(function() {
    'use strict';

    const app = document.getElementById('app');
    const btnClose = document.getElementById('btnClose');
    const btnConfirm = document.getElementById('btnConfirm');

    let currentData = null;
    let selectedArchetype = null;
    let selectedSubArchetype = null;
    let adjustments = { top_speed: 0, acceleration: 0, handling: 0, braking: 0 };
    let originalStats = {};
    let blendedStats = {};

    const statColors = {
        top_speed: '#00d4ff',
        acceleration: '#ff8800',
        handling: '#00ff88',
        braking: '#aa44ff'
    };

    const statLabels = {
        top_speed: 'TOP SPEED',
        acceleration: 'ACCELERATION',
        handling: 'HANDLING',
        braking: 'BRAKING'
    };

    const stats = ['top_speed', 'acceleration', 'handling', 'braking'];

    window.addEventListener('message', function(event) {
        const data = event.data;
        if (data.action === 'openRemap') {
            openRemap(data);
        }
    });

    function openRemap(data) {
        currentData = data;
        selectedArchetype = data.currentArchetype;
        selectedSubArchetype = data.currentSubArchetype;
        originalStats = data.baseStats || {};
        adjustments = data.adjustments || {};
        stats.forEach(function(s) { if (!adjustments[s]) adjustments[s] = 0; });

        document.getElementById('vehicleName').textContent = data.vehicleName || 'UNKNOWN';
        document.getElementById('plateDisplay').textContent = 'PLATE: ' + (data.plate || 'N/A');

        buildArchetypeCards();
        buildSubArchetypeCards();
        buildAdjustmentSliders();
        updateDNAVisualization();
        updateComparison();

        app.classList.remove('hidden');
        fetch('https://fish_remaps/nuiReady', { method: 'POST' });
    }

    function buildArchetypeCards() {
        const grid = document.getElementById('archetypeGrid');
        grid.innerHTML = '';

        const archetypes = [
            { key: 'esportivo', label: 'Esportivo', icon: '🏎️' },
            { key: 'possante', label: 'Possante', icon: '💪' },
            { key: 'exotico', label: 'Exótico', icon: '✨' },
            { key: 'supercarro', label: 'Supercarro', icon: '⚡' },
            { key: 'moto', label: 'Motos', icon: '🏍️' },
            { key: 'utilitario', label: 'Utilitário', icon: '🚛' }
        ];

        archetypes.forEach(function(arch) {
            const card = document.createElement('div');
            card.className = 'arch-card' + (arch.key === selectedArchetype ? ' selected' : '');
            card.dataset.key = arch.key;
            card.innerHTML = '<div class="arch-card-icon">' + arch.icon + '</div><div class="arch-card-name">' + arch.label + '</div>';

            card.addEventListener('click', function() {
                selectedArchetype = arch.key;
                document.querySelectorAll('.arch-card').forEach(function(c) { c.classList.toggle('selected', c.dataset.key === arch.key); });
                recalculate();
            });

            grid.appendChild(card);
        });
    }

    function buildSubArchetypeCards() {
        const grid = document.getElementById('subArchGrid');
        grid.innerHTML = '';

        const subArchetypes = [
            { key: 'drifter', label: 'Drifter', icon: '🌪️' },
            { key: 'dragster', label: 'Dragster', icon: '🚀' },
            { key: 'late_surger', label: 'Late Surger', icon: '🌊' },
            { key: 'curve_king', label: 'Curve King', icon: '👑' },
            { key: 'grip_master', label: 'Grip Master', icon: '🧲' },
            { key: 'street_racer', label: 'Street Racer', icon: '🏙️' },
            { key: 'rally_spec', label: 'Rally Spec', icon: '🏔️' },
            { key: 'drift_king', label: 'Drift King', icon: '🏁' },
            { key: 'time_attack', label: 'Time Attack', icon: '⏱️' },
            { key: 'sleeper', label: 'Sleeper', icon: '😴' }
        ];

        subArchetypes.forEach(function(sub) {
            const card = document.createElement('div');
            card.className = 'subarch-card' + (sub.key === selectedSubArchetype ? ' selected' : '');
            card.dataset.key = sub.key;
            card.innerHTML = '<div class="subarch-icon">' + sub.icon + '</div><div class="subarch-name">' + sub.label + '</div>';

            card.addEventListener('click', function() {
                selectedSubArchetype = sub.key;
                document.querySelectorAll('.subarch-card').forEach(function(c) { c.classList.toggle('selected', c.dataset.key === sub.key); });
            });

            grid.appendChild(card);
        });
    }

    function buildAdjustmentSliders() {
        const container = document.getElementById('adjustments');
        container.innerHTML = '';

        stats.forEach(function(stat) {
            const row = document.createElement('div');
            row.className = 'adjust-row';

            const val = adjustments[stat] || 0;
            const color = statColors[stat];

            row.innerHTML =
                '<div class="adjust-header">' +
                    '<span class="adjust-label">' + statLabels[stat] + '</span>' +
                    '<span class="adjust-value" id="adjVal_' + stat + '" style="color:' + (val >= 0 ? '#00ff88' : '#ff3344') + '">' + (val >= 0 ? '+' : '') + val + '</span>' +
                '</div>' +
                '<input type="range" class="adjust-slider" id="adjSlider_' + stat + '" min="-15" max="15" value="' + val + '" step="1">';

            container.appendChild(row);

            const slider = row.querySelector('.adjust-slider');
            slider.addEventListener('input', function() {
                const newVal = parseInt(this.value);
                adjustments[stat] = newVal;
                document.getElementById('adjVal_' + stat).textContent = (newVal >= 0 ? '+' : '') + newVal;
                document.getElementById('adjVal_' + stat).style.color = newVal >= 0 ? '#00ff88' : '#ff3344';
                recalculate();
            });
        });
    }

    function recalculate() {
        // Simulate DNA blend: 75% new archetype, 25% original
        const inheritance = 0.75;
        blendedStats = {};

        stats.forEach(function(stat) {
            const orig = originalStats[stat] || 50;
            // Simulate new archetype modifier
            let newMod = 1.0;
            if (selectedArchetype === 'possante' && stat === 'acceleration') newMod = 1.2;
            if (selectedArchetype === 'possante' && stat === 'handling') newMod = 0.75;
            if (selectedArchetype === 'exotico' && stat === 'top_speed') newMod = 1.2;
            if (selectedArchetype === 'esportivo' && stat === 'handling') newMod = 1.15;
            if (selectedArchetype === 'supercarro') newMod = 1.1;

            const newStat = orig * newMod;
            blendedStats[stat] = (newStat * inheritance) + (orig * (1 - inheritance));
        });

        updateDNAVisualization();
        updateComparison();

        // Send to Lua for preview
        fetch('https://fish_remaps/previewAdjustment', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ archetype: selectedArchetype, adjustments: adjustments })
        });
    }

    function updateDNAVisualization() {
        document.getElementById('originalArchLabel').textContent = (currentData && currentData.currentArchetype) || 'Esportivo';
        document.getElementById('newArchLabel').textContent = selectedArchetype || 'Esportivo';

        const barsContainer = document.getElementById('dnaBars');
        barsContainer.innerHTML = '';

        stats.forEach(function(stat) {
            const orig = originalStats[stat] || 50;
            const blend = blendedStats[stat] || orig;
            const adj = adjustments[stat] || 0;
            const final = Math.max(0, Math.min(100, blend + adj));

            const row = document.createElement('div');
            row.className = 'dna-bar-row';
            row.innerHTML =
                '<div class="dna-bar-label">' + statLabels[stat] + '</div>' +
                '<div class="dna-bar-track">' +
                    '<div class="dna-bar-original" style="width:' + orig + '%"></div>' +
                    '<div class="dna-bar-blend" style="width:' + final + '%;background:' + statColors[stat] + '"></div>' +
                '</div>' +
                '<div class="dna-bar-value">' + Math.round(final) + '</div>';

            barsContainer.appendChild(row);
        });
    }

    function updateComparison() {
        const container = document.getElementById('comparisonBars');
        container.innerHTML = '';

        stats.forEach(function(stat) {
            const before = originalStats[stat] || 50;
            const blend = blendedStats[stat] || before;
            const adj = adjustments[stat] || 0;
            const after = Math.max(0, Math.min(100, blend + adj));
            const diff = after - before;

            const row = document.createElement('div');
            row.className = 'comp-row';
            row.innerHTML =
                '<div class="comp-label">' + statLabels[stat] + '</div>' +
                '<div class="comp-track">' +
                    '<div class="comp-before" style="width:' + before + '%"></div>' +
                    '<div class="comp-after" style="width:' + after + '%;background:' + (diff >= 0 ? 'rgba(0,255,136,0.5)' : 'rgba(255,51,68,0.5)') + '"></div>' +
                '</div>' +
                '<div class="comp-values">' +
                    '<span class="comp-val before">' + Math.round(before) + '</span>' +
                    '<span class="comp-val after" style="color:' + (diff >= 0 ? '#00ff88' : '#ff3344') + '">' + (diff >= 0 ? '+' : '') + Math.round(diff) + '</span>' +
                '</div>';

            container.appendChild(row);
        });
    }

    btnClose.addEventListener('click', closeNui);
    btnConfirm.addEventListener('click', function() {
        fetch('https://fish_remaps/confirmRemap', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                archetype: selectedArchetype,
                subArchetype: selectedSubArchetype,
                adjustments: adjustments,
                blendedStats: blendedStats,
                finalStats: stats.reduce(function(acc, s) {
                    acc[s] = Math.max(0, Math.min(100, (blendedStats[s] || 50) + (adjustments[s] || 0)));
                    return acc;
                }, {})
            })
        });
        closeNui();
    });

    function closeNui() {
        app.classList.add('hidden');
        fetch('https://fish_remaps/close', { method: 'POST' });
    }

    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') closeNui();
    });
})();
