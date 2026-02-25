-- ╔══════════════════════════════════════════════════════════════╗
-- ║              Clan Member Logger                              ║
-- ║  Multi-Clã · Prefixo+Sufixo · Arquivo por Clã · Presença   ║
-- ╚══════════════════════════════════════════════════════════════╝

-- ══════════════════════════════════════════════════════════════
--  COMPATIBILIDADE CROSS-EXECUTOR
-- ══════════════════════════════════════════════════════════════
local function _isfolder(p)
    if isfolder then return isfolder(p)
    elseif syn and syn.is_folder then return syn.is_folder(p)
    else return false end
end
local function _makefolder(p)
    if makefolder then return makefolder(p)
    elseif syn and syn.make_folder then return syn.make_folder(p) end
end
local function _readfile(p)
    if readfile then return readfile(p)
    elseif syn and syn.read_file then return syn.read_file(p) end
    return nil
end
local function _writefile(p, c)
    if writefile then return writefile(p, c)
    elseif syn and syn.write_file then return syn.write_file(p, c) end
end
local function _listfiles(p)
    if listfiles then return listfiles(p)
    elseif syn and syn.list_files then return syn.list_files(p)
    else return {} end
end

-- ══════════════════════════════════════════════════════════════
--  SERVIÇOS
-- ══════════════════════════════════════════════════════════════
local Players = game:GetService("Players")
local MktSvc  = game:GetService("MarketplaceService")

-- ══════════════════════════════════════════════════════════════
--  CONFIGURAÇÕES GLOBAIS
-- ══════════════════════════════════════════════════════════════
local CFG = {
    LOG_FOLDER  = "ClanLogs",
    AUTOSAVE_IV = 30,
}

-- ══════════════════════════════════════════════════════════════
--  HELPERS DATA/HORA
-- ══════════════════════════════════════════════════════════════
local function dateOnly() return os.date("%d-%m-%Y") end
local function timeOnly() return os.date("%H:%M:%S")  end
local function nowH()     return tonumber(os.date("%H")) end
local function nowM()     return tonumber(os.date("%M")) end
local function nowS()     return tonumber(os.date("%S")) end

local function fmtDur(s)
    s = math.floor(s or 0)
    if s < 60    then return string.format("%ds", s)
    elseif s < 3600 then return string.format("%dm %02ds", math.floor(s/60), s%60)
    else return string.format("%dh %02dm %02ds", math.floor(s/3600), math.floor((s%3600)/60), s%60)
    end
end

-- ══════════════════════════════════════════════════════════════
--  ESTADO GLOBAL
-- ══════════════════════════════════════════════════════════════
local clans             = {}
local activeClan        = nil
local isRecording       = false
local recStart          = nil  -- tick() do início
local recStartTime      = nil  -- horário legível do início (ex: "21:00:05")
local playerAddedConn   = nil
local playerRemovedConn = nil
local autoEnabled       = false
local autoStartH, autoStartM = 21, 0
local autoStopH,  autoStopM  = 22, 0
local autoStartFired    = false
local autoStopFired     = false

local gameName = "N/A"
pcall(function() gameName = MktSvc:GetProductInfo(game.PlaceId).Name end)

-- ══════════════════════════════════════════════════════════════
--  ARQUIVO
-- ══════════════════════════════════════════════════════════════
local function ensureFolder()
    pcall(function()
        if not _isfolder(CFG.LOG_FOLDER) then _makefolder(CFG.LOG_FOLDER) end
    end)
end

local function safeRead(p)
    local ok, d = pcall(_readfile, p)
    return (ok and d) or nil
end

local function safeWrite(p, c)
    pcall(_writefile, p, c)
end

local function clanFileName(clan)
    local data = dateOnly()              -- Formato: DD-MM-YYYY
    local hora = os.date("%H-%M-%S")      -- Formato: HH-MM-SS
    return CFG.LOG_FOLDER .. "/" .. clan.tag:gsub("[^%w%-]", "_") .. "_LOG_" .. data .. "_" .. hora .. ".txt"
end

