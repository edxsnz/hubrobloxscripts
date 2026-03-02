-- Delay inicial para verificar se há troca de place
print("✅ Iniciando carregamento...")
task.wait(1)

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
local HUB_VERSION = "0.0.03"
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
-- Ordem importa: core primeiro, depois ui (que depende do core)
local sharedScripts = {
    "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source",
    "https://raw.githubusercontent.com/7yd7/Hub/refs/heads/Branch/GUIS/Emotes.lua",
    -- Clan Logger separado em core + ui
    "https://raw.githubusercontent.com/user404-hub/hubrobloxscripts/refs/heads/main/playerlogger_core.lua",
    "https://raw.githubusercontent.com/user404-hub/hubrobloxscripts/refs/heads/main/playerlogger_ui.lua",
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

-- Compatibilidade cross-executor: HTTP
local function httpGet(url)
    if syn and syn.request then
        local res = syn.request({Url=url, Method="GET"})
        return res and res.Body
    elseif http and http.request then
        local res = http.request({Url=url, Method="GET"})
        return res and res.Body
    elseif request then
        local res = request({Url=url, Method="GET"})
        return res and res.Body
    elseif game.HttpGet then
        return game:HttpGet(url)
    end
    return nil
end

-- Compatibilidade cross-executor: loadstring
local function getLoader()
    if syn and syn.loadstring then return syn.loadstring end
    if (typeof(potassium) == "table") and potassium.loadstring then return potassium.loadstring end
    if loadstring then return loadstring end
    if load then return load end
    return nil
end

-- runScript com opção de esperar conclusão (para scripts com dependência)
local function runScript(url, scriptNumber, totalScripts, scriptName, waitForDone)
    print("📦 Executando script " ..
        scriptNumber .. "/" .. totalScripts ..
        (scriptName and (" (" .. scriptName .. ")") or "") .. "...")

    local done = false
    local success, errorMsg = pcall(function()
        local content = httpGet(url)
        if not content or content == "" then error("HttpGet retornou vazio") end

        local loader = getLoader()
        if not loader then error("Nenhum loader disponível") end

        if waitForDone then
            -- executa na thread atual e espera terminar
            local func = loader(content)
            if func then
                local ok, execErr = pcall(func)
                if ok then
                    print("✅ Script concluído: " .. (scriptName or url))
                else
                    warn("❌ Erro dentro do script:", execErr)
                end
            else
                warn("❌ Falha ao compilar script")
            end
            done = true
        else
            task.spawn(function()
                local func = loader(content)
                if func then
                    local ok, execErr = pcall(func)
                    if ok then
                        print("✅ Script iniciado (thread separada)")
                    else
                        warn("❌ Erro dentro do script:", execErr)
                    end
                else
                    warn("❌ Falha ao compilar script: loader retornou nil")
                end
                done = true
            end)
        end
    end)

    if success then
        print("🟢 Loader enviado: " .. (scriptName or "script " .. scriptNumber))
    else
        warn("❌ Falha ao carregar script:", errorMsg)
    end

    if scriptNumber < totalScripts then task.wait(SCRIPT_DELAY) end
    return done
end

-- Banner de inicialização
local function showBanner()
    print("\n" .. string.rep("=", 50))
    print("🚀 GAME HUB (" .. HUB_VERSION .. ")")
    print("🎮 " .. getGameName(game.PlaceId))
    print("👤 " .. game.Players.LocalPlayer.Name)
    print("📅 " .. os.date("%H:%M:%S"))
    print(string.rep("=", 50))
end

showBanner()

-- Execução principal
local gameId = game.GameId
local scriptList, scriptType = {}, ""

local function inSharedGames(id)
    for _, v in ipairs(sharedGames) do
        if v == id then return true end
    end
    return false
end

if scripts[gameId] then
    scriptList = scripts[gameId]
    scriptType = "específicos"
elseif inSharedGames(gameId) then
    scriptList = sharedScripts
    scriptType = "compartilhados"
else
    scriptList = { "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source" }
    scriptType = "fallback"
end

local totalScripts = #scriptList
for i, url in ipairs(scriptList) do
    -- playerlogger_core precisa terminar antes de ui carregar
    local isCore = url:find("playerlogger_core")
    runScript(url, i, totalScripts, nil, isCore)
end

print("\n" .. string.rep("=", 50))
print("✅ " .. totalScripts .. " scripts " .. scriptType .. " injetados!")
print(string.rep("=", 50))
