// Fish Remaps v2.0 - NUI Script
(function() {
    'use strict';

    // ==================== ELEMENTS ====================
    const app = document.getElementById('app');
    const btnClose = document.getElementById('btnClose');

    // Tab nav
    const tabBtns = document.querySelectorAll('.tab-btn');
    const tabContents = document.querySelectorAll('.tab-content');

    // ==================== STATE ====================
    let currentData = null;
    let playerBalance = 0;

    // Dyno state
    let dynoSettings = {
        afr: 13.5,
        timing: 0,
        boost: 0,
        finalDrive: 3.55
    };
    let hasTurbo = false;
    let basePower = 250;
    let baseTorque = 300;

    // Transmission state
    let transSettings = {
        mode: 'auto',
        gearPreset: 'stock'
    };

    // Remap state
    let selectedArchetype = null;
    let selectedSubArchetype = null;
    let originalArchetype = null;
    let originalSubArchetype = null;
    let adjustments = { top_speed: 0, acceleration: 0, handling: 0, braking: 0 };
    let originalStats = {};
    let blendedStats = {};
    let subArchetypeBonuses = {};

    // Normalizer data cache
    let archetypes = {};
    let subArchetypes = {};
    let rankConfig = [];
    let weights = {};

    const stats = ['top_speed', 'acceleration', 'handling', 'braking'];
    const statLabels = {
        top_speed: 'TOP SPEED',
        acceleration: 'ACCEL',
        handling: 'HANDLING',
        braking: 'BRAKING'
    };
    const statColors = {
        top_speed: '#00d4ff',
        acceleration: '#ff8800',
        handling: '#00ff88',
        braking: '#aa44ff'
    };

    // Gear ratio impact data
    const gearPresetImpact = {
        stock:  { accel: 0, speed: 0 },
        short:  { accel: 15, speed: -10 },
        long:   { accel: -10, speed: 15 },
        drag:   { accel: 25, speed: -20 },
        drift:  { accel: 10, speed: -5 }
    };

    // ==================== INIT ====================
    window.addEventListener('message', function(event) {
        const data = event.data;
        switch (data.action) {
            case 'openRemap': openRemap(data); break;
            case 'updateBalance': playerBalance = data.balance || 0; updateBalanceDisplay(); break;
            case 'receiveNormalizerData': handleNormalizerData(data); break;
        }
    });

    // ==================== TAB NAVIGATION ====================
    tabBtns.forEach(function(btn) {
        btn.addEventListener('click', function() {
            const targetTab = this.dataset.tab;
            tabBtns.forEach(function(b) { b.classList.remove('active'); });
            tabContents.forEach(function(c) { c.classList.remove('active'); });
            this.classList.add('active');
            document.getElementById('tab-' + targetTab).classList.add('active');
        });
    });

    // ==================== OPEN REMAP ====================
    function openRemap(data) {
        currentData = data;
        playerBalance = data.balance || 0;

        // Vehicle info
        document.getElementById('vehicleName').textContent = data.vehicleName || 'UNKNOWN';
        document.getElementById('plateDisplay').textContent = 'PLATE: ' + (data.plate || 'N/A');

        // Normalizer data
        if (data.archetypes) archetypes = data.archetypes;
        if (data.subArchetypes) subArchetypes = data.subArchetypes;
        if (data.rankConfig) rankConfig = data.rankConfig;
        if (data.weights) weights = data.weights;

        // Base vehicle stats
        basePower = data.basePower || 250;
        baseTorque = data.baseTorque || 300;
        hasTurbo = data.hasTurbo || false;
        originalStats = data.baseStats || {};

        // Dyno - load saved values
        if (data.dynoSettings) {
            dynoSettings = data.dynoSettings;
        } else {
            dynoSettings = { afr: 13.5, timing: 0, boost: 0, finalDrive: 3.55 };
        }

        // Transmission - load saved values
        if (data.transSettings) {
            transSettings = data.transSettings;
        } else {
            transSettings = { mode: 'auto', gearPreset: 'stock' };
        }

        // Remap - load saved values
        originalArchetype = data.originalArchetype || data.currentArchetype || 'esportivo';
        selectedArchetype = data.currentArchetype || originalArchetype;
        originalSubArchetype = data.originalSubArchetype || data.currentSubArchetype || null;
        selectedSubArchetype = data.currentSubArchetype || null;
        adjustments = data.adjustments || { top_speed: 0, acceleration: 0, handling: 0, braking: 0 };
        stats.forEach(function(s) { if (adjustments[s] === undefined) adjustments[s] = 0; });
        subArchetypeBonuses = data.subArchetypeBonuses || {};

        // Initialize all tabs
        initDynoTab();
        initTransmissionTab();
        initRemapTab();
        updateBalanceDisplay();

        // Show app
        app.classList.remove('hidden');
        fetch('https://fish_remaps/nuiReady', { method: 'POST' });
    }

    function handleNormalizerData(data) {
        if (data.archetypes) archetypes = data.archetypes;
        if (data.subArchetypes) subArchetypes = data.subArchetypes;
        if (data.rankConfig) rankConfig = data.rankConfig;
        if (data.weights) weights = data.weights;
        // Refresh remap tab if visible
        buildArchetypeCards();
        buildSubArchetypeCards();
    }

    function updateBalanceDisplay() {
        document.getElementById('balanceDisplay').textContent = '$' + playerBalance.toLocaleString();
    }

    // ==================== CLOSE ====================
    btnClose.addEventListener('click', closeNui);
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') closeNui();
    });

    function closeNui() {
        app.classList.add('hidden');
        fetch('https://fish_remaps/close', { method: 'POST' });
    }

    // ================================================================
    // ==================== DYNO TUNING TAB ====================
    // ================================================================

    function initDynoTab() {
        // Set slider values
        document.getElementById('sliderAfr').value = dynoSettings.afr;
        document.getElementById('valAfr').textContent = dynoSettings.afr.toFixed(1);

        document.getElementById('sliderTiming').value = dynoSettings.timing;
        document.getElementById('valTiming').textContent = dynoSettings.timing + '°';

        document.getElementById('sliderBoost').value = dynoSettings.boost;
        document.getElementById('valBoost').textContent = dynoSettings.boost + ' PSI';

        document.getElementById('sliderDrive').value = dynoSettings.finalDrive;
        document.getElementById('valDrive').textContent = dynoSettings.finalDrive.toFixed(2);

        // Show/hide boost based on turbo
        const boostGroup = document.getElementById('boostGroup');
        if (!hasTurbo) {
            boostGroup.style.opacity = '0.4';
            boostGroup.style.pointerEvents = 'none';
        } else {
            boostGroup.style.opacity = '1';
            boostGroup.style.pointerEvents = 'auto';
        }

        updateDynoTelemetry();
    }

    // Slider event listeners
    document.getElementById('sliderAfr').addEventListener('input', function() {
        dynoSettings.afr = parseFloat(this.value);
        document.getElementById('valAfr').textContent = dynoSettings.afr.toFixed(1);
        updateDynoTelemetry();
    });

    document.getElementById('sliderTiming').addEventListener('input', function() {
        dynoSettings.timing = parseInt(this.value);
        document.getElementById('valTiming').textContent = dynoSettings.timing + '°';
        updateDynoTelemetry();
    });

    document.getElementById('sliderBoost').addEventListener('input', function() {
        dynoSettings.boost = parseInt(this.value);
        document.getElementById('valBoost').textContent = dynoSettings.boost + ' PSI';
        updateDynoTelemetry();
    });

    document.getElementById('sliderDrive').addEventListener('input', function() {
        dynoSettings.finalDrive = parseFloat(this.value);
        document.getElementById('valDrive').textContent = dynoSettings.finalDrive.toFixed(2);
        updateDynoTelemetry();
    });

    document.getElementById('btnApplyDyno').addEventListener('click', function() {
        const cost = 2000;
        if (playerBalance < cost) {
            showDynoAlert('danger', 'Insufficient funds. Need $' + cost.toLocaleString());
            return;
        }
        fetch('https://fish_remaps/applyDyno', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                dynoSettings: dynoSettings,
                cost: cost
            })
        });
    });

    function updateDynoTelemetry() {
        const afr = dynoSettings.afr;
        const timing = dynoSettings.timing;
        const boost = dynoSettings.boost;
        const finalDrive = dynoSettings.finalDrive;

        // AFR efficiency factor
        // Optimal: 13.2-13.8 (best power at ~13.5)
        // Rich (<13.0): less power, safer, cooler
        // Lean (>14.0): less power, dangerous, hotter
        let afrEfficiency = 1.0;
        let afrWarning = '';
        let alertLevel = 'ok';

        if (afr >= 13.2 && afr <= 13.8) {
            afrEfficiency = 1.0; // Optimal
        } else if (afr >= 12.8 && afr < 13.2) {
            afrEfficiency = 0.97; // Slightly rich, minor loss
        } else if (afr > 13.8 && afr <= 14.2) {
            afrEfficiency = 0.96; // Slightly lean, minor loss
        } else if (afr >= 12.0 && afr < 12.8) {
            afrEfficiency = 0.92; // Rich, power loss
            afrWarning = 'Rich mixture: Power reduced, fuel waste';
            alertLevel = 'warning';
        } else if (afr > 14.2 && afr <= 14.6) {
            afrEfficiency = 0.90; // Lean, risk
            afrWarning = 'Lean mixture: Reduced power, engine knock risk';
            alertLevel = 'warning';
        } else if (afr < 12.0) {
            afrEfficiency = 0.85; // Very rich
            afrWarning = 'Extremely rich: Major power loss, fouled plugs';
            alertLevel = 'danger';
        } else if (afr > 14.6) {
            afrEfficiency = 0.80; // Dangerously lean
            afrWarning = 'DANGEROUSLY LEAN: Severe engine damage risk!';
            alertLevel = 'danger';
        }

        // Show/hide AFR warning
        const afrWarningEl = document.getElementById('afrWarning');
        if (afrWarning) {
            afrWarningEl.classList.remove('hidden');
            document.getElementById('afrWarningText').textContent = afrWarning;
            afrWarningEl.className = 'afr-warning' + (alertLevel === 'warning' ? ' caution' : '');
        } else {
            afrWarningEl.classList.add('hidden');
        }

        // Timing efficiency (advance = more power up to a point, retard = safer)
        // Optimal around +4° to +8° for most engines
        let timingEfficiency = 1.0 + (timing * 0.008); // Each degree = ~0.8% change
        timingEfficiency = Math.max(0.85, Math.min(1.08, timingEfficiency));

        // Boost power multiplier
        let boostMultiplier = 1.0;
        if (hasTurbo && boost > 0) {
            // Each PSI adds roughly 3-5% power depending on engine
            boostMultiplier = 1.0 + (boost * 0.04);
        }

        // Final drive affects acceleration vs top speed tradeoff
        // Lower ratio = higher top speed, less acceleration
        // Higher ratio = lower top speed, more acceleration
        let driveAccelFactor = 0.7 + (finalDrive - 1.5) * 0.2; // 0.7 at 1.5, 1.3 at 4.5
        let driveSpeedFactor = 1.3 - (finalDrive - 1.5) * 0.2; // 1.3 at 1.5, 0.7 at 4.5

        // Calculate power
        let effectivePower = basePower * afrEfficiency * timingEfficiency * boostMultiplier;
        let effectiveTorque = baseTorque * afrEfficiency * timingEfficiency * boostMultiplier;

        // Engine temperature calculation
        let baseTemp = 90;
        let tempFromBoost = boost * 1.5; // Each PSI adds ~1.5°C
        let tempFromAfr = 0;
        if (afr < 13.0) tempFromAfr = (13.0 - afr) * -5; // Rich = cooler
        if (afr > 14.0) tempFromAfr = (afr - 14.0) * 8; // Lean = hotter
        let tempFromTiming = timing * 0.8; // Advance = hotter
        let engineTemp = Math.round(baseTemp + tempFromBoost + tempFromAfr + tempFromTiming);
        engineTemp = Math.max(60, Math.min(150, engineTemp));

        // 0-100 km/h time (simplified physics)
        // Base time inversely proportional to power/weight ratio
        // Using a rough formula: base time = constant / sqrt(hp_per_ton)
        let weightFactor = 1.0; // Could be model-specific
        let hpPerTon = effectivePower / (1.5 * weightFactor); // Assume 1.5 ton base
        let baseAccelTime = 280 / Math.sqrt(hpPerTon);
        baseAccelTime *= (1 / driveAccelFactor); // Final drive affects accel
        baseAccelTime = Math.max(2.0, Math.min(8.0, baseAccelTime));

        // Top speed estimate
        let baseTopSpeed = Math.sqrt(effectivePower / 0.35) * 1.2; // Rough aero calc
        baseTopSpeed *= driveSpeedFactor;
        baseTopSpeed = Math.round(Math.max(120, Math.min(400, baseTopSpeed)));

        // Update gauge displays
        const hpPercent = Math.min(100, (effectivePower / 1000) * 100);
        const tqPercent = Math.min(100, (effectiveTorque / 1000) * 100);

        document.getElementById('gaugeHp').textContent = Math.round(effectivePower);
        document.getElementById('gaugeTq').textContent = Math.round(effectiveTorque);

        // Update gauge SVG circles
        const hpOffset = 326.7 - (326.7 * hpPercent / 100);
        const tqOffset = 326.7 - (326.7 * tqPercent / 100);
        document.getElementById('gaugeHpFill').style.strokeDashoffset = hpOffset;
        document.getElementById('gaugeTqFill').style.strokeDashoffset = tqOffset;

        // Color gauges based on values
        let hpColor = '#00d4ff';
        if (effectivePower > basePower * 1.3) hpColor = '#ff8800';
        if (effectivePower > basePower * 1.5) hpColor = '#ff3344';
        document.getElementById('gaugeHpFill').style.stroke = hpColor;

        // Stat cards
        document.getElementById('statAccel').textContent = baseAccelTime.toFixed(1) + 's';
        document.getElementById('statAccel').className = 'stat-value' +
            (baseAccelTime <= 3.5 ? ' positive' : baseAccelTime >= 6 ? ' negative' : '');

        document.getElementById('statTopSpeed').textContent = baseTopSpeed + ' km/h';
        document.getElementById('statTopSpeed').className = 'stat-value' +
            (baseTopSpeed >= 280 ? ' positive' : baseTopSpeed <= 160 ? ' negative' : '');

        document.getElementById('statTemp').textContent = engineTemp + '°C';
        document.getElementById('statTemp').className = 'stat-value' +
            (engineTemp > 110 ? ' danger' : engineTemp > 100 ? ' warning' : '');

        // Rank impact estimate
        let rankImpact = calculateDynoRankImpact(effectivePower, effectiveTorque, baseAccelTime, baseTopSpeed);
        let rankEl = document.getElementById('statRank');
        if (rankImpact > 0) {
            rankEl.textContent = '+' + rankImpact.toFixed(0) + ' pts';
            rankEl.className = 'stat-value positive';
        } else if (rankImpact < 0) {
            rankEl.textContent = rankImpact.toFixed(0) + ' pts';
            rankEl.className = 'stat-value negative';
        } else {
            rankEl.textContent = 'Neutral';
            rankEl.className = 'stat-value';
        }

        // Draw power curve
        drawPowerCurve(effectivePower, effectiveTorque, boost, afr, timing);

        // Update alert
        updateDynoAlert(alertLevel, afrWarning, engineTemp);
    }

    function calculateDynoRankImpact(hp, torque, accelTime, topSpeed) {
        // Simplified: compare tuned vs stock performance
        let stockHp = basePower;
        let hpGain = ((hp - stockHp) / stockHp) * 100;

        // Score roughly based on power improvement
        let scoreImpact = hpGain * 2;

        // Penalize extreme AFR
        let afr = dynoSettings.afr;
        if (afr < 12.5 || afr > 14.5) scoreImpact -= 10;
        if (afr < 12.0 || afr > 14.8) scoreImpact -= 20;

        return Math.round(scoreImpact);
    }

    function showDynoAlert(type, message) {
        // Create a floating notification
        const div = document.createElement('div');
        div.className = 'dyno-notification ' + type;
        div.textContent = message;
        div.style.cssText = 'position:fixed;top:20px;right:20px;padding:12px 20px;border-radius:8px;z-index:9999;font-family:var(--font-body);font-size:14px;animation:slideIn 0.3s ease;';
        if (type === 'danger') {
            div.style.background = 'rgba(255,51,68,0.15)';
            div.style.border = '1px solid #ff3344';
            div.style.color = '#ff3344';
        } else {
            div.style.background = 'rgba(0,212,255,0.15)';
            div.style.border = '1px solid #00d4ff';
            div.style.color = '#00d4ff';
        }
        document.body.appendChild(div);
        setTimeout(() => div.remove(), 3000);
    }

    function updateDynoAlert(level, message, temp) {
        const alert = document.getElementById('dynoAlert');
        const icon = alert.querySelector('.alert-icon');
        const text = alert.querySelector('.alert-text');

        alert.className = 'dyno-alert';

        if (level === 'danger') {
            alert.classList.add('danger');
            icon.textContent = '🚨';
            text.textContent = message || 'Critical engine parameters detected!';
        } else if (level === 'warning') {
            alert.classList.add('warning');
            icon.textContent = '⚠️';
            text.textContent = message || 'Sub-optimal tuning detected.';
        } else {
            icon.textContent = '✅';
            let msg = 'Optimal tuning. All parameters within safe range.';
            if (temp > 95) msg = 'Tuning applied. Engine temp slightly elevated (' + temp + '°C).';
            text.textContent = msg;
        }
    }

    function drawPowerCurve(hp, tq, boost, afr, timing) {
        const canvas = document.getElementById('powerCurveCanvas');
        const ctx = canvas.getContext('2d');
        const W = canvas.width;
        const H = canvas.height;

        ctx.clearRect(0, 0, W, H);

        // Background
        ctx.fillStyle = '#1a1a2e';
        ctx.fillRect(0, 0, W, H);

        // Grid lines
        ctx.strokeStyle = 'rgba(0,212,255,0.1)';
        ctx.lineWidth = 0.5;
        for (let i = 0; i < 5; i++) {
            let y = 20 + i * ((H - 40) / 4);
            ctx.beginPath(); ctx.moveTo(40, y); ctx.lineTo(W - 10, y); ctx.stroke();
        }

        // RPM labels
        ctx.fillStyle = '#555577';
        ctx.font = '9px Share Tech Mono';
        let rpmLabels = ['1000', '2000', '3000', '4000', '5000', '6000', '7000', '8000'];
        let rpmStep = (W - 50) / (rpmLabels.length - 1);
        rpmLabels.forEach(function(label, i) {
            ctx.fillText(label, 40 + i * rpmStep, H - 4);
        });

        // HP curve (blue)
        let hpPoints = generatePowerCurvePoints(hp, boost, 'hp');
        ctx.beginPath();
        ctx.strokeStyle = '#00d4ff';
        ctx.lineWidth = 2;
        ctx.shadowColor = 'rgba(0,212,255,0.5)';
        ctx.shadowBlur = 4;
        hpPoints.forEach(function(p, i) {
            let x = 40 + (i / (hpPoints.length - 1)) * (W - 50);
            let y = H - 20 - (p / (hp * 1.2)) * (H - 40);
            if (i === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
        });
        ctx.stroke();
        ctx.shadowBlur = 0;

        // Torque curve (orange)
        let tqPoints = generatePowerCurvePoints(tq, boost, 'tq');
        ctx.beginPath();
        ctx.strokeStyle = '#ff8800';
        ctx.lineWidth = 2;
        ctx.shadowColor = 'rgba(255,136,0,0.5)';
        ctx.shadowBlur = 4;
        tqPoints.forEach(function(p, i) {
            let x = 40 + (i / (tqPoints.length - 1)) * (W - 50);
            let y = H - 20 - (p / (tq * 1.2)) * (H - 40);
            if (i === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
        });
        ctx.stroke();
        ctx.shadowBlur = 0;

        // Legend
        ctx.fillStyle = '#00d4ff';
        ctx.fillRect(W - 120, 10, 10, 3);
        ctx.fillStyle = '#8888aa';
        ctx.font = '9px Share Tech Mono';
        ctx.fillText('Power (HP)', W - 106, 14);

        ctx.fillStyle = '#ff8800';
        ctx.fillRect(W - 120, 24, 10, 3);
        ctx.fillStyle = '#8888aa';
        ctx.fillText('Torque (Nm)', W - 106, 28);
    }

    function generatePowerCurvePoints(peakVal, boost, type) {
        // Generate a realistic power/torque curve shape
        // 20 data points from ~1000 to ~8000 RPM
        let points = [];
        let numPoints = 20;

        for (let i = 0; i < numPoints; i++) {
            let rpm = i / (numPoints - 1); // 0 to 1
            let val;

            if (type === 'hp') {
                // HP peaks later (around 6000-7000 RPM)
                // Shape: slow start, rapid climb, peak at ~75%, slight drop
                val = peakVal * Math.pow(rpm, 0.6) * Math.pow(1 - Math.pow(rpm - 0.75, 2) * 2, 0.3);
                if (rpm > 0.85) val *= (1 - (rpm - 0.85) * 2); // Drop at high RPM
            } else {
                // Torque peaks earlier (around 4000-5000 RPM)
                val = peakVal * Math.pow(rpm, 0.4) * Math.exp(-2 * Math.pow(rpm - 0.55, 2));
            }

            // Turbo spool effect
            if (boost > 0 && rpm < 0.3) {
                let turboSpool = Math.min(1, rpm / 0.3); // Linear spool up to 3000 RPM
                val *= turboSpool;
            }

            points.push(Math.max(0, val));
        }
        return points;
    }

    // ================================================================
    // ==================== TRANSMISSION TAB ====================
    // ================================================================

    function initTransmissionTab() {
        // Set mode selection
        document.querySelectorAll('#transModeGrid .mode-card').forEach(function(card) {
            card.classList.toggle('selected', card.dataset.mode === transSettings.mode);
            card.addEventListener('click', function() {
                document.querySelectorAll('#transModeGrid .mode-card').forEach(function(c) {
                    c.classList.remove('selected');
                });
                this.classList.add('selected');
                transSettings.mode = this.dataset.mode;
            });
        });

        // Set gear ratio selection
        document.querySelectorAll('#gearRatioGrid .mode-card').forEach(function(card) {
            card.classList.toggle('selected', card.dataset.preset === transSettings.gearPreset);
            card.addEventListener('click', function() {
                document.querySelectorAll('#gearRatioGrid .mode-card').forEach(function(c) {
                    c.classList.remove('selected');
                });
                this.classList.add('selected');
                transSettings.gearPreset = this.dataset.preset;
                updateGearImpactPreview();
            });
        });

        updateGearImpactPreview();
    }

    function updateGearImpactPreview() {
        let impact = gearPresetImpact[transSettings.gearPreset] || { accel: 0, speed: 0 };
        let accelEl = document.getElementById('impactAccel');
        let speedEl = document.getElementById('impactSpeed');

        accelEl.textContent = (impact.accel >= 0 ? '+' : '') + impact.accel + '%';
        accelEl.className = 'impact-value ' + (impact.accel > 0 ? 'positive' : impact.accel < 0 ? 'negative' : 'neutral');

        speedEl.textContent = (impact.speed >= 0 ? '+' : '') + impact.speed + '%';
        speedEl.className = 'impact-value ' + (impact.speed > 0 ? 'positive' : impact.speed < 0 ? 'negative' : 'neutral');
    }

    document.getElementById('btnApplyTransMode').addEventListener('click', function() {
        let cost = 3000;
        if (playerBalance < cost) {
            alert('Insufficient funds. Need $' + cost.toLocaleString());
            return;
        }
        fetch('https://fish_remaps/applyTransMode', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ mode: transSettings.mode, cost: cost })
        });
    });

    document.getElementById('btnApplyGearRatio').addEventListener('click', function() {
        let cost = 5000;
        if (playerBalance < cost) {
            alert('Insufficient funds. Need $' + cost.toLocaleString());
            return;
        }
        fetch('https://fish_remaps/applyGearRatio', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ preset: transSettings.gearPreset, cost: cost })
        });
    });

    // ================================================================
    // ==================== REMAP TAB ====================
    // ================================================================

    function initRemapTab() {
        document.getElementById('originalArchLabel').textContent =
            (archetypes[originalArchetype] && archetypes[originalArchetype].label) || originalArchetype || 'Esportivo';
        document.getElementById('newArchLabel').textContent =
            (archetypes[selectedArchetype] && archetypes[selectedArchetype].label) || selectedArchetype || 'Esportivo';

        buildArchetypeCards();
        buildSubArchetypeCards();
        buildAdjustmentSliders();
        recalculateRemap();
        updateRemapCost();
    }

    function buildArchetypeCards() {
        const grid = document.getElementById('archetypeGrid');
        grid.innerHTML = '';

        Object.keys(archetypes).forEach(function(key) {
            const arch = archetypes[key];
            const card = document.createElement('div');
            card.className = 'arch-card' + (key === selectedArchetype ? ' selected' : '');
            card.dataset.key = key;
            card.innerHTML =
                '<div class="arch-card-icon">' + (arch.icon || '🚗') + '</div>' +
                '<div class="arch-card-name">' + (arch.label || key) + '</div>' +
                '<div class="arch-card-desc">' + (arch.description || '') + '</div>';

            card.addEventListener('click', function() {
                selectedArchetype = key;
                document.querySelectorAll('.arch-card').forEach(function(c) {
                    c.classList.toggle('selected', c.dataset.key === key);
                });
                document.getElementById('newArchLabel').textContent = arch.label || key;
                recalculateRemap();
                updateRemapCost();
            });

            grid.appendChild(card);
        });
    }

    function buildSubArchetypeCards() {
        const grid = document.getElementById('subArchGrid');
        grid.innerHTML = '';

        Object.keys(subArchetypes).forEach(function(key) {
            const sub = subArchetypes[key];
            const card = document.createElement('div');
            card.className = 'subarch-card' + (key === selectedSubArchetype ? ' selected' : '');
            card.dataset.key = key;
            card.innerHTML =
                '<div class="subarch-icon">' + (sub.icon || '🔧') + '</div>' +
                '<div class="subarch-name">' + (sub.label || key) + '</div>';

            card.addEventListener('click', function() {
                selectedSubArchetype = key;
                document.querySelectorAll('.subarch-card').forEach(function(c) {
                    c.classList.toggle('selected', c.dataset.key === key);
                });
                recalculateRemap();
                updateRemapCost();
            });

            grid.appendChild(card);
        });

        // Show bonus preview if subarchetype selected
        updateSubArchetypeBonusPreview();
    }

    function updateSubArchetypeBonusPreview() {
        const preview = document.getElementById('subarchBonusPreview');
        const bonusList = document.getElementById('bonusList');

        if (!selectedSubArchetype || !subArchetypes[selectedSubArchetype]) {
            preview.classList.add('hidden');
            return;
        }

        const sub = subArchetypes[selectedSubArchetype];
        const bonuses = sub.statBonus || {};
        bonusList.innerHTML = '';

        let hasBonuses = false;
        Object.keys(bonuses).forEach(function(stat) {
            const val = bonuses[stat];
            if (val === 0) return;
            hasBonuses = true;
            const row = document.createElement('div');
            row.className = 'bonus-row';
            const displayName = stat.replace(/_/g, ' ').toUpperCase();
            row.innerHTML =
                '<span class="bonus-stat-name">' + displayName + '</span>' +
                '<span class="bonus-stat-value ' + (val >= 0 ? 'positive' : 'negative') + '">' +
                (val >= 0 ? '+' : '') + val + '</span>';
            bonusList.appendChild(row);
        });

        if (hasBonuses) {
            preview.classList.remove('hidden');
        } else {
            preview.classList.add('hidden');
        }
    }

    function buildAdjustmentSliders() {
        const container = document.getElementById('adjustments');
        container.innerHTML = '';

        stats.forEach(function(stat) {
            const val = adjustments[stat] || 0;
            const row = document.createElement('div');
            row.className = 'adjust-row';
            row.innerHTML =
                '<div class="adjust-header">' +
                    '<span class="adjust-label">' + statLabels[stat] + '</span>' +
                    '<span class="adjust-value" id="adjVal_' + stat + '" style="color:' +
                    (val >= 0 ? '#00ff88' : '#ff3344') + '">' +
                    (val >= 0 ? '+' : '') + val + '</span>' +
                '</div>' +
                '<input type="range" class="adjust-slider" id="adjSlider_' + stat + '" min="-15" max="15" value="' + val + '" step="1">';

            container.appendChild(row);

            const slider = row.querySelector('.adjust-slider');
            slider.addEventListener('input', function() {
                const newVal = parseInt(this.value);
                adjustments[stat] = newVal;
                const valEl = document.getElementById('adjVal_' + stat);
                valEl.textContent = (newVal >= 0 ? '+' : '') + newVal;
                valEl.style.color = newVal >= 0 ? '#00ff88' : '#ff3344';
                recalculateRemap();
                updateRemapCost();
            });
        });
    }

    function recalculateRemap() {
        // DNA blend: 75% new archetype, 25% original
        const inheritance = 0.75;
        blendedStats = {};

        stats.forEach(function(stat) {
            const orig = originalStats[stat] || 50;

            // Get archetype modifier
            let archMod = 1.0;
            if (archetypes[selectedArchetype] && archetypes[selectedArchetype].statModifiers) {
                archMod = archetypes[selectedArchetype].statModifiers[stat] || 1.0;
            }

            // Apply archetype modifier to get "new" stat
            const newStat = orig * archMod;

            // DNA blend
            let blended = (newStat * inheritance) + (orig * (1 - inheritance));

            // Apply subarchetype bonus (THIS IS THE FIX - apply subarchetype to final stat)
            if (selectedSubArchetype && subArchetypes[selectedSubArchetype]) {
                const subBonuses = subArchetypes[selectedSubArchetype].statBonus || {};
                blended += (subBonuses[stat] || 0);
            }

            blendedStats[stat] = blended;
        });

        updateDNAVisualization();
        updateComparison();
        updateSubArchetypeBonusPreview();

        // Send preview to server
        fetch('https://fish_remaps/previewAdjustment', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                archetype: selectedArchetype,
                subArchetype: selectedSubArchetype,
                adjustments: adjustments
            })
        });
    }

    function updateDNAVisualization() {
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

        let totalBefore = 0;
        let totalAfter = 0;

        stats.forEach(function(stat) {
            const before = originalStats[stat] || 50;
            const blend = blendedStats[stat] || before;
            const adj = adjustments[stat] || 0;
            const after = Math.max(0, Math.min(100, blend + adj));
            const diff = after - before;

            totalBefore += before * (weights[stat] || 0.25);
            totalAfter += after * (weights[stat] || 0.25);

            const row = document.createElement('div');
            row.className = 'comp-row';
            row.innerHTML =
                '<div class="comp-label">' + statLabels[stat] + '</div>' +
                '<div class="comp-track">' +
                    '<div class="comp-before" style="width:' + before + '%"></div>' +
                    '<div class="comp-after" style="width:' + after + '%;background:' +
                    (diff >= 0 ? 'rgba(0,255,136,0.5)' : 'rgba(255,51,68,0.5)') + '"></div>' +
                '</div>' +
                '<div class="comp-values">' +
                    '<span class="comp-val before">' + Math.round(before) + '</span>' +
                    '<span class="comp-val after ' + (diff >= 0 ? 'up' : 'down') + '">' +
                    (diff >= 0 ? '+' : '') + Math.round(diff) + '</span>' +
                '</div>';
            container.appendChild(row);
        });

        // Update rank change indicator
        const rankBefore = getRank(totalBefore);
        const rankAfter = getRank(totalAfter);
        document.getElementById('rankBefore').textContent = rankBefore.name;
        document.getElementById('rankBefore').style.color = rankBefore.color;
        document.getElementById('rankAfter').textContent = rankAfter.name;
        document.getElementById('rankAfter').style.color = rankAfter.color;
    }

    function getRank(score) {
        // Score is weighted average (0-100 scale), map to rank config
        let scaledScore = score; // Already 0-100
        for (let i = 0; i < rankConfig.length; i++) {
            let r = rankConfig[i];
            // Rank config min/max are in 0-1000 scale, convert
            if (scaledScore * 10 >= r.min && scaledScore * 10 <= r.max) {
                return { name: r.name, color: r.color };
            }
        }
        return { name: 'C', color: '#8B8B8B' };
    }

    function updateRemapCost() {
        let totalCost = 0;

        // Archetype change cost
        let archChanged = selectedArchetype !== originalArchetype;
        let archCost = archChanged ? 15000 : 0;
        document.getElementById('costArchetype').style.display = archChanged ? 'flex' : 'none';
        totalCost += archCost;

        // Subarchetype change cost
        let subChanged = selectedSubArchetype !== originalSubArchetype;
        let subCost = (subChanged && selectedSubArchetype) ? 5000 : 0;
        document.getElementById('costSubarch').style.display = subCost > 0 ? 'flex' : 'none';
        totalCost += subCost;

        // Adjustment cost (sum of absolute values)
        let totalAdjPoints = 0;
        stats.forEach(function(s) { totalAdjPoints += Math.abs(adjustments[s] || 0); });
        let adjCost = totalAdjPoints * 1000;
        document.getElementById('costAdjustment').style.display = adjCost > 0 ? 'flex' : 'none';
        if (adjCost > 0) {
            document.getElementById('costAdjustment').querySelector('span:last-child').textContent = '$' + adjCost.toLocaleString();
        }
        totalCost += adjCost;

        document.getElementById('remapTotalCost').textContent = '$' + totalCost.toLocaleString();

        // Update confirm button state
        const btn = document.getElementById('btnConfirmRemap');
        const zeroSumValid = checkZeroSum();
        btn.disabled = !zeroSumValid || totalCost > playerBalance;
    }

    function checkZeroSum() {
        // Sum of adjustments must be <= 0 (can't create points from nothing)
        let sum = 0;
        stats.forEach(function(s) { sum += (adjustments[s] || 0); });
        return sum <= 0;
    }

    function updateRemapPoints() {
        let totalSum = 0;
        stats.forEach(function(s) { totalSum += (adjustments[s] || 0); });
        let balance = -totalSum;

        document.getElementById('remapPointsUsed').textContent = balance;

        const maxBalance = 30;
        const pct = Math.max(0, Math.min(100, (Math.abs(balance) / maxBalance) * 100));
        const fill = document.getElementById('remapPointsFill');

        if (balance < 0) {
            fill.style.backgroundColor = '#ff3344';
            fill.style.width = '100%';
        } else if (balance > 0) {
            fill.style.backgroundColor = '#ffaa00';
            fill.style.width = pct + '%';
        } else {
            fill.style.backgroundColor = '#00ff88';
            fill.style.width = '100%';
        }
    }

    // Override recalculateRemap to also update points
    const origRecalc = recalculateRemap;
    recalculateRemap = function() {
        origRecalc();
        updateRemapPoints();
    };

    // Confirm remap button
    document.getElementById('btnConfirmRemap').addEventListener('click', function() {
        if (this.disabled) return;

        // Calculate total cost
        let totalCost = 0;
        if (selectedArchetype !== originalArchetype) totalCost += 15000;
        if (selectedSubArchetype !== originalSubArchetype && selectedSubArchetype) totalCost += 5000;
        stats.forEach(function(s) { totalCost += Math.abs(adjustments[s] || 0) * 1000; });

        if (playerBalance < totalCost) return;

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
                }, {}),
                cost: totalCost
            })
        });
    });

})();