-- ══════════════════════════════════════════════════════════════
--  MATCH DE CLÃ
-- ══════════════════════════════════════════════════════════════
local function matchesClan(dn, clan)
    if not dn or dn == "" then return false end
    local d   = dn:upper()
    local pre = (clan.prefix or ""):upper()
    local suf = (clan.suffix or ""):upper()
    if pre == "" and suf == "" then return false end
    local okP = pre == "" or d:sub(1, #pre) == pre
    local okS = suf == "" or d:sub(-#suf) == suf
    return okP and okS
end

local function getCurrentSecs(info)
    local t = info.totalSeconds or 0
    if info.online and info.joinTick then
        t = t + (tick() - info.joinTick)
    end
    return t
end

-- ══════════════════════════════════════════════════════════════
--  BUILD / SAVE
-- ══════════════════════════════════════════════════════════════
local function buildContent(clan, isFinal)
    local L = {}
    local function w(s) L[#L+1] = s end

    w(string.rep("═", 72))
    w("  CLAN MEMBER LOGGER — REGISTRO DE INVASÃO")
    w(string.rep("═", 72))
    w("Data           : " .. dateOnly())
    w("Jogo           : " .. gameName)
    w("Place ID       : " .. tostring(game.PlaceId))
    w("Clã / Tag      : " .. clan.tag)
    w("Padrão         : prefixo=[ " .. (clan.prefix or "") .. " ]  sufixo=[ " .. (clan.suffix or "") .. " ]")
    w(string.rep("─", 72))
    w(string.format("%-12s | %-26s | %-12s | %-10s | %s", "[HORA]", "[USUÁRIO]", "[USER ID]", "[ENTRADA]", "[TEMPO TOTAL]"))
    w(string.rep("─", 72))

    -- Jogadores ordenados por ordem de entrada
    local ord = {}
    for uid, info in pairs(clan.logs) do
        ord[#ord+1] = { uid = uid, info = info }
    end
    table.sort(ord, function(a, b) return (a.info.idx or 0) < (b.info.idx or 0) end)

    for _, e in ipairs(ord) do
        local info = e.info
        w(string.format("[%s] | %-26s | %-12s | %-10s | %s",
            info.entryTime, info.displayName, tostring(e.uid),
            info.entryTime, fmtDur(getCurrentSecs(info))))
    end

    w(string.rep("─", 72))
    w("STATUS         : " .. (isFinal and "✔ GRAVAÇÃO FINALIZADA" or "⏺ GRAVANDO... (auto-save " .. timeOnly() .. ")"))
    if recStart then
        w("Duração sessão : " .. fmtDur(tick() - recStart))
    end
    w("Início         : " .. (recStartTime or "--"))
    w("Fim            : " .. (isFinal and timeOnly() or "--"))
    w("Total logados  : " .. (clan.total or 0) .. " membro(s)")
    w(string.rep("═", 72))
    w("")
    w("╔════════════════════════════════════════════════════╗")
    w("                ✦  DESENVOLVIDO POR  ✦               ")
    w("")
    w("  Discord  →  edson_       ID: 1077067290945802271   ")
    w("  Roblox   →  edson6389    ID: 183265855             ")
    w("")
    w("  Gerado em: " .. dateOnly() .. " às " .. timeOnly())
    w("╚════════════════════════════════════════════════════╝")

    return table.concat(L, "\n") .. "\n"
end

local function saveClan(clan, isFinal)
    if not clan.file or clan.file == "" then return end
    safeWrite(clan.file, buildContent(clan, isFinal))
end

local function saveAllClans(isFinal)
    for _, c in ipairs(clans) do
        if (c.total or 0) > 0 then saveClan(c, isFinal) end
    end
end

-- ══════════════════════════════════════════════════════════════
--  PARSER (para retomar gravações salvas)
-- ══════════════════════════════════════════════════════════════
local function parseFile(content)
    local players, idx = {}, 0
    for line in content:gmatch("[^\n]+") do
        local t, name, uid, entry, dur = line:match("^%[(%d+:%d+:%d+)%] | (.-) | (%d+) | (%d+:%d+:%d+) | (.-)%s*$")
        if t and name and uid then
            local id = tonumber(uid)
            if id then
                idx = idx + 1
                local secs = 0
                local h2 = dur and dur:match("(%d+)h")
                local m2 = dur and dur:match("(%d+)m")
                local s2 = dur and dur:match("(%d+)s")
                if h2 then secs = secs + tonumber(h2) * 3600 end
                if m2 then secs = secs + tonumber(m2) * 60  end
                if s2 then secs = secs + tonumber(s2)       end
                players[id] = {
                    displayName  = name:match("^%s*(.-)%s*$"),
                    entryTime    = entry or t,
                    joinTick     = nil,
                    totalSeconds = secs,
                    sessions     = 1,
                    idx          = idx,
                    online       = false,
                }
            end
        end
    end
    return players, idx
end

local function parseConfig(content)
    local cfg = {}
    local sh, sm = content:match("AutoStart%s*:%s*(%d+):(%d+)")
    local eh, em = content:match("AutoStop%s*:%s*(%d+):(%d+)")
    if sh then cfg.startH = tonumber(sh); cfg.startM = tonumber(sm) or 0 end
    if eh then cfg.stopH  = tonumber(eh); cfg.stopM  = tonumber(em) or 0 end
    return cfg
end

-- ══════════════════════════════════════════════════════════════
--  GRAVAÇÃO
-- ══════════════════════════════════════════════════════════════
local function logPlayerToClan(player, clan)
    -- Guard: player pode ter saído antes de ser processado
    if not player or not player.Parent then return end
    local uid = player.UserId
    if not uid or uid == 0 then return end

    if clan.logs[uid] then
        local info = clan.logs[uid]
        info.joinTick = tick()
        info.online   = true
        info.sessions = (info.sessions or 1) + 1
    else
        clan.total = (clan.total or 0) + 1
        clan.logs[uid] = {
            displayName  = player.DisplayName,
            entryTime    = timeOnly(),
            joinTick     = tick(),
            totalSeconds = 0,
            sessions     = 1,
            idx          = clan.total,
            online       = true,
        }
        print(string.format("[Logger] ✓ #%d %s → %s", clan.total, player.DisplayName, clan.tag))
    end
    saveClan(clan, false)
end

local function checkAll(player)
    if not player or not player.Parent then return end
    local uid = player.UserId
    if not uid or uid == 0 then return end
    local dn = player.DisplayName or ""

    -- Só adia se DisplayName estiver completamente vazio (não carregou ainda)
    -- DisplayName == Name é válido: é um player sem DisplayName customizado
    if dn == "" then
        task.delay(2, function()
            if player and player.Parent then
                local dn2 = player.DisplayName or ""
                if dn2 ~= "" then
                    for _, clan in ipairs(clans) do
                        if matchesClan(dn2, clan) then
                            logPlayerToClan(player, clan)
                        end
                    end
                end
            end
        end)
        return
    end

    for _, clan in ipairs(clans) do
        if matchesClan(dn, clan) then
            logPlayerToClan(player, clan)
        end
    end
end

local function onLeave(player)
    if not isRecording then return end
    if not player then return end
    local uid = player.UserId
    if not uid or uid == 0 then return end
    for _, clan in ipairs(clans) do
        local info = clan.logs[uid]
        if info and info.online and info.joinTick then
            info.totalSeconds = info.totalSeconds + (tick() - info.joinTick)
            info.joinTick     = nil
            info.online       = false
            saveClan(clan, false)
        end
    end
end

-- ══════════════════════════════════════════════════════════════
--  FORWARD REFS (usados antes de serem criados na GUI)
-- ══════════════════════════════════════════════════════════════
local statusLbl, recBtn, schedInfo, clockLbl, clanCountLbl, clanNameLbl, clanFileLbl, removeBtn, addInfo

-- ══════════════════════════════════════════════════════════════
--  CONTROLE DE GRAVAÇÃO
-- ══════════════════════════════════════════════════════════════
local function startRecording()
    if isRecording then return end
    if #clans == 0 then return end

    ensureFolder()
    isRecording  = true
    recStart     = tick()
    recStartTime = timeOnly()

    for _, clan in ipairs(clans) do
        clan.file  = clanFileName(clan)
        clan.logs  = {}
        clan.total = 0
    end

    -- Loga quem já está no servidor agora
    for _, p in ipairs(Players:GetPlayers()) do checkAll(p) end

    -- Monitora entradas e saídas
    playerAddedConn = Players.PlayerAdded:Connect(function(p)
        task.wait(1) -- aguarda DisplayName carregar
        checkAll(p)
    end)
    playerRemovedConn = Players.PlayerRemoving:Connect(function(p) onLeave(p) end)

    saveAllClans(false)
end

local function stopRecording()
    if not isRecording then return end
    isRecording = false

    -- Finaliza tempo de quem ainda está online
    for _, p in ipairs(Players:GetPlayers()) do
        for _, clan in ipairs(clans) do
            local info = clan.logs[p.UserId]
            if info and info.online and info.joinTick then
                info.totalSeconds = info.totalSeconds + (tick() - info.joinTick)
                info.joinTick     = nil
                info.online       = false
            end
        end
    end

    if playerAddedConn   then playerAddedConn:Disconnect();   playerAddedConn   = nil end
    if playerRemovedConn then playerRemovedConn:Disconnect(); playerRemovedConn = nil end

    saveAllClans(true)
end

-- ══════════════════════════════════════════════════════════════
--  CORES DOS CLÃS
-- ══════════════════════════════════════════════════════════════
local CLAN_COLORS = {
    Color3.fromRGB(55,  130, 255),
    Color3.fromRGB(80,  200, 100),
    Color3.fromRGB(220, 100, 60),
    Color3.fromRGB(180, 80,  220),
    Color3.fromRGB(220, 200, 50),
    Color3.fromRGB(60,  200, 200),
    Color3.fromRGB(220, 70,  100),
    Color3.fromRGB(180, 140, 80),
}

-- ══════════════════════════════════════════════════════════════
--  GUI — limpeza de instância anterior
-- ══════════════════════════════════════════════════════════════
local prev = game:GetService("CoreGui"):FindFirstChild("ClanLogger")
if prev then prev:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name            = "ClanLogger"
ScreenGui.ResetOnSpawn    = false
ScreenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent          = game:GetService("CoreGui")

-- ══════════════════════════════════════════════════════════════
--  GUI — helpers de criação
-- ══════════════════════════════════════════════════════════════
local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
end

local function stroke(p, col, th)
    local s = Instance.new("UIStroke")
    s.Color     = col or Color3.fromRGB(80, 120, 255)
    s.Thickness = th or 1.5
    s.Parent    = p
end

local function mkLabel(par, x, y, w, h, txt, ts, col, font, ax)
    local l = Instance.new("TextLabel")
    l.Position          = UDim2.new(0, x, 0, y)
    l.Size              = UDim2.new(0, w, 0, h)
    l.BackgroundTransparency = 1
    l.Text              = txt
    l.TextSize          = ts or 12
    l.TextColor3        = col or Color3.fromRGB(210, 210, 210)
    l.Font              = font or Enum.Font.Gotham
    l.TextXAlignment    = ax or Enum.TextXAlignment.Left
    l.TextWrapped       = true
    l.Parent            = par
    return l
end

local function mkBtn(par, x, y, w, h, txt, bg, ts)
    local b = Instance.new("TextButton")
    b.Position       = UDim2.new(0, x, 0, y)
    b.Size           = UDim2.new(0, w, 0, h)
    b.BackgroundColor3 = bg or Color3.fromRGB(55, 55, 85)
    b.Text           = txt
    b.TextColor3     = Color3.fromRGB(255, 255, 255)
    b.TextSize       = ts or 13
    b.Font           = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.Parent         = par
    corner(b, 7)
    return b
end

local function mkBox(par, x, y, w, h, def, ph)
    local b = Instance.new("TextBox")
    b.Position           = UDim2.new(0, x, 0, y)
    b.Size               = UDim2.new(0, w, 0, h)
    b.BackgroundColor3   = Color3.fromRGB(18, 18, 34)
    b.Text               = def or ""
    b.PlaceholderText    = ph or ""
    b.PlaceholderColor3  = Color3.fromRGB(80, 80, 110)
    b.TextColor3         = Color3.fromRGB(255, 255, 255)
    b.TextSize           = 13
    b.Font               = Enum.Font.Gotham
    b.BorderSizePixel    = 0
    b.ClearTextOnFocus   = false
    b.TextXAlignment     = Enum.TextXAlignment.Center
    b.Parent             = par
    corner(b, 6)
    stroke(b, Color3.fromRGB(55, 65, 120), 1)
    return b
end

local function mkDiv(par, y)
    local d = Instance.new("Frame")
    d.Size             = UDim2.new(1, -24, 0, 1)
    d.Position         = UDim2.new(0, 12, 0, y)
    d.BackgroundColor3 = Color3.fromRGB(36, 36, 62)
    d.BorderSizePixel  = 0
    d.Parent           = par
end

-- ══════════════════════════════════════════════════════════════
--  JANELA PRINCIPAL
-- ══════════════════════════════════════════════════════════════
local WW = 450
local WH = 608

local Main = Instance.new("Frame")
Main.Name              = "Main"
Main.Size              = UDim2.new(0, WW, 0, WH)
Main.Position          = UDim2.new(0.5, -WW/2, 0.5, -WH/2)
Main.BackgroundColor3  = Color3.fromRGB(10, 10, 19)
Main.BorderSizePixel   = 0
Main.Active            = true
Main.Draggable         = true
Main.Parent            = ScreenGui
corner(Main, 12)
stroke(Main, Color3.fromRGB(55, 95, 230), 2)

do -- gradiente de fundo
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 15, 30)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(9,  9,  17)),
    }
    g.Rotation = 135
    g.Parent   = Main
end

-- ── TitleBar (y=0, h=44) ──────────────────────────────────────
local TBar = Instance.new("Frame")
TBar.Size                 = UDim2.new(1, 0, 0, 44)
TBar.Position             = UDim2.new(0, 0, 0, 0)
TBar.BackgroundTransparency = 1
TBar.BorderSizePixel      = 0
TBar.Parent               = Main

mkLabel(TBar, 14, 0, WW-54, 44, "  Clan Member Logger", 14, Color3.fromRGB(255,255,255), Enum.Font.GothamBold)

local xBtn = Instance.new("TextButton")
xBtn.Size              = UDim2.new(0, 28, 0, 28)
xBtn.Position          = UDim2.new(1, -36, 0, 8)
xBtn.BackgroundColor3  = Color3.fromRGB(160, 35, 35)
xBtn.Text              = "X"
xBtn.TextColor3        = Color3.fromRGB(255, 255, 255)
xBtn.TextSize          = 14
xBtn.Font              = Enum.Font.GothamBold
xBtn.BorderSizePixel   = 0
xBtn.Parent            = TBar
corner(xBtn, 7)

-- ── Status + Clock (y=50, h=22) ──────────────────────────────
statusLbl = mkLabel(Main, 14, 50, WW-160, 22, "⚪ Aguardando...", 13, Color3.fromRGB(180,180,180), Enum.Font.Gotham)
clockLbl  = mkLabel(Main, WW-150, 50, 138, 22, "🕐 --:--:--", 12, Color3.fromRGB(130,190,255), Enum.Font.GothamBold, Enum.TextXAlignment.Right)

mkDiv(Main, 78)

-- ══════════════════════════════════════════════════════════════
--  ADICIONAR CLÃ (y=86)
-- ══════════════════════════════════════════════════════════════
mkLabel(Main, 14, 86, WW-28, 18, "➕  ADICIONAR CLÃ", 12, Color3.fromRGB(255,200,70), Enum.Font.GothamBold)

mkLabel(Main, 12,  106, 116, 14, "Nome / Tag", 10, Color3.fromRGB(150,150,200))
mkLabel(Main, 136, 106, 100, 14, "Prefixo",    10, Color3.fromRGB(150,210,150))
mkLabel(Main, 244, 106, 100, 14, "Sufixo",     10, Color3.fromRGB(210,150,150))

local tagBox    = mkBox(Main, 12,  122, 116, 32, "", "ex: FBI")
local prefixBox = mkBox(Main, 136, 122, 100, 32, "", "ex: FBI_")
local suffixBox = mkBox(Main, 244, 122, 100, 32, "", "ex: _z")
local addBtn    = mkBtn(Main, 350, 122,  90, 32, "➕ Adicionar", Color3.fromRGB(40,140,70), 12)

addInfo = mkLabel(Main, 12, 160, WW-24, 16, "💡 Prefixo e/ou sufixo. Pode deixar um vazio.", 10, Color3.fromRGB(110,110,160))

mkDiv(Main, 182)

-- ══════════════════════════════════════════════════════════════
--  ABAS DE CLÃS (y=189)
-- ══════════════════════════════════════════════════════════════
mkLabel(Main, 14, 189, WW-28, 18, "📂  CLÃS ATIVOS", 12, Color3.fromRGB(255,200,70), Enum.Font.GothamBold)

local TabScroll = Instance.new("ScrollingFrame")
TabScroll.Size                 = UDim2.new(1, -24, 0, 34)
TabScroll.Position             = UDim2.new(0, 12, 0, 209)
TabScroll.BackgroundTransparency = 1
TabScroll.BorderSizePixel      = 0
TabScroll.ScrollBarThickness   = 0
TabScroll.ScrollingDirection   = Enum.ScrollingDirection.X
TabScroll.CanvasSize           = UDim2.new(0, 0, 0, 0)
TabScroll.AutomaticCanvasSize  = Enum.AutomaticSize.X
TabScroll.Parent               = Main

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.SortOrder     = Enum.SortOrder.LayoutOrder
TabLayout.Padding       = UDim.new(0, 6)
TabLayout.Parent        = TabScroll

-- Fora do TabScroll para não interferir no UIListLayout
local noClansLbl = mkLabel(Main, 12, 215, 260, 22, "Nenhum clã adicionado ainda.", 11, Color3.fromRGB(90,90,130))

mkDiv(Main, 249)

-- ══════════════════════════════════════════════════════════════
--  PAINEL DO CLÃ SELECIONADO (y=256)
-- ══════════════════════════════════════════════════════════════
clanNameLbl  = mkLabel(Main, 14, 257, WW-160, 20, "Selecione um clã acima", 12, Color3.fromRGB(160,160,200), Enum.Font.GothamBold)
clanCountLbl = mkLabel(Main, WW-148, 257, 136, 20, "", 12, Color3.fromRGB(160,255,160), Enum.Font.GothamBold, Enum.TextXAlignment.Right)
clanFileLbl  = mkLabel(Main, 14, 279, WW-110, 14, "", 9, Color3.fromRGB(200,170,60))
removeBtn    = mkBtn(Main, WW-106, 275, 94, 20, "🗑 Remover Clã", Color3.fromRGB(110,30,30), 10)
removeBtn.Visible = false

-- Dimensões da tabela (usadas no header e nas rows)
local colW  = WW - 24 - 8
local nameW = math.floor(colW * 0.44)

-- Header da tabela (y=298, h=22)
local tHead = Instance.new("Frame")
tHead.Size             = UDim2.new(1, -24, 0, 22)
tHead.Position         = UDim2.new(0, 12, 0, 298)
tHead.BackgroundColor3 = Color3.fromRGB(20, 20, 42)
tHead.BorderSizePixel  = 0
tHead.Parent           = Main
corner(tHead, 4)

mkLabel(tHead, 6,       0, nameW, 22, "USUÁRIO", 10, Color3.fromRGB(155,155,200), Enum.Font.GothamBold)
mkLabel(tHead, nameW,   0, 64,    22, "ENTRADA", 10, Color3.fromRGB(155,155,200), Enum.Font.GothamBold)
mkLabel(tHead, colW-80, 0, 76,    22, "TEMPO",   10, Color3.fromRGB(155,155,200), Enum.Font.GothamBold, Enum.TextXAlignment.Right)

-- Lista de jogadores (y=322, h=120)
local Scroll = Instance.new("ScrollingFrame")
Scroll.Size                  = UDim2.new(1, -24, 0, 120)
Scroll.Position              = UDim2.new(0, 12, 0, 322)
Scroll.BackgroundColor3      = Color3.fromRGB(13, 13, 24)
Scroll.BorderSizePixel       = 0
Scroll.ScrollBarThickness    = 3
Scroll.ScrollBarImageColor3  = Color3.fromRGB(70, 90, 200)
Scroll.CanvasSize            = UDim2.new(0, 0, 0, 0)
Scroll.AutomaticCanvasSize   = Enum.AutomaticSize.Y
Scroll.Parent                = Main
corner(Scroll, 6)
stroke(Scroll, Color3.fromRGB(30, 30, 58), 1)

local ListLayout = Instance.new("UIListLayout")
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding   = UDim.new(0, 2)
ListLayout.Parent    = Scroll

local lPad = Instance.new("UIPadding")
lPad.PaddingTop   = UDim.new(0, 3)
lPad.PaddingLeft  = UDim.new(0, 4)
lPad.PaddingRight = UDim.new(0, 4)
lPad.Parent       = Scroll

local rows = {}
for i = 1, 16 do
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 22)
    row.BorderSizePixel  = 0
    row.LayoutOrder      = i
    row.BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(17,17,32) or Color3.fromRGB(13,13,24)
    row.Visible          = false
    row.Parent           = Scroll
    corner(row, 3)

    local dot   = mkLabel(row, 3,        0, 14,         22, "🟢", 10, Color3.fromRGB(255,255,255))
    local name  = mkLabel(row, 17,       0, nameW - 14, 22, "",   10, Color3.fromRGB(220,220,220))
    local entry = mkLabel(row, nameW,    0, 64,         22, "",   10, Color3.fromRGB(140,180,140))
    local dur   = mkLabel(row, colW-80,  0, 78,         22, "",   10, Color3.fromRGB(255,210,80), Enum.Font.GothamBold, Enum.TextXAlignment.Right)
    rows[i] = { frame = row, dot = dot, name = name, entry = entry, dur = dur }
