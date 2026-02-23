-- ╔══════════════════════════════════════════════════════════════╗
-- ║         Clan Member Logger  v5.0  —  Potassium              ║
-- ║  Multi-Clã · Prefixo+Sufixo · Arquivo por Clã · Presença   ║
-- ╚══════════════════════════════════════════════════════════════╝

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
local function dateOnly() return os.date("%d-%m-%Y")     end
local function timeOnly() return os.date("%H:%M:%S")     end
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
--  ESTRUTURA DE CLÃS
--  clans = lista de { tag, prefix, suffix, color, logs, file }
--  logs[userId] = { displayName, entryTime, joinTick,
--                   totalSeconds, sessions, idx, online }
-- ══════════════════════════════════════════════════════════════
local clans       = {}   -- lista de clãs ativos
local activeClan  = nil  -- clã selecionado na aba
local isRecording = false
local recStart    = nil
local playerAddedConn   = nil
local playerRemovedConn = nil
local autoEnabled    = false
local autoStartH, autoStartM = 21, 0
local autoStopH,  autoStopM  = 22, 0
local autoStartFired = false
local autoStopFired  = false

-- nome do jogo
local gameName = "N/A"
pcall(function() gameName = MktSvc:GetProductInfo(game.PlaceId).Name end)

-- ══════════════════════════════════════════════════════════════
--  ARQUIVO
-- ══════════════════════════════════════════════════════════════
local function ensureFolder()
    pcall(function()
        if not isfolder(CFG.LOG_FOLDER) then makefolder(CFG.LOG_FOLDER) end
    end)
end

local function safeRead(path)
    local ok, d = pcall(readfile, path); return (ok and d) or nil
end
local function safeWrite(path, content)
    pcall(writefile, path, content)
end

-- nome do arquivo para um clã (um por dia)
local function clanFileName(clan)
    local tag = clan.tag:gsub("[^%w%-]","_")  -- sanitiza
    return CFG.LOG_FOLDER .. "/" .. tag .. "_LOG_" .. dateOnly() .. ".txt"
end

