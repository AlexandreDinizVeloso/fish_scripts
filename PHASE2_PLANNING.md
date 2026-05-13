# Phase 2 Implementation Plan - Advanced Tuning Systems

## Overview

Phase 2 will add advanced tuning mechanics and build upon the Phase 1 foundation to create a comprehensive vehicle tuning ecosystem.

---

## 🎯 Phase 2 Features

### 1. Dyno Tuning System (HIGH PRIORITY)
**Purpose**: Real-time engine performance tuning with physics simulation

#### Features to Implement:
- AFR (Air-Fuel Ratio) display and tuning (-15 to +15 range)
- Ignition timing adjustment (-10 to +10 degrees)
- Fuel table tuning (50-150%)
- Final drive ratio modification (1.5-4.5)
- Boost pressure tuning (0-30 PSI)
- Engine temperature monitoring
- Real-time power/torque display
- Tuning profile save/load

#### Integration Points:
- Uses Config.DynoTuning parameters
- Reads from vehicleData.tuning_efficiency
- Affects degradation rates
- Impacts performance multipliers

#### Implementation Files:
- fish_tunes/server/dyno.lua (NEW)
- fish_tunes/server/dyno_client.lua (NEW)
- fish_tunes/html/dyno.html (NEW)

---

### 2. Advanced Tire System (MEDIUM PRIORITY)
**Purpose**: Expand tire system with weather and temperature effects

#### Features to Implement:
- Wet weather grip reduction (15-30% depending on type)
- Tire temperature modeling
- Tire degradation based on temperature
- Tire grip vs Temperature curve
- Hydroplaning risk calculation
- Tire flatspot detection
- All-season vs racing vs drift tuning

#### Configuration:
```lua
Config.TireTemperature = {
    cold_threshold = 40,      -- degrees C
    optimal_min = 60,
    optimal_max = 90,
    overheating_threshold = 110,
    flatspot_risk_above = 120
}

Config.WetWeatherGripLoss = {
    street = 0.15,    -- 15% loss
    sport = 0.20,
    racing = 0.35,    -- racing slicks bad in wet
    drift = 0.18,
}
```

#### Integration:
- Affects TireSystem.GetGripCoefficient()
- Impacts braking and acceleration
- Linked to weather system

---

### 3. Drivetrain Modification System (MEDIUM PRIORITY)
**Purpose**: Allow FWD/RWD/AWD conversion with handling changes

#### Features to Implement:
- AWD/FWD/RWD conversion system
- Handling flag modification using CCarHandlingData
- Traction coefficient changes
- Acceleration distribution
- Braking behavior modification
- Cost calculation per conversion

#### Handling Changes:
```lua
Config.DrivetrainHandling = {
    FWD = {
        handling_modifier = 0.95,
        acceleration_gain = 1.1,
        traction = 0.9,
        cost = 5000
    },
    RWD = {
        handling_modifier = 1.0,
        acceleration_gain = 0.95,
        traction = 1.0,
        cost = 8000
    },
    AWD = {
        handling_modifier = 1.05,
        acceleration_gain = 1.15,
        traction = 1.2,
        cost = 15000
    }
}
```

#### Implementation Files:
- fish_tunes/server/drivetrain.lua (NEW)

---

### 4. Engine Swap System (MEDIUM PRIORITY)
**Purpose**: Replace vehicle engines with performance variations

#### Features to Implement:
- Engine catalog with different specs
- Power/Torque profiles per engine
- Compatibility checking
- Installation simulation
- Cost calculation
- Archetype recalculation

#### Engine Database Structure:
```lua
Config.EngineDatabase = {
    engine_1 = {
        label = "Stock Engine",
        power = 100,
        torque = 100,
        cost = 0,
        description = "Original equipment"
    },
    engine_2 = {
        label = "Racing V8",
        power = 180,
        torque = 160,
        cost = 25000,
        description = "High-performance displacement"
    },
    -- ... more engines
}
```

#### Implementation Files:
- fish_tunes/server/engine_swap.lua (NEW)

---

### 5. Advanced Part Crafting (HIGH PRIORITY)
**Purpose**: Create customizable part crafting with quality variance

#### Features to Implement:
- Recipe system for part combinations
- Quality level determination (0-100%)
- Material cost calculation
- Crafting time simulation
- Success/failure mechanics
- Part DNA inheritance (if crafted from other parts)

#### Recipe Example:
```lua
Config.CraftingRecipes = {
    racing_pistons = {
        label = "Racing Pistons",
        materials = {
            titanium = 5,
            steel = 10,
            rare_alloy = 2
        },
        time = 300,  -- seconds
        difficulty = 85,  -- affects success rate
        baseStats = {acceleration = 20, top_speed = 15}
    }
}
```

#### Implementation Files:
- fish_tunes/server/crafting.lua (NEW)
- fish_tunes/server/crafting_client.lua (NEW)

---

### 6. Vehicle Performance Analytics (MEDIUM PRIORITY)
**Purpose**: Comprehensive statistics and performance tracking

#### Features to Implement:
- Acceleration curve simulation
- Top speed calculation
- Braking distance calculation
- Lap time estimation
- Performance comparisons
- Historical tracking

#### Metrics to Track:
- 0-100 km/h time
- Top speed
- Braking distance (60-0 km/h)
- Handling rating
- Estimated lap time on circuit

#### Integration Files:
- fish_tunes/server/analytics.lua (NEW)

---

