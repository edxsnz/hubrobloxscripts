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
        task.wait(0.3) -- mais rápido que 0.5, sem impacto
    end

    print("✅ Jogo completamente carregado!")
    return true
end

waitForGameToFullyLoad()

-- Configurações
local HUB_VERSION = "0.1.11"
local SCRIPT_DELAY = 2

local scripts = {
    [994732206] = { -- Blox Fruits
        "https://raw.githubusercontent.com/debunked69/Solixreworkkeysystem/refs/heads/main/solix%20new%20keyui.lua"
    },
    [7326934954] = { -- 99 Nights in the Forest
        "https://raw.githubusercontent.com/caomod2077/Script/refs/heads/main/FoxnameHub.lua"
    },
    [7671049560] = { -- The Forge
        ["minerar"] = "https://lumin-hub.lol/loader.lua",
        ["bosses"] = "https://rifton.top/loader.lua"
    }
}

local sharedGames = {
    2355999843, -- Salon de Fiestas
    7513986953, -- Step Music  
    7907925158, -- Myster
    2977417782, -- Snow Party
    9090968990  -- Star Rave
}

local sharedScripts = {
    "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source",
    "https://raw.githubusercontent.com/7yd7/Hub/refs/heads/Branch/GUIS/Emotes.lua"
}

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

-- GUI The Forge
local function createSelectionGUI()
    local player = game:GetService("Players").LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "GameHubSelector"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 400, 0, 250)
    frame.Position = UDim2.new(0.5, -200, 0.5, -125)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frame.BorderSizePixel = 0
    frame.BackgroundTransparency = 0.1
    frame.Active = true
    frame.Draggable = true
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Text = "🎮 THE FORGE - ESCOLHA O MODO"
    title.Size = UDim2.new(1, 0, 0, 50)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 20
    title.Parent = frame

    local desc = Instance.new("TextLabel")
    desc.Text = "Escolha qual script deseja injetar:"
    desc.Size = UDim2.new(1, 0, 0, 30)
    desc.Position = UDim2.new(0, 0, 0, 50)
    desc.BackgroundTransparency = 1
    desc.TextColor3 = Color3.fromRGB(200, 200, 200)
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 16
    desc.Parent = frame

    local miningButton = Instance.new("TextButton")
    miningButton.Name = "MiningButton"
    miningButton.Text = "⛏️ MODO MINERAR\nUsar: https://lumin-hub.lol/loader.lua"
    miningButton.Size = UDim2.new(0.9, 0, 0, 60)
    miningButton.Position = UDim2.new(0.05, 0, 0, 100)
    miningButton.BackgroundColor3 = Color3.fromRGB(45, 80, 130)
    miningButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    miningButton.Font = Enum.Font.Gotham
    miningButton.TextSize = 14
    miningButton.TextWrapped = true
    Instance.new("UICorner", miningButton).CornerRadius = UDim.new(0, 8)
    miningButton.Parent = frame

    local bossButton = Instance.new("TextButton")
    bossButton.Name = "BossButton"
    bossButton.Text = "⚔️ MODO BOSSES\nUsar: https://rifton.top/loader.lua"
    bossButton.Size = UDim2.new(0.9, 0, 0, 60)
    bossButton.Position = UDim2.new(0.05, 0, 0, 170)
    bossButton.BackgroundColor3 = Color3.fromRGB(130, 45, 60)
    bossButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    bossButton.Font = Enum.Font.Gotham
    bossButton.TextSize = 14
    bossButton.TextWrapped = true
    Instance.new("UICorner", bossButton).CornerRadius = UDim.new(0, 8)
    bossButton.Parent = frame

    local function createHoverEffect(button, normalColor, hoverColor)
        local TweenService = game:GetService("TweenService")
        button.MouseEnter:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = hoverColor}):Play()
        end)
        button.MouseLeave:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = normalColor}):Play()
        end)
    end
    createHoverEffect(miningButton, Color3.fromRGB(45, 80, 130), Color3.fromRGB(60, 100, 160))
    createHoverEffect(bossButton, Color3.fromRGB(130, 45, 60), Color3.fromRGB(160, 60, 80))

    local parentGui = gethui and gethui() or game:GetService("CoreGui") or playerGui
    screenGui.Parent = parentGui

    local choiceMade = Instance.new("BindableEvent")
    local chosenUrl = ""
    miningButton.MouseButton1Click:Connect(function()
        chosenUrl = scripts[7671049560]["minerar"]
        choiceMade:Fire("minerar")
    end)
    bossButton.MouseButton1Click:Connect(function()
        chosenUrl = scripts[7671049560]["bosses"]
        choiceMade:Fire("bosses")
    end)

    local mode = choiceMade.Event:Wait()
    game:GetService("TweenService"):Create(frame, TweenInfo.new(0.3), {Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0.5, 0, 0.5, 0)}):Play()
    task.wait(0.3)
    screenGui:Destroy()
    return {chosenUrl}, mode
end

-- Função para executar script (Potassium)
local function runScript(url, scriptNumber, totalScripts, scriptName)
    print("📦 Executando script " .. scriptNumber .. "/" .. totalScripts .. (scriptName and (" (" .. scriptName .. ")") or "") .. "...")

    local success, errorMsg = pcall(function()
        local content = game:HttpGet(url)
        if not content or content == "" then error("HttpGet retornou vazio") end

        local loader = (potassium and potassium.loadstring) or loadstring or load
        if not loader then error("Nenhum loader disponível") end

        task.spawn(function()
            local ok, execErr = pcall(function() loader(content)() end)
            if ok then print("✅ Script iniciado com sucesso (thread separada)") 
            else warn("❌ Erro dentro do script:", execErr) end
        end)
    end)

    if success then print("🟢 Loader enviado para execução")
    else warn("❌ Falha ao carregar script:", errorMsg) end

    if scriptNumber < totalScripts then task.wait(SCRIPT_DELAY) end
end

-- Banner
local function showBanner()
    print("\n" .. string.rep("=", 50))
    print("🚀 GAME HUB (" .. HUB_VERSION .. ")")
    print("🎮 " .. getGameName(game.PlaceId))
    print("👤 " .. game.Players.LocalPlayer.Name)
    print("📅 " .. os.date("%H:%M:%S"))
    print(string.rep("=", 50))
end

showBanner()

-- Execução
local gameId = game.GameId
local scriptList, scriptType = {}, ""

if scripts[gameId] then
    if gameId == 7671049560 then
        print("🎯 The Forge detectado - Abrindo seletor...")
        scriptList, selectedMode = createSelectionGUI()
        scriptType = "específico (The Forge - Modo " .. selectedMode .. ")"
    else
        scriptList = scripts[gameId]
        scriptType = "específicos"
    end
elseif table.find(sharedGames, gameId) then
    scriptList = sharedScripts
    scriptType = "compartilhados"
else
    scriptList = {"https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"}
    scriptType = "fallback"
end

local totalScripts = #scriptList
for i, url in ipairs(scriptList) do
    local scriptName = (gameId == 7671049560) and selectedMode or nil
    runScript(url, i, totalScripts, scriptName)
end

print("\n" .. string.rep("=", 50))
print("✅ " .. totalScripts .. " scripts " .. scriptType .. " injetados com sucesso!")
print(string.rep("=", 50))