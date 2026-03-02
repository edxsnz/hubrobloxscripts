-- ╔══════════════════════════════════════════════════════════════╗
-- ║         Clan Member Logger — UI                             ║
-- ║  Requer playerlogger_core.lua carregado antes               ║
-- ╚══════════════════════════════════════════════════════════════╝

-- Aguarda o core estar disponível (até 10s)
local core
do
    local t = 0
    while not (_G.ClanLogger and _G.ClanLogger._loaded) and t < 10 do
        task.wait(0.2); t = t + 0.2
    end
    core = _G.ClanLogger
    if not core then
        warn("[ClanLogger UI] Core não encontrado! Carregue playerlogger_core.lua primeiro.")
        return
    end
end

local UIS = game:GetService("UserInputService")
local fmtDur         = core.fmtDur
local getCurrentSecs = core.getCurrentSecs

-- ══════════════════════════════════════════════════════════════
--  LIMPA INSTÂNCIA ANTERIOR
-- ══════════════════════════════════════════════════════════════
local prev = game:GetService("CoreGui"):FindFirstChild("ClanLogger")
if prev then prev:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "ClanLogger"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent         = game:GetService("CoreGui")

-- ══════════════════════════════════════════════════════════════
--  HELPERS
-- ══════════════════════════════════════════════════════════════
local function corner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = p
end

local function stroke(p, col, th)
    local s = Instance.new("UIStroke"); s.Color = col or Color3.fromRGB(40,40,70); s.Thickness = th or 1; s.Parent = p
end

-- Label: Gotham (não bold) por padrão. Sem emojis problemáticos.
local function mkLabel(par, x, y, w, h, txt, ts, col, font, ax)
    local l = Instance.new("TextLabel")
    l.Position               = UDim2.new(0,x,0,y)
    l.Size                   = UDim2.new(0,w,0,h)
    l.BackgroundTransparency = 1
    l.Text                   = txt
    l.TextSize               = ts or 12
    l.TextColor3             = col or Color3.fromRGB(210,210,210)
    l.Font                   = font or Enum.Font.Gotham
    l.TextXAlignment         = ax or Enum.TextXAlignment.Left
    l.TextWrapped            = true
    l.Parent                 = par
    return l
end

-- Botão: GothamSemibold, sem emojis
local function mkBtn(par, x, y, w, h, txt, bg, ts, textCol)
    local b = Instance.new("TextButton")
    b.Position         = UDim2.new(0,x,0,y)
    b.Size             = UDim2.new(0,w,0,h)
    b.BackgroundColor3 = bg or Color3.fromRGB(40,40,70)
    b.Text             = txt
    b.TextColor3       = textCol or Color3.fromRGB(225,225,225)
    b.TextSize         = ts or 12
    b.Font             = Enum.Font.GothamSemibold
    b.BorderSizePixel  = 0
    b.AutoButtonColor  = false
    b.Parent           = par
    corner(b, 6)
    return b
end

local function mkBox(par, x, y, w, h, def, ph)
    local b = Instance.new("TextBox")
    b.Position          = UDim2.new(0,x,0,y)
    b.Size              = UDim2.new(0,w,0,h)
    b.BackgroundColor3  = Color3.fromRGB(16,16,30)
    b.Text              = def or ""
    b.PlaceholderText   = ph or ""
    b.PlaceholderColor3 = Color3.fromRGB(65,65,95)
    b.TextColor3        = Color3.fromRGB(220,220,220)
    b.TextSize          = 12
    b.Font              = Enum.Font.Gotham
    b.BorderSizePixel   = 0
    b.ClearTextOnFocus  = false
    b.TextXAlignment    = Enum.TextXAlignment.Center
    b.Parent            = par
    corner(b, 5)
    stroke(b, Color3.fromRGB(42,42,75), 1)
    return b
end

local function mkDiv(par, y)
    local d = Instance.new("Frame")
    d.Size             = UDim2.new(1,-28,0,1)
    d.Position         = UDim2.new(0,14,0,y)
    d.BackgroundColor3 = Color3.fromRGB(28,28,50)
    d.BorderSizePixel  = 0
    d.Parent           = par
end

-- ══════════════════════════════════════════════════════════════
--  JANELA PRINCIPAL
-- ══════════════════════════════════════════════════════════════
local WW, WH = 460, 585

