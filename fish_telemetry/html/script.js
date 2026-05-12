/**
 * FISH Telemetry - Script
 * Vehicle telemetry NUI controller
 */

(function() {
    'use strict';

    // State
    let state = {
        isOpen: false,
        isRecording: false,
        vehicleName: 'No Vehicle',
        plate: '',
        currentSpeed: 0,
        maxSpeed: 0,
        best: null,
        last: null,
        versions: {},
        currentVersion: 1
    };

    // DOM Elements
    const app = document.getElementById('app');
    const vehicleNameEl = document.getElementById('vehicleName');
    const vehiclePlateEl = document.getElementById('vehiclePlate');
    const currentSpeedEl = document.getElementById('currentSpeed');
    const maxSpeedEl = document.getElementById('maxSpeed');
    const speedBar = document.getElementById('speedBar');
    const recordingIndicator = document.getElementById('recordingIndicator');
    const speedSection = document.querySelector('.speedometer-section');
    const btnClose = document.getElementById('btnClose');
    const btnToggleRecording = document.getElementById('btnToggleRecording');
    const btnClear = document.getElementById('btnClear');
    const btnCopy = document.getElementById('btnCopy');
    const versionSection = document.getElementById('versionSection');
    const versionTableBody = document.getElementById('versionTableBody');
    const nearbyRatings = document.getElementById('nearbyRatings');
    const ratingsList = document.getElementById('ratingsList');
    const toast = document.getElementById('toast');
    const toastText = document.getElementById('toastText');

    // Stat elements
    const statElements = {
        '0_100': { best: document.getElementById('best0_100'), last: document.getElementById('last0_100'), bar: document.getElementById('bar0_100') },
        '0_200': { best: document.getElementById('best0_200'), last: document.getElementById('last0_200'), bar: document.getElementById('bar0_200') },
        '100_0': { best: document.getElementById('best100_0'), last: document.getElementById('last100_0'), bar: document.getElementById('bar100_0') },
        '200_0': { best: document.getElementById('best200_0'), last: document.getElementById('last200_0'), bar: document.getElementById('bar200_0') },
        'gforce': { best: document.getElementById('bestGforce'), last: document.getElementById('lastGforce'), bar: document.getElementById('barGforce') }
    };

    // Format time value
    function formatTime(value) {
        if (value === null || value === undefined) return '--';
        return value.toFixed(2);
    }

    // Format speed value
    function formatSpeed(value) {
        if (value === null || value === undefined) return '0';
        return Math.round(value).toString();
    }

    // Update speed display
    function updateSpeedDisplay(speed) {
        state.currentSpeed = speed;
        currentSpeedEl.textContent = formatSpeed(speed);

        // Update speed bar (max 400 km/h)
        const percentage = Math.min(speed / 400 * 100, 100);
        speedBar.style.width = percentage + '%';

        // High speed effect
        if (speed > 200) {
            currentSpeedEl.classList.add('high-speed');
        } else {
            currentSpeedEl.classList.remove('high-speed');
        }
    }

    // Update max speed display
    function updateMaxSpeed(speed) {
        state.maxSpeed = speed;
        maxSpeedEl.textContent = formatSpeed(speed);
    }

    // Update stat display
    function updateStat(key, best, last, maxScale) {
        const el = statElements[key];
        if (!el) return;

        el.best.textContent = formatTime(best);
        el.last.textContent = formatTime(last);

        // Update bar based on last value
        const value = last || best;
        if (value && maxScale) {
            const percentage = Math.min((value / maxScale) * 100, 100);
            el.bar.style.width = percentage + '%';
        }
    }

    // Update all stats from result data
    function updateStats(best, last) {
        if (best) {
            updateStat('0_100', best.zero_to_100, last ? last.zero_to_100 : null, 30);
            updateStat('0_200', best.zero_to_200, last ? last.zero_to_200 : null, 60);
            updateStat('100_0', best.hundred_to_zero, last ? last.hundred_to_zero : null, 10);
            updateStat('200_0', best.two_hundred_to_zero, last ? last.two_hundred_to_zero : null, 20);
            updateStat('gforce', best.lateral_gforce, last ? last.lateral_gforce : null, 3);
        }
    }

    // Update recording state UI
    function setRecordingUI(recording) {
        state.isRecording = recording;

        if (recording) {
            recordingIndicator.classList.add('active');
            speedSection.classList.add('recording');
            btnToggleRecording.classList.add('recording');
            btnToggleRecording.querySelector('.btn-icon').textContent = '⏹';
            btnToggleRecording.querySelector('.btn-label').textContent = 'STOP RECORDING';
        } else {
            recordingIndicator.classList.remove('active');
            speedSection.classList.remove('recording');
            btnToggleRecording.classList.remove('recording');
            btnToggleRecording.querySelector('.btn-icon').textContent = '⏺';
            btnToggleRecording.querySelector('.btn-label').textContent = 'START RECORDING';
        }
    }

    // Render version comparison table
    function renderVersionTable(versions) {
        if (!versions || Object.keys(versions).length <= 1) {
            versionSection.classList.add('hidden');
            return;
        }

        versionSection.classList.remove('hidden');
        versionTableBody.innerHTML = '';

        // Find best values for highlighting
        let bestValues = {
            max_speed: 0,
            zero_to_100: Infinity,
            zero_to_200: Infinity,
            hundred_to_zero: Infinity,
            two_hundred_to_zero: Infinity,
            lateral_gforce: 0
        };

        Object.values(versions).forEach(v => {
            if (v.max_speed > bestValues.max_speed) bestValues.max_speed = v.max_speed;
            if (v.zero_to_100 && v.zero_to_100 < bestValues.zero_to_100) bestValues.zero_to_100 = v.zero_to_100;
            if (v.zero_to_200 && v.zero_to_200 < bestValues.zero_to_200) bestValues.zero_to_200 = v.zero_to_200;
            if (v.hundred_to_zero && v.hundred_to_zero < bestValues.hundred_to_zero) bestValues.hundred_to_zero = v.hundred_to_zero;
            if (v.two_hundred_to_zero && v.two_hundred_to_zero < bestValues.two_hundred_to_zero) bestValues.two_hundred_to_zero = v.two_hundred_to_zero;
            if (Math.abs(v.lateral_gforce) > Math.abs(bestValues.lateral_gforce)) bestValues.lateral_gforce = v.lateral_gforce;
        });

        // Sort versions by number
        const sortedVersions = Object.entries(versions).sort((a, b) => {
            return (a[1].version || 0) - (b[1].version || 0);
        });

        sortedVersions.forEach(([key, v]) => {
            const row = document.createElement('tr');
            if (v.version === state.currentVersion) {
                row.classList.add('current-version');
            }

            const cells = [
                { value: 'v' + (v.version || key), isBest: false },
                { value: v.max_speed ? v.max_speed.toFixed(1) : '--', isBest: v.max_speed === bestValues.max_speed },
                { value: v.zero_to_100 ? v.zero_to_100.toFixed(2) : '--', isBest: v.zero_to_100 === bestValues.zero_to_100 },
                { value: v.zero_to_200 ? v.zero_to_200.toFixed(2) : '--', isBest: v.zero_to_200 === bestValues.zero_to_200 },
                { value: v.hundred_to_zero ? v.hundred_to_zero.toFixed(2) : '--', isBest: v.hundred_to_zero === bestValues.hundred_to_zero },
                { value: v.two_hundred_to_zero ? v.two_hundred_to_zero.toFixed(2) : '--', isBest: v.two_hundred_to_zero === bestValues.two_hundred_to_zero },
                { value: v.lateral_gforce ? v.lateral_gforce.toFixed(2) : '--', isBest: Math.abs(v.lateral_gforce) === Math.abs(bestValues.lateral_gforce) }
            ];

            cells.forEach(cell => {
                const td = document.createElement('td');
                td.textContent = cell.value;
                if (cell.isBest) td.classList.add('best-value');
                row.appendChild(td);
            });

            versionTableBody.appendChild(row);
        });
    }

    // Show toast notification
    function showToast(message, duration) {
        duration = duration || 2000;
        toastText.textContent = message;
        toast.classList.remove('hidden');
        toast.classList.add('show');

        setTimeout(function() {
            toast.classList.remove('show');
            setTimeout(function() {
                toast.classList.add('hidden');
            }, 300);
        }, duration);
    }

    // Render nearby ratings
    function renderNearbyRatings(vehicles) {
        if (!vehicles || vehicles.length === 0) {
            ratingsList.innerHTML = '<p class="no-data">No nearby vehicles with telemetry data</p>';
            return;
        }

        ratingsList.innerHTML = '';
        vehicles.forEach(function(v) {
            const item = document.createElement('div');
            item.className = 'rating-item';

            const info = document.createElement('div');
            info.className = 'rating-item-info';
            info.innerHTML = '<span class="rating-item-name">' + (v.name || 'Unknown') + '</span>' +
                '<span class="rating-item-plate">' + (v.plate || '---') + '</span>';

            const stats = document.createElement('div');
            stats.className = 'rating-item-stats';

            if (v.best) {
                if (v.best.max_speed) {
                    const stat = document.createElement('div');
                    stat.className = 'rating-stat';
                    stat.innerHTML = '<span class="rating-stat-label">MAX</span>' +
                        '<span class="rating-stat-value">' + Math.round(v.best.max_speed) + '</span>';
                    stats.appendChild(stat);
                }
                if (v.best.zero_to_100) {
                    const stat = document.createElement('div');
                    stat.className = 'rating-stat';
                    stat.innerHTML = '<span class="rating-stat-label">0-100</span>' +
                        '<span class="rating-stat-value">' + v.best.zero_to_100.toFixed(1) + 's</span>';
                    stats.appendChild(stat);
                }
            }

            if (v.versionCount > 1) {
                const stat = document.createElement('div');
                stat.className = 'rating-stat';
                stat.innerHTML = '<span class="rating-stat-label">VER</span>' +
                    '<span class="rating-stat-value">v' + v.versionCount + '</span>';
                stats.appendChild(stat);
            }

            item.appendChild(info);
            item.appendChild(stats);
            ratingsList.appendChild(item);
        });
    }

    // Open telemetry UI
    function openTelemetry(data) {
        state.isOpen = true;
        state.vehicleName = data.vehicleName || 'No Vehicle';
        state.plate = data.plate || '';
        state.isRecording = data.recording || false;
        state.best = data.best || null;
        state.last = data.last || null;
        state.versions = data.versions || {};
        state.currentVersion = data.currentVersion || 1;

        vehicleNameEl.textContent = state.vehicleName;
        vehiclePlateEl.textContent = state.plate;

        setRecordingUI(state.isRecording);
        updateStats(state.best, state.last);
        renderVersionTable(state.versions);

        if (state.best) {
            updateMaxSpeed(state.best.max_speed || 0);
        }

        app.classList.remove('hidden');
    }

    // Close telemetry UI
    function closeTelemetry() {
        state.isOpen = false;
        app.classList.add('hidden');

        fetch('https://fish_telemetry/close', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
    }

    // NUI Message handler
    window.addEventListener('message', function(event) {
        var data = event.data;

        switch (data.type) {
            case 'openTelemetry':
                openTelemetry(data);
                break;

            case 'updateLive':
                updateSpeedDisplay(data.speed || 0);
                updateMaxSpeed(data.maxSpeed || 0);

                // Update live milestones
                if (data.milestones) {
                    if (data.milestones.zero_to_100) {
                        statElements['0_100'].last.textContent = data.milestones.zero_to_100.toFixed(2);
                        statElements['0_100'].bar.style.width = Math.min((data.milestones.zero_to_100 / 30) * 100, 100) + '%';
                    }
                    if (data.milestones.zero_to_200) {
                        statElements['0_200'].last.textContent = data.milestones.zero_to_200.toFixed(2);
                        statElements['0_200'].bar.style.width = Math.min((data.milestones.zero_to_200 / 60) * 100, 100) + '%';
                    }
                    if (data.milestones.hundred_to_zero) {
                        statElements['100_0'].last.textContent = data.milestones.hundred_to_zero.toFixed(2);
                        statElements['100_0'].bar.style.width = Math.min((data.milestones.hundred_to_zero / 10) * 100, 100) + '%';
                    }
                    if (data.milestones.two_hundred_to_zero) {
                        statElements['200_0'].last.textContent = data.milestones.two_hundred_to_zero.toFixed(2);
                        statElements['200_0'].bar.style.width = Math.min((data.milestones.two_hundred_to_zero / 20) * 100, 100) + '%';
                    }
                    if (data.milestones.lateral_gforce) {
                        statElements['gforce'].last.textContent = Math.abs(data.milestones.lateral_gforce).toFixed(2);
                        statElements['gforce'].bar.style.width = Math.min((Math.abs(data.milestones.lateral_gforce) / 3) * 100, 100) + '%';
                    }
                }
                break;

            case 'recordingStarted':
                setRecordingUI(true);
                if (data.vehicleName) {
                    vehicleNameEl.textContent = data.vehicleName;
                }
                break;

            case 'recordingStopped':
                setRecordingUI(false);
                if (data.result) {
                    state.last = data.result;
                    updateStats(data.best, data.result);
                    updateMaxSpeed(data.best ? data.best.max_speed : data.result.max_speed);
                }
                if (data.versions) {
                    state.versions = data.versions;
                    renderVersionTable(data.versions);
                }
                showToast('Recording complete');
                break;

            case 'versionDetected':
                if (data.versions) {
                    state.versions = data.versions;
                    renderVersionTable(data.versions);
                }
                showToast('Version ' + (data.version || '?') + ' detected - stats changed >5%');
                break;

            case 'copySuccess':
                // Copy to clipboard using NUI
                if (data.text) {
                    copyToClipboard(data.text);
                    showToast('Results copied to clipboard');
                }
                break;

            case 'dataCleared':
                resetDisplay();
                showToast('Data cleared');
                break;

            case 'nearbyRatings':
                nearbyRatings.classList.remove('hidden');
                renderNearbyRatings(data.vehicles);
                break;

            case 'hideRatings':
                nearbyRatings.classList.add('hidden');
                break;

            case 'historicalData':
                if (data.data) {
                    if (data.data.best) {
                        state.best = data.data.best;
                        updateStats(data.data.best, state.last);
                    }
                }
                break;
        }
    });

    // Copy to clipboard helper
    function copyToClipboard(text) {
        // Try modern API first
        if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(text).catch(function() {
                fallbackCopy(text);
            });
        } else {
            fallbackCopy(text);
        }
    }

    function fallbackCopy(text) {
        var textarea = document.createElement('textarea');
        textarea.value = text;
        textarea.style.position = 'fixed';
        textarea.style.opacity = '0';
        document.body.appendChild(textarea);
        textarea.select();
        try {
            document.execCommand('copy');
        } catch (e) {
            // silent fail
        }
        document.body.removeChild(textarea);
    }

    // Reset display to defaults
    function resetDisplay() {
        state.best = null;
        state.last = null;
        state.versions = {};
        state.currentVersion = 1;
        state.currentSpeed = 0;
        state.maxSpeed = 0;

        updateSpeedDisplay(0);
        maxSpeedEl.textContent = '0';

        Object.keys(statElements).forEach(function(key) {
            statElements[key].best.textContent = '--';
            statElements[key].last.textContent = '--';
            statElements[key].bar.style.width = '0%';
        });

        versionSection.classList.add('hidden');
        versionTableBody.innerHTML = '';
    }

    // Event Listeners
    btnClose.addEventListener('click', closeTelemetry);

    btnToggleRecording.addEventListener('click', function() {
        var endpoint = state.isRecording ? 'stopRecording' : 'startRecording';
        fetch('https://fish_telemetry/' + endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
    });

    btnClear.addEventListener('click', function() {
        fetch('https://fish_telemetry/clearData', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
    });

    btnCopy.addEventListener('click', function() {
        var result = state.last || state.best;
        if (!result) {
            showToast('No data to copy');
            return;
        }
        fetch('https://fish_telemetry/copyResults', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ result: result })
        });
    });

    // Keyboard handler: Escape to close
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape' && state.isOpen) {
            closeTelemetry();
        }
    });

    // Start with app hidden
    app.classList.add('hidden');

})();
