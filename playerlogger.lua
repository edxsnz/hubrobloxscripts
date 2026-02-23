-- ╔══════════════════════════════════════════════════════════════╗
-- ║           CSI Member Logger  v3.0  —  Potassium             ║
-- ║    AutoStart · AutoStop · Retomada · Livre · Auto-Save      ║
-- ╚══════════════════════════════════════════════════════════════╝

local Players   = game:GetService("Players")
local MktSvc    = game:GetService("MarketplaceService")

-- ══════════════════════════════════════════════════════════════
--  CONFIGURAÇÕES GLOBAIS
-- ══════════════════════════════════════════════════════════════
local CFG = {
    PREFIX      = "CSI_",       -- prefixo monitorado (case-insensitive)
    LOG_FOLDER  = "CSI_Logs",   -- pasta de saída
    AUTOSAVE_IV = 30,           -- intervalo de auto-save em segundos
}

-- ══════════════════════════════════════════════════════════════
--  HELPERS DE DATA/HORA  (usa relógio LOCAL do PC)
-- ══════════════════════════════════════════════════════════════
local function dateOnly()   return os.date("%d-%m-%Y")          end
local function timeOnly()   return os.date("%H:%M:%S")          end
local function nowH()       return tonumber(os.date("%H"))      end
local function nowM()       return tonumber(os.date("%M"))      end
local function nowS()       return tonumber(os.date("%S"))      end

-- ══════════════════════════════════════════════════════════════
--  ESTADO GLOBAL
-- ══════════════════════════════════════════════════════════════
local isRecording       = false
local loggedPlayers     = {}   -- [userId(number)] = { name, time, idx }
local totalLogged       = 0
local recStart          = nil  -- tick() do início
local playerAddedConn   = nil

-- Agendamento
local autoEnabled       = false
local autoStartH, autoStartM = 21, 0
local autoStopH,  autoStopM  = 22, 0
local autoStartFired    = false
local autoStopFired     = false

-- Arquivo ativo
local fileName          = ""

-- Nome do jogo (cache)
local gameName = "N/A"
pcall(function() gameName = MktSvc:GetProductInfo(game.PlaceId).Name end)

-- ══════════════════════════════════════════════════════════════
--  SISTEMA DE ARQUIVO
-- ══════════════════════════════════════════════════════════════

local function ensureFolder()
    pcall(function()
        if not isfolder(CFG.LOG_FOLDER) then makefolder(CFG.LOG_FOLDER) end
    end)
end

-- Retorna o nome canônico do arquivo para HOJE (1 arquivo por dia)
local function todayFileName()
    return CFG.LOG_FOLDER .. "/CSI_LOG_" .. dateOnly() .. ".txt"
end

-- Lê arquivo com segurança
local function safeRead(path)
    local ok, data = pcall(readfile, path)
    return (ok and data) or nil
end

-- Escreve arquivo com segurança
local function safeWrite(path, content)
    pcall(writefile, path, content)
end

-- ══════════════════════════════════════════════════════════════
--  PARSER — lê arquivo existente e extrai membros já salvos
-- ══════════════════════════════════════════════════════════════
local function parseExistingFile(content)
    local players = {}
    local idx = 0
    -- formato: [HH:MM:SS] | Nome                         | UserId
    for line in content:gmatch("[^\n]+") do
        local t, name, uid = line:match("^%[(%d+:%d+:%d+)%] | (.-) | (%d+)%s*$")
        if t and name and uid then
            local id = tonumber(uid)
            if id then
                idx = idx + 1
                players[id] = {
                    name = name:match("^%s*(.-)%s*$"),
                    time = t,
                    idx  = idx
                }
            end
        end
    end
    return players, idx
end

-- Extrai configs salvas do cabeçalho (AutoStart / AutoStop)
local function parseConfig(content)
    local cfg = {}
    local sh, sm = content:match("AutoStart%s*:%s*(%d+):(%d+)")
    local eh, em = content:match("AutoStop%s*:%s*(%d+):(%d+)")
    if sh then cfg.startH = tonumber(sh); cfg.startM = tonumber(sm) or 0 end
    if eh then cfg.stopH  = tonumber(eh); cfg.stopM  = tonumber(em) or 0 end
    return cfg
end