local Main = Instance.new("Frame")
Main.Name             = "Main"
Main.Size             = UDim2.new(0,WW,0,WH)
Main.Position         = UDim2.new(0.5,-WW/2,0.5,-WH/2)
Main.BackgroundColor3 = Color3.fromRGB(10,10,20)
Main.BorderSizePixel  = 0
Main.Active           = true
Main.Draggable        = true
Main.Parent           = ScreenGui
corner(Main, 12)
stroke(Main, Color3.fromRGB(45,70,185), 1.5)

do
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(13,13,26)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(8,8,16)),
    }
    g.Rotation = 120; g.Parent = Main
end

-- ── TitleBar ──────────────────────────────────────────────────
-- Usamos um frame separado para o título e o X fica diretamente no Main
-- para não ser afetado pelo ClipsDescendants do TBar
local TBar = Instance.new("Frame")
TBar.Name             = "TBar"
TBar.Size             = UDim2.new(1,0,0,44)
TBar.Position         = UDim2.new(0,0,0,0)
TBar.BackgroundColor3 = Color3.fromRGB(11,11,22)
TBar.BorderSizePixel  = 0
TBar.ClipsDescendants = false   -- importante: não clip o X
TBar.Parent           = Main
do
    -- corners só em cima
    local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0,12); tc.Parent = TBar
    local cap = Instance.new("Frame")   -- tapa o arredondamento de baixo
    cap.Size             = UDim2.new(1,0,0,14)
    cap.Position         = UDim2.new(0,0,1,-14)
    cap.BackgroundColor3 = Color3.fromRGB(11,11,22)
    cap.BorderSizePixel  = 0
    cap.ZIndex           = 2
    cap.Parent           = TBar
end

-- Dot verde pulsante
local titleDot = Instance.new("Frame")
titleDot.Size             = UDim2.new(0,8,0,8)
titleDot.Position         = UDim2.new(0,14,0.5,-4)
titleDot.BackgroundColor3 = Color3.fromRGB(0,210,100)
titleDot.BorderSizePixel  = 0
titleDot.ZIndex           = 3
titleDot.Parent           = TBar
corner(titleDot, 4)

task.spawn(function()
    local t = 0
    while TBar.Parent do
        t = t + task.wait(0.05)
        titleDot.BackgroundTransparency = 0.2 + 0.55 * math.abs(math.sin(t * 2.2))
    end
end)

local titleLbl = mkLabel(TBar, 28, 0, WW-60, 44, "CLAN MEMBER LOGGER", 12, Color3.fromRGB(225,225,225), Enum.Font.GothamSemibold)
titleLbl.ZIndex = 3

-- ── Botão X — filho do Main (não do TBar), posicionado sobre a titlebar
local xBtn = Instance.new("TextButton")
xBtn.Name             = "xBtn"
xBtn.Size             = UDim2.new(0,26,0,26)
xBtn.Position         = UDim2.new(1,-38,0,9)   -- relativo ao Main
xBtn.BackgroundColor3 = Color3.fromRGB(130,25,25)
xBtn.Text             = "X"
xBtn.TextColor3       = Color3.fromRGB(255,170,170)
xBtn.TextSize         = 11
xBtn.Font             = Enum.Font.GothamSemibold
xBtn.BorderSizePixel  = 0
xBtn.AutoButtonColor  = false
xBtn.ZIndex           = 20      -- garante que fica por cima de tudo
xBtn.Parent           = Main    -- pai = Main, não TBar
corner(xBtn, 5)
stroke(xBtn, Color3.fromRGB(190,45,45), 1)

-- ── Barra de status + Clock ───────────────────────────────────
local statusLbl = mkLabel(Main, 14, 50, WW-165, 22, "Aguardando...", 11, Color3.fromRGB(160,160,185), Enum.Font.Gotham)
local clockLbl  = mkLabel(Main, WW-155, 50, 140, 22, "--:--:--", 11, Color3.fromRGB(95,160,255), Enum.Font.GothamSemibold, Enum.TextXAlignment.Right)

mkDiv(Main, 77)

-- ══════════════════════════════════════════════════════════════
--  NOVO CLA
-- ══════════════════════════════════════════════════════════════
mkLabel(Main, 14, 84, WW-28, 16, "NOVO CLA", 10, Color3.fromRGB(195,165,55), Enum.Font.GothamSemibold)