end

mkDiv(Main, 448)

-- ══════════════════════════════════════════════════════════════
--  BOTÃO GRAVAR (y=456, h=38)
-- ══════════════════════════════════════════════════════════════
recBtn = mkBtn(Main, 12, 456, WW-24, 38, "⏺  INICIAR GRAVAÇÃO  (todos os clãs)", Color3.fromRGB(35,165,70), 13)

mkDiv(Main, 500)

-- ══════════════════════════════════════════════════════════════
--  AGENDAMENTO AUTOMÁTICO (y=507)
-- ══════════════════════════════════════════════════════════════
mkLabel(Main, 14, 507, WW-28, 16, "⏰  AGENDAMENTO AUTOMÁTICO", 12, Color3.fromRGB(255,200,70), Enum.Font.GothamBold)

mkLabel(Main, 12,  526, 130, 14, "▶ Início ( HH : MM )", 10, Color3.fromRGB(130,210,130))
mkLabel(Main, 148, 526, 130, 14, "⏹ Fim  ( HH : MM )",   10, Color3.fromRGB(210,130,130))

local sH = mkBox(Main, 12,  542, 44, 34, "21")
mkLabel(Main, 60,  546, 14, 26, ":", 16, Color3.fromRGB(255,255,255), Enum.Font.GothamBold, Enum.TextXAlignment.Center)
local sM = mkBox(Main, 76,  542, 44, 34, "00")