-- ══════════════════════════════════════════════════════════════
--  GERAÇÃO DO CONTEÚDO COMPLETO DO ARQUIVO
--  O arquivo é REESCRITO inteiro a cada save, garantindo que o
--  rodapé esteja sempre atualizado mesmo sem fechar direito.
-- ══════════════════════════════════════════════════════════════
local function buildFileContent(isFinal)
    local lines = {}
    local function w(s) lines[#lines+1] = s end

    w(string.rep("═", 58))
    w("  CSI MEMBER LOGGER — REGISTRO DE INVASÃO")
    w(string.rep("═", 58))
    w("Data           : " .. dateOnly())
    w("Jogo           : " .. gameName)
    w("Place ID       : " .. tostring(game.PlaceId))
    w("Prefixo        : " .. CFG.PREFIX)
    w(string.format("AutoStart      : %02d:%02d", autoStartH, autoStartM))
    w(string.format("AutoStop       : %02d:%02d", autoStopH,  autoStopM))
    w(string.rep("─", 58))
    w(string.format("%-12s | %-28s | %s", "[HORA]", "[USUÁRIO]", "[USER ID]"))
    w(string.rep("─", 58))

    -- Ordena por ordem de chegada (campo idx)
    local ordered = {}
    for uid, info in pairs(loggedPlayers) do
        ordered[#ordered+1] = { uid=uid, name=info.name, time=info.time, idx=info.idx or 0 }
    end
    table.sort(ordered, function(a,b) return a.idx < b.idx end)

    for _, entry in ipairs(ordered) do
        w(string.format("[%s] | %-28s | %s",
            entry.time, entry.name, tostring(entry.uid)))
    end

    w(string.rep("─", 58))
    if isFinal then
        w("STATUS         : ✔ GRAVAÇÃO FINALIZADA")
    else
        w("STATUS         : ⏺ GRAVANDO... (auto-save " .. timeOnly() .. ")")
    end
    if recStart then
        local elapsed = math.floor(tick() - recStart)
        w(string.format("Duração        : %02d:%02d", math.floor(elapsed/60), elapsed%60))
    end
    w("Fim            : " .. (isFinal and timeOnly() or "--"))
    w("Total logados  : " .. totalLogged .. " membro(s) " .. CFG.PREFIX)
    w(string.rep("═", 58))

    return table.concat(lines, "\n") .. "\n"
end

local function saveFile(isFinal)
    safeWrite(fileName, buildFileContent(isFinal))
end

-- ══════════════════════════════════════════════════════════════
--  LÓGICA DE GRAVAÇÃO
-- ══════════════════════════════════════════════════════════════
local function logPlayer(player)
    if not isRecording then return end
    if loggedPlayers[player.UserId] then return end  -- sem duplicatas

    totalLogged = totalLogged + 1
    loggedPlayers[player.UserId] = {
        name = player.DisplayName,
        time = timeOnly(),
        idx  = totalLogged,
    }
    print(string.format("[CSI Logger] ✓ #%d — %s (ID: %d)",
        totalLogged, player.DisplayName, player.UserId))
    saveFile(false)  -- grava imediatamente a cada novo membro
end

local function checkPlayer(player)
    if player.DisplayName:sub(1, #CFG.PREFIX):upper() == CFG.PREFIX:upper() then
        logPlayer(player)
    end
end

-- Referências de UI (forward declarations)
local UI = {}

local function updateUI()
    if UI.status then
        if isRecording then
            local elapsed = recStart and math.floor(tick() - recStart) or 0
            UI.status.Text = string.format("🔴 Gravando... %02d:%02d",
                math.floor(elapsed/60), elapsed%60)
            UI.status.TextColor3 = Color3.fromRGB(255, 80, 80)
        end
    end
    if UI.count then
        UI.count.Text = "📋 Logados: " .. totalLogged
    end
    if UI.fileLabel then
        UI.fileLabel.Text = "📁 " .. (fileName ~= "" and fileName or "--")
    end
end

-- ──────────────────────────────────────────────────────────────
--  startRecording — com retomada inteligente de sessão do dia
-- ──────────────────────────────────────────────────────────────
local function startRecording()
    if isRecording then return end

    ensureFolder()
    fileName = todayFileName()  -- sempre o arquivo do DIA

    local existing = safeRead(fileName)

    if existing and #existing > 0 then
        -- ── RETOMADA: arquivo do dia já existe ──
        local saved, count = parseExistingFile(existing)
        loggedPlayers = saved
        totalLogged   = count
        print(string.format("[CSI Logger] 🔄 Retomando — %d membro(s) já registrado(s).", count))
        if UI.schedInfo then
            UI.schedInfo.Text = string.format("🔄 Sessão retomada!\n%d membro(s) já estavam salvos.", count)
            UI.schedInfo.TextColor3 = Color3.fromRGB(100, 220, 255)
        end
    else
        -- ── NOVA SESSÃO ──
        loggedPlayers = {}
        totalLogged   = 0
        if UI.schedInfo and not autoEnabled then
            UI.schedInfo.Text = "▶ Nova sessão iniciada!"
            UI.schedInfo.TextColor3 = Color3.fromRGB(100,255,150)
        end
    end

    isRecording = true
    recStart    = tick()

    -- ★ Loga TODOS os CSI_ que já estão no servidor neste momento
    for _, p in ipairs(Players:GetPlayers()) do
        checkPlayer(p)
    end

    -- Monitora chegadas futuras em tempo real
    playerAddedConn = Players.PlayerAdded:Connect(function(p)
        task.wait(0.3)  -- aguarda nome carregar
        checkPlayer(p)
        updateUI()
    end)

    saveFile(false)

    -- Atualiza UI
    if UI.recBtn then
        UI.recBtn.Text             = "⏹  PARAR GRAVAÇÃO"
        UI.recBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    end
    updateUI()
end

-- ──────────────────────────────────────────────────────────────
--  stopRecording
-- ──────────────────────────────────────────────────────────────
local function stopRecording()
    if not isRecording then return end
    isRecording = false

    if playerAddedConn then
        playerAddedConn:Disconnect()
        playerAddedConn = nil
    end

    saveFile(true)   -- rodapé final com STATUS: FINALIZADA

    if UI.recBtn then
        UI.recBtn.Text             = "⏺  INICIAR GRAVAÇÃO"
        UI.recBtn.BackgroundColor3 = Color3.fromRGB(35, 165, 70)
    end
    if UI.status then
        UI.status.Text       = string.format("✅ Finalizado! %d membro(s) registrado(s).", totalLogged)
        UI.status.TextColor3 = Color3.fromRGB(100, 255, 100)
    end
    print(string.format("[CSI Logger] ⏹ Parado. Total: %d | Arquivo: %s", totalLogged, fileName))
end

-- ══════════════════════════════════════════════════════════════
--  GUI
-- ══════════════════════════════════════════════════════════════

-- Remove instância anterior (caso reinjeção)
local prev = game:GetService("CoreGui"):FindFirstChild("CSILoggerV3")
if prev then prev:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "CSILoggerV3"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent         = game:GetService("CoreGui")

-- ── Helpers de UI ──────────────────────────────────────────
local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
end
local function stroke(p, col, th)
    local s = Instance.new("UIStroke")
    s.Color     = col or Color3.fromRGB(80,120,255)
    s.Thickness = th  or 1.5
    s.Parent    = p
end
local function lbl(parent, pos, size, text, ts, col, font, ax)
    local l = Instance.new("TextLabel")
    l.Position          = pos
    l.Size              = size
    l.BackgroundTransparency = 1
    l.Text              = text
    l.TextSize          = ts   or 12
    l.TextColor3        = col  or Color3.fromRGB(210,210,210)
    l.Font              = font or Enum.Font.Gotham
    l.TextXAlignment    = ax   or Enum.TextXAlignment.Left
    l.TextWrapped       = true
    l.Parent            = parent
    return l
end
local function mkbtn(parent, pos, size, text, bg, ts)
    local b = Instance.new("TextButton")
    b.Position         = pos
    b.Size             = size
    b.BackgroundColor3 = bg or Color3.fromRGB(60,60,90)
    b.Text             = text
    b.TextColor3       = Color3.fromRGB(255,255,255)
    b.TextSize         = ts or 13
    b.Font             = Enum.Font.GothamBold
    b.BorderSizePixel  = 0
    b.Parent           = parent
    corner(b, 7)
    return b
end
local function mkbox(parent, pos, size, def)
    local b = Instance.new("TextBox")
    b.Position         = pos
    b.Size             = size
    b.BackgroundColor3 = Color3.fromRGB(20,20,36)
    b.Text             = def or ""
    b.TextColor3       = Color3.fromRGB(255,255,255)
    b.TextSize         = 15
    b.Font             = Enum.Font.GothamBold
    b.BorderSizePixel  = 0
    b.ClearTextOnFocus = false
    b.TextXAlignment   = Enum.TextXAlignment.Center
    b.Parent           = parent
    corner(b, 6)
    stroke(b, Color3.fromRGB(70,80,140), 1)
    return b
end
local function divider(parent, y)
    local d = Instance.new("Frame")
    d.Size             = UDim2.new(1,-24,0,1)
    d.Position         = UDim2.new(0,12,0,y)
    d.BackgroundColor3 = Color3.fromRGB(40,40,70)
    d.BorderSizePixel  = 0
    d.Parent           = parent
end

-- ── Janela principal ────────────────────────────────────────
local WW, WH = 350, 480

local Main = Instance.new("Frame")
Main.Name             = "Main"
Main.Size             = UDim2.new(0,WW,0,WH)
Main.Position         = UDim2.new(0.5,-WW/2, 0.5,-WH/2)
Main.BackgroundColor3 = Color3.fromRGB(11,11,20)
Main.BorderSizePixel  = 0
Main.Active           = true
Main.Draggable        = true
Main.Parent           = ScreenGui
corner(Main, 12)
stroke(Main, Color3.fromRGB(55,95,230), 2)

-- Gradiente de fundo
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(16,16,32)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10,10,18)),
}
grad.Rotation = 135
grad.Parent   = Main