mkLabel(Main, 14,  102, 112, 14, "Tag / Nome", 9, Color3.fromRGB(120,120,175))
mkLabel(Main, 134, 102,  98, 14, "Prefixo",    9, Color3.fromRGB(110,170,110))
mkLabel(Main, 240, 102,  98, 14, "Sufixo",     9, Color3.fromRGB(170,110,110))

local tagBox    = mkBox(Main, 14,  118, 112, 30, "", "FBI")
local prefixBox = mkBox(Main, 134, 118,  98, 30, "", "FBI_")
local suffixBox = mkBox(Main, 240, 118,  98, 30, "", "_z")
local addBtn    = mkBtn(Main, 346, 118,  100, 30, "+ ADICIONAR", Color3.fromRGB(30,110,50), 10, Color3.fromRGB(150,245,170))

local addInfo = mkLabel(Main, 14, 154, WW-28, 16, "Preencha prefixo e/ou sufixo.", 9, Color3.fromRGB(80,80,118))

mkDiv(Main, 175)

-- ══════════════════════════════════════════════════════════════
--  CLAS ATIVOS
-- ══════════════════════════════════════════════════════════════
mkLabel(Main, 14, 181, WW-28, 16, "CLAS ATIVOS", 10, Color3.fromRGB(195,165,55), Enum.Font.GothamSemibold)

local TabScroll = Instance.new("ScrollingFrame")
TabScroll.Size                = UDim2.new(1,-28,0,28)
TabScroll.Position            = UDim2.new(0,14,0,199)
TabScroll.BackgroundTransparency = 1
TabScroll.BorderSizePixel     = 0
TabScroll.ScrollBarThickness  = 0
TabScroll.ScrollingDirection  = Enum.ScrollingDirection.X
TabScroll.CanvasSize          = UDim2.new(0,0,0,0)
TabScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
TabScroll.Parent              = Main

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.SortOrder     = Enum.SortOrder.LayoutOrder
TabLayout.Padding       = UDim.new(0,5)
TabLayout.Parent        = TabScroll

local noClansLbl = mkLabel(Main, 14, 203, 260, 20, "Nenhum cla adicionado.", 10, Color3.fromRGB(75,75,115))

mkDiv(Main, 234)

-- ══════════════════════════════════════════════════════════════
--  PAINEL DO CLA SELECIONADO
-- ══════════════════════════════════════════════════════════════
local clanNameLbl  = mkLabel(Main, 14, 241, WW-165, 20, "Selecione um cla acima", 11, Color3.fromRGB(130,130,175), Enum.Font.GothamSemibold)
local clanCountLbl = mkLabel(Main, WW-152, 241, 138, 20, "", 11, Color3.fromRGB(130,220,130), Enum.Font.GothamSemibold, Enum.TextXAlignment.Right)
local clanFileLbl  = mkLabel(Main, 14, 263, WW-115, 13, "", 8, Color3.fromRGB(160,135,48))

local removeBtn = mkBtn(Main, WW-110, 259, 96, 20, "Remover", Color3.fromRGB(90,22,22), 9, Color3.fromRGB(245,150,150))
removeBtn.Visible = false

-- ── Header da tabela ─────────────────────────────────────────
local colW  = WW - 28 - 8
local nameW = math.floor(colW * 0.44)

local tHead = Instance.new("Frame")
tHead.Size             = UDim2.new(1,-28,0,20)
tHead.Position         = UDim2.new(0,14,0,282)
tHead.BackgroundColor3 = Color3.fromRGB(17,17,36)
tHead.BorderSizePixel  = 0
tHead.Parent           = Main
corner(tHead, 4)

mkLabel(tHead, 7,         0, nameW, 20, "USUARIO",  9, Color3.fromRGB(120,120,175), Enum.Font.GothamSemibold)
mkLabel(tHead, nameW,     0, 64,    20, "ENTRADA",  9, Color3.fromRGB(120,120,175), Enum.Font.GothamSemibold)
mkLabel(tHead, colW-78,   0, 78,    20, "TEMPO",    9, Color3.fromRGB(120,120,175), Enum.Font.GothamSemibold, Enum.TextXAlignment.Right)

