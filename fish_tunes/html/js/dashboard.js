(function () {
    'use strict';

    // ── State ──────────────────────────────────────────────────────────
    let state = {
        plate: '',
        dyno: {
            afr: 13.5,
            timing: 0,
            boost: 0,
            drive: 3.55
        },
        drivetrain: 'RWD',
        maxHeat: 100,
        currentHeat: 0
    };

    // ── DOM refs ───────────────────────────────────────────────────────
    const $app = document.getElementById('app');
    const $btnClose = document.getElementById('btnClose');
    const $navTabs = document.querySelectorAll('.nav-tab');
    const $tabContents = document.querySelectorAll('.tab-content');
    
    // Sliders
    const $sliderAfr = document.getElementById('sliderAfr');
    const $sliderTiming = document.getElementById('sliderTiming');
    const $sliderBoost = document.getElementById('sliderBoost');
    const $sliderDrive = document.getElementById('sliderDrive');
    
    // Values
    const $valAfr = document.getElementById('valAfr');
    const $valTiming = document.getElementById('valTiming');
    const $valBoost = document.getElementById('valBoost');
    const $valDrive = document.getElementById('valDrive');

    // Gauges
    const $gaugePower = document.getElementById('gaugePower');
    const $gaugeTorque = document.getElementById('gaugeTorque');
    const $statAccel = document.getElementById('statAccel');
    const $statSpeed = document.getElementById('statSpeed');
    const $statTemp = document.getElementById('statTemp');
    const $dynoAlert = document.getElementById('dynoAlert');

    // Drivetrain
    const $dtCards = document.querySelectorAll('.dt-card');
    const $btnConvertDrivetrain = document.getElementById('btnConvertDrivetrain');

    // Transmission
    let currentTransMode = 'auto';
    let currentGearRatio = 'stock';
    const $btnSetTransMode = document.getElementById('btnSetTransMode');
    const $btnSetGearRatio = document.getElementById('btnSetGearRatio');
    const $transModesList = document.querySelectorAll('#transModesList .option-btn');
    const $gearRatioList = document.querySelectorAll('#gearRatioList .option-btn');

    // Engine & Crafting
    const $engineList = document.getElementById('engineList');
    const $craftingList = document.getElementById('craftingList');

    // ── Helpers ────────────────────────────────────────────────────────
    function post(endpoint, data = {}) {
        return fetch(`https://fish_tunes/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        }).then(r => r.json()).catch(() => null);
    }

    // ── Navigation ─────────────────────────────────────────────────────
    $navTabs.forEach(tab => {
        tab.addEventListener('click', () => {
            $navTabs.forEach(t => t.classList.remove('active'));
            $tabContents.forEach(c => c.classList.remove('active'));
            
            tab.classList.add('active');
            document.getElementById(`tab-${tab.dataset.tab}`).classList.add('active');
        });
    });

    // ── Dyno Logic ─────────────────────────────────────────────────────
    function updateDynoPreview() {
        state.dyno.afr = parseFloat($sliderAfr.value);
        state.dyno.timing = parseInt($sliderTiming.value);
        state.dyno.boost = parseInt($sliderBoost.value);
        state.dyno.drive = parseFloat($sliderDrive.value);

        $valAfr.textContent = state.dyno.afr.toFixed(1);
        $valTiming.textContent = state.dyno.timing + '°';
        $valBoost.textContent = state.dyno.boost + ' PSI';
        $valDrive.textContent = state.dyno.drive.toFixed(2);

        // Simulation (Frontend preview only, backend does real calculation)
        let powerMult = 1.0;
        let alertMsg = 'Optimal tuning achieved. Wear rates normal.';
        let alertType = '';

        if (state.dyno.afr < 13.2) {
            powerMult = 0.95;
            alertMsg = 'Danger: Lean mixture. High risk of engine damage!';
            alertType = 'danger';
        } else if (state.dyno.afr > 13.8) {
            powerMult = 0.9;
            alertMsg = 'Warning: Rich mixture. Unburned fuel and power loss.';
            alertType = 'warning';
        }

        if (state.dyno.timing > 5) powerMult += 0.05;
        if (state.dyno.boost > 0) powerMult += (state.dyno.boost / 30) * 0.4;

        let estimatedHp = Math.floor(250 * powerMult);
        let estimatedTq = Math.floor(230 * powerMult);
        
        $gaugePower.innerHTML = `${estimatedHp}<span class="unit">HP</span>`;
        $gaugeTorque.innerHTML = `${estimatedTq}<span class="unit">TQ</span>`;
        
        let temp = 85 + (state.dyno.boost * 1.5);
        if (state.dyno.afr < 13.2) temp += 20;
        
        $statTemp.textContent = `${Math.floor(temp)}°C`;
        if (temp > 110) $statTemp.className = 'stat-val danger';
        else if (temp > 95) $statTemp.className = 'stat-val warning';
        else $statTemp.className = 'stat-val';

        $dynoAlert.className = 'status-alert ' + alertType;
        $dynoAlert.querySelector('span').textContent = alertMsg;
    }

    $sliderAfr.addEventListener('input', updateDynoPreview);
    $sliderTiming.addEventListener('input', updateDynoPreview);
    $sliderBoost.addEventListener('input', updateDynoPreview);
    $sliderDrive.addEventListener('input', updateDynoPreview);

    document.getElementById('btnApplyTune').addEventListener('click', () => {
        post('applyDynoTune', {
            plate: state.plate,
            afr: state.dyno.afr,
            timing: state.dyno.timing,
            boost: state.dyno.boost,
            drive: state.dyno.drive
        });
        
        const btn = document.getElementById('btnApplyTune');
        btn.textContent = 'FLASHING...';
        btn.style.pointerEvents = 'none';
        
        setTimeout(() => {
            btn.textContent = 'APPLY ECU FLASH';
            btn.style.pointerEvents = 'auto';
        }, 1000);
    });

    // ── Drivetrain Logic ───────────────────────────────────────────────
    $dtCards.forEach(card => {
        card.addEventListener('click', () => {
            $dtCards.forEach(c => c.classList.remove('active'));
            card.classList.add('active');
            state.drivetrain = card.dataset.dt;
        });
    });

    $btnConvertDrivetrain.addEventListener('click', () => {
        post('convertDrivetrain', {
            plate: state.plate,
            drivetrain: state.drivetrain
        });
        
        $btnConvertDrivetrain.textContent = 'CONVERTING...';
        $btnConvertDrivetrain.style.pointerEvents = 'none';
        
        setTimeout(() => {
            $btnConvertDrivetrain.textContent = 'CONVERT DRIVETRAIN';
            $btnConvertDrivetrain.style.pointerEvents = 'auto';
        }, 1500);
    });

    // ── Transmission Logic ─────────────────────────────────────────────
    $transModesList.forEach(btn => {
        btn.addEventListener('click', () => {
            $transModesList.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            currentTransMode = btn.dataset.mode;
        });
    });

    $gearRatioList.forEach(btn => {
        btn.addEventListener('click', () => {
            $gearRatioList.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            currentGearRatio = btn.dataset.preset;
        });
    });

    $btnSetTransMode.addEventListener('click', () => {
        post('setTransmissionMode', { mode: currentTransMode });
        $btnSetTransMode.textContent = 'SAVED';
        setTimeout(() => $btnSetTransMode.textContent = 'SET MODE', 1000);
    });

    $btnSetGearRatio.addEventListener('click', () => {
        post('setGearRatio', { preset: currentGearRatio });
        $btnSetGearRatio.textContent = 'INSTALLED';
        setTimeout(() => $btnSetGearRatio.textContent = 'INSTALL GEARING', 1000);
    });

    // ── Engine Swap Rendering ──────────────────────────────────────────
    function renderEngines(engines) {
        $engineList.innerHTML = '';
        engines.forEach(eng => {
            const el = document.createElement('div');
            el.className = 'item-card';
            el.innerHTML = `
                <h3>${eng.label}</h3>
                <p>${eng.description}</p>
                <div class="item-stats">
                    <div>PWR: <span>${eng.power}</span></div>
                    <div>TRQ: <span>${eng.torque}</span></div>
                    <div>REL: <span>${eng.reliability}%</span></div>
                </div>
                <div class="item-footer">
                    <span class="item-cost">$${eng.cost}</span>
                    <button class="btn-small">INSTALL</button>
                </div>
            `;
            el.querySelector('.btn-small').addEventListener('click', () => {
                post('swapEngine', { engineType: eng.type, cost: eng.cost });
            });
            $engineList.appendChild(el);
        });
    }

    // ── Crafting Rendering ─────────────────────────────────────────────
    function renderCrafting(recipes) {
        $craftingList.innerHTML = '';
        recipes.forEach(rec => {
            const el = document.createElement('div');
            el.className = 'item-card';
            el.innerHTML = `
                <h3>${rec.label}</h3>
                <p>${rec.description}</p>
                <div class="item-stats">
                    <div>DIFF: <span style="color:var(--accent-orange)">${rec.difficulty}%</span></div>
                    <div>TIME: <span style="color:var(--text-secondary)">${rec.crafting_time}s</span></div>
                </div>
                <div class="item-footer">
                    <span class="item-cost">$${rec.cost}</span>
                    <button class="btn-small">CRAFT</button>
                </div>
            `;
            el.querySelector('.btn-small').addEventListener('click', () => {
                post('craftPart', { recipeId: rec.id });
            });
            $craftingList.appendChild(el);
        });
    }

    // ── Initialization ─────────────────────────────────────────────────
    window.addEventListener('message', (event) => {
        const data = event.data;
        if (data.action === 'openAdvancedTunes') {
            state.plate = data.plate;
            document.getElementById('vehicleName').textContent = data.vehicleName;
            document.getElementById('vehiclePlate').textContent = data.plate;
            
            if (data.dyno) {
                $sliderAfr.value = data.dyno.afr || 13.5;
                $sliderTiming.value = data.dyno.timing || 0;
                $sliderBoost.value = data.dyno.boost || 0;
                $sliderDrive.value = data.dyno.drive || 3.55;
                updateDynoPreview();
            }

            if (data.drivetrain) {
                state.drivetrain = data.drivetrain;
                $dtCards.forEach(c => {
                    c.classList.toggle('active', c.dataset.dt === state.drivetrain);
                });
            }
            
            if (data.engines) {
                renderEngines(data.engines);
            }
            
            if (data.recipes) {
                renderCrafting(data.recipes);
            }

            $app.classList.remove('hidden');
        }
    });

    $btnClose.addEventListener('click', () => {
        $app.classList.add('hidden');
        post('close');
        window.parent.postMessage({ action: 'closeIframe' }, '*');
    });

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            $app.classList.add('hidden');
            post('close');
            window.parent.postMessage({ action: 'closeIframe' }, '*');
        }
    });

    // Ready
    post('nuiReadyAdvanced');
})();
