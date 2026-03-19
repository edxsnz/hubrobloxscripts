-- Delay inicial para garantir que tudo carregou
task.wait(2)

print("⚙️ Carregando seletor do The Forge...")

-- Função para criar o menu de seleção do The Forge
local function createTheForgeMenu()
    local player = game:GetService("Players").LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    -- Scripts disponíveis para The Forge
    local forgeScripts = {
        minerar = "https://lumin-hub.lol/loader.lua",
        bosses = "https://rifton.top/loader.lua"
    }

    -- Criar a interface
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "TheForgeSelector"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Frame principal
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 400, 0, 250)
    frame.Position = UDim2.new(0.5, -200, 0.5, -125)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frame.BorderSizePixel = 0
    frame.BackgroundTransparency = 0.1
    frame.Active = true
    frame.Draggable = true
    frame.Parent = screenGui

    -- Cantos arredondados
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame

    -- Título
    local title = Instance.new("TextLabel")
    title.Text = "⚒️ THE FORGE - SELEÇÃO DE MODO"
    title.Size = UDim2.new(1, 0, 0, 50)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 20
    title.Parent = frame

    -- Descrição
    local desc = Instance.new("TextLabel")
    desc.Text = "Escolha qual script deseja executar:"
    desc.Size = UDim2.new(1, 0, 0, 30)
    desc.Position = UDim2.new(0, 0, 0, 50)
    desc.BackgroundTransparency = 1
    desc.TextColor3 = Color3.fromRGB(200, 200, 200)
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 16
    desc.Parent = frame

    -- Botão Modo Minerar
    local miningButton = Instance.new("TextButton")
    miningButton.Name = "MiningButton"
    miningButton.Text = "⛏️ MODO MINERAR\nFarm automático de minérios"
    miningButton.Size = UDim2.new(0.9, 0, 0, 60)
    miningButton.Position = UDim2.new(0.05, 0, 0, 100)
    miningButton.BackgroundColor3 = Color3.fromRGB(45, 80, 130)
    miningButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    miningButton.Font = Enum.Font.Gotham
    miningButton.TextSize = 14
    miningButton.TextWrapped = true
    Instance.new("UICorner", miningButton).CornerRadius = UDim.new(0, 8)
    miningButton.Parent = frame

    -- Botão Modo Bosses
    local bossButton = Instance.new("TextButton")
    bossButton.Name = "BossButton"
    bossButton.Text = "⚔️ MODO BOSSES\nFarm automático de bosses"
    bossButton.Size = UDim2.new(0.9, 0, 0, 60)
    bossButton.Position = UDim2.new(0.05, 0, 0, 170)
    bossButton.BackgroundColor3 = Color3.fromRGB(130, 45, 60)
    bossButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    bossButton.Font = Enum.Font.Gotham
    bossButton.TextSize = 14
    bossButton.TextWrapped = true
    Instance.new("UICorner", bossButton).CornerRadius = UDim.new(0, 8)
    bossButton.Parent = frame

    -- Efeito hover
    local TweenService = game:GetService("TweenService")

    local function createHoverEffect(button, normalColor, hoverColor)
        button.MouseEnter:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.2), { BackgroundColor3 = hoverColor }):Play()
        end)
        button.MouseLeave:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.2), { BackgroundColor3 = normalColor }):Play()
        end)
    end

    createHoverEffect(miningButton, Color3.fromRGB(45, 80, 130), Color3.fromRGB(60, 100, 160))
    createHoverEffect(bossButton, Color3.fromRGB(130, 45, 60), Color3.fromRGB(160, 60, 80))

    -- Decidir onde colocar a GUI (CoreGui, PlayerGui ou gethui)
    local parentGui = (gethui and gethui()) or game:GetService("CoreGui") or playerGui
    screenGui.Parent = parentGui

    -- Aguardar escolha do usuário (proteção contra duplo clique)
    local choiceMade = Instance.new("BindableEvent")
    local chosenUrl = ""
    local clicked = false

    miningButton.MouseButton1Click:Connect(function()
        if clicked then return end
        clicked = true
        chosenUrl = forgeScripts.minerar
        choiceMade:Fire("minerar")
    end)

    bossButton.MouseButton1Click:Connect(function()
        if clicked then return end
        clicked = true
        chosenUrl = forgeScripts.bosses
        choiceMade:Fire("bosses")
    end)

    local selectedMode = choiceMade.Event:Wait()
    choiceMade:Destroy()

    -- Animação de saída
    TweenService:Create(frame, TweenInfo.new(0.3), {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0)
    }):Play()

    task.wait(0.3)
    screenGui:Destroy()

    print("🎯 Modo selecionado: " .. selectedMode)

    -- Retornar o script escolhido
    return chosenUrl, selectedMode
end

-- Executar o seletor e carregar o script escolhido
local success, result = pcall(function()
    local scriptUrl, mode = createTheForgeMenu()

    if scriptUrl and scriptUrl ~= "" then
        print("📦 Carregando script do modo: " .. mode)

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

        -- Baixar e executar o script
        local content = httpGet(scriptUrl)
        if content and content ~= "" then
            local loader = getLoader()
            if loader then
                local func = loader(content)
                if func then
                    task.spawn(function()
                        local ok, err = pcall(func)
                        if ok then
                            print("✅ Script do The Forge executado com sucesso!")
                        else
                            warn("❌ Erro ao executar script do The Forge:", err)
                        end
                    end)
                else
                    warn("❌ Falha ao compilar script do The Forge")
                end
            else
                warn("❌ Nenhum loader disponível")
            end
        else
            warn("❌ Falha ao baixar script: " .. scriptUrl)
        end
    else
        warn("❌ Nenhum script selecionado")
    end
end)

if not success then
    warn("❌ Erro no carregamento do The Forge:", result)
end