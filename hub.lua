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
local HUB_VERSION = "0.1.7"
local SCRIPT_DELAY = 2 -- Delay de 2 segundos entre scripts

-- Scripts por GAME ID
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

-- Jogos para scripts compartilhados
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

-- Função para criar GUI de escolha para The Forge
local function createSelectionGUI()
    local player = game:GetService("Players").LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    
    -- Cria a tela de fundo
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
    frame.Parent = screenGui -- 🔥 ESSENCIAL
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame
    
    -- Título
    local title = Instance.new("TextLabel")
    title.Text = "🎮 THE FORGE - ESCOLHA O MODO"
    title.Size = UDim2.new(1, 0, 0, 50)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 20
    title.Parent = frame
    
    -- Descrição
    local desc = Instance.new("TextLabel")
    desc.Text = "Escolha qual script deseja injetar:"
    desc.Size = UDim2.new(1, 0, 0, 30)
    desc.Position = UDim2.new(0, 0, 0, 50)
    desc.BackgroundTransparency = 1
    desc.TextColor3 = Color3.fromRGB(200, 200, 200)
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 16
    desc.Parent = frame
    
    -- Botão Minerar
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
    
    local miningCorner = Instance.new("UICorner")
    miningCorner.CornerRadius = UDim.new(0, 8)
    miningCorner.Parent = miningButton
    
    miningButton.Parent = frame
    
    -- Botão Bosses
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
    
    local bossCorner = Instance.new("UICorner")
    bossCorner.CornerRadius = UDim.new(0, 8)
    bossCorner.Parent = bossButton
    
    bossButton.Parent = frame
    
    -- Adiciona efeitos de hover
    local function createHoverEffect(button, normalColor, hoverColor)
        button.MouseEnter:Connect(function()
            game:GetService("TweenService"):Create(
                button,
                TweenInfo.new(0.2),
                {BackgroundColor3 = hoverColor}
            ):Play()
        end)
        
        button.MouseLeave:Connect(function()
            game:GetService("TweenService"):Create(
                button,
                TweenInfo.new(0.2),
                {BackgroundColor3 = normalColor}
            ):Play()
        end)
    end
    
    createHoverEffect(miningButton, Color3.fromRGB(45, 80, 130), Color3.fromRGB(60, 100, 160))
    createHoverEffect(bossButton, Color3.fromRGB(130, 45, 60), Color3.fromRGB(160, 60, 80))
    
local parentGui =
    (gethui and gethui())
    or game:GetService("CoreGui")
    or playerGui

screenGui.Parent = parentGui
    
    -- Retorna uma promise para aguardar a escolha
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
    
print("🧪 GUI criada, aguardando escolha do usuário...")

    -- Aguarda a escolha
    local mode = choiceMade.Event:Wait()
    
    -- Animação de fechamento
    game:GetService("TweenService"):Create(
        frame,
        TweenInfo.new(0.3),
        {Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0.5, 0, 0.5, 0)}
    ):Play()
    
    task.wait(0.3)
    screenGui:Destroy()
    
    return {chosenUrl}, mode
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
local function runScript(url, scriptNumber, totalScripts, scriptName)
    if scriptName then
        print("📦 Executando script " .. scriptNumber .. "/" .. totalScripts .. " (" .. scriptName .. ")...")
    else
        print("📦 Executando script " .. scriptNumber .. "/" .. totalScripts .. "...")
    end

    local success, errorMsg = pcall(function()
        local content = game:HttpGet(url)

        if not content or content == "" then
            error("HttpGet retornou vazio")
        end

        local loader = loadstring or load
        if not loader then
            error("loadstring não está disponível neste executor")
        end

        loader(content)()
    end)

    if success then
        print("✅ Script executado com sucesso!")
    else
        warn("❌ Falha ao executar script:", errorMsg)
    end

    if scriptNumber < totalScripts then
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
    if gameId == 7671049560 then -- The Forge
        print("🎯 The Forge detectado - Abrindo seletor...")
        scriptList, selectedMode = createSelectionGUI()
        scriptType = "específico (The Forge - Modo " .. selectedMode .. ")"
    else
        -- Outros jogos com scripts normais
        scriptList = scripts[gameId]
        scriptType = "específicos"
    end
    print("🎯 Executando scripts " .. scriptType .. "...")
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
    local scriptName = nil
    if gameId == 7671049560 then
        scriptName = selectedMode
    end
    runScript(url, i, totalScripts, scriptName)
end

-- Finaliza o script
print("\n" .. string.rep("=", 50))
print("✅ " .. totalScripts .. " scripts " .. scriptType .. " injetados com sucesso!")
print(string.rep("=", 50))