-- ══════════════════════════════════════════════════════════════
--  MATCH  — verifica se DisplayName bate com prefixo/sufixo
-- ══════════════════════════════════════════════════════════════
local function matchesClan(displayName, clan)
    local dn = displayName:upper()
    local pre = (clan.prefix or ""):upper()
    local suf = (clan.suffix or ""):upper()
    local hasPrefix = pre == "" or dn:sub(1, #pre) == pre
    local hasSuffix = suf == "" or dn:sub(-#suf) == suf
    -- precisa ter pelo menos prefixo ou sufixo configurado
    if pre == "" and suf == "" then return false end
    return hasPrefix and hasSuffix
end

-- ══════════════════════════════════════════════════════════════
--  TEMPO REAL
-- ══════════════════════════════════════════════════════════════
local function getCurrentSecs(info)
    local t = info.totalSeconds or 0
    if info.online and info.joinTick then
        t = t + (tick() - info.joinTick)
    end
    return t
end

-- ══════════════════════════════════════════════════════════════
--  BUILD + SAVE por clã
-- ══════════════════════════════════════════════════════════════
local function buildContent(clan, isFinal)
    local lines = {}
    local function w(s) lines[#lines+1] = s end

    local tag = (clan.prefix or "") .. "*" .. (clan.suffix or "")
    w(string.rep("═", 72))
    w("  CLAN MEMBER LOGGER — REGISTRO DE INVASÃO")
    w(string.rep("═", 72))
    w("Data           : " .. dateOnly())
    w("Jogo           : " .. gameName)
    w("Place ID       : " .. tostring(game.PlaceId))
    w("Clã / Tag      : " .. clan.tag)
    w("Padrão         : prefixo=[ " .. (clan.prefix or "") ..
      " ]  sufixo=[ " .. (clan.suffix or "") .. " ]")
    w(string.format("AutoStart      : %02d:%02d", autoStartH, autoStartM))
    w(string.format("AutoStop       : %02d:%02d", autoStopH,  autoStopM))
    w(string.rep("─", 72))
    w(string.format("%-12s | %-26s | %-12s | %-10s | %s",
        "[HORA]","[USUÁRIO]","[USER ID]","[ENTRADA]","[TEMPO TOTAL]"))
    w(string.rep("─", 72))

    local ordered = {}
    for uid, info in pairs(clan.logs) do
        ordered[#ordered+1] = { uid=uid, info=info }
    end
    table.sort(ordered, function(a,b) return (a.info.idx or 0)<(b.info.idx or 0) end)

    for _, entry in ipairs(ordered) do
        local info = entry.info
        local secs = getCurrentSecs(info)
        w(string.format("[%s] | %-26s | %-12s | %-10s | %s %s",
            info.entryTime,
            info.displayName,
            tostring(entry.uid),
            info.entryTime,
            fmtDur(secs),
            info.online and "🟢" or "🔴"
        ))
    end

    w(string.rep("─", 72))
    w("STATUS         : " .. (isFinal and "✔ GRAVAÇÃO FINALIZADA" or
        "⏺ GRAVANDO... (auto-save " .. timeOnly() .. ")"))
    if recStart then
        w("Duração sessão : " .. fmtDur(tick() - recStart))
    end
    w("Fim            : " .. (isFinal and timeOnly() or "--"))
    w("Total logados  : " .. (clan.total or 0) .. " membro(s)")
    w(string.rep("═", 72))
    w("")
    w("  LEGENDA:  🟢 Online no momento do save  |  🔴 Saiu do servidor")
    w(string.rep("═", 72))
    return table.concat(lines,"\n").."\n"
end

local function saveClan(clan, isFinal)
    safeWrite(clan.file, buildContent(clan, isFinal))
end

local function saveAllClans(isFinal)
    for _, clan in ipairs(clans) do
        if clan.total and clan.total > 0 then
            saveClan(clan, isFinal)
        end
    end
end

-- ══════════════════════════════════════════════════════════════
--  PARSER — retomada de arquivo existente
-- ══════════════════════════════════════════════════════════════
local function parseFile(content)
    local players, idx = {}, 0
    for line in content:gmatch("[^\n]+") do
        local t,name,uid,entry,dur = line:match(
            "^%[(%d+:%d+:%d+)%] | (.-) | (%d+) | (%d+:%d+:%d+) | (.-)%s*[🟢🔴]?%s*$")
        if t and name and uid then
            local id = tonumber(uid)
            if id then
                idx = idx + 1
                local secs = 0
                local h2 = dur and dur:match("(%d+)h")
                local m2 = dur and dur:match("(%d+)m")
                local s2 = dur and dur:match("(%d+)s")
                if h2 then secs=secs+tonumber(h2)*3600 end
                if m2 then secs=secs+tonumber(m2)*60   end
                if s2 then secs=secs+tonumber(s2)      end
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

-- ══════════════════════════════════════════════════════════════
--  LOG DE UM JOGADOR num clã específico
-- ══════════════════════════════════════════════════════════════
local function logPlayerToClan(player, clan)
    local uid = player.UserId
    if clan.logs[uid] then
        -- voltou — soma tempo
        local info = clan.logs[uid]
        info.joinTick = tick()
        info.online   = true
        info.sessions = (info.sessions or 1) + 1
        print(string.format("[Logger] 🔄 Voltou: %s → %s (sessão #%d)",
            player.DisplayName, clan.tag, info.sessions))
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
        print(string.format("[Logger] ✓ #%d %s → Clã: %s",
            clan.total, player.DisplayName, clan.tag))
    end
    saveClan(clan, false)
end

-- Verifica jogador em TODOS os clãs ativos
local function checkPlayerAllClans(player)
    for _, clan in ipairs(clans) do
        if matchesClan(player.DisplayName, clan) then
            logPlayerToClan(player, clan)
        end
    end
end

local function onPlayerLeave(player)
    if not isRecording then return end
    local uid = player.UserId
    for _, clan in ipairs(clans) do
        local info = clan.logs[uid]
        if info and info.online and info.joinTick then
            info.totalSeconds = info.totalSeconds + (tick() - info.joinTick)
            info.joinTick     = nil
            info.online       = false
            print(string.format("[Logger] 👋 Saiu: %s | %s | Tempo: %s",
                player.DisplayName, clan.tag, fmtDur(info.totalSeconds)))
            saveClan(clan, false)
        end
    end
end

-- ══════════════════════════════════════════════════════════════
--  START / STOP GRAVAÇÃO
-- ══════════════════════════════════════════════════════════════
local function startRecording()
    if isRecording then return end
    if #clans == 0 then return end

    ensureFolder()
    isRecording = true
    recStart    = tick()

    -- Inicializa/retoma arquivo de cada clã
    for _, clan in ipairs(clans) do
        clan.file  = clanFileName(clan)
        local ex   = safeRead(clan.file)
        if ex and #ex > 0 then
            local saved, n = parseFile(ex)
            clan.logs  = saved
            clan.total = n
            print(string.format("[Logger] 🔄 Clã %s retomado — %d membros.", clan.tag, n))
        else
            clan.logs  = {}
            clan.total = 0
        end
    end

    -- Varre quem já está no servidor
    for _, p in ipairs(Players:GetPlayers()) do
        checkPlayerAllClans(p)
    end

    playerAddedConn = Players.PlayerAdded:Connect(function(p)
        task.wait(0.3)
        checkPlayerAllClans(p)
    end)
    playerRemovedConn = Players.PlayerRemoving:Connect(function(p)
        onPlayerLeave(p)
    end)

    saveAllClans(false)
end

local function stopRecording()
    if not isRecording then return end
    isRecording = false

    -- Congela tempo de quem está online
    for _, p in ipairs(Players:GetPlayers()) do
        local uid = p.UserId
        for _, clan in ipairs(clans) do
            local info = clan.logs[uid]
            if info and info.online and info.joinTick then
                info.totalSeconds = info.totalSeconds + (tick() - info.joinTick)
                info.joinTick = nil
                info.online   = false
            end
        end
    end

    if playerAddedConn   then playerAddedConn:Disconnect();   playerAddedConn   = nil end
    if playerRemovedConn then playerRemovedConn:Disconnect(); playerRemovedConn = nil end

    saveAllClans(true)
    print("[Logger] ⏹ Gravação finalizada para todos os clãs.")
end

-- ══════════════════════════════════════════════════════════════
--  CORES PARA ABAS  (uma cor por clã, até 8)
-- ══════════════════════════════════════════════════════════════
local CLAN_COLORS = {
    Color3.fromRGB(55,130,255),   -- azul
    Color3.fromRGB(80,200,100),   -- verde
    Color3.fromRGB(220,100,60),   -- laranja
    Color3.fromRGB(180,80,220),   -- roxo
    Color3.fromRGB(220,200,50),   -- amarelo
    Color3.fromRGB(60,200,200),   -- ciano
    Color3.fromRGB(220,70,100),   -- vermelho
    Color3.fromRGB(180,140,80),   -- dourado
}

-- ══════════════════════════════════════════════════════════════
--  GUI
-- ══════════════════════════════════════════════════════════════
local prev = game:GetService("CoreGui"):FindFirstChild("ClanLoggerV5")
if prev then prev:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "ClanLoggerV5"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent         = game:GetService("CoreGui")

-- helpers
local function corner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,r or 8); c.Parent=p
end
local function stroke(p, col, th)
    local s = Instance.new("UIStroke"); s.Color=col or Color3.fromRGB(80,120,255); s.Thickness=th or 1.5; s.Parent=p
end
local function lbl(par, pos, sz, txt, ts, col, font, ax)
    local l = Instance.new("TextLabel")
    l.Position=pos; l.Size=sz; l.BackgroundTransparency=1
    l.Text=txt; l.TextSize=ts or 12
    l.TextColor3=col or Color3.fromRGB(210,210,210)
    l.Font=font or Enum.Font.Gotham
    l.TextXAlignment=ax or Enum.TextXAlignment.Left
    l.TextWrapped=true; l.Parent=par; return l
end
local function mkbtn(par, pos, sz, txt, bg, ts)
    local b = Instance.new("TextButton")
    b.Position=pos; b.Size=sz; b.BackgroundColor3=bg or Color3.fromRGB(55,55,85)
    b.Text=txt; b.TextColor3=Color3.fromRGB(255,255,255)
    b.TextSize=ts or 13; b.Font=Enum.Font.GothamBold
    b.BorderSizePixel=0; b.Parent=par; corner(b,7); return b
end
local function mkbox(par, pos, sz, def, ph)
    local b = Instance.new("TextBox")
    b.Position=pos; b.Size=sz; b.BackgroundColor3=Color3.fromRGB(18,18,34)
    b.Text=def or ""; b.PlaceholderText=ph or ""
    b.PlaceholderColor3=Color3.fromRGB(90,90,110)
    b.TextColor3=Color3.fromRGB(255,255,255)
    b.TextSize=13; b.Font=Enum.Font.Gotham
    b.BorderSizePixel=0; b.ClearTextOnFocus=false
    b.TextXAlignment=Enum.TextXAlignment.Center; b.Parent=par
    corner(b,6); stroke(b,Color3.fromRGB(60,70,130),1); return b
end
local function divider(par, y)
    local d=Instance.new("Frame"); d.Size=UDim2.new(1,-24,0,1)
    d.Position=UDim2.new(0,12,0,y); d.BackgroundColor3=Color3.fromRGB(38,38,65)
    d.BorderSizePixel=0; d.Parent=par
end

-- ── Janela ──────────────────────────────────────────────────
local WW, WH = 400, 600

local Main = Instance.new("Frame")
Main.Name="Main"; Main.Size=UDim2.new(0,WW,0,WH)
Main.Position=UDim2.new(0.5,-WW/2,0.5,-WH/2)
Main.BackgroundColor3=Color3.fromRGB(10,10,19)
Main.BorderSizePixel=0; Main.Active=true; Main.Draggable=true; Main.Parent=ScreenGui
corner(Main,12); stroke(Main,Color3.fromRGB(55,95,230),2)

local grad=Instance.new("UIGradient")
grad.Color=ColorSequence.new{
    ColorSequenceKeypoint.new(0,Color3.fromRGB(15,15,30)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(9,9,17)),
}; grad.Rotation=135; grad.Parent=Main

-- Título
local TBar=Instance.new("Frame")
TBar.Size=UDim2.new(1,0,0,44); TBar.BackgroundColor3=Color3.fromRGB(16,16,36)
TBar.BorderSizePixel=0; TBar.Parent=Main; corner(TBar,12)
lbl(TBar,UDim2.new(0,14,0,0),UDim2.new(1,-50,1,0),
    "⬡  Clan Member Logger  v5.0",14,Color3.fromRGB(255,255,255),Enum.Font.GothamBold)

local xBtn=Instance.new("TextButton")
xBtn.Size=UDim2.new(0,26,0,26); xBtn.Position=UDim2.new(1,-34,0,9)
xBtn.BackgroundColor3=Color3.fromRGB(160,35,35); xBtn.Text="✕"
xBtn.TextColor3=Color3.fromRGB(255,255,255); xBtn.TextSize=12
xBtn.Font=Enum.Font.GothamBold; xBtn.BorderSizePixel=0; xBtn.Parent=TBar; corner(xBtn,6)

-- Status / relógio / contador
local statusLbl = lbl(Main,UDim2.new(0,14,0,52),UDim2.new(1,-28,0,20),
    "⚪ Aguardando...",13,Color3.fromRGB(180,180,180),Enum.Font.Gotham)
local clockLbl  = lbl(Main,UDim2.new(1,-155,0,52),UDim2.new(0,141,0,20),
    "🕐 --:--:--",12,Color3.fromRGB(130,190,255),Enum.Font.GothamBold,Enum.TextXAlignment.Right)

divider(Main,78)

-- ══════════════════════════════════════════════════════════════
--  SEÇÃO: ADICIONAR CLÃ
-- ══════════════════════════════════════════════════════════════
lbl(Main,UDim2.new(0,14,0,86),UDim2.new(1,-28,0,18),
    "➕  ADICIONAR CLÃ",12,Color3.fromRGB(255,200,70),Enum.Font.GothamBold)

-- Nome/Tag do clã
lbl(Main,UDim2.new(0,14,0,108),UDim2.new(0,80,0,14),"Nome/Tag",10,Color3.fromRGB(150,150,200))
local tagBox = mkbox(Main,UDim2.new(0,14,0,124),UDim2.new(0,110,0,30),"","ex: CSI")

-- Prefixo
lbl(Main,UDim2.new(0,136,0,108),UDim2.new(0,80,0,14),"Prefixo",10,Color3.fromRGB(150,210,150))
local prefixBox = mkbox(Main,UDim2.new(0,136,0,124),UDim2.new(0,90,0,30),"","ex: CSI_")

-- Sufixo
lbl(Main,UDim2.new(0,238,0,108),UDim2.new(0,80,0,14),"Sufixo",10,Color3.fromRGB(210,150,150))
local suffixBox = mkbox(Main,UDim2.new(0,238,0,124),UDim2.new(0,90,0,30),"","ex: _z")

-- Info auxiliar
local addInfo = lbl(Main,UDim2.new(0,14,0,158),UDim2.new(1,-110,0,14),
    "💡 Prefixo e/ou sufixo. Pode deixar um em branco.",10,Color3.fromRGB(120,120,170))

-- Botão adicionar
local addBtn = mkbtn(Main,UDim2.new(1,-106,0,120),UDim2.new(0,92,0,32),
    "＋ Adicionar",Color3.fromRGB(40,140,70),12)

divider(Main,178)

-- ══════════════════════════════════════════════════════════════
--  ABAS DE CLÃS
-- ══════════════════════════════════════════════════════════════
lbl(Main,UDim2.new(0,14,0,186),UDim2.new(1,-28,0,18),
    "📂  CLÃS ATIVOS",12,Color3.fromRGB(255,200,70),Enum.Font.GothamBold)

-- ScrollFrame horizontal para as abas
local TabScroll = Instance.new("ScrollingFrame")
TabScroll.Size=UDim2.new(1,-24,0,36); TabScroll.Position=UDim2.new(0,12,0,206)
TabScroll.BackgroundTransparency=1; TabScroll.BorderSizePixel=0
TabScroll.ScrollBarThickness=0; TabScroll.ScrollingDirection=Enum.ScrollingDirection.X
TabScroll.CanvasSize=UDim2.new(0,0,0,0); TabScroll.AutomaticCanvasSize=Enum.AutomaticSize.X
TabScroll.Parent=Main

local TabLayout=Instance.new("UIListLayout")
TabLayout.FillDirection=Enum.FillDirection.Horizontal
TabLayout.SortOrder=Enum.SortOrder.LayoutOrder
TabLayout.Padding=UDim.new(0,6); TabLayout.Parent=TabScroll

-- "Nenhum clã" placeholder
local noClansLbl = lbl(TabScroll,UDim2.new(0,0,0,8),UDim2.new(0,200,0,20),
    "Nenhum clã adicionado ainda.",11,Color3.fromRGB(100,100,140))

divider(Main,248)

-- ══════════════════════════════════════════════════════════════
--  PAINEL DO CLÃ SELECIONADO
-- ══════════════════════════════════════════════════════════════
local clanNameLbl = lbl(Main,UDim2.new(0,14,0,256),UDim2.new(0,200,0,18),
    "Selecione um clã acima",12,Color3.fromRGB(160,160,200),Enum.Font.GothamBold)
local clanCountLbl = lbl(Main,UDim2.new(1,-130,0,256),UDim2.new(0,116,0,18),
    "",12,Color3.fromRGB(160,255,160),Enum.Font.GothamBold,Enum.TextXAlignment.Right)
local clanFileLbl = lbl(Main,UDim2.new(0,14,0,274),UDim2.new(1,-28,0,14),
    "",9,Color3.fromRGB(200,170,60))

-- Remover clã
local removeBtn = mkbtn(Main,UDim2.new(1,-100,0,254),UDim2.new(0,86,0,22),
    "🗑 Remover",Color3.fromRGB(130,35,35),10)
removeBtn.Visible=false

-- Header tabela presença
local tHead=Instance.new("Frame")
tHead.Size=UDim2.new(1,-24,0,20); tHead.Position=UDim2.new(0,12,0,292)
tHead.BackgroundColor3=Color3.fromRGB(20,20,42); tHead.BorderSizePixel=0; tHead.Parent=Main
corner(tHead,4)
lbl(tHead,UDim2.new(0,6,0,0),   UDim2.new(0.44,0,1,0),"USUÁRIO",10,Color3.fromRGB(160,160,200),Enum.Font.GothamBold)
lbl(tHead,UDim2.new(0.44,0,0,0),UDim2.new(0,56,1,0),  "ENTRADA",10,Color3.fromRGB(160,160,200),Enum.Font.GothamBold)
lbl(tHead,UDim2.new(1,-80,0,0), UDim2.new(0,74,1,0),  "TEMPO",  10,Color3.fromRGB(160,160,200),Enum.Font.GothamBold,Enum.TextXAlignment.Right)

-- Lista com scroll
local Scroll=Instance.new("ScrollingFrame")
Scroll.Size=UDim2.new(1,-24,0,130); Scroll.Position=UDim2.new(0,12,0,314)
Scroll.BackgroundColor3=Color3.fromRGB(13,13,24); Scroll.BorderSizePixel=0
Scroll.ScrollBarThickness=3; Scroll.ScrollBarImageColor3=Color3.fromRGB(70,90,200)
Scroll.CanvasSize=UDim2.new(0,0,0,0); Scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
Scroll.Parent=Main; corner(Scroll,6); stroke(Scroll,Color3.fromRGB(32,32,60),1)

local ListLayout=Instance.new("UIListLayout")
ListLayout.SortOrder=Enum.SortOrder.LayoutOrder; ListLayout.Padding=UDim.new(0,2); ListLayout.Parent=Scroll
local lPad=Instance.new("UIPadding"); lPad.PaddingTop=UDim.new(0,3)
lPad.PaddingLeft=UDim.new(0,4); lPad.PaddingRight=UDim.new(0,4); lPad.Parent=Scroll

-- Pool de rows
local rows={}
for i=1,18 do
    local row=Instance.new("Frame")
    row.Size=UDim2.new(1,-8,0,22); row.BorderSizePixel=0; row.LayoutOrder=i
    row.BackgroundColor3=(i%2==0) and Color3.fromRGB(17,17,32) or Color3.fromRGB(13,13,24)
    row.Visible=false; row.Parent=Scroll; corner(row,3)
    local dot  = lbl(row,UDim2.new(0,3,0,0),   UDim2.new(0,14,1,0),"🟢",10)
    local name = lbl(row,UDim2.new(0,17,0,0),  UDim2.new(0.46,0,1,0),"",10,Color3.fromRGB(220,220,220))
    local entry= lbl(row,UDim2.new(0.46,0,0,0),UDim2.new(0,56,1,0),"",10,Color3.fromRGB(140,180,140))
    local dur  = lbl(row,UDim2.new(1,-78,0,0), UDim2.new(0,74,1,0),"",10,Color3.fromRGB(255,210,80),Enum.Font.GothamBold,Enum.TextXAlignment.Right)
    rows[i]={frame=row,dot=dot,name=name,entry=entry,dur=dur}
end

divider(Main,452)

-- ══════════════════════════════════════════════════════════════
--  BOTÕES GRAVAR + AGENDAMENTO
-- ══════════════════════════════════════════════════════════════
local recBtn = mkbtn(Main,UDim2.new(0,12,0,460),UDim2.new(1,-24,0,38),
    "⏺  INICIAR GRAVAÇÃO (todos os clãs)",Color3.fromRGB(35,165,70),13)

divider(Main,506)

lbl(Main,UDim2.new(0,14,0,513),UDim2.new(0.5,0,0,14),
    "⏰ AGENDAMENTO",11,Color3.fromRGB(255,200,70),Enum.Font.GothamBold)

-- Boxes horário
lbl(Main,UDim2.new(0,14,0,530),UDim2.new(0,70,0,12),"▶ Início",10,Color3.fromRGB(130,210,130))
lbl(Main,UDim2.new(0.5,4,0,530),UDim2.new(0,70,0,12),"⏹ Fim",10,Color3.fromRGB(210,130,130))

local sH=mkbox(Main,UDim2.new(0,14,0,544),UDim2.new(0,44,0,28),"21")
lbl(Main,UDim2.new(0,61,0,544),UDim2.new(0,12,0,28),":",16,Color3.fromRGB(255,255,255),Enum.Font.GothamBold,Enum.TextXAlignment.Center)
local sM=mkbox(Main,UDim2.new(0,76,0,544),UDim2.new(0,44,0,28),"00")

local eH=mkbox(Main,UDim2.new(0.5,4,0,544),UDim2.new(0,44,0,28),"22")
lbl(Main,UDim2.new(0.5,51,0,544),UDim2.new(0,12,0,28),":",16,Color3.fromRGB(255,255,255),Enum.Font.GothamBold,Enum.TextXAlignment.Center)
local eM=mkbox(Main,UDim2.new(0.5,66,0,544),UDim2.new(0,44,0,28),"00")

local autoBtn=mkbtn(Main,UDim2.new(1,-136,0,540),UDim2.new(0,122,0,36),
    "📅 Ativar",Color3.fromRGB(55,85,200),12)

local schedInfo=lbl(Main,UDim2.new(0,14,0,580),UDim2.new(1,-28,0,16),
    "",10,Color3.fromRGB(180,180,180))
schedInfo.TextXAlignment=Enum.TextXAlignment.Center

-- ══════════════════════════════════════════════════════════════
--  LÓGICA DE ABAS  (dinâmica)
-- ══════════════════════════════════════════════════════════════
local tabButtons = {}  -- { btn, clan }

local function refreshList()
    if not activeClan then
        for _, r in ipairs(rows) do r.frame.Visible=false end
        return
    end
    local ordered={}
    for uid, info in pairs(activeClan.logs) do
        ordered[#ordered+1]={uid=uid,info=info}
    end
    table.sort(ordered,function(a,b) return (a.info.idx or 0)<(b.info.idx or 0) end)
    for i,r in ipairs(rows) do
        local e=ordered[i]
        if e then
            local info=e.info
            r.dot.Text   = info.online and "🟢" or "🔴"
            r.name.Text  = info.displayName
            r.entry.Text = info.entryTime
            r.dur.Text   = fmtDur(getCurrentSecs(info))
            r.frame.Visible=true
        else r.frame.Visible=false end
    end
end

local function selectClan(clan)
    activeClan = clan
    -- atualiza highlight das abas
    for _, tb in ipairs(tabButtons) do
        if tb.clan == clan then
            tb.btn.BackgroundColor3 = tb.clan.color
            stroke(tb.btn, Color3.fromRGB(255,255,255), 1.5)
        else
            tb.btn.BackgroundColor3 = Color3.fromRGB(28,28,50)
            -- remove stroke extra se tiver
            local s=tb.btn:FindFirstChildOfClass("UIStroke")
            if s then s:Destroy() end
        end
    end
    if clan then
        clanNameLbl.Text  = "📁 " .. clan.tag
        clanNameLbl.TextColor3 = clan.color
        clanCountLbl.Text = "👥 " .. (clan.total or 0) .. " membros"
        clanFileLbl.Text  = clan.file ~= "" and clan.file or clanFileName(clan)
        removeBtn.Visible = true
    else
        clanNameLbl.Text  = "Selecione um clã acima"
        clanNameLbl.TextColor3 = Color3.fromRGB(160,160,200)
        clanCountLbl.Text = ""
        clanFileLbl.Text  = ""
        removeBtn.Visible = false
    end
    refreshList()
end

local function rebuildTabs()
    -- limpa botões antigos
    for _, tb in ipairs(tabButtons) do tb.btn:Destroy() end
    tabButtons = {}

    noClansLbl.Visible = #clans == 0

    for i, clan in ipairs(clans) do
        local tb = Instance.new("TextButton")
        tb.Size=UDim2.new(0,0,1,0); tb.AutomaticSize=Enum.AutomaticSize.X
        tb.BackgroundColor3 = (activeClan==clan) and clan.color or Color3.fromRGB(28,28,50)
        tb.Text=" "..clan.tag.." "
        tb.TextColor3=Color3.fromRGB(255,255,255); tb.TextSize=12
        tb.Font=Enum.Font.GothamBold; tb.BorderSizePixel=0
        tb.LayoutOrder=i; tb.Parent=TabScroll
        corner(tb,7)
        if activeClan==clan then stroke(tb,Color3.fromRGB(255,255,255),1.5) end

        local entry={btn=tb,clan=clan}
        tabButtons[#tabButtons+1]=entry

        tb.MouseButton1Click:Connect(function()
            selectClan(clan)
            rebuildTabs()
        end)
    end
end

-- ══════════════════════════════════════════════════════════════
--  ADICIONAR CLÃ
-- ══════════════════════════════════════════════════════════════
addBtn.MouseButton1Click:Connect(function()
    local tag    = tagBox.Text:match("^%s*(.-)%s*$")
    local prefix = prefixBox.Text:match("^%s*(.-)%s*$")
    local suffix = suffixBox.Text:match("^%s*(.-)%s*$")

    if tag == "" then
        addInfo.Text="⚠ Digite um nome/tag para o clã!"
        addInfo.TextColor3=Color3.fromRGB(255,100,100); return
    end
    if prefix == "" and suffix == "" then
        addInfo.Text="⚠ Preencha pelo menos prefixo ou sufixo!"
        addInfo.TextColor3=Color3.fromRGB(255,100,100); return
    end
    -- verifica duplicata
    for _, c in ipairs(clans) do
        if c.tag:upper()==tag:upper() then
            addInfo.Text="⚠ Clã '"..tag.."' já existe!"
            addInfo.TextColor3=Color3.fromRGB(255,180,50); return
        end
    end
    if #clans >= 8 then
        addInfo.Text="⚠ Máximo de 8 clãs simultâneos."
        addInfo.TextColor3=Color3.fromRGB(255,100,100); return
    end

    local newClan = {
        tag    = tag,
        prefix = prefix,
        suffix = suffix,
        color  = CLAN_COLORS[(#clans % #CLAN_COLORS) + 1],
        logs   = {},
        total  = 0,
        file   = "",
    }
    clans[#clans+1] = newClan

    -- limpa campos
    tagBox.Text=""; prefixBox.Text=""; suffixBox.Text=""
    addInfo.Text = string.format("✅ Clã '%s' adicionado! (pref='%s' suf='%s')",
        tag, prefix, suffix)
    addInfo.TextColor3=Color3.fromRGB(100,255,150)

    if not activeClan then selectClan(newClan) end
    rebuildTabs()

    print(string.format("[Logger] ➕ Clã adicionado: %s | pref='%s' suf='%s'",
        tag, prefix, suffix))
end)

-- ══════════════════════════════════════════════════════════════
--  REMOVER CLÃ
-- ══════════════════════════════════════════════════════════════
removeBtn.MouseButton1Click:Connect(function()
    if not activeClan then return end
    if isRecording then
        -- finaliza arquivo deste clã antes de remover
        saveClan(activeClan, true)
    end
    -- remove da lista
    for i, c in ipairs(clans) do
        if c == activeClan then table.remove(clans, i); break end
    end
    activeClan = clans[1] or nil
    selectClan(activeClan)
    rebuildTabs()
    addInfo.Text="🗑 Clã removido."; addInfo.TextColor3=Color3.fromRGB(200,200,200)
end)

-- ══════════════════════════════════════════════════════════════
--  GRAVAR
-- ══════════════════════════════════════════════════════════════
recBtn.MouseButton1Click:Connect(function()
    if #clans == 0 then
        addInfo.Text="⚠ Adicione pelo menos 1 clã antes de gravar!"
        addInfo.TextColor3=Color3.fromRGB(255,100,100); return
    end
    if not isRecording then
        startRecording()
        recBtn.Text="⏹  PARAR GRAVAÇÃO (todos os clãs)"
        recBtn.BackgroundColor3=Color3.fromRGB(200,50,50)
        statusLbl.Text="🔴 Gravando..."; statusLbl.TextColor3=Color3.fromRGB(255,80,80)
    else
        stopRecording()
        recBtn.Text="⏺  INICIAR GRAVAÇÃO (todos os clãs)"
        recBtn.BackgroundColor3=Color3.fromRGB(35,165,70)
        statusLbl.Text="✅ Finalizado!"; statusLbl.TextColor3=Color3.fromRGB(100,255,100)
    end
end)

-- ══════════════════════════════════════════════════════════════
--  AGENDAMENTO
-- ══════════════════════════════════════════════════════════════
autoBtn.MouseButton1Click:Connect(function()
    if not autoEnabled then
        if #clans == 0 then
            schedInfo.Text="⚠ Adicione clãs antes de agendar!"
            schedInfo.TextColor3=Color3.fromRGB(255,100,100); return
        end
        local sh,sm2,eh2,em2=tonumber(sH.Text),tonumber(sM.Text),tonumber(eH.Text),tonumber(eM.Text)
        if not(sh and sm2 and eh2 and em2) or sh>23 or sm2>59 or eh2>23 or em2>59 then
            schedInfo.Text="⚠ Horários inválidos!"; schedInfo.TextColor3=Color3.fromRGB(255,100,100); return
        end
        autoStartH,autoStartM,autoStopH,autoStopM=sh,sm2,eh2,em2
        autoEnabled=true; autoStartFired=false; autoStopFired=false
        sH.TextEditable=false; sM.TextEditable=false; eH.TextEditable=false; eM.TextEditable=false
        autoBtn.Text="❌ Cancelar"; autoBtn.BackgroundColor3=Color3.fromRGB(180,50,50)
        schedInfo.Text=string.format("✅ %02d:%02d → %02d:%02d  |  %d clã(s)",sh,sm2,eh2,em2,#clans)
        schedInfo.TextColor3=Color3.fromRGB(100,255,150)
    else
        autoEnabled=false
        sH.TextEditable=true; sM.TextEditable=true; eH.TextEditable=true; eM.TextEditable=true
        autoBtn.Text="📅 Ativar"; autoBtn.BackgroundColor3=Color3.fromRGB(55,85,200)
        schedInfo.Text="🚫 Agendamento cancelado."; schedInfo.TextColor3=Color3.fromRGB(200,200,200)
    end
end)

xBtn.MouseButton1Click:Connect(function()
    if isRecording then stopRecording() end; ScreenGui:Destroy()
end)

-- ══════════════════════════════════════════════════════════════
--  LOOP PRINCIPAL
-- ══════════════════════════════════════════════════════════════
task.spawn(function()
    local autoSaveTimer=0
    while ScreenGui.Parent do
        task.wait(1)
        local H,M,S=nowH(),nowM(),nowS()
        clockLbl.Text=string.format("🕐 %02d:%02d:%02d",H,M,S)

        if isRecording then
            autoSaveTimer=autoSaveTimer+1
            if autoSaveTimer>=CFG.AUTOSAVE_IV then
                autoSaveTimer=0; saveAllClans(false)
            end
            local elapsed=math.floor(tick()-recStart)
            statusLbl.Text="🔴 Gravando... "..fmtDur(elapsed)
            statusLbl.TextColor3=Color3.fromRGB(255,80,80)
        else autoSaveTimer=0 end

        -- Atualiza painel do clã ativo
        if activeClan then
            clanCountLbl.Text="👥 "..(activeClan.total or 0).." membros"
            refreshList()
        end

        -- Agendamento
        if autoEnabled then
            if not autoStartFired and H==autoStartH and M==autoStartM then
                autoStartFired=true; startRecording()
                recBtn.Text="⏹  PARAR GRAVAÇÃO (todos os clãs)"
                recBtn.BackgroundColor3=Color3.fromRGB(200,50,50)
                schedInfo.Text=string.format("▶ Iniciado às %02d:%02d! (%d clã(s))",H,M,#clans)
                schedInfo.TextColor3=Color3.fromRGB(100,255,150)
            end
            if not autoStopFired and H==autoStopH and M==autoStopM then
                if isRecording then
                    autoStopFired=true; stopRecording()
                    recBtn.Text="⏺  INICIAR GRAVAÇÃO (todos os clãs)"
                    recBtn.BackgroundColor3=Color3.fromRGB(35,165,70)
                    local total=0
                    for _,c in ipairs(clans) do total=total+(c.total or 0) end
                    schedInfo.Text=string.format("⏹ Finalizado às %02d:%02d! Total geral: %d",H,M,total)
                    schedInfo.TextColor3=Color3.fromRGB(255,200,80)
                end
            end
        end
    end
end)

print("[Clan Logger v5.0] ✅ Carregado! Pasta: " .. CFG.LOG_FOLDER)