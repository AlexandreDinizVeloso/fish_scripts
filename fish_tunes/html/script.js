// Fish Tunes NUI - Complete Script
(function () {
    'use strict';

    // ── State ──────────────────────────────────────────────────────────
    let state = {
        categories: [],
        currentParts: {},
        totalBonuses: {},
        currentHeat: 0,
        maxHeat: 100,
        partLevels: {},
        vehicleName: '',
        plate: '',
        selectedCategory: null,
        selectedLevel: null,
        hoveredLevel: null,
        instability: 0,
        durabilityLoss: 0
    };

    // ── Stat config ────────────────────────────────────────────────────
    const STAT_META = {
        acceleration: { label: 'ACCEL', icon: '⚡', color: '#00d4ff', negative: false },
        top_speed:    { label: 'TOP SPD', icon: '🏎️', color: '#aa44ff', negative: false },
        handling:     { label: 'HANDLING', icon: '🎯', color: '#00ff88', negative: false },
        braking:      { label: 'BRAKING', icon: '🛑', color: '#ffd700', negative: false },
        instability:  { label: 'UNSTABLE', icon: '⚠️', color: '#ff8800', negative: true },
        durability_loss: { label: 'WEAR', icon: '💀', color: '#ff3344', negative: true }
    };

    // All stats we track for comparison
    const ALL_STATS = ['acceleration', 'top_speed', 'handling', 'braking', 'instability', 'durability_loss'];

    // ── DOM refs ───────────────────────────────────────────────────────
    const $app        = document.getElementById('app');
    const $tabs       = document.getElementById('categoryTabs');
    const $grid       = document.getElementById('levelsGrid');
    const $compare    = document.getElementById('compareBars');
    const $heatBar    = document.getElementById('heatBar');
    const $heatValue  = document.getElementById('heatValue');
    const $vName      = document.getElementById('vehicleName');
    const $plate      = document.getElementById('plateDisplay');
    const $totalBars  = document.getElementById('totalBars');
    const $partInfo   = document.getElementById('partInfoContent');
    const $warnings   = document.getElementById('warnings');
    const $btnInstall = document.getElementById('btnInstall');
    const $btnUninstall = document.getElementById('btnUninstall');
    const $btnClose   = document.getElementById('btnClose');
    const $catTitle   = document.getElementById('categoryTitle');

    // ── Helpers ────────────────────────────────────────────────────────
    function post(endpoint, data = {}) {
        return fetch(`https://fish_tunes/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        }).then(r => r.json()).catch(() => null);
    }

    function clamp(v, min, max) { return Math.max(min, Math.min(max, v)); }

    function formatStat(val) {
        if (val > 0) return `+${val}`;
        return `${val}`;
    }

    // ── Render: Category Tabs ──────────────────────────────────────────
    function renderTabs() {
        $tabs.innerHTML = '';
        state.categories.forEach(cat => {
            const div = document.createElement('div');
            div.className = 'category-tab' + (state.selectedCategory === cat.key ? ' selected' : '');
            div.dataset.key = cat.key;

            const currentLevel = state.currentParts[cat.key] || 'stock';
            const levelInfo = state.partLevels[currentLevel] || {};
            const levelColor = levelInfo.color || '#8B8B8B';

            div.innerHTML = `
                <span class="category-tab-icon">${cat.icon}</span>
                <div class="category-tab-info">
                    <div class="category-tab-label">${cat.label}</div>
                    <div class="category-tab-level" style="color:${levelColor}">${levelInfo.label || 'Stock'}</div>
                </div>
            `;
            div.addEventListener('click', () => selectCategory(cat.key));
            $tabs.appendChild(div);
        });
    }

    function selectCategory(key) {
        state.selectedCategory = key;
        state.selectedLevel = null;
        state.hoveredLevel = null;
        renderTabs();
        renderLevels();
        renderCompare();
        renderPartInfo();
        renderWarnings();
        updateActionButtons();
    }

    // ── Render: Level Cards ────────────────────────────────────────────
    function renderLevels() {
        const cat = state.categories.find(c => c.key === state.selectedCategory);
        if (!cat) { $grid.innerHTML = '<div style="color:var(--text-muted);text-align:center;padding:40px;">Select a category</div>'; return; }

        $catTitle.textContent = cat.label.toUpperCase() + ' — SELECT LEVEL';

        // Sort levels by level number
        const levelOrder = ['stock', 'l1', 'l2', 'l3', 'l4', 'l5'];
        const sortedLevels = [...cat.levels].sort((a, b) => levelOrder.indexOf(a.key) - levelOrder.indexOf(b.key));

        $grid.innerHTML = '';
        sortedLevels.forEach(lv => {
            const card = document.createElement('div');
            const isIllegal = !lv.legal;
            const isCurrent = lv.key === cat.currentLevel;
            const isSelected = state.selectedLevel === lv.key;

            card.className = 'level-card'
                + (isIllegal ? ' illegal' : '')
                + (isSelected ? ' selected' : '');

            // Highlight current installed level
            if (isCurrent && !isSelected) {
                card.style.borderColor = lv.color || 'var(--border-active)';
                card.style.boxShadow = `0 0 8px ${lv.color}33`;
            }

            card.innerHTML = `
                <div class="level-icon">${lv.icon}</div>
                <div class="level-name" style="color:${lv.color}">${lv.label}</div>
                <div class="level-legal ${lv.legal ? 'yes' : 'no'}">${lv.legal ? 'LEGAL' : 'ILLEGAL'}</div>
                ${lv.heat ? `<div class="level-heat">+${lv.heat} HEAT</div>` : ''}
                ${isCurrent ? '<div style="font-family:var(--font-mono);font-size:8px;color:var(--accent-blue);margin-top:4px;">● INSTALLED</div>' : ''}
            `;

            // Click to select
            card.addEventListener('click', () => {
                state.selectedLevel = lv.key;
                renderLevels();
                renderCompare();
                renderPartInfo();
                renderWarnings();
                updateActionButtons();
            });

            // Hover for preview
            card.addEventListener('mouseenter', () => {
                state.hoveredLevel = lv.key;
                if (!state.selectedLevel) {
                    renderCompare();
                    renderPartInfo();
                }
            });
            card.addEventListener('mouseleave', () => {
                state.hoveredLevel = null;
                if (!state.selectedLevel) {
                    renderCompare();
                    renderPartInfo();
                }
            });

            $grid.appendChild(card);
        });
    }

    // ── Render: Compare Bars ───────────────────────────────────────────
    function renderCompare() {
        const cat = state.categories.find(c => c.key === state.selectedCategory);
        if (!cat) { $compare.innerHTML = ''; return; }

        const currentLevel = cat.currentLevel || 'stock';
        const previewKey = state.selectedLevel || state.hoveredLevel;

        if (!previewKey || previewKey === currentLevel) {
            // Show current stats only
            const currentBonuses = getBonusesFor(state.selectedCategory, currentLevel);
            renderCompareBars(currentBonuses, null);
            return;
        }

        const currentBonuses = getBonusesFor(state.selectedCategory, currentLevel);
        const previewBonuses = getBonusesFor(state.selectedCategory, previewKey);
        renderCompareBars(currentBonuses, previewBonuses);
    }

    function getBonusesFor(category, level) {
        const cat = state.categories.find(c => c.key === category);
        if (!cat) return {};
        const lv = cat.levels.find(l => l.key === level);
        return lv ? (lv.bonuses || {}) : {};
    }

    function renderCompareBars(current, preview) {
        // Collect all relevant stats
        const statsToShow = new Set();
        if (current) Object.keys(current).forEach(s => statsToShow.add(s));
        if (preview) Object.keys(preview).forEach(s => statsToShow.add(s));

        // Always show core stats
        ['acceleration', 'top_speed', 'handling', 'braking'].forEach(s => statsToShow.add(s));

        // Find max value for scaling
        let maxVal = 1;
        statsToShow.forEach(s => {
            const cv = Math.abs((current && current[s]) || 0);
            const pv = Math.abs((preview && preview[s]) || 0);
            maxVal = Math.max(maxVal, cv, pv);
        });
        maxVal = Math.ceil(maxVal * 1.2) || 1;

        $compare.innerHTML = '';
        const orderedStats = ALL_STATS.filter(s => statsToShow.has(s));

        orderedStats.forEach(stat => {
            const meta = STAT_META[stat];
            if (!meta) return;

            const currentVal = (current && current[stat]) || 0;
            const previewVal = preview ? ((preview[stat]) || 0) : null;
            const displayVal = previewVal !== null ? previewVal : currentVal;

            const currentPct = (Math.abs(currentVal) / maxVal) * 100;
            const previewPct = previewVal !== null ? (Math.abs(previewVal) / maxVal) * 100 : 0;

            const row = document.createElement('div');
            row.className = 'compare-row';

            const isNegative = meta.negative;
            const barColor = isNegative
                ? (displayVal > 0 ? 'var(--accent-red)' : 'var(--accent-green)')
                : meta.color;

            const diffColor = previewVal !== null
                ? (previewVal > currentVal
                    ? (isNegative ? 'var(--accent-red)' : 'var(--accent-green)')
                    : previewVal < currentVal
                        ? (isNegative ? 'var(--accent-green)' : 'var(--accent-red)')
                        : 'var(--text-muted)')
                : 'var(--text-primary)';

            const diffText = previewVal !== null
                ? (previewVal > currentVal ? '▲' : previewVal < currentVal ? '▼' : '＝')
                : '';

            row.innerHTML = `
                <div class="compare-label">${meta.icon} ${meta.label}</div>
                <div class="compare-track">
                    <div class="compare-current" style="width:${currentPct}%"></div>
                    ${previewVal !== null ? `<div class="compare-new" style="width:${previewPct}%;background:${barColor};opacity:0.8"></div>` : ''}
                </div>
                <div class="compare-value" style="color:${diffColor}">
                    ${formatStat(displayVal)}${diffText ? ` <span style="font-size:9px">${diffText}</span>` : ''}
                </div>
            `;
            $compare.appendChild(row);
        });

        // Animate bars in
        requestAnimationFrame(() => {
            $compare.querySelectorAll('.compare-new').forEach(el => {
                el.style.transition = 'width 0.4s cubic-bezier(0.22, 1, 0.36, 1)';
            });
        });
    }

    // ── Render: Heat Meter ─────────────────────────────────────────────
    function updateHeat() {
        const pct = state.maxHeat > 0 ? (state.currentHeat / state.maxHeat) * 100 : 0;
        $heatBar.style.width = pct + '%';
        $heatValue.textContent = state.currentHeat;

        // Color shifts
        if (pct >= 60) {
            $heatValue.style.color = 'var(--accent-red)';
        } else if (pct >= 30) {
            $heatValue.style.color = 'var(--accent-orange)';
        } else {
            $heatValue.style.color = 'var(--accent-yellow)';
        }

        // Pulse animation on high heat
        if (pct >= 50) {
            $heatBar.style.animation = 'heatPulse 1.5s ease-in-out infinite';
        } else {
            $heatBar.style.animation = 'none';
        }
    }

    // ── Render: Total Bonuses ──────────────────────────────────────────
    function renderTotals() {
        const bonuses = state.totalBonuses || {};
        const stats = ['acceleration', 'top_speed', 'handling', 'braking'];

        // Find max for scaling
        let maxVal = 1;
        stats.forEach(s => { maxVal = Math.max(maxVal, Math.abs(bonuses[s] || 0)); });
        maxVal = Math.ceil(maxVal * 1.2) || 1;

        $totalBars.innerHTML = '';
        stats.forEach(stat => {
            const meta = STAT_META[stat];
            if (!meta) return;
            const val = bonuses[stat] || 0;
            const pct = (Math.abs(val) / maxVal) * 100;

            const row = document.createElement('div');
            row.className = 'total-bar-row';
            row.innerHTML = `
                <div class="total-bar-label">${meta.label}</div>
                <div class="total-bar-track">
                    <div class="total-bar-fill" style="width:${pct}%;background:${meta.color}"></div>
                </div>
                <div class="total-bar-value" style="color:${meta.color}">${formatStat(val)}</div>
            `;
            $totalBars.appendChild(row);
        });

        // Instability / durability summary
        if (state.instability > 0 || state.durabilityLoss > 0) {
            const extra = document.createElement('div');
            extra.style.cssText = 'margin-top:8px;padding-top:8px;border-top:1px solid var(--border-color);font-family:var(--font-mono);font-size:10px;';
            let html = '';
            if (state.instability > 0) html += `<div style="color:var(--accent-orange);">⚠ Instability: +${state.instability}</div>`;
            if (state.durabilityLoss > 0) html += `<div style="color:var(--accent-red);">💀 Wear: +${state.durabilityLoss}</div>`;
            extra.innerHTML = html;
            $totalBars.appendChild(extra);
        }
    }

    // ── Render: Part Info ──────────────────────────────────────────────
    function renderPartInfo() {
        const cat = state.categories.find(c => c.key === state.selectedCategory);
        if (!cat) { $partInfo.textContent = 'Select a category'; return; }

        const levelKey = state.selectedLevel || state.hoveredLevel;
        if (!levelKey) {
            $partInfo.innerHTML = `
                <div style="color:var(--text-muted);font-size:12px;">${cat.description}</div>
                <div style="margin-top:6px;font-size:11px;color:var(--text-secondary);">
                    Current: <span style="color:${state.partLevels[cat.currentLevel]?.color || '#8B8B8B'}">${state.partLevels[cat.currentLevel]?.label || 'Stock'}</span>
                </div>
            `;
            return;
        }

        const levelInfo = cat.levels.find(l => l.key === levelKey);
        if (!levelInfo) { $partInfo.textContent = 'No data'; return; }

        const bonuses = levelInfo.bonuses || {};
        const isIllegal = !levelInfo.legal;

        let bonusesHtml = '';
        ALL_STATS.forEach(stat => {
            const val = bonuses[stat];
            if (val === undefined || val === 0) return;
            const meta = STAT_META[stat];
            const isNeg = meta.negative;
            const color = isNeg ? (val > 0 ? 'var(--accent-red)' : 'var(--accent-green)') : meta.color;
            bonusesHtml += `<span style="color:${color};margin-right:12px;">${meta.icon} ${meta.label} ${formatStat(val)}</span>`;
        });

        $partInfo.innerHTML = `
            <div style="display:flex;align-items:center;gap:8px;margin-bottom:8px;">
                <span style="font-size:24px;">${levelInfo.icon}</span>
                <div>
                    <div style="font-family:var(--font-display);font-size:14px;font-weight:700;color:${levelInfo.color};letter-spacing:1px;">${levelInfo.label}</div>
                    <div style="font-family:var(--font-mono);font-size:10px;color:${isIllegal ? 'var(--accent-red)' : 'var(--accent-green)'};">${isIllegal ? '⚠ ILLEGAL' : '✓ LEGAL'}</div>
                </div>
                ${levelInfo.heat ? `<div style="margin-left:auto;font-family:var(--font-mono);font-size:11px;color:var(--accent-orange);">+${levelInfo.heat} HEAT</div>` : ''}
            </div>
            <div style="font-size:11px;line-height:1.8;">${bonusesHtml || '<span style="color:var(--text-muted);">No bonuses</span>'}</div>
        `;
    }

    // ── Render: Warnings ───────────────────────────────────────────────
    function renderWarnings() {
        const cat = state.categories.find(c => c.key === state.selectedCategory);
        if (!cat) { $warnings.innerHTML = ''; return; }

        const levelKey = state.selectedLevel;
        if (!levelKey) { $warnings.innerHTML = ''; return; }

        const levelInfo = cat.levels.find(l => l.key === levelKey);
        if (!levelInfo) { $warnings.innerHTML = ''; return; }

        const bonuses = levelInfo.bonuses || {};
        $warnings.innerHTML = '';

        // Illegal warning
        if (!levelInfo.legal) {
            addWarning('This part is ILLEGAL and will attract police attention', 'danger', '🚨');
        }

        // Instability warning
        if (bonuses.instability && bonuses.instability > 0) {
            addWarning(`+${bonuses.instability} Instability — vehicle may be harder to control`, '', '⚠️');
        }

        // Durability loss warning
        if (bonuses.durability_loss && bonuses.durability_loss > 0) {
            addWarning(`+${bonuses.durability_loss} Durability loss — increased part wear`, 'danger', '💀');
        }

        // Heat warning
        if (levelInfo.heat > 0) {
            const newHeat = calculatePreviewHeat(levelKey);
            if (newHeat >= 60) {
                addWarning(`Heat will reach ${newHeat}/${state.maxHeat} — HIGH police risk`, 'danger', '🔥');
            } else if (levelInfo.heat > 0) {
                addWarning(`Adds +${levelInfo.heat} heat to vehicle`, '', '🌡️');
            }
        }
    }

    function addWarning(text, type, icon) {
        const div = document.createElement('div');
        div.className = 'warning' + (type ? ` ${type}` : '');
        div.innerHTML = `
            <span class="warning-icon">${icon}</span>
            <span class="warning-text">${text}</span>
        `;
        $warnings.appendChild(div);
    }

    function calculatePreviewHeat(excludeLevel) {
        // Calculate what heat would be if we install the selected level
        let heat = 0;
        const cat = state.categories.find(c => c.key === state.selectedCategory);
        if (!cat) return 0;

        // Sum heat from all other categories' current parts
        state.categories.forEach(c => {
            if (c.key === state.selectedCategory) return;
            const currentLv = state.currentParts[c.key] || 'stock';
            const lvInfo = state.partLevels[currentLv];
            if (lvInfo && !lvInfo.legal) heat += lvInfo.heat;
        });

        // Add heat from the selected level
        if (excludeLevel && excludeLevel !== 'stock') {
            const selectedLvInfo = state.partLevels[excludeLevel];
            if (selectedLvInfo && !selectedLvInfo.legal) heat += selectedLvInfo.heat;
        }

        return Math.min(heat, state.maxHeat);
    }

    // ── Action Buttons ─────────────────────────────────────────────────
    function updateActionButtons() {
        const cat = state.categories.find(c => c.key === state.selectedCategory);
        const hasSelection = cat && state.selectedLevel && state.selectedLevel !== cat.currentLevel;
        const isCurrentStock = cat && (!cat.currentLevel || cat.currentLevel === 'stock');

        $btnInstall.style.display = hasSelection ? 'flex' : 'none';
        $btnUninstall.style.display = (cat && !isCurrentStock) ? 'flex' : 'none';

        // Disable install if same as current
        if (hasSelection) {
            $btnInstall.style.opacity = '1';
            $btnInstall.style.pointerEvents = 'auto';
        }
    }

    // ── Install / Uninstall ────────────────────────────────────────────
    async function installPart() {
        const cat = state.categories.find(c => c.key === state.selectedCategory);
        if (!cat || !state.selectedLevel) return;

        $btnInstall.style.pointerEvents = 'none';
        $btnInstall.innerHTML = '<span>⏳</span> INSTALLING...';

        try {
            const resp = await post('installPart', {
                category: state.selectedCategory,
                level: state.selectedLevel
            });

            if (resp && resp.success) {
                // Update local state
                cat.currentLevel = state.selectedLevel;
                state.currentParts[state.selectedCategory] = state.selectedLevel;

                if (resp.totalBonuses) state.totalBonuses = resp.totalBonuses;
                if (resp.currentHeat !== undefined) state.currentHeat = resp.currentHeat;
                if (resp.instability !== undefined) state.instability = resp.instability;

                // Refresh everything
                renderTabs();
                renderLevels();
                renderCompare();
                renderPartInfo();
                renderWarnings();
                renderTotals();
                updateHeat();
                updateActionButtons();

                // Flash effect
                flashElement($btnInstall, 'var(--accent-green)');
            }
        } catch (e) {
            console.error('Install failed:', e);
        }

        $btnInstall.innerHTML = '<span>⚡</span> INSTALL PART';
        $btnInstall.style.pointerEvents = 'auto';
    }

    async function uninstallPart() {
        const cat = state.categories.find(c => c.key === state.selectedCategory);
        if (!cat) return;

        $btnUninstall.style.pointerEvents = 'none';
        $btnUninstall.innerHTML = '<span>⏳</span> REMOVING...';

        try {
            const resp = await post('uninstallPart', {
                category: state.selectedCategory
            });

            if (resp && resp.success) {
                cat.currentLevel = 'stock';
                state.currentParts[state.selectedCategory] = 'stock';

                if (resp.totalBonuses) state.totalBonuses = resp.totalBonuses;
                if (resp.currentHeat !== undefined) state.currentHeat = resp.currentHeat;

                state.selectedLevel = null;
                state.hoveredLevel = null;

                renderTabs();
                renderLevels();
                renderCompare();
                renderPartInfo();
                renderWarnings();
                renderTotals();
                updateHeat();
                updateActionButtons();

                flashElement($btnUninstall, 'var(--accent-blue)');
            }
        } catch (e) {
            console.error('Uninstall failed:', e);
        }

        $btnUninstall.innerHTML = '<span>🔧</span> REMOVE TO STOCK';
        $btnUninstall.style.pointerEvents = 'auto';
    }

    // ── Flash feedback ─────────────────────────────────────────────────
    function flashElement(el, color) {
        const orig = el.style.borderColor;
        el.style.borderColor = color;
        el.style.boxShadow = `0 0 20px ${color}44`;
        setTimeout(() => {
            el.style.borderColor = orig;
            el.style.boxShadow = '';
        }, 600);
    }

    // ── Close ──────────────────────────────────────────────────────────
    function closeUI() {
        $app.classList.add('hidden');
        post('close');
        window.parent.postMessage({ action: 'closeIframe' }, '*');
    }

    // ── Keyboard handler ───────────────────────────────────────────────
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') closeUI();
    });

    // ── Init & Event Listeners ─────────────────────────────────────────
    $btnClose.addEventListener('click', closeUI);
    $btnInstall.addEventListener('click', installPart);
    $btnUninstall.addEventListener('click', uninstallPart);

    // ── Inject animation keyframes ─────────────────────────────────────
    const style = document.createElement('style');
    style.textContent = `
        @keyframes heatPulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.7; }
        }
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(8px); }
            to { opacity: 1; transform: translateY(0); }
        }
        @keyframes slideIn {
            from { opacity: 0; transform: translateX(-12px); }
            to { opacity: 1; transform: translateX(0); }
        }
        .level-card { animation: fadeIn 0.3s ease forwards; }
        .category-tab { animation: slideIn 0.25s ease forwards; }
        .compare-row { animation: fadeIn 0.3s ease forwards; }
        .total-bar-row { animation: fadeIn 0.25s ease forwards; }
        .warning { animation: fadeIn 0.25s ease forwards; }
    `;
    document.head.appendChild(style);

    // ── NUI Message Handler ────────────────────────────────────────────
    window.addEventListener('message', (event) => {
        const data = event.data;
        if (!data || !data.action) return;

        if (data.action === 'openTunes') {
            // Populate state
            state.vehicleName = data.vehicleName || 'UNKNOWN';
            state.plate = data.plate || '';
            state.categories = data.categories || [];
            state.currentParts = data.currentParts || {};
            state.totalBonuses = data.totalBonuses || {};
            state.currentHeat = data.currentHeat || 0;
            state.maxHeat = data.maxHeat || 100;
            state.partLevels = data.partLevels || {};
            state.selectedCategory = null;
            state.selectedLevel = null;
            state.hoveredLevel = null;

            // Calculate instability & durability from current parts
            state.instability = 0;
            state.durabilityLoss = 0;
            Object.keys(state.currentParts).forEach(catKey => {
                const lvKey = state.currentParts[catKey];
                const bonuses = getBonusesFor(catKey, lvKey);
                if (bonuses.instability) state.instability += bonuses.instability;
                if (bonuses.durability_loss) state.durabilityLoss += bonuses.durability_loss;
            });

            // Update header
            $vName.textContent = state.vehicleName;
            $plate.textContent = state.plate ? `PLATE: ${state.plate}` : '';

            // Show app
            $app.classList.remove('hidden');

            // Render everything
            renderTabs();
            updateHeat();
            renderTotals();

            // Auto-select first category
            if (state.categories.length > 0) {
                selectCategory(state.categories[0].key);
            }

            renderCompare();
            renderPartInfo();
            renderWarnings();
            updateActionButtons();
        }
    });

    // ── Ready signal ───────────────────────────────────────────────────
    post('nuiReady');
})();
