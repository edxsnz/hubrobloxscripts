-- Aguarda o jogo carregar
if not game:IsLoaded() then
    game.Loaded:Wait()
end

task.wait(10)

-- Configurações
local HUB_VERSION = "0.3"

-- Scripts por GAME ID
local scripts = {
    [994732206] = { -- Blox Fruits
        "https://raw.githubusercontent.com/debunked69/Solixreworkkeysystem/refs/heads/main/solix%20new%20keyui.lua"
    },
    [7671049560] = { -- The Forge
        "https://api.luarmor.net/files/v3/loaders/2529a5f9dfddd5523ca4e22f21cceffa.lua"
    },
    [7326934954] = { -- 99 Nights in the Forest
        "https://raw.githubusercontent.com/caomod2077/Script/refs/heads/main/FoxnameHub.lua"
    }
}

-- Jogos para scripts compartilhados
local sharedGames = {
    2355999843, -- Salon de Fiestas
    7513986953, -- Step Music  
    7907925158 -- Myster
}

-- Scripts compartilhados
local sharedScripts = {
    "https://raw.githubusercontent.com/7yd7/Hub/refs/heads/Branch/GUIS/Emotes.lua",
    "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"
}

-- Cache para nomes de jogos
local gameNameCache = {}

-- Função para obter o nome do jogo
local function getGameName(placeId)
    if gameNameCache[placeId] then
        return gameNameCache[placeId]
    end
    
    local success, result = pcall(function()
        return game:GetService("MarketplaceService"):GetProductInfo(placeId).Name
    end)
    
    if success then
        gameNameCache[placeId] = result
        return result
    end
    
    return "Unknown Game"
end

-- Banner de inicialização
local function showBanner()
    local gameName = getGameName(game.PlaceId)
    
    print("\n" .. string.rep("=", 50))
    print("🚀 GAME HUB (" .. HUB_VERSION .. ")")
    print("🎮 " .. gameName)
    print("👤 " .. game.Players.LocalPlayer.Name)
    print("📅 " .. os.date("%H:%M:%S"))
    print(string.rep("=", 50))
end

-- Exibe o banner
showBanner()

-- Função para executar script
local function runScript(url)
    local content = game:HttpGet(url)
    loadstring(content)()
end

-- Executa scripts baseado no jogo
local gameId = game.GameId

if scripts[gameId] then
    print("🎯 Executando scripts específicos...")
    for _, url in ipairs(scripts[gameId]) do
        pcall(runScript, url)
    end
elseif table.find(sharedGames, gameId) then
    print("🔄 Executando scripts compartilhados...")
    for _, url in ipairs(sharedScripts) do
        pcall(runScript, url)
    end
else
    print("⚠️ Jogo não suportado - Executando Infinite Yield...")
    -- Infinite Yield como fallback
    pcall(runScript, "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source")
end

-- Finaliza o script
print("✅ Scripts injetados com sucesso!")
return