-- ══════════════════════════════════════════════════════════════
--  LISTA DE JOGADORES
-- ══════════════════════════════════════════════════════════════
local Scroll = Instance.new("ScrollingFrame")
Scroll.Size                 = UDim2.new(1,-28,0,120)
Scroll.Position             = UDim2.new(0,14,0,304)
Scroll.BackgroundColor3     = Color3.fromRGB(10,10,21)
Scroll.BorderSizePixel      = 0
Scroll.ScrollBarThickness   = 3
Scroll.ScrollBarImageColor3 = Color3.fromRGB(55,75,175)
Scroll.CanvasSize           = UDim2.new(0,0,0,0)
Scroll.AutomaticCanvasSize  = Enum.AutomaticSize.Y
Scroll.Parent               = Main
corner(Scroll, 5)
stroke(Scroll, Color3.fromRGB(26,26,50), 1)

local ListLayout = Instance.new("UIListLayout")
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding   = UDim.new(0,1)
ListLayout.Parent    = Scroll

local lPad = Instance.new("UIPadding")
lPad.PaddingTop   = UDim.new(0,2)
lPad.PaddingLeft  = UDim.new(0,3)
lPad.PaddingRight = UDim.new(0,3)
lPad.Parent       = Scroll

-- 32 linhas pré-criadas
local rows = {}
for i = 1, 32 do
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1,0,0,22)
    row.BorderSizePixel  = 0
    row.LayoutOrder      = i
    row.BackgroundColor3 = (i%2==0) and Color3.fromRGB(14,14,27) or Color3.fromRGB(10,10,21)
    row.Visible          = false
    row.Parent           = Scroll
    corner(row, 3)

    -- Dot online/offline usando Frame circular (sem emoji)
    local dotFr = Instance.new("Frame")
    dotFr.Size             = UDim2.new(0,7,0,7)
    dotFr.Position         = UDim2.new(0,5,0.5,-3)
    dotFr.BackgroundColor3 = Color3.fromRGB(80,215,80)
    dotFr.BorderSizePixel  = 0
    dotFr.Parent           = row
    corner(dotFr, 4)

    local name  = mkLabel(row, 17, 0, nameW-14, 22, "",  10, Color3.fromRGB(208,208,213))
    local entry = mkLabel(row, nameW, 0, 64, 22, "",      9, Color3.fromRGB(125,155,125))
    local dur   = mkLabel(row, colW-78, 0, 78, 22, "",   10, Color3.fromRGB(238,196,65), Enum.Font.GothamSemibold, Enum.TextXAlignment.Right)
    rows[i] = { frame=row, dot=dotFr, name=name, entry=entry, dur=dur }
end

mkDiv(Main, 430)

-- ══════════════════════════════════════════════════════════════
--  BOTAO GRAVAR
-- ══════════════════════════════════════════════════════════════
local recBtn = mkBtn(Main, 14, 436, WW-28, 40, "INICIAR GRAVACAO", Color3.fromRGB(28,115,52), 12, Color3.fromRGB(155,250,175))
stroke(recBtn, Color3.fromRGB(38,155,65), 1)

mkDiv(Main, 482)

-- ══════════════════════════════════════════════════════════════
--  AGENDAMENTO
-- ══════════════════════════════════════════════════════════════
mkLabel(Main, 14, 488, WW-28, 16, "AGENDAMENTO", 10, Color3.fromRGB(195,165,55), Enum.Font.GothamSemibold)

mkLabel(Main, 14,  506, 80, 13, "Inicio", 9, Color3.fromRGB(110,185,110))
mkLabel(Main, 152, 506, 80, 13, "Fim",    9, Color3.fromRGB(185,110,110))

local sH = mkBox(Main, 14,  521, 44, 32, "21")
mkLabel(Main, 62,  526, 12, 22, ":", 15, Color3.fromRGB(190,190,190), Enum.Font.GothamSemibold, Enum.TextXAlignment.Center)
local sM = mkBox(Main, 76,  521, 44, 32, "00")

local eH = mkBox(Main, 152, 521, 44, 32, "22")
mkLabel(Main, 200, 526, 12, 22, ":", 15, Color3.fromRGB(190,190,190), Enum.Font.GothamSemibold, Enum.TextXAlignment.Center)
local eM = mkBox(Main, 214, 521, 44, 32, "00")

