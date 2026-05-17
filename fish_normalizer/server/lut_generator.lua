-- ============================================================
-- fish_normalizer: Server-Side Lookup Table (LUT) Generator
-- Memoizes exponential damping multipliers to guarantee O(1) PI score calculations
-- ============================================================

PI_LUT = {}

local function GenerateLUT()
    -- Perfectly calibrated exponential damping decay coefficient
    -- Closer to 1000 PI (Class X limit), the harder it is to gain PI
    local k = 0.003
    for x = 0, 1000 do
        PI_LUT[x] = math.exp(-k * x)
    end
    print(("[fish_normalizer] Contiguous Lookup Table (PI_LUT) generated successfully (%d entries, %.2f KB memory)"):format(#PI_LUT + 1, (#PI_LUT + 1) * 8 / 1024))
end

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        GenerateLUT()
    end
end)

-- Initialize immediately on load so the global table is available prior to main execution
GenerateLUT()