-- ── Barra de título ─────────────────────────────────────────
local TBar = Instance.new("Frame")
TBar.Size             = UDim2.new(1,0,0,44)
TBar.BackgroundColor3 = Color3.fromRGB(18,18,38)
TBar.BorderSizePixel  = 0
TBar.Parent           = Main
corner(TBar, 12)

lbl(TBar, UDim2.new(0,14,0,0), UDim2.new(1,-50,1,0),
    "⬡  CSI Member Logger  v3.0", 14,
    Color3.fromRGB(255,255,255), Enum.Font.GothamBold)

local xBtn = Instance.new("TextButton")
xBtn.Size             = UDim2.new(0,26,0,26)
xBtn.Position         = UDim2.new(1,-34,0,9)
xBtn.BackgroundColor3 = Color3.fromRGB(160,35,35)
xBtn.Text             = "✕"
xBtn.TextColor3       = Color3.fromRGB(255,255,255)
xBtn.TextSize         = 12
xBtn.Font             = Enum.Font.GothamBold
xBtn.BorderSizePixel  = 0
xBtn.Parent           = TBar
corner(xBtn, 6)

-- ── Info principal ───────────────────────────────────────────
UI.status = lbl(Main, UDim2.new(0,14,0,52), UDim2.new(1,-28,0,20),
    "⚪ Aguardando...", 13, Color3.fromRGB(180,180,180), Enum.Font.Gotham)

