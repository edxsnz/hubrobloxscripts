-- ╔══════════════════════════════════════════════════════════════╗
-- ║           Clan Member Logger — CORE (lógica pura)           ║
-- ║  Carregue este arquivo ANTES do playerlogger_ui.lua         ║
-- ╚══════════════════════════════════════════════════════════════╝

-- Evita recarregar se já está rodando
if _G.ClanLogger and _G.ClanLogger._loaded then
    print("[ClanLogger Core] já carregado, ignorando.")
    return
end

-- ══════════════════════════════════════════════════════════════
--  COMPATIBILIDADE CROSS-EXECUTOR
-- ══════════════════════════════════════════════════════════════
local _syn = rawget(getfenv and getfenv() or {}, "syn")

local function _isfolder(p)
    if rawget(getfenv(), "isfolder") then return isfolder(p)
    elseif _syn and _syn.is_folder then return _syn.is_folder(p)
    else return false end
end
local function _makefolder(p)
    if rawget(getfenv(), "makefolder") then return makefolder(p)
    elseif _syn and _syn.make_folder then return _syn.make_folder(p) end
end
local function _writefile(p, c)
    if rawget(getfenv(), "writefile") then return writefile(p, c)
    elseif _syn and _syn.write_file then return _syn.write_file(p, c) end
end

-- ══════════════════════════════════════════════════════════════
--  SERVIÇOS
-- ══════════════════════════════════════════════════════════════
local Players = game:GetService("Players")
local MktSvc  = game:GetService("MarketplaceService")