local eH = mkBox(Main, 148, 542, 44, 34, "22")
mkLabel(Main, 196, 546, 14, 26, ":", 16, Color3.fromRGB(255,255,255), Enum.Font.GothamBold, Enum.TextXAlignment.Center)
local eM = mkBox(Main, 212, 542, 44, 34, "00")

local autoBtn = mkBtn(Main, WW-138, 542, 128, 34, "📅 Ativar", Color3.fromRGB(55,85,200), 13)
autoBtn.AutomaticSize = Enum.AutomaticSize.None

schedInfo = mkLabel(Main, 12, 582, WW-24, 20, "", 10, Color3.fromRGB(180,180,180))
schedInfo.TextXAlignment = Enum.TextXAlignment.Center

-- ══════════════════════════════════════════════════════════════
--  LÓGICA DAS ABAS
-- ══════════════════════════════════════════════════════════════
local tabButtons = {}

local function refreshList()
    if not activeClan then
        for _, r in ipairs(rows) do r.frame.Visible = false end
        return
    end
    local ord = {}
    for uid, info in pairs(activeClan.logs) do
        ord[#ord+1] = { uid = uid, info = info }
    end
    table.sort(ord, function(a, b) return (a.info.idx or 0) < (b.info.idx or 0) end)
    for i, r in ipairs(rows) do
        local e = ord[i]
        if e then
            local info = e.info
            r.dot.Text   = info.online and "🟢" or "🔴"
            r.name.Text  = info.displayName
            r.entry.Text = info.entryTime
            r.dur.Text   = fmtDur(getCurrentSecs(info))
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
            s.Color = Color3.fromRGB(255,255,255); s.Thickness = 1.5
        else
            tb.btn.BackgroundColor3 = Color3.fromRGB(28, 28, 50)
            local s = tb.btn:FindFirstChildOfClass("UIStroke")
            if s then s:Destroy() end
        end
    end
    if clan then
        clanNameLbl.Text      = "📁 " .. clan.tag
        clanNameLbl.TextColor3 = clan.color
        clanCountLbl.Text     = "👥 " .. (clan.total or 0) .. " membros"
        clanFileLbl.Text      = (clan.file ~= "" and clan.file or clanFileName(clan))
        removeBtn.Visible     = true
    else
        clanNameLbl.Text       = "Selecione um clã acima"
        clanNameLbl.TextColor3 = Color3.fromRGB(160,160,200)
        clanCountLbl.Text      = ""
        clanFileLbl.Text       = ""
        removeBtn.Visible      = false
    end
    refreshList()
end

local function rebuildTabs()
    for _, tb in ipairs(tabButtons) do tb.btn:Destroy() end
    tabButtons = {}
    noClansLbl.Visible = (#clans == 0)
    for i, clan in ipairs(clans) do
        local tb = Instance.new("TextButton")
        tb.Size              = UDim2.new(0, 0, 1, 0)
        tb.AutomaticSize     = Enum.AutomaticSize.X
        tb.BackgroundColor3  = (activeClan == clan) and clan.color or Color3.fromRGB(28,28,50)
        tb.Text              = "  " .. clan.tag .. "  "
        tb.TextColor3        = Color3.fromRGB(255,255,255)
        tb.TextSize          = 12
        tb.Font              = Enum.Font.GothamBold
        tb.BorderSizePixel   = 0
        tb.LayoutOrder       = i
        tb.Parent            = TabScroll
        corner(tb, 7)
        if activeClan == clan then
            local s = Instance.new("UIStroke", tb)
            s.Color = Color3.fromRGB(255,255,255); s.Thickness = 1.5
        end
        tabButtons[#tabButtons+1] = { btn = tb, clan = clan }
        tb.MouseButton1Click:Connect(function() selectClan(clan); rebuildTabs() end)
    end
end

-- ══════════════════════════════════════════════════════════════
--  EVENTOS DOS BOTÕES
-- ══════════════════════════════════════════════════════════════
addBtn.MouseButton1Click:Connect(function()
    local tag = tagBox.Text:match("^%s*(.-)%s*$")
    local pre = prefixBox.Text:match("^%s*(.-)%s*$")
    local suf = suffixBox.Text:match("^%s*(.-)%s*$")

    if tag == "" then
        addInfo.Text = "⚠ Digite um nome/tag!"; addInfo.TextColor3 = Color3.fromRGB(255,100,100); return
    end
    if pre == "" and suf == "" then
        addInfo.Text = "⚠ Preencha prefixo e/ou sufixo!"; addInfo.TextColor3 = Color3.fromRGB(255,100,100); return
    end
    for _, c in ipairs(clans) do
        if c.tag:upper() == tag:upper() then
            addInfo.Text = "⚠ Clã '" .. tag .. "' já existe!"; addInfo.TextColor3 = Color3.fromRGB(255,180,50); return
        end
    end
    if #clans >= 8 then
        addInfo.Text = "⚠ Máximo 8 clãs."; addInfo.TextColor3 = Color3.fromRGB(255,100,100); return
    end

    local nc = { tag = tag, prefix = pre, suffix = suf, color = CLAN_COLORS[(#clans % #CLAN_COLORS) + 1], logs = {}, total = 0, file = "" }
    clans[#clans+1] = nc
    tagBox.Text = ""; prefixBox.Text = ""; suffixBox.Text = ""
    addInfo.Text      = string.format("✅ '%s' adicionado! (pref='%s'  suf='%s')", tag, pre, suf)
    addInfo.TextColor3 = Color3.fromRGB(100,255,150)
    if not activeClan then selectClan(nc) end
    rebuildTabs()
end)

removeBtn.MouseButton1Click:Connect(function()
    if not activeClan then return end
    if isRecording then saveClan(activeClan, true) end
    for i, c in ipairs(clans) do
        if c == activeClan then table.remove(clans, i); break end
    end
    activeClan = clans[1] or nil
    selectClan(activeClan)
    rebuildTabs()
    addInfo.Text = "🗑 Clã removido."; addInfo.TextColor3 = Color3.fromRGB(200,200,200)
end)

recBtn.MouseButton1Click:Connect(function()
    if #clans == 0 then
        addInfo.Text = "⚠ Adicione pelo menos 1 clã!"; addInfo.TextColor3 = Color3.fromRGB(255,100,100); return
    end
    if not isRecording then
        startRecording()
        recBtn.Text            = "⏹  PARAR GRAVAÇÃO  (todos os clãs)"
        recBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
        statusLbl.Text         = "🔴 Gravando..."
        statusLbl.TextColor3   = Color3.fromRGB(255,80,80)
    else
        stopRecording()
        recBtn.Text            = "⏺  INICIAR GRAVAÇÃO  (todos os clãs)"
        recBtn.BackgroundColor3 = Color3.fromRGB(35,165,70)
        statusLbl.Text         = "✅ Finalizado!"
        statusLbl.TextColor3   = Color3.fromRGB(100,255,100)
    end
end)

autoBtn.MouseButton1Click:Connect(function()
    if not autoEnabled then
        if #clans == 0 then
            schedInfo.Text = "⚠ Adicione clãs antes!"; schedInfo.TextColor3 = Color3.fromRGB(255,100,100); return
        end
        local sh, sm2, eh2, em2 = tonumber(sH.Text), tonumber(sM.Text), tonumber(eH.Text), tonumber(eM.Text)
        if not (sh and sm2 and eh2 and em2) or sh > 23 or sm2 > 59 or eh2 > 23 or em2 > 59 then
            schedInfo.Text = "⚠ Horários inválidos!"; schedInfo.TextColor3 = Color3.fromRGB(255,100,100); return
        end
        autoStartH, autoStartM, autoStopH, autoStopM = sh, sm2, eh2, em2
        autoEnabled = true; autoStartFired = false; autoStopFired = false
        sH.TextEditable = false; sM.TextEditable = false
        eH.TextEditable = false; eM.TextEditable = false
        autoBtn.Text            = "❌ Cancelar"
        autoBtn.BackgroundColor3 = Color3.fromRGB(180,50,50)
        schedInfo.Text      = string.format("✅ Agendado: %02d:%02d → %02d:%02d  |  %d clã(s)", sh, sm2, eh2, em2, #clans)
        schedInfo.TextColor3 = Color3.fromRGB(100,255,150)
    else
        autoEnabled = false
        sH.TextEditable = true; sM.TextEditable = true
        eH.TextEditable = true; eM.TextEditable = true
        autoBtn.Text            = "📅 Ativar"
        autoBtn.BackgroundColor3 = Color3.fromRGB(55,85,200)
        schedInfo.Text      = "🚫 Agendamento cancelado."
        schedInfo.TextColor3 = Color3.fromRGB(200,200,200)
    end
end)

xBtn.MouseButton1Click:Connect(function()
    if isRecording then stopRecording() end
    ScreenGui:Destroy()
end)

-- ══════════════════════════════════════════════════════════════
--  TOGGLE VISIBILIDADE — tecla G
-- ══════════════════════════════════════════════════════════════
local UserInputService = game:GetService("UserInputService")
local menuVisible = true

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.G then
        menuVisible = not menuVisible
        Main.Visible = menuVisible
    end
end)

-- ══════════════════════════════════════════════════════════════
--  LOOP PRINCIPAL (tick a cada 1s)
-- ══════════════════════════════════════════════════════════════
task.spawn(function()
    local autoSaveTimer = 0
    local rescanTimer   = 0
    local watchdogTimer = 0
    while ScreenGui.Parent do
        task.wait(1)
        local H, M, S = nowH(), nowM(), nowS()
        clockLbl.Text = string.format("🕐 %02d:%02d:%02d", H, M, S)

        if isRecording then
            autoSaveTimer = autoSaveTimer + 1
            rescanTimer   = rescanTimer   + 1
            watchdogTimer = watchdogTimer + 1

            -- Auto-save
            if autoSaveTimer >= CFG.AUTOSAVE_IV then
                autoSaveTimer = 0
                saveAllClans(false)
            end

            -- Re-scan: a cada 15s varre todos os players do servidor
            -- só processa quem AINDA NÃO foi logado (não sobrescreve joinTick de quem já está)
            if rescanTimer >= 15 then
                rescanTimer = 0
                for _, p in ipairs(Players:GetPlayers()) do
                    pcall(function()
                        if not p or not p.Parent then return end
                        local uid = p.UserId
                        local jaLogado = false
                        for _, clan in ipairs(clans) do
                            if clan.logs[uid] then jaLogado = true; break end
                        end
                        if not jaLogado then checkAll(p) end
                    end)
                end
            end

            -- Watchdog: a cada 5s verifica se as conexões ainda estão vivas
            -- se morreram, reconecta na hora
            if watchdogTimer >= 5 then
                watchdogTimer = 0
                if not playerAddedConn or not playerAddedConn.Connected then
                    warn("[Logger] ⚠ playerAddedConn morreu — reconectando...")
                    playerAddedConn = Players.PlayerAdded:Connect(function(p)
                        task.wait(1)
                        checkAll(p)
                    end)
                end
                if not playerRemovedConn or not playerRemovedConn.Connected then
                    warn("[Logger] ⚠ playerRemovedConn morreu — reconectando...")
                    playerRemovedConn = Players.PlayerRemoving:Connect(function(p) onLeave(p) end)
                end
            end

            statusLbl.Text      = "🔴 Gravando... " .. fmtDur(tick() - recStart)
            statusLbl.TextColor3 = Color3.fromRGB(255,80,80)
        else
            autoSaveTimer = 0
            rescanTimer   = 0
            watchdogTimer = 0
        end

        if activeClan then
            clanCountLbl.Text = "👥 " .. (activeClan.total or 0) .. " membros"
            refreshList()
        end

        if autoEnabled then
            if not autoStartFired and H == autoStartH and M == autoStartM then
                autoStartFired = true
                startRecording()
                recBtn.Text            = "⏹  PARAR GRAVAÇÃO  (todos os clãs)"
                recBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
                schedInfo.Text      = string.format("▶ Iniciado automaticamente às %02d:%02d! (%d clã(s))", H, M, #clans)
                schedInfo.TextColor3 = Color3.fromRGB(100,255,150)
            end
            if not autoStopFired and H == autoStopH and M == autoStopM then
                if isRecording then
                    autoStopFired = true
                    stopRecording()
                    recBtn.Text            = "⏺  INICIAR GRAVAÇÃO  (todos os clãs)"
                    recBtn.BackgroundColor3 = Color3.fromRGB(35,165,70)
                    local total = 0
                    for _, c in ipairs(clans) do total = total + (c.total or 0) end
                    schedInfo.Text      = string.format("⏹ Finalizado às %02d:%02d! Total geral: %d membro(s)", H, M, total)
                    schedInfo.TextColor3 = Color3.fromRGB(255,200,80)
                end
            end
        end
    end
end)

print("[Clan Logger] ✅ Carregado! Pasta: " .. CFG.LOG_FOLDER)
