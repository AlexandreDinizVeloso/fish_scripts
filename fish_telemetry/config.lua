Config = {}

-- Recording settings
Config.RecordingInterval = 100 -- ms between data collection
Config.MaxRecordingDuration = 300000 -- 300 seconds in ms

-- Change detection: 5% stat change = new version
Config.ChangeDetectionThreshold = 0.05

-- Key bindings
Config.Keys = {
    ShowRatings = 311, -- K key: show nearby vehicle ratings
    ToggleRecording = 47 -- G key: toggle telemetry recording
}

-- Stats tracked
Config.Stats = {
    'current_speed',
    'max_speed',
    'zero_to_100',
    'zero_to_200',
    'hundred_to_zero',
    'two_hundred_to_zero',
    'lateral_gforce'
}

-- Display labels for stats
Config.StatLabels = {
    current_speed = 'Speed',
    max_speed = 'Max Speed',
    zero_to_100 = '0-100',
    zero_to_200 = '0-200',
    hundred_to_zero = '100-0',
    two_hundred_to_zero = '200-0',
    lateral_gforce = 'Lateral G'
}

-- Units
Config.SpeedUnit = 'km/h' -- km/h for display
Config.TimeUnit = 's' -- seconds for acceleration/braking times
Config.DistanceUnit = 'm' -- meters for braking distances
Config.GForceUnit = 'G' -- G-force units
