-- Aguarda o jogo carregar
if not game:IsLoaded() then
    game.Loaded:Wait()
end

task.wait(10)

-- Configurações
local HUB_VERSION = "0.4"

-- Cores para as prints (RGB)
local colors = {
    cyan = Color3.fromRGB(0, 255, 255),
    green = Color3.fromRGB(0, 255, 128),
    yellow = Color3.fromRGB(255, 255, 0),
    orange = Color3.fromRGB(255, 165, 0),
    pink = Color3.fromRGB(255, 105, 180),
    white = Color3.fromRGB(255, 255, 255),
    blue = Color3.fromRGB(135, 206, 235)
}

-- Função para print colorido
local function cprint(text, color)
    rconsoleprint("@@")
    rconsoleprint(tostring(color.R * 255) .. "," .. tostring(color.G * 255) .. "," .. tostring(color.B * 255) .. "@@")
    rconsoleprint(text .. "\n")
    rconsoleprint("@@WHITE@@")
end

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
    local playerName = game.Players.LocalPlayer.Name
    
    rconsoleclear()
    cprint("╔══════════════════════════════════════════════╗", colors.cyan)
    cprint("║           🚀 GAME HUB v" .. HUB_VERSION .. "           ║", colors.cyan)
    cprint("╚══════════════════════════════════════════════╝", colors.cyan)
    cprint("", colors.white)
    cprint("  🎮  JOGO: " .. gameName, colors.green)
    cprint("  👤  PLAYER: " .. playerName, colors.yellow)
    cprint("  📅  HORA: " .. os.date("%H:%M:%S"), colors.blue)
    cprint("", colors.white)
    cprint("════════════════════════════════════════════════", colors.cyan)
    cprint("", colors.white)
end

-- Exibe o banner
showBanner()

-- Função para executar script com contador
local function runScript(url, scriptNumber, totalScripts)
    cprint("  📦 [" .. scriptNumber .. "/" .. totalScripts .. "] Baixando script...", colors.orange)
    local content = game:HttpGet(url)
    cprint("  ⚡ [" .. scriptNumber .. "/" .. totalScripts .. "] Executando...", colors.pink)
    loadstring(content)()
end

-- Executa scripts baseado no jogo
local gameId = game.GameId

if scripts[gameId] then
    cprint("🎯 Scripts específicos encontrados!", colors.green)
    local total = #scripts[gameId]
    for i, url in ipairs(scripts[gameId]) do
        pcall(runScript, url, i, total)
        task.wait(0.5)
    end
    
elseif table.find(sharedGames, gameId) then
    cprint("🔄 Carregando scripts compartilhados...", colors.yellow)
    local total = #sharedScripts
    for i, url in ipairs(sharedScripts) do
        pcall(runScript, url, i, total)
        task.wait(0.5)
    end
    
else
    cprint("⚠️ Jogo não suportado", colors.orange)
    cprint("🔄 Executando Infinite Yield...", colors.yellow)
    pcall(runScript, "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source", 1, 1)
end

-- Finalização colorida
cprint("", colors.white)
cprint("════════════════════════════════════════════════", colors.cyan)
cprint("✅  INJEÇÃO CONCLUÍDA COM SUCESSO!", colors.green)
cprint("🎮  Aproveite o jogo!", colors.blue)
cprint("════════════════════════════════════════════════", colors.cyan)

-- Finaliza o script
return