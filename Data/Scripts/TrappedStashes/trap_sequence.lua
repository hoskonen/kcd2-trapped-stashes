TrappedStashes = TrappedStashes or {}
TrappedStashes.TrapSequence = TrappedStashes.TrapSequence or {}

local TrapSequence = TrappedStashes.TrapSequence
local Debug = TrappedStashes.Debug
local Session = TrappedStashes.LockpickSession
local Audio = TrappedStashes.Audio
local GameOver = TrappedStashes.GameOver

TrapSequence._generation = tonumber(TrapSequence._generation) or 0

local BLOOD_SCREEN_BUFF_ID = "25bb8ae5-4b2a-4d82-aeef-0309d885f147"

local function cfg()
    return TrappedStashes.Config and TrappedStashes.Config.trapSequence or {}
end

local function buffExperimentCfg()
    return TrappedStashes.Config and TrappedStashes.Config.trapBuffExperiment or {}
end

local function gameOverReason()
    local config = TrappedStashes.Config and TrappedStashes.Config.gameOverProof or {}
    return config.reason or GameOver.TrapReason
end

local function ms(value, fallback)
    local number = tonumber(value)
    if number == nil then return fallback end
    if number < 0 then return 0 end
    return number
end

local function schedule(delayMs, callback)
    if type(Script) ~= "table" or type(Script.SetTimer) ~= "function" then
        return false, "Script.SetTimer unavailable"
    end

    Script.SetTimer(delayMs, callback)
    return true, nil
end

local function validSession(session)
    return session ~= nil and session.eligibility ~= nil and
        session.eligibility.eligible == true
end

local function stale(generation, sessionId, phase)
    if generation == TrapSequence._generation then
        return false
    end

    Debug.Trace("trap-sequence stale-callback ignored session=" ..
        tostring(sessionId) .. " phase=" .. tostring(phase))
    return true
end

local function parseUserdataHex(value)
    local text = tostring(value or "")
    local hex = string.match(text, "userdata:%s*([0-9A-Fa-f]+)")
    if hex == nil then return nil end
    return tonumber(hex, 16)
end

local function rawUserId(session)
    local target = session and session.target or nil
    local value = target and target.nUserId or nil
    local number = tonumber(value)
    if number ~= nil and number > 0 then return number, "target.nUserId" end

    local entity = target and target.entity or nil
    value = type(entity) == "table" and entity.nUserId or nil
    number = tonumber(value)
    if number ~= nil and number > 0 then return number, "target.entity.nUserId" end

    if type(Game) == "table" and type(Game.GetPlayerId) == "function" then
        local ok, playerId = pcall(Game.GetPlayerId)
        number = ok and tonumber(playerId) or nil
        if number ~= nil and number > 0 then return number, "Game.GetPlayerId()" end
        number = ok and parseUserdataHex(playerId) or nil
        if number ~= nil and number > 0 then return number, "Game.GetPlayerId():userdata" end
    end

    if type(player) == "table" then
        number = tonumber(player.id)
        if number ~= nil and number > 0 then return number, "player.id" end
        number = parseUserdataHex(player.id)
        if number ~= nil and number > 0 then return number, "player.id:userdata" end
    end

    return nil, "unavailable"
end

local function requestLockpickExit(session)
    local sessionId = session and session.id or nil
    local userId, source = rawUserId(session)

    Debug.Log("trap lockpick-exit requested session=" .. tostring(sessionId) ..
        " rawUserId=" .. tostring(userId) ..
        " source=" .. tostring(source))

    local native = rawget(_G, "Minigame")
    if type(native) ~= "table" or type(native.RequestExit) ~= "function" then
        Debug.Log("trap lockpick-exit result=false session=" ..
            tostring(sessionId) .. " error=Minigame.RequestExit-unavailable")
        return false, "Minigame.RequestExit unavailable"
    end

    if type(userId) ~= "number" then
        Debug.Log("trap lockpick-exit result=false session=" ..
            tostring(sessionId) .. " error=rawUserId-unavailable")
        return false, "rawUserId unavailable"
    end

    local ok, result = pcall(native.RequestExit, userId)
    if not ok then
        Debug.Log("trap lockpick-exit result=false session=" ..
            tostring(sessionId) .. " error=" .. tostring(result))
        return false, result
    end

    Debug.Log("trap lockpick-exit result=" .. tostring(result) ..
        " session=" .. tostring(sessionId))
    return result == true, result
end

local function addBloodScreenBuff(sessionId)
    if type(player) ~= "table" or type(player.soul) ~= "table" or
            type(player.soul.AddBuff) ~= "function" then
        Debug.Log("trap-sequence blood-buff failed session=" ..
            tostring(sessionId) .. " error=player-soul-addbuff-unavailable")
        return false, "player-soul-addbuff-unavailable"
    end

    local ok, result = pcall(function()
        return player.soul:AddBuff(BLOOD_SCREEN_BUFF_ID)
    end)

    if not ok then
        Debug.Log("trap-sequence blood-buff failed session=" ..
            tostring(sessionId) .. " buff=" .. BLOOD_SCREEN_BUFF_ID ..
            " error=" .. tostring(result))
        return false, result
    end

    Debug.Log("trap-sequence blood-buff session=" .. tostring(sessionId) ..
        " buff=" .. BLOOD_SCREEN_BUFF_ID ..
        " result=" .. tostring(result))
    return true, result
end

