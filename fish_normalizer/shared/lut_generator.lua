-- ============================================================
-- fish_normalizer: Shared LUT Generator
-- Pré-computação determinística O(1) no heap compartilhado
-- Zero serialização IPC — acesso direto à memória
-- Executa síncrono no carregamento (ambos client e server)
-- 1001 iterações de math.exp são negligenciáveis em startup
-- ============================================================

-- Tabela global para acesso direto via PI_LUT[lowerBound]
-- (shared_scripts garantem mesmo heap client+server)
PI_LUT = {}

local m_exp = math.exp
local k = 0.003
for x = 0, 1000 do
    PI_LUT[x] = m_exp(-k * x)
end

print(('[fish_normalizer] LUT gerada: %d entradas, acesso O(1) direto à memória.'):format(#PI_LUT + 1))

-- Função exportável com clamp automático nos limites [0, 1000]
function GetPerformanceMultiplier(value)
    local idx = value < 0 and 0 or (value > 1000 and 1000 or math.floor(value))
    return PI_LUT[idx]
end