UI.count = lbl(Main, UDim2.new(0,14,0,74), UDim2.new(0,170,0,18),
    "📋 Logados: 0", 12, Color3.fromRGB(160,255,160))

UI.clock = lbl(Main, UDim2.new(1,-155,0,74), UDim2.new(0,141,0,18),
    "🕐 --:--:--", 12, Color3.fromRGB(130,190,255),
    Enum.Font.GothamBold, Enum.TextXAlignment.Right)

UI.fileLabel = lbl(Main, UDim2.new(0,14,0,94), UDim2.new(1,-28,0,18),
    "📁 --", 10, Color3.fromRGB(220,190,70))

divider(Main, 120)

-- ── Botão gravar ─────────────────────────────────────────────
UI.recBtn = mkbtn(Main,
    UDim2.new(0,12,0,128), UDim2.new(1,-24,0,42),
    "⏺  INICIAR GRAVAÇÃO", Color3.fromRGB(35,165,70), 14)

-- ── Seção Agendamento ────────────────────────────────────────
divider(Main, 182)

lbl(Main, UDim2.new(0,14,0,190), UDim2.new(1,-28,0,20),
    "⏰  AGENDAMENTO AUTOMÁTICO", 12,
    Color3.fromRGB(255,200,70), Enum.Font.GothamBold)

-- Rótulos
lbl(Main, UDim2.new(0,14,0,214), UDim2.new(0,145,0,15),
    "▶  INÍCIO  ( HH : MM )", 10, Color3.fromRGB(130,210,130))
