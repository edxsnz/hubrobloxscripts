-- Aguarda o jogo carregar completamente
if not game:IsLoaded() then
    game.Loaded:Wait()
end

task.wait(1) -- segurança extra

-- Scripts por GAME ID (Universe)
local scripts = {
    [994732206] = "https://rawscripts.net/raw/Blox-Fruits-Atherhub-Auto-Level-Auto-Raid-Auto-Boss-BEST-Script-79550",
    [8321616508] = "https://rawscripts.net/raw/QOL-Rogue-Piece-BEST-SCRIPT-AUTO-FARM-AUTO-FISH-AUTO-SKILL-AUTO-ROLL-N-MORE-66148",
    [] = ""
}

-- Debug (opcional)
warn("GameId detectado:", game.GameId)

local url = scripts[game.GameId]

if url then
    warn("Script do jogo encontrado, carregando...")
    loadstring(game:HttpGet(url))()
else
    warn("Jogo não suportado, fallback executado")
    loadstring(game:HttpGet(
        "https://rawscripts.net/raw/Universal-Script-Infinite-Yield-modded-80479"
    ))()
end