local function addPlayerBuff(sessionId, buffId, name, index)
    if type(buffId) ~= "string" or buffId == "" then
        Debug.Log("trap-buff-experiment failed session=" .. tostring(sessionId) ..
            " index=" .. tostring(index) .. " error=missing-buff-id")
        return false, "missing-buff-id"
    end

    if type(player) ~= "table" or type(player.soul) ~= "table" or
            type(player.soul.AddBuff) ~= "function" then
        Debug.Log("trap-buff-experiment failed session=" .. tostring(sessionId) ..
            " index=" .. tostring(index) .. " name=" .. tostring(name) ..
            " buff=" .. tostring(buffId) ..
            " error=player-soul-addbuff-unavailable")
        return false, "player-soul-addbuff-unavailable"
    end

    local ok, result = pcall(function()
        return player.soul:AddBuff(buffId)
    end)

    if not ok then
        Debug.Log("trap-buff-experiment failed session=" .. tostring(sessionId) ..
            " index=" .. tostring(index) .. " name=" .. tostring(name) ..
            " buff=" .. tostring(buffId) .. " error=" .. tostring(result))
        return false, result
    end

    Debug.Log("trap-buff-experiment applied session=" .. tostring(sessionId) ..
        " index=" .. tostring(index) .. " name=" .. tostring(name) ..
        " buff=" .. tostring(buffId) .. " result=" .. tostring(result))
    return true, result
end

local function applyBuffExperiment(sessionId)
    local config = buffExperimentCfg()
    if config.enabled ~= true then
        return false, "disabled"
    end

    local buffs = config.buffs
    if type(buffs) ~= "table" then
        Debug.Log("trap-buff-experiment skipped session=" .. tostring(sessionId) ..
            " reason=no-buffs")
        return false, "no-buffs"
    end

    local maxBuffs = tonumber(config.maxBuffs) or 20
    if maxBuffs < 0 then maxBuffs = 0 end

    local applied = 0
    Debug.Log("trap-buff-experiment start session=" .. tostring(sessionId) ..
        " maxBuffs=" .. tostring(maxBuffs))

    for index, entry in ipairs(buffs) do
        if applied >= maxBuffs then
            break
        end

        local buffId = entry
        local name = ""
        if type(entry) == "table" then
            buffId = entry.id or entry.buffId
            name = entry.name or ""
        end

        local ok = addPlayerBuff(sessionId, buffId, name, index)
        if ok then
            applied = applied + 1
        end
    end

    Debug.Log("trap-buff-experiment done session=" .. tostring(sessionId) ..
        " applied=" .. tostring(applied))
    return true, applied
end

function TrapSequence.Reset(reason)
    TrapSequence._generation = TrapSequence._generation + 1
    Debug.Trace("trap-sequence reset reason=" .. tostring(reason or "unknown"))
end

function TrapSequence.Start(session)
    local config = cfg()
    if config.enabled ~= true then
        return false, "disabled"
    end

    if not validSession(session) then
        return false, "not-eligible"
    end

    if not Session.MarkTrapTriggered() then
        Debug.Trace("trap-sequence skipped=session-already-triggered session=" ..
            tostring(session and session.id))
        return false, "already-triggered"
    end

    requestLockpickExit(session)

    TrapSequence._generation = TrapSequence._generation + 1
    local generation = TrapSequence._generation
    local sessionId = session.id
    local soundAtMs = ms(config.soundAtMs, 250)
    local gameOverAtMs = ms(config.gameOverAtMs, 1250)

    Debug.Log("trap-sequence start session=" .. tostring(sessionId) ..
        " soundAtMs=" .. tostring(soundAtMs) ..
        " gameOverAtMs=" .. tostring(gameOverAtMs) ..
        " gameOverEnabled=" .. tostring(config.gameOverEnabled ~= false))

    addBloodScreenBuff(sessionId)
    applyBuffExperiment(sessionId)

    if gameOverAtMs < soundAtMs then
        Debug.Log("trap-sequence config gameOverBeforeSound session=" ..
            tostring(sessionId) .. " soundAtMs=" .. tostring(soundAtMs) ..
            " gameOverAtMs=" .. tostring(gameOverAtMs))
    end

    local okSoundTimer, soundTimerErr = schedule(soundAtMs, function()
        if stale(generation, sessionId, "sound") then return end

        Debug.Log("trap-sequence sound session=" .. tostring(sessionId))
        if Audio and type(Audio.PlayArrowTrapSound) == "function" then
            local ok, result = Audio.PlayArrowTrapSound(session)
            if not ok then
                Debug.Log("trap-sequence sound-failed session=" ..
                    tostring(sessionId) .. " error=" .. tostring(result))
            end
        else
            Debug.Log("trap-sequence sound-failed session=" ..
                tostring(sessionId) .. " error=audio-function-unavailable")
        end
    end)

    if not okSoundTimer then
        Debug.Log("trap-sequence sound-schedule-failed session=" ..
            tostring(sessionId) .. " error=" .. tostring(soundTimerErr))
    end

    if config.gameOverEnabled == false then
        Debug.Log("trap-sequence gameover skipped session=" ..
            tostring(sessionId) .. " reason=disabled")
        return true, nil
    end

    local okGameOverTimer, gameOverTimerErr = schedule(gameOverAtMs, function()
        if stale(generation, sessionId, "gameover") then return end

        Debug.Log("trap-sequence gameover session=" .. tostring(sessionId))
        TrapSequence._generation = TrapSequence._generation + 1
        GameOver.Trigger(gameOverReason())
    end)

    if not okGameOverTimer then
        Debug.Log("trap-sequence gameover-schedule-failed session=" ..
            tostring(sessionId) .. " error=" .. tostring(gameOverTimerErr))
        GameOver.Trigger(gameOverReason())
    end

    return true, nil
end