lbl(Main, UDim2.new(0,187,0,214), UDim2.new(0,145,0,15),
    "⏹  FIM  ( HH : MM )", 10, Color3.fromRGB(210,130,130))

-- Boxes início
local sH = mkbox(Main, UDim2.new(0,14, 0,232), UDim2.new(0,56,0,32), "21")
lbl(Main, UDim2.new(0,74,0,232), UDim2.new(0,16,0,32),
    ":", 18, Color3.fromRGB(255,255,255), Enum.Font.GothamBold, Enum.TextXAlignment.Center)
local sM = mkbox(Main, UDim2.new(0,94, 0,232), UDim2.new(0,56,0,32), "00")

-- Boxes fim
local eH = mkbox(Main, UDim2.new(0,187,0,232), UDim2.new(0,56,0,32), "22")
lbl(Main, UDim2.new(0,247,0,232), UDim2.new(0,16,0,32),
    ":", 18, Color3.fromRGB(255,255,255), Enum.Font.GothamBold, Enum.TextXAlignment.Center)
local eM = mkbox(Main, UDim2.new(0,267,0,232), UDim2.new(0,56,0,32), "00")

-- Botão ativar agendamento
UI.autoBtn = mkbtn(Main,
    UDim2.new(0,12,0,274), UDim2.new(1,-24,0,34),
    "📅  ATIVAR AGENDAMENTO", Color3.fromRGB(55,85,200))

-- Info / feedback do agendamento
UI.schedInfo = lbl(Main, UDim2.new(0,14,0,316), UDim2.new(1,-28,0,36),
    "", 11, Color3.fromRGB(180,180,180))
UI.schedInfo.TextXAlignment = Enum.TextXAlignment.Center

divider(Main, 360)

-- ── Modo livre ───────────────────────────────────────────────
lbl(Main, UDim2.new(0,14,0,368), UDim2.new(1,-28,0,18),
    "🔓  MODO LIVRE", 11, Color3.fromRGB(150,150,210), Enum.Font.GothamBold)
lbl(Main, UDim2.new(0,14,0,386), UDim2.new(1,-28,0,28),
    "Clique em ⏺ INICIAR acima para gravar\nlivremente, sem horário definido.", 10,
    Color3.fromRGB(120,120,170))

divider(Main, 422)

local closeBtn = mkbtn(Main,
    UDim2.new(0,12,0,430), UDim2.new(1,-24,0,32),
    "✖  Fechar", Color3.fromRGB(44,44,66))

-- ══════════════════════════════════════════════════════════════
--  RETOMADA AUTOMÁTICA AO INJETAR
--  Verifica se já há arquivo de hoje e carrega as configs salvas
-- ══════════════════════════════════════════════════════════════
task.defer(function()
    ensureFolder()
    local existing = safeRead(todayFileName())
    if existing and #existing > 0 then
        -- Carrega configurações do cabeçalho
        local cfg = parseConfig(existing)
        if cfg.startH then
            autoStartH = cfg.startH; autoStartM = cfg.startM
            sH.Text = string.format("%02d", autoStartH)
            sM.Text = string.format("%02d", autoStartM)
        end
        if cfg.stopH then
            autoStopH  = cfg.stopH;  autoStopM  = cfg.stopM
            eH.Text = string.format("%02d", autoStopH)
            eM.Text = string.format("%02d", autoStopM)
        end
        -- Conta membros já salvos
        local _, n = parseExistingFile(existing)
        if n > 0 then
            UI.schedInfo.Text = string.format(
                "💾 Arquivo do dia encontrado!\n%d membro(s) já registrado(s).\nConfigs do agendamento restauradas.", n)
            UI.schedInfo.TextColor3 = Color3.fromRGB(100,220,255)
            print(string.format("[CSI Logger] 💾 Arquivo do dia com %d membros. Configs restauradas.", n))
        end
    end
end)

-- ══════════════════════════════════════════════════════════════
--  EVENTOS DOS BOTÕES
-- ══════════════════════════════════════════════════════════════
UI.recBtn.MouseButton1Click:Connect(function()
    if not isRecording then
        startRecording()
    else
        stopRecording()
    end
end)

