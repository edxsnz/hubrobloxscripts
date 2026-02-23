-- Delay inicial para verificar se há troca de place
print("✅ Iniciando carregamento...")
task.wait(10)

-- Função avançada de espera por carregamento completo
local function waitForGameToFullyLoad()
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end

    local players = game:GetService("Players")
    local player = players.LocalPlayer or players.PlayerAdded:Wait()

    if not player.Character then
        player.CharacterAdded:Wait()
    end

    local playerGui = player:WaitForChild("PlayerGui")
    while #playerGui:GetChildren() == 0 do
        task.wait(0.3)
    end

    print("✅ Jogo completamente carregado!")
    return true
end

waitForGameToFullyLoad()

-- Configurações
local HUB_VERSION = "0.1.18"
local SCRIPT_DELAY = 2

-- SCRIPTS POR JOGO (IDs numéricos)
local scripts = {
    [994732206] = { -- Blox Fruits
        "https://raw.githubusercontent.com/debunked69/Solixreworkkeysystem/refs/heads/main/solix%20new%20keyui.lua"
    },
    [7326934954] = { -- 99 Nights in the Forest
        "https://raw.githubusercontent.com/caomod2077/Script/refs/heads/main/FoxnameHub.lua"
    },
    [7671049560] = { -- The Forge
      --"https://raw.githubusercontent.com/user404-hub/hubrobloxscripts/refs/heads/main/theforge.lua"
        "https://lumin-hub.lol/loader.lua" 
    }
}

-- Jogos que compartilham os mesmos scripts
local sharedGames = {
    2355999843, -- Salon de Fiestas
    7513986953, -- Step Music  
    7907925158, -- Myster
    2977417782, -- Snow Party
    9090968990  -- Star Rave
}

-- Scripts compartilhados
local sharedScripts = {
    "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source",
    "https://raw.githubusercontent.com/7yd7/Hub/refs/heads/Branch/GUIS/Emotes.lua"
    "https://raw.githubusercontent.com/user404-hub/hubrobloxscripts/refs/heads/main/playerlogger.lua"
}

-- Cache para nomes dos jogos
local gameNameCache = {}
local function getGameName(placeId)
    if gameNameCache[placeId] then return gameNameCache[placeId] end
    local success, result = pcall(function()
        return game:GetService("MarketplaceService"):GetProductInfo(placeId).Name
    end)
    if success then
        gameNameCache[placeId] = result
        return result
    end
    return "Unknown Game"
end

-- Função para executar script (compatível com Potassium/executores)
local function runScript(url, scriptNumber, totalScripts, scriptName)
    print("📦 Executando script " .. scriptNumber .. "/" .. totalScripts .. (scriptName and (" (" .. scriptName .. ")") or "") .. "...")

    local success, errorMsg = pcall(function()
        local content = game:HttpGet(url)
        if not content or content == "" then error("HttpGet retornou vazio") end

        local loader = (potassium and potassium.loadstring) or loadstring or load
        if not loader then error("Nenhum loader disponível") end

        task.spawn(function()
            local func = loader(content)
            if func then
                local ok, execErr = pcall(func)
                if ok then
                    print("✅ Script iniciado com sucesso (thread separada)")
                else
                    warn("❌ Erro dentro do script:", execErr)
                end
            else
                warn("❌ Falha ao compilar script: loader retornou nil")
            end
        end)
    end)

    if success then print("🟢 Loader enviado para execução")
    else warn("❌ Falha ao carregar script:", errorMsg) end

    if scriptNumber < totalScripts then task.wait(SCRIPT_DELAY) end
end

-- Banner de inicialização
local function showBanner()
    print("\n" .. string.rep("=", 50))
    print("🚀 GAME HUB (" .. HUB_VERSION .. ")")
    print("🎮 " .. getGameName(game.placeId))
    print("👤 " .. game.Players.LocalPlayer.Name)
    print("📅 " .. os.date("%H:%M:%S"))
    print(string.rep("=", 50))
end

showBanner()

-- Execução principal
local gameId = game.GameId
local scriptList, scriptType = {}, ""

if scripts[gameId] then
    scriptList = scripts[gameId]
    scriptType = "específicos"
elseif table.find(sharedGames, gameId) then
    scriptList = sharedScripts
    scriptType = "compartilhados"
else
    scriptList = {"https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"}
    scriptType = "fallback"
end

local totalScripts = #scriptList
for i, url in ipairs(scriptList) do
    runScript(url, i, totalScripts, nil)
end

print("\n" .. string.rep("=", 50))
print("✅ " .. totalScripts .. " scripts " .. scriptType .. " injetados com sucesso!")
print(string.rep("=", 50))