-- ══════════════════════════════════════════════════════════════
--  CONFIGURAÇÕES
-- ══════════════════════════════════════════════════════════════
local CFG = {
    LOG_FOLDER  = "ClanLogs",
    AUTOSAVE_IV = 5,
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
    if s < 60       then return string.format("%ds", s)
    elseif s < 3600 then return string.format("%dm %02ds", math.floor(s/60), s%60)
    else return string.format("%dh %02dm %02ds", math.floor(s/3600), math.floor((s%3600)/60), s%60)
    end
end

-- ══════════════════════════════════════════════════════════════
--  ESTADO
-- ══════════════════════════════════════════════════════════════
local clans             = {}
local isRecording       = false
local recStart          = nil
local recStartTime      = nil
local playerAddedConn   = nil
local playerRemovedConn = nil
local autoEnabled       = false
local autoStartH, autoStartM = 21, 0
local autoStopH,  autoStopM  = 22, 0
local autoStartFired    = false
local autoStopFired     = false

local gameName = "N/A"
pcall(function() gameName = MktSvc:GetProductInfo(game.PlaceId).Name end)

-- callbacks opcionais para a UI
local _onStateChange = nil  -- function(event, data)

local function emit(event, data)
    if _onStateChange then
        pcall(_onStateChange, event, data or {})
    end
end

-- ══════════════════════════════════════════════════════════════
--  ARQUIVO
-- ══════════════════════════════════════════════════════════════
local function ensureFolder()
    pcall(function()
        if not _isfolder(CFG.LOG_FOLDER) then _makefolder(CFG.LOG_FOLDER) end
    end)
end

local function safeWrite(p, c)
    pcall(_writefile, p, c)
end

local function clanFileName(clan)
    return CFG.LOG_FOLDER .. "/" .. clan.tag:gsub("[^%w%-]","_")
        .. "_LOG_" .. dateOnly() .. "_" .. os.date("%H-%M-%S") .. ".txt"
end

-- ══════════════════════════════════════════════════════════════
--  MATCH
-- ══════════════════════════════════════════════════════════════
local function matchesClan(dn, clan)
    if not dn or dn == "" then return false end
    local d   = dn:upper()
    local pre = (clan.prefix or ""):upper()
    local suf = (clan.suffix or ""):upper()
    if pre == "" and suf == "" then return false end
    local okP = pre == "" or d:sub(1, #pre) == pre
    local okS = suf == "" or d:sub(-#suf)    == suf
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
    w(string.format("%-12s | %-26s | %-12s | %-10s | %s",
        "[HORA]","[USUÁRIO]","[USER ID]","[ENTRADA]","[TEMPO TOTAL]"))
    w(string.rep("─", 72))

    local ord = {}
    for uid, info in pairs(clan.logs) do
        ord[#ord+1] = { uid = uid, info = info }
    end
    table.sort(ord, function(a,b) return (a.info.idx or 0) < (b.info.idx or 0) end)

    for _, e in ipairs(ord) do
        local info = e.info
        w(string.format("[%s] | %-26s | %-12s | %-10s | %s",
            info.entryTime, info.displayName, tostring(e.uid),
            info.entryTime, fmtDur(getCurrentSecs(info))))
    end

    w(string.rep("─", 72))
    w("STATUS         : " .. (isFinal
        and "✔ GRAVAÇÃO FINALIZADA"
        or  "⏺ GRAVANDO... (auto-save " .. timeOnly() .. ")"))
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
    w("  Discord  →  edson_       ID: 1077067290945802271   ")
    w("  Roblox   →  edson6389    ID: 183265855             ")
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
--  GRAVAÇÃO — eventos de jogador
-- ══════════════════════════════════════════════════════════════
local function logPlayerToClan(player, clan)
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
        emit("playerLogged", { clan = clan, uid = uid })
    end
    saveClan(clan, false)
end

local function checkAll(player)
    if not player or not player.Parent then return end
    local uid = player.UserId
    if not uid or uid == 0 then return end
    local dn = player.DisplayName or ""

    if dn == "" then
        task.delay(2, function()
            if not isRecording then return end
            if player and player.Parent then
                local dn2 = player.DisplayName or ""
                if dn2 ~= "" then
                    for _, clan in ipairs(clans) do
                        if matchesClan(dn2, clan) then logPlayerToClan(player, clan) end
                    end
                end
            end
        end)
        return
    end

    for _, clan in ipairs(clans) do
        if matchesClan(dn, clan) then logPlayerToClan(player, clan) end
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
--  CONTROLE DE GRAVAÇÃO
-- ══════════════════════════════════════════════════════════════
local function startRecording()
    if isRecording then return end
    if #clans == 0 then return end
    if playerAddedConn   then playerAddedConn:Disconnect();   playerAddedConn   = nil end
    if playerRemovedConn then playerRemovedConn:Disconnect(); playerRemovedConn = nil end

    ensureFolder()
    isRecording  = true
    recStart     = tick()
    recStartTime = timeOnly()

    for _, clan in ipairs(clans) do
        clan.file  = clanFileName(clan)
        clan.logs  = {}
        clan.total = 0
    end

    for _, p in ipairs(Players:GetPlayers()) do checkAll(p) end

    playerAddedConn   = Players.PlayerAdded:Connect(function(p) task.wait(1); checkAll(p) end)
    playerRemovedConn = Players.PlayerRemoving:Connect(function(p) onLeave(p) end)

    saveAllClans(false)
    emit("recordingStarted", {})
end

local function stopRecording()
    if not isRecording then return end
    isRecording = false

    for _, p in ipairs(Players:GetPlayers()) do
        for _, clan in ipairs(clans) do
            local info = clan.logs[p.UserId]
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
    emit("recordingStopped", {})
end

-- ══════════════════════════════════════════════════════════════
--  LOOP DO CORE (autosave, rescan, watchdog, agendamento)
-- ══════════════════════════════════════════════════════════════
task.spawn(function()
    local autoSaveTimer = 0
    local rescanTimer   = 0
    local watchdogTimer = 0

    while true do
        task.wait(1)
        local H, M, S = nowH(), nowM(), nowS()

        if isRecording then
            autoSaveTimer = autoSaveTimer + 1
            rescanTimer   = rescanTimer   + 1
            watchdogTimer = watchdogTimer + 1

            if autoSaveTimer >= CFG.AUTOSAVE_IV then
                autoSaveTimer = 0
                saveAllClans(false)
            end

            if rescanTimer >= 15 then
                rescanTimer = 0
                for _, p in ipairs(Players:GetPlayers()) do
                    pcall(function()
                        if not p or not p.Parent then return end
                        local jaLogado = false
                        for _, clan in ipairs(clans) do
                            if clan.logs[p.UserId] then jaLogado = true; break end
                        end
                        if not jaLogado then checkAll(p) end
                    end)
                end
            end

            if watchdogTimer >= 5 then
                watchdogTimer = 0
                if not playerAddedConn or not playerAddedConn.Connected then
                    warn("[Logger] ⚠ playerAddedConn morreu — reconectando...")
                    playerAddedConn = Players.PlayerAdded:Connect(function(p) task.wait(1); checkAll(p) end)
                end
                if not playerRemovedConn or not playerRemovedConn.Connected then
                    warn("[Logger] ⚠ playerRemovedConn morreu — reconectando...")
                    playerRemovedConn = Players.PlayerRemoving:Connect(function(p) onLeave(p) end)
                end
            end

            -- tick para a UI atualizar duração
            emit("tick", { H=H, M=M, S=S, elapsed = tick() - (recStart or tick()) })
        else
            autoSaveTimer = 0
            rescanTimer   = 0
            watchdogTimer = 0
            emit("tick", { H=H, M=M, S=S, elapsed=0 })
        end

        -- Agendamento automático
        if autoEnabled then
            if not autoStartFired and H == autoStartH and M == autoStartM then
                autoStartFired = true
                if isRecording then stopRecording() end
                for _, c in ipairs(clans) do c.logs={}; c.total=0; c.file="" end
                startRecording()
                emit("schedStarted", { H=H, M=M })
            end
            if not autoStopFired and H == autoStopH and M == autoStopM then
                if isRecording then
                    autoStopFired = true
                    stopRecording()
                    emit("schedStopped", { H=H, M=M })
                end
            end
            -- reset para o próximo ciclo
            if autoStartFired and autoStopFired then
                if not (H == autoStopH and M == autoStopM) then
                    autoStartFired = false
                    autoStopFired  = false
                end
            end
        end
    end
end)

-- ══════════════════════════════════════════════════════════════
--  API PÚBLICA  (_G.ClanLogger)
-- ══════════════════════════════════════════════════════════════
_G.ClanLogger = {
    _loaded = true,

    -- estado (leitura)
    getClans       = function() return clans end,
    isRecording    = function() return isRecording end,
    getRecStart    = function() return recStart end,
    getGameName    = function() return gameName end,

    -- agendamento (leitura)
    isAutoEnabled  = function() return autoEnabled end,
    getAutoTimes   = function()
        return autoStartH, autoStartM, autoStopH, autoStopM
    end,

    -- ações
    startRecording = startRecording,
    stopRecording  = stopRecording,

    addClan = function(tag, prefix, suffix, color)
        -- valida
        if not tag or tag == "" then return false, "tag vazia" end
        if (prefix or "") == "" and (suffix or "") == "" then
            return false, "prefixo e sufixo vazios"
        end
        for _, c in ipairs(clans) do
            if c.tag:upper() == tag:upper() then return false, "já existe" end
        end
        if #clans >= 8 then return false, "máximo 8 clãs" end

        local COLORS = {
            Color3.fromRGB(55,130,255), Color3.fromRGB(80,200,100),
            Color3.fromRGB(220,100,60), Color3.fromRGB(180,80,220),
            Color3.fromRGB(220,200,50), Color3.fromRGB(60,200,200),
            Color3.fromRGB(220,70,100), Color3.fromRGB(180,140,80),
        }
        local nc = {
            tag    = tag,
            prefix = prefix or "",
            suffix = suffix or "",
            color  = color or COLORS[(#clans % #COLORS) + 1],
            logs   = {},
            total  = 0,
            file   = "",
        }
        clans[#clans+1] = nc
        emit("clanAdded", { clan = nc })
        return true, nc
    end,

    removeClan = function(clan)
        for i, c in ipairs(clans) do
            if c == clan then
                if isRecording then saveClan(c, true) end
                table.remove(clans, i)
                emit("clanRemoved", { clan = c })
                if isRecording and #clans == 0 then stopRecording() end
                return true
            end
        end
        return false
    end,

    setSchedule = function(sh, sm, eh, em)
        if not (sh and sm and eh and em) then return false, "valores nulos" end
        if sh>23 or sm>59 or eh>23 or em>59 then return false, "fora do range" end
        if (eh*60+em) <= (sh*60+sm) then return false, "fim antes do início" end
        autoStartH, autoStartM = sh, sm
        autoStopH,  autoStopM  = eh, em
        autoEnabled    = true
        autoStartFired = false
        autoStopFired  = false
        emit("schedEnabled", { sh=sh, sm=sm, eh=eh, em=em })
        return true
    end,

    cancelSchedule = function()
        autoEnabled = false
        emit("schedDisabled", {})
    end,

    -- helpers expostos
    fmtDur         = fmtDur,
    getCurrentSecs = getCurrentSecs,
    saveClan       = saveClan,
    clanFileName   = clanFileName,

    -- registrar callback de evento
    onEvent = function(fn)
        _onStateChange = fn
    end,
}

print("[ClanLogger Core] ✅ Carregado! Pasta: " .. CFG.LOG_FOLDER)
