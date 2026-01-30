-- Delay inicial para verificar se há troca de place
print("⏳ Aguardando 10 segundos para verificar possível troca de place...")
task.wait(10)
print("✅ Iniciando carregamento...")

-- Função avançada de espera por carregamento completo
local function waitForGameToFullyLoad()
    print("🔄 Aguardando carregamento completo do jogo...")
    
    -- 1. Espera pelo Loaded básico
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end
    print("✓ Fase 1/4: Jogo básico carregado")
    
    -- 2. Espera pelo player local
    local players = game:GetService("Players")
    while not players.LocalPlayer do
        players.PlayerAdded:Wait()
    end
    local player = players.LocalPlayer
    print("✓ Fase 2/4: Player local carregado")
    
    -- 3. Espera pelo character
    if not player.Character then
        player.CharacterAdded:Wait()
    end
    print("✓ Fase 3/4: Character carregado")
    
    -- 4. Espera pela interface do jogador
    local playerGui = player:WaitForChild("PlayerGui")
    if #playerGui:GetChildren() == 0 then
        repeat
            task.wait(0.5)
        until #playerGui:GetChildren() > 0
    end
    print("✓ Fase 4/4: Interface carregada")
    
    -- 5. Espera adicional para scripts de inicialização
    task.wait(2)
    
    print("✅ Jogo completamente carregado!")
    return true
end

-- Usa a função para aguardar carregamento completo
waitForGameToFullyLoad()

-- Configurações
local HUB_VERSION = "0.7"
local SCRIPT_DELAY = 1 -- Delay de 1 segundo entre scripts

-- Scripts por GAME ID
local scripts = {
    [994732206] = { -- Blox Fruits
        "https://raw.githubusercontent.com/debunked69/Solixreworkkeysystem/refs/heads/main/solix%20new%20keyui.lua"
    },
    [7326934954] = { -- 99 Nights in the Forest
        "https://raw.githubusercontent.com/caomod2077/Script/refs/heads/main/FoxnameHub.lua"
    },
    [7671049560] = { -- The Forge
        "https://api.luarmor.net/files/v3/loaders/2529a5f9dfddd5523ca4e22f21cceffa.lua"
    }
}

-- Jogos para scripts compartilhados
local sharedGames = {
    2355999843, -- Salon de Fiestas
    7513986953, -- Step Music  
    7907925158, -- Myster
    2977417782 -- Snow Party
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

-- Função para executar script com feedback
local function runScript(url, scriptNumber, totalScripts)
    print("📦 Executando script " .. scriptNumber .. "/" .. totalScripts .. "...")
    
    local success, errorMsg = pcall(function()
        local content = game:HttpGet(url)
        loadstring(content)()
    end)
    
    if success then
        print("✅ Script " .. scriptNumber .. "/" .. totalScripts .. " executado!")
    else
        print("❌ Erro no script " .. scriptNumber .. "/" .. totalScripts .. ": " .. errorMsg)
    end
    
    -- Delay entre scripts
    if scriptNumber < totalScripts then
        print("⏳ Aguardando " .. SCRIPT_DELAY .. " segundos...")
        task.wait(SCRIPT_DELAY)
    end
end

-- Exibe o banner
showBanner()

-- Executa scripts baseado no jogo
local gameId = game.GameId
local scriptList = {}
local scriptType = ""

if scripts[gameId] then
    scriptList = scripts[gameId]
    scriptType = "específicos"
    print("🎯 Executando scripts específicos...")
elseif table.find(sharedGames, gameId) then
    scriptList = sharedScripts
    scriptType = "compartilhados"
    print("🔄 Executando scripts compartilhados...")
else
    scriptList = {"https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"}
    scriptType = "fallback"
    print("⚠️ Jogo não suportado - Executando Infinite Yield...")
end

-- Executa cada script com delay
local totalScripts = #scriptList
print("📊 Total de scripts a executar: " .. totalScripts)

for i, url in ipairs(scriptList) do
    runScript(url, i, totalScripts)
end

-- Finaliza o script
print("\n" .. string.rep("=", 50))
print("✅ " .. totalScripts .. " scripts " .. scriptType .. " injetados com sucesso!")
print(string.rep("=", 50))