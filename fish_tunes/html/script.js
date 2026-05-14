// Fish Tunes - Unified Tabbed UI
(function () {
    'use strict';

    // ══════════════════════════════════════════════════════════════════
    // STATE
    // ══════════════════════════════════════════════════════════════════
    let state = {
        vehicleName: '',
        plate: '',
        categories: [],
        currentParts: {},
        totalBonuses: {},
        currentHeat: 0,
        maxHeat: 100,
        partLevels: {},
        selectedCategory: null,
        selectedLevel: null,
        hoveredLevel: null,
        instability: 0,
        durabilityLoss: 0,
        drivetrain: 'RWD',
        currentClass: 'C',
        // Maintenance
        diagnostics: null,
        tireHealth: { fl: 100, fr: 100, rl: 100, rr: 100 },
        // Crafting
        recipes: [],
        // Cost config
        partCosts: { l1: 1000, l2: 2500, l3: 5000, l4: 12000, l5: 25000 },
        drivetrainCost: 5000,
        classSwapCosts: {
            'C_B': 10000, 'C_A': 30000,
            'B_C': 5000, 'B_A': 20000,
            'A_C': 5000, 'A_B': 5000
        }
    };

    // ══════════════════════════════════════════════════════════════════
    // STAT META
    // ══════════════════════════════════════════════════════════════════
    const STAT_META = {
        acceleration: { label: 'ACCEL', icon: '⚡', color: '#00d4ff', negative: false },
        top_speed:    { label: 'TOP SPD', icon: '🏎️', color: '#aa44ff', negative: false },
        handling:     { label: 'HANDLING', icon: '🎯', color: '#00ff88', negative: false },
        braking:      { label: 'BRAKING', icon: '🛑', color: '#ffd700', negative: false },
        instability:  { label: 'UNSTABLE', icon: '⚠️', color: '#ff8800', negative: true },
        durability_loss: { label: 'WEAR', icon: '💀', color: '#ff3344', negative: true }
    };
    const ALL_STATS = ['acceleration', 'top_speed', 'handling', 'braking', 'instability', 'durability_loss'];

    // ══════════════════════════════════════════════════════════════════
    // DOM REFS
    // ══════════════════════════════════════════════════════════════════
    const $ = id => document.getElementById(id);
    const $app          = $('app');
    const $heatBar      = $('heatBar');
    const $heatValue    = $('heatValue');
    const $vName        = $('vehicleName');
    const $plate        = $('plateDisplay');
    const $btnClose     = $('btnClose');

    // Parts tab refs
    const $tabs         = $('categoryTabs');
    const $grid         = $('levelsGrid');
    const $compare      = $('compareBars');
    const $totalBars    = $('totalBars');
    const $partInfo     = $('partInfoContent');
    const $warnings     = $('warnings');
    const $btnInstall   = $('btnInstall');
    const $btnUninstall = $('btnUninstall');
    const $installCost  = $('installCost');
    const $catTitle     = $('categoryTitle');

    // Drivetrain
    const $dtCards      = document.querySelectorAll('.dt-card');
    const $btnConvert   = $('btnConvertDrivetrain');

    // Swap
    const $currentClass = $('currentClass');
    const $targetClass  = $('targetClass');
    const $swapCost     = $('swapCost');
    const $btnApplySwap = $('btnApplySwap');

    // Maintenance
    const $diagList     = $('diagnosticsList');
    const $btnRepairAll = $('btnRepairAll');

    // Crafting
    const $craftingGrid = $('craftingGrid');

    // ══════════════════════════════════════════════════════════════════
    // HELPERS
    // ══════════════════════════════════════════════════════════════════
    function post(endpoint, data = {}) {
        return fetch(`https://fish_tunes/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        }).then(r => r.json()).catch(() => null);
    }

    function formatStat(val) {
        return val > 0 ? `+${val}` : `${val}`;
    }

    function flashElement(el, color) {
        const orig = el.style.borderColor;
        el.style.borderColor = color;
        el.style.boxShadow = `0 0 20px ${color}44`;
        setTimeout(() => { el.style.borderColor = orig; el.style.boxShadow = ''; }, 600);
    }

    // ══════════════════════════════════════════════════════════════════
    // TAB NAVIGATION
    // ══════════════════════════════════════════════════════════════════
    document.querySelectorAll('.nav-tab').forEach(tab => {
        tab.addEventListener('click', () => {
            document.querySelectorAll('.nav-tab').forEach(t => t.classList.remove('active'));
            document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
            tab.classList.add('active');
            const tabId = `tab-${tab.dataset.tab}`;
            const el = document.getElementById(tabId);
            if (el) el.classList.add('active');

            // Refresh tab-specific data
            if (tab.dataset.tab === 'maintenance') renderMaintenance();
            if (tab.dataset.tab === 'swap') renderSwap();
            if (tab.dataset.tab === 'parts') renderPartsInit();
            if (tab.dataset.tab === 'crafting') renderCrafting();
        });
    });

    // ══════════════════════════════════════════════════════════════════
    // CLOSE
    // ══════════════════════════════════════════════════════════════════
    function closeUI() {
        $app.classList.add('hidden');
        post('close');
    }
    $btnClose.addEventListener('click', closeUI);
    document.addEventListener('keydown', e => { if (e.key === 'Escape') closeUI(); });

    // ══════════════════════════════════════════════════════════════════
    // HEAT METER
    // ══════════════════════════════════════════════════════════════════
    function updateHeat() {
        const pct = state.maxHeat > 0 ? (state.currentHeat / state.maxHeat) * 100 : 0;
        $heatBar.style.width = pct + '%';
        $heatValue.textContent = state.currentHeat;
        if (pct >= 60) $heatValue.style.color = 'var(--accent-red)';
        else if (pct >= 30) $heatValue.style.color = 'var(--accent-orange)';
        else $heatValue.style.color = 'var(--accent-yellow)';
        if (pct >= 50) $heatBar.style.animation = 'heatPulse 1.5s ease-in-out infinite';
        else $heatBar.style.animation = 'none';
    }

    // ══════════════════════════════════════════════════════════════════
    // MAINTENANCE TAB
    // ══════════════════════════════════════════════════════════════════
    const PART_ICONS = {
        engine: '⚙️', transmission: '🔄', suspension: '🔧',
        brakes: '🛑', tires: '🔘', turbo: '💨'
    };

    function renderMaintenance() {
        // Diagnostics
        const diag = state.diagnostics || {};
        $diagList.innerHTML = '';
        ['engine', 'transmission', 'suspension', 'brakes', 'tires', 'turbo'].forEach(part => {
            const health = diag[part] || 100;
            const status = getStatus(health);
            const div = document.createElement('div');
            div.className = 'diag-item';
            div.innerHTML = `
                <span class="diag-icon">${PART_ICONS[part] || '❓'}</span>
                <div class="diag-info">
                    <div class="diag-name">${part.toUpperCase()}</div>
                    <div class="diag-bar-track">
                        <div class="diag-bar-fill" style="width:${health}%;background:${status.color}"></div>
                    </div>
                    <div class="diag-status">
                        <span class="diag-status-label" style="color:${status.color}">${status.label}</span>
                        <span class="diag-status-pct">${Math.floor(health)}%</span>
                    </div>
                </div>
            `;
            $diagList.appendChild(div);
        });

        // Tires
        renderTires();
    }

    function renderTires() {
        const th = state.tireHealth;
        const positions = [
            { key: 'fl', id: 'tireFL' },
            { key: 'fr', id: 'tireFR' },
            { key: 'rl', id: 'tireRL' },
            { key: 'rr', id: 'tireRR' }
        ];
        positions.forEach(pos => {
            const card = $(pos.id);
            if (!card) return;
            const health = th[pos.key] || 100;
            const status = getStatus(health);
            const fill = card.querySelector('.tire-health-fill');
            const pct = card.querySelector('.tire-pct');
            if (fill) {
                fill.style.height = health + '%';
                fill.style.background = status.color;
            }
            if (pct) {
                pct.textContent = Math.floor(health) + '%';
                pct.style.color = status.color;
            }
        });
    }

    function getStatus(health) {
        if (health >= 90) return { label: 'Excellent', color: '#66BB6A' };
        if (health >= 75) return { label: 'Good', color: '#4FC3F7' };
        if (health >= 50) return { label: 'Fair', color: '#FFD54F' };
        if (health >= 25) return { label: 'Poor', color: '#FF8800' };
        return { label: 'Critical', color: '#FF1744' };
    }

    $btnRepairAll.addEventListener('click', async () => {
        $btnRepairAll.textContent = '⏳ Repairing...';
        $btnRepairAll.style.pointerEvents = 'none';
        const resp = await post('repairVehicle', { plate: state.plate });
        if (resp && resp.success) {
            // Reset diagnostics
            state.diagnostics = { engine: 100, transmission: 100, suspension: 100, brakes: 100, tires: 100, turbo: 100 };
            state.tireHealth = { fl: 100, fr: 100, rl: 100, rr: 100 };
            renderMaintenance();
        }
        $btnRepairAll.textContent = '🔧 Repair All Parts';
        $btnRepairAll.style.pointerEvents = 'auto';
    });

    // ══════════════════════════════════════════════════════════════════
    // DRIVETRAIN TAB
    // ══════════════════════════════════════════════════════════════════
    $dtCards.forEach(card => {
        card.addEventListener('click', () => {
            $dtCards.forEach(c => c.classList.remove('active'));
            card.classList.add('active');
            state.drivetrain = card.dataset.dt;
        });
    });

    $btnConvert.addEventListener('click', async () => {
        $btnConvert.style.pointerEvents = 'none';
        $btnConvert.textContent = 'CONVERTING...';
        const resp = await post('convertDrivetrain', {
            plate: state.plate,
            drivetrain: state.drivetrain,
            cost: state.drivetrainCost
        });
        if (resp && resp.success) {
            flashElement($btnConvert, 'var(--accent-green)');
        }
        $btnConvert.textContent = `Convert Drivetrain — $${state.drivetrainCost.toLocaleString()}`;
        $btnConvert.style.pointerEvents = 'auto';
    });

    function renderDrivetrain() {
        $dtCards.forEach(c => {
            c.classList.toggle('active', c.dataset.dt === state.drivetrain);
        });
    }

    // ══════════════════════════════════════════════════════════════════
    // CLASS SWAP TAB
    // ══════════════════════════════════════════════════════════════════
    function renderSwap() {
        $currentClass.textContent = state.currentClass || '—';
        updateSwapCost();
    }

    function updateSwapCost() {
        const from = state.currentClass;
        const to = $targetClass.value;
        if (from === to) {
            $swapCost.textContent = '$0';
            $swapCost.style.color = 'var(--accent-green)';
        } else {
            const key = `${from}_${to}`;
            const cost = state.classSwapCosts[key] || 0;
            $swapCost.textContent = `$${cost.toLocaleString()}`;
            $swapCost.style.color = 'var(--accent-orange)';
        }
    }

    $targetClass.addEventListener('change', updateSwapCost);

    $btnApplySwap.addEventListener('click', async () => {
        const from = state.currentClass;
        const to = $targetClass.value;
        if (from === to) return;
        const key = `${from}_${to}`;
        const cost = state.classSwapCosts[key] || 0;

        $btnApplySwap.style.pointerEvents = 'none';
        $btnApplySwap.textContent = 'APPLYING...';

        const resp = await post('classSwap', {
            plate: state.plate,
            fromClass: from,
            toClass: to,
            cost: cost
        });

        if (resp && resp.success) {
            state.currentClass = to;
            renderSwap();
            flashElement($btnApplySwap, 'var(--accent-green)');
        }
        $btnApplySwap.textContent = 'Apply Class Swap';
        $btnApplySwap.style.pointerEvents = 'auto';
    });

    // ══════════════════════════════════════════════════════════════════
    // PARTS TAB
    // ══════════════════════════════════════════════════════════════════
    function renderPartsInit() {
        renderTabs();
        if (!state.selectedCategory && state.categories.length > 0) {
            selectCategory(state.categories[0].key);
        } else {
            renderLevels();
            renderCompare();
            renderPartInfo();
            renderWarnings();
            updateActionButtons();
        }
        renderTotals();
    }

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

    function renderLevels() {
        const cat = state.categories.find(c => c.key === state.selectedCategory);
        if (!cat) { $grid.innerHTML = '<div style="color:var(--text-muted);text-align:center;padding:40px;">Select a category</div>'; return; }

        $catTitle.textContent = cat.label.toUpperCase() + ' — SELECT LEVEL';

        const levelOrder = ['stock', 'l1', 'l2', 'l3', 'l4', 'l5'];
        const sortedLevels = [...cat.levels].sort((a, b) => levelOrder.indexOf(a.key) - levelOrder.indexOf(b.key));

        $grid.innerHTML = '';
        sortedLevels.forEach(lv => {
            const card = document.createElement('div');
            const isIllegal = !lv.legal;
            const isCurrent = lv.key === (cat.currentLevel || 'stock');
            const isSelected = state.selectedLevel === lv.key;

            card.className = 'level-card' + (isIllegal ? ' illegal' : '') + (isSelected ? ' selected' : '');

            if (isCurrent && !isSelected) {
                card.style.borderColor = lv.color || 'var(--border-active)';
                card.style.boxShadow = `0 0 8px ${lv.color}33`;
            }

            const costKey = lv.key;
            const cost = state.partCosts[costKey] || 0;
            const costDisplay = cost > 0 ? `<div style="font-family:var(--font-mono);font-size:9px;color:var(--accent-yellow);margin-top:2px;">$${cost.toLocaleString()}</div>` : '';

            card.innerHTML = `
                <div class="level-icon">${lv.icon}</div>
                <div class="level-name" style="color:${lv.color}">${lv.label}</div>
                <div class="level-legal ${lv.legal ? 'yes' : 'no'}">${lv.legal ? 'LEGAL' : 'ILLEGAL'}</div>
                ${lv.heat ? `<div class="level-heat">+${lv.heat} HEAT</div>` : ''}
                ${costDisplay}
                ${isCurrent ? '<div style="font-family:var(--font-mono);font-size:8px;color:var(--accent-blue);margin-top:4px;">● INSTALLED</div>' : ''}
            `;

            card.addEventListener('click', () => {
                state.selectedLevel = lv.key;
                renderLevels();
                renderCompare();
                renderPartInfo();
                renderWarnings();
                updateActionButtons();
            });
            card.addEventListener('mouseenter', () => {
                state.hoveredLevel = lv.key;
                if (!state.selectedLevel) { renderCompare(); renderPartInfo(); }
            });
            card.addEventListener('mouseleave', () => {
                state.hoveredLevel = null;
                if (!state.selectedLevel) { renderCompare(); renderPartInfo(); }
            });

            $grid.appendChild(card);
        });
    }

    function getBonusesFor(category, level) {
        const cat = state.categories.find(c => c.key === category);
        if (!cat) return {};
        const lv = cat.levels.find(l => l.key === level);
        return lv ? (lv.bonuses || {}) : {};
    }

    function renderCompare() {
        const cat = state.categories.find(c => c.key === state.selectedCategory);
        if (!cat) { $compare.innerHTML = ''; return; }

        const currentLevel = cat.currentLevel || 'stock';
        const previewKey = state.selectedLevel || state.hoveredLevel;

        if (!previewKey || previewKey === currentLevel) {
            renderCompareBars(getBonusesFor(state.selectedCategory, currentLevel), null);
            return;
        }
        renderCompareBars(
            getBonusesFor(state.selectedCategory, currentLevel),
            getBonusesFor(state.selectedCategory, previewKey)
        );
    }

    function renderCompareBars(current, preview) {
        const statsToShow = new Set();
        if (current) Object.keys(current).forEach(s => statsToShow.add(s));
        if (preview) Object.keys(preview).forEach(s => statsToShow.add(s));
        ['acceleration', 'top_speed', 'handling', 'braking'].forEach(s => statsToShow.add(s));

        let maxVal = 1;
        statsToShow.forEach(s => {
            const cv = Math.abs((current && current[s]) || 0);
            const pv = Math.abs((preview && preview[s]) || 0);
            maxVal = Math.max(maxVal, cv, pv);
        });
        maxVal = Math.ceil(maxVal * 1.2) || 1;

        $compare.innerHTML = '';
        ALL_STATS.filter(s => statsToShow.has(s)).forEach(stat => {
            const meta = STAT_META[stat];
            if (!meta) return;
            const currentVal = (current && current[stat]) || 0;
            const previewVal = preview ? ((preview[stat]) || 0) : null;
            const displayVal = previewVal !== null ? previewVal : currentVal;
            const currentPct = (Math.abs(currentVal) / maxVal) * 100;
            const previewPct = previewVal !== null ? (Math.abs(previewVal) / maxVal) * 100 : 0;

            const isNegative = meta.negative;
            const barColor = isNegative
                ? (displayVal > 0 ? 'var(--accent-red)' : 'var(--accent-green)')
                : meta.color;

            const diffColor = previewVal !== null
                ? (previewVal > currentVal ? (isNegative ? 'var(--accent-red)' : 'var(--accent-green)')
                    : previewVal < currentVal ? (isNegative ? 'var(--accent-green)' : 'var(--accent-red)')
                    : 'var(--text-muted)')
                : 'var(--text-primary)';
            const diffText = previewVal !== null ? (previewVal > currentVal ? '▲' : previewVal < currentVal ? '▼' : '＝') : '';

            const row = document.createElement('div');
            row.className = 'compare-row';
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
    }

    function renderTotals() {
        const bonuses = state.totalBonuses || {};
        const stats = ['acceleration', 'top_speed', 'handling', 'braking'];
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
            const color = meta.negative ? (val > 0 ? 'var(--accent-red)' : 'var(--accent-green)') : meta.color;
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

    function renderWarnings() {
        const cat = state.categories.find(c => c.key === state.selectedCategory);
        if (!cat) { $warnings.innerHTML = ''; return; }
        const levelKey = state.selectedLevel;
        if (!levelKey) { $warnings.innerHTML = ''; return; }
        const levelInfo = cat.levels.find(l => l.key === levelKey);
        if (!levelInfo) { $warnings.innerHTML = ''; return; }
        const bonuses = levelInfo.bonuses || {};
        $warnings.innerHTML = '';

        if (!levelInfo.legal) addWarning('This part is ILLEGAL and will attract police attention', 'danger', '🚨');
        if (bonuses.instability && bonuses.instability > 0) addWarning(`+${bonuses.instability} Instability — vehicle may be harder to control`, '', '⚠️');
        if (bonuses.durability_loss && bonuses.durability_loss > 0) addWarning(`+${bonuses.durability_loss} Durability loss — increased part wear`, 'danger', '💀');
        if (levelInfo.heat > 0) addWarning(`Adds +${levelInfo.heat} heat to vehicle`, '', '🌡️');
    }

    function addWarning(text, type, icon) {
        const div = document.createElement('div');
        div.className = 'warning' + (type ? ` ${type}` : '');
        div.innerHTML = `<span class="warning-icon">${icon}</span><span class="warning-text">${text}</span>`;
        $warnings.appendChild(div);
    }

    function updateActionButtons() {
        const cat = state.categories.find(c => c.key === state.selectedCategory);
        const hasSelection = cat && state.selectedLevel && state.selectedLevel !== (cat.currentLevel || 'stock');
        const isCurrentStock = cat && (!cat.currentLevel || cat.currentLevel === 'stock');

        $btnInstall.style.display = hasSelection ? 'flex' : 'none';
        $btnUninstall.style.display = (cat && !isCurrentStock) ? 'flex' : 'none';

        // Show cost
        if (hasSelection) {
            const cost = state.partCosts[state.selectedLevel] || 0;
            $installCost.textContent = cost > 0 ? `Cost: $${cost.toLocaleString()}` : '';
        } else {
            $installCost.textContent = '';
        }
    }

    // Install / Uninstall
    $btnInstall.addEventListener('click', async () => {
        const cat = state.categories.find(c => c.key === state.selectedCategory);
        if (!cat || !state.selectedLevel) return;

        $btnInstall.style.pointerEvents = 'none';
        $btnInstall.innerHTML = '<span>⏳</span> INSTALLING...';

        const resp = await post('installPart', {
            category: state.selectedCategory,
            level: state.selectedLevel,
            plate: state.plate,
            cost: state.partCosts[state.selectedLevel] || 0
        });

        if (resp && resp.success) {
            cat.currentLevel = state.selectedLevel;
            state.currentParts[state.selectedCategory] = state.selectedLevel;
            if (resp.totalBonuses) state.totalBonuses = resp.totalBonuses;
            if (resp.currentHeat !== undefined) state.currentHeat = resp.currentHeat;
            if (resp.instability !== undefined) state.instability = resp.instability;

            renderTabs();
            renderLevels();
            renderCompare();
            renderPartInfo();
            renderWarnings();
            renderTotals();
            updateHeat();
            updateActionButtons();
            flashElement($btnInstall, 'var(--accent-green)');
        }

        $btnInstall.innerHTML = '<span>⚡</span> INSTALL PART';
        $btnInstall.style.pointerEvents = 'auto';
    });

    $btnUninstall.addEventListener('click', async () => {
        const cat = state.categories.find(c => c.key === state.selectedCategory);
        if (!cat) return;

        $btnUninstall.style.pointerEvents = 'none';
        $btnUninstall.innerHTML = '<span>⏳</span> REMOVING...';

        const resp = await post('uninstallPart', { category: state.selectedCategory, plate: state.plate });

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

        $btnUninstall.innerHTML = '<span>🔧</span> REMOVE TO STOCK';
        $btnUninstall.style.pointerEvents = 'auto';
    });

    // ══════════════════════════════════════════════════════════════════
    // CRAFTING TAB
    // ══════════════════════════════════════════════════════════════════
    function renderCrafting() {
        $craftingGrid.innerHTML = '';
        if (!state.recipes || state.recipes.length === 0) {
            $craftingGrid.innerHTML = '<div style="color:var(--text-muted);text-align:center;padding:40px;grid-column:1/-1;">No recipes available</div>';
            return;
        }

        state.recipes.forEach(rec => {
            const card = document.createElement('div');
            card.className = 'craft-card';

            // Build materials display
            let materialsHtml = '';
            if (rec.materials) {
                const items = Object.entries(rec.materials).map(([mat, amt]) =>
                    `<span style="color:var(--text-primary);">${amt}x ${mat}</span>`
                ).join(', ');
                materialsHtml = `
                    <div class="craft-materials">
                        <div class="craft-materials-title">MATERIALS NEEDED</div>
                        ${items}
                    </div>
                `;
            }

            const successRate = rec.success_rate || rec.difficulty || 75;
            const successColor = successRate >= 80 ? 'var(--accent-green)' : successRate >= 60 ? 'var(--accent-orange)' : 'var(--accent-red)';

            card.innerHTML = `
                <div class="craft-header">
                    <span class="craft-icon">${rec.icon || '🔧'}</span>
                    <span class="craft-title">${rec.label}</span>
                </div>
                <div class="craft-desc">${rec.description || ''}</div>
                <div class="craft-stats">
                    <div class="craft-stat">
                        <span class="craft-stat-label">Success</span>
                        <span class="craft-stat-value" style="color:${successColor}">${successRate}%</span>
                    </div>
                    <div class="craft-stat">
                        <span class="craft-stat-label">Time</span>
                        <span class="craft-stat-value">${rec.crafting_time || 0}s</span>
                    </div>
                    <div class="craft-stat">
                        <span class="craft-stat-label">Category</span>
                        <span class="craft-stat-value warn">${rec.category || '?'}</span>
                    </div>
                </div>
                ${materialsHtml}
                <div class="craft-footer">
                    <span class="craft-cost">$${(rec.cost || 0).toLocaleString()}</span>
                    <button class="btn-craft" data-id="${rec.id}">CRAFT</button>
                </div>
            `;

            card.querySelector('.btn-craft').addEventListener('click', async (e) => {
                const btn = e.target;
                btn.textContent = 'CRAFTING...';
                btn.style.pointerEvents = 'none';
                const resp = await post('craftPart', { recipeId: rec.id, plate: state.plate });
                if (resp && resp.success) {
                    flashElement(card, 'var(--accent-green)');
                }
                btn.textContent = 'CRAFT';
                btn.style.pointerEvents = 'auto';
            });

            $craftingGrid.appendChild(card);
        });
    }

    // ══════════════════════════════════════════════════════════════════
    // NUI MESSAGE HANDLER
    // ══════════════════════════════════════════════════════════════════
    window.addEventListener('message', (event) => {
        const data = event.data;
        if (!data || !data.action) return;

        if (data.action === 'openTunes' || data.action === 'openAdvancedTunes') {
            state.vehicleName = data.vehicleName || 'UNKNOWN';
            state.plate = data.plate || '';
            state.categories = data.categories || [];
            state.currentParts = data.currentParts || {};
            state.totalBonuses = data.totalBonuses || {};
            state.currentHeat = data.currentHeat || 0;
            state.maxHeat = data.maxHeat || 100;
            state.partLevels = data.partLevels || {};
            state.drivetrain = data.drivetrain || 'RWD';
            state.currentClass = data.currentClass || 'C';
            state.diagnostics = data.diagnostics || null;
            state.tireHealth = data.tireHealth || { fl: 100, fr: 100, rl: 100, rr: 100 };
            state.recipes = data.recipes || [];
            state.selectedCategory = null;
            state.selectedLevel = null;
            state.hoveredLevel = null;

            // Cost config from server
            if (data.partCosts) state.partCosts = data.partCosts;
            if (data.drivetrainCost) state.drivetrainCost = data.drivetrainCost;
            if (data.classSwapCosts) state.classSwapCosts = data.classSwapCosts;

            // Calculate instability & durability
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

            // Render active tab
            updateHeat();
            renderDrivetrain();
            renderSwap();
            renderPartsInit();
            renderMaintenance();
            renderCrafting();

            // Ensure first tab is active
            document.querySelectorAll('.nav-tab').forEach((t, i) => {
                if (i === 0) t.classList.add('active');
                else t.classList.remove('active');
            });
            document.querySelectorAll('.tab-content').forEach((c, i) => {
                if (i === 0) c.classList.add('active');
                else c.classList.remove('active');
            });
        }
    });

    // Ready signal
    post('nuiReady');
})();