UI.autoBtn.MouseButton1Click:Connect(function()
    if not autoEnabled then
        local sh = tonumber(sH.Text)
        local sm = tonumber(sM.Text)
        local eh = tonumber(eH.Text)
        local em = tonumber(eM.Text)

        if not (sh and sm and eh and em)
           or sh < 0 or sh > 23 or sm < 0 or sm > 59
           or eh < 0 or eh > 23 or em < 0 or em > 59 then
            UI.schedInfo.Text = "⚠ Horários inválidos!\nUse 0–23 para horas e 0–59 para minutos."
            UI.schedInfo.TextColor3 = Color3.fromRGB(255,100,100)
            return
        end

        autoStartH, autoStartM = sh, sm
        autoStopH,  autoStopM  = eh, em
        autoEnabled    = true
        autoStartFired = false
        autoStopFired  = false

        sH.TextEditable = false; sM.TextEditable = false
        eH.TextEditable = false; eM.TextEditable = false

        UI.autoBtn.Text             = "❌  CANCELAR AGENDAMENTO"
        UI.autoBtn.BackgroundColor3 = Color3.fromRGB(180,50,50)
        UI.schedInfo.Text = string.format(
            "✅ Agendado com sucesso!\nInício: %02d:%02d  →  Fim: %02d:%02d", sh,sm,eh,em)
        UI.schedInfo.TextColor3 = Color3.fromRGB(100,255,150)
        print(string.format("[CSI Logger] ⏰ Agendado %02d:%02d → %02d:%02d", sh,sm,eh,em))
    else
        autoEnabled = false
        sH.TextEditable = true; sM.TextEditable = true
        eH.TextEditable = true; eM.TextEditable = true
        UI.autoBtn.Text             = "📅  ATIVAR AGENDAMENTO"
        UI.autoBtn.BackgroundColor3 = Color3.fromRGB(55,85,200)
        UI.schedInfo.Text           = "🚫 Agendamento cancelado."
        UI.schedInfo.TextColor3     = Color3.fromRGB(200,200,200)
    end
end)

xBtn.MouseButton1Click:Connect(function()
    if isRecording then stopRecording() end
    ScreenGui:Destroy()
end)

closeBtn.MouseButton1Click:Connect(function()
    if isRecording then stopRecording() end
    ScreenGui:Destroy()
end)

-- ══════════════════════════════════════════════════════════════
--  LOOP PRINCIPAL — executa a cada 1 segundo
-- ══════════════════════════════════════════════════════════════
task.spawn(function()
    local autoSaveTimer = 0

    while ScreenGui.Parent do
        task.wait(1)

        local H = nowH()
        local M = nowM()
        local S = nowS()

        -- Relógio ao vivo
        UI.clock.Text = string.format("🕐 %02d:%02d:%02d", H, M, S)

        -- Atualiza contadores
        updateUI()

        -- Auto-save periódico (a cada AUTOSAVE_IV segundos)
        if isRecording then
            autoSaveTimer = autoSaveTimer + 1
            if autoSaveTimer >= CFG.AUTOSAVE_IV then
                autoSaveTimer = 0
                saveFile(false)
            end
        else
            autoSaveTimer = 0
        end

        -- ── Lógica de agendamento ──────────────────────────
        if autoEnabled then
            -- Dispara START
            if not autoStartFired and H == autoStartH and M == autoStartM then
                autoStartFired = true
                startRecording()
                UI.schedInfo.Text = string.format(
                    "▶ Iniciado automaticamente às %02d:%02d!\nMonitorando membros %s...",
                    H, M, CFG.PREFIX)
                UI.schedInfo.TextColor3 = Color3.fromRGB(100,255,150)
            end
            -- Dispara STOP
            if not autoStopFired and H == autoStopH and M == autoStopM then
                if isRecording then
                    autoStopFired = true
                    stopRecording()
                    UI.schedInfo.Text = string.format(
                        "⏹ Finalizado automaticamente às %02d:%02d!\nTotal: %d membro(s) registrado(s).",
                        H, M, totalLogged)
                    UI.schedInfo.TextColor3 = Color3.fromRGB(255,200,80)
                end
            end
        end
    end
end)

-- ══════════════════════════════════════════════════════════════
print("[CSI Logger v3.0] ✅ Script carregado com sucesso!")
print("[CSI Logger v3.0] 📂 Pasta de logs: " .. CFG.LOG_FOLDER)
print("[CSI Logger v3.0] 📄 Arquivo do dia: " .. todayFileName())