### 7. NUI Dashboard Enhancement (HIGH PRIORITY)
**Purpose**: Create interactive UI for all tuning systems

#### Dashboard Sections:
1. **Health Monitor**
   - Part health bars
   - Maintenance alerts
   - Repair cost estimates

2. **Dyno Tuning**
   - Real-time AFR display
   - Ignition timing slider
   - Fuel table adjuster
   - Boost pressure control
   - Temperature gauge

3. **Performance Analytics**
   - 0-60 time
   - Top speed
   - Braking performance
   - Handling rating
   - Tire grip display

4. **Maintenance Schedule**
   - Next service due
   - Parts needing attention
   - Estimated repair costs
   - Service history

#### Implementation Files:
- fish_tunes/html/dashboard.html (NEW/UPDATED)
- fish_tunes/html/css/dashboard.css (NEW)
- fish_tunes/html/js/dashboard.js (NEW)

---

## 📊 Implementation Priority

### Tier 1 (Immediate)
- [ ] Dyno Tuning System
- [ ] NUI Dashboard

### Tier 2 (Short-term)
- [ ] Advanced Tire System
- [ ] Part Crafting System
- [ ] Performance Analytics

### Tier 3 (Medium-term)
- [ ] Drivetrain Modification
- [ ] Engine Swap System
- [ ] Advanced UI Features

---

## 🔧 Technical Considerations

### Performance Optimization
- Cache dyno calculations
- Batch database writes
- Optimize NUI updates
- Limit calculation frequency

### Database Impact
- Plan for increased data storage
- Implement archival strategy
- Optimize JSON size
- Consider database migration for large servers

### Network Optimization
- Use event throttling for frequent updates
- Compress data transfers
- Cache client-side where possible

---

## 📈 Testing Requirements

### Unit Testing
- [ ] AFR calculation accuracy
- [ ] Gear ratio calculations
- [ ] Degradation formula validation
- [ ] Crafting recipe success rates

### Integration Testing
- [ ] Dyno data persistence
- [ ] NUI responsiveness
- [ ] fish_hub marketplace integration
- [ ] fish_normalizer archetype updates

### Performance Testing
- [ ] Server load with many tuned vehicles
- [ ] NUI frame rate with complex calculations
- [ ] Database query performance
- [ ] Event processing speed

---

## 📝 Documentation Needed

1. **Dyno Tuning Guide** - How to tune AFR, timing, boost
2. **Performance Calculation Docs** - Formula explanation
3. **Part Crafting Tutorial** - Recipe creation and balancing
4. **API Reference** - All new exports and functions
5. **Troubleshooting Guide** - Common issues and solutions

---

## 🎮 Player Experience Flow

```
Player enters vehicle
    ↓
Health check notification
    ↓
Open dashboard (/tuning)
    ↓
View dyno data & health
    ↓
Adjust AFR/Timing if ECU installed
    ↓
Drive and accumulate mileage
    ↓
Parts degrade based on driving
    ↓
Maintenance notification at milestone
    ↓
Visit mechanic for repair/part swap
    ↓
Return to tuning dashboard
```

---

## 💾 Data Persistence Strategy

### Saving Points:
1. **On Vehicle Exit** - Save tuning and health
2. **On Mileage Milestone** - Save degradation state
3. **On Tuning Change** - Save new configuration
4. **On Part Replacement** - Update parts data
5. **Periodic Backup** - Auto-save every 5 minutes

---

## 🔗 Integration Checkpoints

### fish_normalizer
- [ ] Update archetype on drivetrain change
- [ ] Recalculate score based on parts health
- [ ] Update rank based on performance

### fish_hub
- [ ] Create repair service listings
- [ ] Add engine swap marketplace items
- [ ] List crafting materials
- [ ] Create maintenance packages

### fish_remaps
- [ ] Use AFR tuning in DNA inheritance
- [ ] Store tuning presets
- [ ] DNA affects crafting success

### fish_telemetry
- [ ] Log all tuning changes
- [ ] Track degradation events
- [ ] Record performance metrics
- [ ] Store maintenance history

---

## 🚀 Launch Checklist

- [ ] All code tested locally
- [ ] Configuration balanced
- [ ] Documentation complete
- [ ] NUI tested on multiple resolutions
- [ ] Database backup plan
- [ ] Rollback procedure documented
- [ ] Performance benchmarks passed
- [ ] Integration tests passed
- [ ] Player feedback process established
- [ ] Hotfix deployment ready

---

## 📞 Support Structure

### For Issues
1. Check IMPLEMENTATION_GUIDE_PHASE1.md
2. Review config.lua parameters
3. Check server console for errors
4. Verify fish_normalizer is running
5. Check database file permissions

### For Customization
- Modify degradation rates in config
- Adjust AFR ranges for difficulty
- Create new engine profiles
- Define custom crafting recipes

---

## 🎯 Success Criteria

✅ Phase 2 is successful when:
1. Dyno tuning accurately reflects AFR and performance
2. Players can perform all tuning operations
3. Degradation system provides meaningful gameplay
4. Performance analytics are accurate
5. NUI is responsive and intuitive
6. All integration points working smoothly
7. Server performance stable with large player counts
8. Data persistence reliable
9. Documentation is comprehensive
10. Community feedback is positive

---

**Phase 2 Planned Start**: After Phase 1 testing
**Estimated Duration**: 3-4 weeks
**Status**: 📋 Ready for Planning & Development