local autoBtn = mkBtn(Main, WW-138, 521, 124, 32, "Ativar Agenda", Color3.fromRGB(42,62,175), 11, Color3.fromRGB(155,185,255))
stroke(autoBtn, Color3.fromRGB(58,88,220), 1)
autoBtn.AutomaticSize = Enum.AutomaticSize.None

local schedInfo = mkLabel(Main, 14, 558, WW-28, 20, "", 9, Color3.fromRGB(150,150,175))
schedInfo.TextXAlignment = Enum.TextXAlignment.Center

-- ══════════════════════════════════════════════════════════════
--  LOGICA DAS ABAS
-- ══════════════════════════════════════════════════════════════
local activeClan = nil
local tabButtons = {}

local function refreshList()
    if not activeClan then
        for _, r in ipairs(rows) do r.frame.Visible = false end
        return
    end
    local ord = {}
    for uid, info in pairs(activeClan.logs) do
        ord[#ord+1] = { uid=uid, info=info }
    end
    table.sort(ord, function(a,b) return (a.info.idx or 0) < (b.info.idx or 0) end)
    for i, r in ipairs(rows) do
        local e = ord[i]
        if e then
            local info = e.info
            -- dot colorido: verde = online, vermelho = offline
            r.dot.BackgroundColor3 = info.online
                and Color3.fromRGB(60,210,80)
                or  Color3.fromRGB(200,65,65)
            r.name.Text     = info.displayName
            r.entry.Text    = info.entryTime
            r.dur.Text      = fmtDur(getCurrentSecs(info))
            r.frame.Visible = true
        else
            r.frame.Visible = false
        end
    end
end

local function selectClan(clan)
    activeClan = clan
    for _, tb in ipairs(tabButtons) do
        if tb.clan == clan then
            tb.btn.BackgroundColor3 = tb.clan.color
            local s = tb.btn:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke", tb.btn)
            s.Color = Color3.fromRGB(255,255,255); s.Thickness = 1
        else
            tb.btn.BackgroundColor3 = Color3.fromRGB(22,22,42)
            local s = tb.btn:FindFirstChildOfClass("UIStroke")
            if s then s:Destroy() end
        end
    end
    if clan then
        clanNameLbl.Text       = clan.tag
        clanNameLbl.TextColor3 = clan.color
        clanCountLbl.Text      = (clan.total or 0) .. " membros"
        clanFileLbl.Text       = (clan.file ~= "" and clan.file or core.clanFileName(clan))
        removeBtn.Visible      = true
    else
        clanNameLbl.Text       = "Selecione um cla acima"
        clanNameLbl.TextColor3 = Color3.fromRGB(130,130,175)
        clanCountLbl.Text      = ""
        clanFileLbl.Text       = ""
        removeBtn.Visible      = false
    end
    Scroll.CanvasPosition = Vector2.new(0,0)
    refreshList()
end

local function rebuildTabs()
    for _, tb in ipairs(tabButtons) do tb.btn:Destroy() end
    tabButtons = {}
    local clans = core.getClans()
    noClansLbl.Visible = (#clans == 0)
    for i, clan in ipairs(clans) do
        local tb = Instance.new("TextButton")
        tb.Size             = UDim2.new(0,0,1,0)
        tb.AutomaticSize    = Enum.AutomaticSize.X
        tb.BackgroundColor3 = (activeClan == clan) and clan.color or Color3.fromRGB(22,22,42)
        tb.Text             = "  " .. clan.tag .. "  "
        tb.TextColor3       = Color3.fromRGB(215,215,215)
        tb.TextSize         = 11
        tb.Font             = Enum.Font.GothamSemibold
        tb.BorderSizePixel  = 0
        tb.AutoButtonColor  = false
        tb.LayoutOrder      = i
        tb.Parent           = TabScroll
        corner(tb, 5)
        if activeClan == clan then
            local s = Instance.new("UIStroke", tb); s.Color = Color3.fromRGB(240,240,240); s.Thickness = 1
        end
        tabButtons[#tabButtons+1] = { btn=tb, clan=clan }
        tb.MouseButton1Click:Connect(function() selectClan(clan); rebuildTabs() end)
    end
end

-- ══════════════════════════════════════════════════════════════
--  EVENTOS DOS BOTOES
-- ══════════════════════════════════════════════════════════════
addBtn.MouseButton1Click:Connect(function()
    local tag = tagBox.Text:match("^%s*(.-)%s*$")
    local pre = prefixBox.Text:match("^%s*(.-)%s*$")
    local suf = suffixBox.Text:match("^%s*(.-)%s*$")

    local ok, result = core.addClan(tag, pre, suf)
    if not ok then
        local msgs = {
            ["tag vazia"]               = "! Digite um nome/tag!",
            ["prefixo e sufixo vazios"] = "! Preencha prefixo e/ou sufixo!",
            ["ja existe"]               = "! Cla '" .. tag .. "' ja existe!",
            ["maximo 8 clas"]           = "! Maximo 8 clas.",
        }
        addInfo.Text       = msgs[result] or ("! " .. tostring(result))
        addInfo.TextColor3 = Color3.fromRGB(255,95,95)
        return
    end
    tagBox.Text=""; prefixBox.Text=""; suffixBox.Text=""
    addInfo.Text       = "'" .. tag .. "' adicionado com sucesso!"
    addInfo.TextColor3 = Color3.fromRGB(95,230,125)
    if not activeClan then selectClan(result) end
    rebuildTabs()
end)

removeBtn.MouseButton1Click:Connect(function()
    if not activeClan then return end
    core.removeClan(activeClan)
    activeClan = core.getClans()[1] or nil
    selectClan(activeClan)
    rebuildTabs()
    addInfo.Text       = "Cla removido."
    addInfo.TextColor3 = Color3.fromRGB(185,185,185)
end)

recBtn.MouseButton1Click:Connect(function()
    if #core.getClans() == 0 then
        addInfo.Text = "! Adicione pelo menos 1 cla!"; addInfo.TextColor3 = Color3.fromRGB(255,95,95); return
    end
    if not core.isRecording() then
        core.startRecording()
        recBtn.Text             = "PARAR GRAVACAO"
        recBtn.BackgroundColor3 = Color3.fromRGB(140,28,28)
        recBtn.TextColor3       = Color3.fromRGB(255,155,155)
        do local s = recBtn:FindFirstChildOfClass("UIStroke"); if s then s.Color=Color3.fromRGB(190,45,45) end end
        statusLbl.Text      = "[ REC ] Gravando..."
        statusLbl.TextColor3 = Color3.fromRGB(255,95,95)
        if activeClan and activeClan.file ~= "" then clanFileLbl.Text = activeClan.file end
    else
        core.stopRecording()
        recBtn.Text             = "INICIAR GRAVACAO"
        recBtn.BackgroundColor3 = Color3.fromRGB(28,115,52)
        recBtn.TextColor3       = Color3.fromRGB(155,250,175)
        do local s = recBtn:FindFirstChildOfClass("UIStroke"); if s then s.Color=Color3.fromRGB(38,155,65) end end
        statusLbl.Text       = "Finalizado!"
        statusLbl.TextColor3 = Color3.fromRGB(90,225,120)
    end
end)

autoBtn.MouseButton1Click:Connect(function()
    if not core.isAutoEnabled() then
        if #core.getClans() == 0 then
            schedInfo.Text="! Adicione clas antes!"; schedInfo.TextColor3=Color3.fromRGB(255,95,95); return
        end
        local sh,sm2,eh2,em2 = tonumber(sH.Text),tonumber(sM.Text),tonumber(eH.Text),tonumber(eM.Text)
        local ok, err = core.setSchedule(sh,sm2,eh2,em2)
        if not ok then
            schedInfo.Text="! "..(err or "Horario invalido"); schedInfo.TextColor3=Color3.fromRGB(255,95,95); return
        end
        sH.TextEditable=false; sM.TextEditable=false
        eH.TextEditable=false; eM.TextEditable=false
        autoBtn.Text             = "Cancelar"
        autoBtn.BackgroundColor3 = Color3.fromRGB(135,28,28)
        autoBtn.TextColor3       = Color3.fromRGB(255,155,155)
        do local s = autoBtn:FindFirstChildOfClass("UIStroke"); if s then s.Color=Color3.fromRGB(190,45,45) end end
        schedInfo.Text       = string.format("Agendado: %02d:%02d  ->  %02d:%02d  (%d cla(s))", sh,sm2,eh2,em2, #core.getClans())
        schedInfo.TextColor3 = Color3.fromRGB(90,220,120)
    else
        core.cancelSchedule()
        sH.TextEditable=true; sM.TextEditable=true
        eH.TextEditable=true; eM.TextEditable=true
        autoBtn.Text             = "Ativar Agenda"
        autoBtn.BackgroundColor3 = Color3.fromRGB(42,62,175)
        autoBtn.TextColor3       = Color3.fromRGB(155,185,255)
        do local s = autoBtn:FindFirstChildOfClass("UIStroke"); if s then s.Color=Color3.fromRGB(58,88,220) end end
        schedInfo.Text       = "Agendamento cancelado."
        schedInfo.TextColor3 = Color3.fromRGB(150,150,175)
    end
end)

xBtn.MouseButton1Click:Connect(function()
    if core.isRecording() then core.stopRecording() end
    ScreenGui:Destroy()
end)

-- ══════════════════════════════════════════════════════════════
--  EVENTOS DO CORE
-- ══════════════════════════════════════════════════════════════
core.onEvent(function(event, data)
    if event == "tick" then
        clockLbl.Text = string.format("%02d:%02d:%02d", data.H, data.M, data.S)
        if core.isRecording() then
            statusLbl.Text       = "[ REC ] " .. fmtDur(data.elapsed)
            statusLbl.TextColor3 = Color3.fromRGB(255,95,95)
        end
        if activeClan then
            clanCountLbl.Text = (activeClan.total or 0) .. " membros"
            refreshList()
        end

    elseif event == "schedStarted" then
        recBtn.Text             = "PARAR GRAVACAO"
        recBtn.BackgroundColor3 = Color3.fromRGB(140,28,28)
        recBtn.TextColor3       = Color3.fromRGB(255,155,155)
        statusLbl.Text          = "[ REC ] Gravando..."
        statusLbl.TextColor3    = Color3.fromRGB(255,95,95)
        schedInfo.Text          = string.format("Iniciado automaticamente as %02d:%02d!", data.H, data.M)
        schedInfo.TextColor3    = Color3.fromRGB(90,220,120)

    elseif event == "schedStopped" then
        recBtn.Text             = "INICIAR GRAVACAO"
        recBtn.BackgroundColor3 = Color3.fromRGB(28,115,52)
        recBtn.TextColor3       = Color3.fromRGB(155,250,175)
        statusLbl.Text          = "Finalizado!"
        statusLbl.TextColor3    = Color3.fromRGB(90,225,120)
        local total = 0
        for _, c in ipairs(core.getClans()) do total = total + (c.total or 0) end
        schedInfo.Text       = string.format("Finalizado as %02d:%02d  |  Total: %d membro(s)", data.H, data.M, total)
        schedInfo.TextColor3 = Color3.fromRGB(235,195,60)

    elseif event == "clanAdded" or event == "clanRemoved" then
        rebuildTabs()

    elseif event == "playerLogged" then
        if activeClan == data.clan then refreshList() end
    end
end)

-- ══════════════════════════════════════════════════════════════
--  MINI-LABEL FLUTUANTE  (tecla G para mostrar/esconder)
-- ══════════════════════════════════════════════════════════════
local toggleHint = Instance.new("TextLabel")
toggleHint.Size                   = UDim2.new(0,155,0,26)
toggleHint.Position               = UDim2.new(0,12,1,-42)
toggleHint.BackgroundColor3       = Color3.fromRGB(11,11,22)
toggleHint.BackgroundTransparency = 0.1
toggleHint.BorderSizePixel        = 0
toggleHint.Text                   = "[ G ]  Clan Logger"
toggleHint.TextColor3             = Color3.fromRGB(95,155,255)
toggleHint.TextSize               = 10
toggleHint.Font                   = Enum.Font.GothamSemibold
toggleHint.TextXAlignment         = Enum.TextXAlignment.Center
toggleHint.Visible                = false
toggleHint.Parent                 = ScreenGui
corner(toggleHint, 6)
stroke(toggleHint, Color3.fromRGB(48,75,195), 1)

local menuVisible = true
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.G then
        menuVisible        = not menuVisible
        Main.Visible       = menuVisible
        toggleHint.Visible = not menuVisible
    end
end)

print("[ClanLogger UI] Carregado!")
