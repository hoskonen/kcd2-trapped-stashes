TrappedStashes = TrappedStashes or {}
TrappedStashes.TrapSequence = TrappedStashes.TrapSequence or {}

local TrapSequence = TrappedStashes.TrapSequence
local Debug = TrappedStashes.Debug
local Session = TrappedStashes.LockpickSession
local GameOver = TrappedStashes.GameOver
local TrapEffects = TrappedStashes.TrapEffects

TrapSequence._generation = tonumber(TrapSequence._generation) or 0

local function cfg()
    return TrappedStashes.Config and TrappedStashes.Config.trapSequence or {}
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

    if TrapEffects and type(TrapEffects.ApplyBloodEffect) == "function" then
        TrapEffects.ApplyBloodEffect(sessionId)
    end
    if TrapEffects and type(TrapEffects.ApplyBuffExperiment) == "function" then
        TrapEffects.ApplyBuffExperiment(sessionId)
    end

    if gameOverAtMs < soundAtMs then
        Debug.Log("trap-sequence config gameOverBeforeSound session=" ..
            tostring(sessionId) .. " soundAtMs=" .. tostring(soundAtMs) ..
            " gameOverAtMs=" .. tostring(gameOverAtMs))
    end

    local okSoundTimer, soundTimerErr = schedule(soundAtMs, function()
        if stale(generation, sessionId, "sound") then return end

        Debug.Log("trap-sequence sound session=" .. tostring(sessionId))
        if TrapEffects and type(TrapEffects.PlayArrowSound) == "function" then
            local ok, result = TrapEffects.PlayArrowSound(session)
            if not ok then
                Debug.Log("trap-sequence sound-failed session=" ..
                    tostring(sessionId) .. " error=" .. tostring(result))
            end
        else
            Debug.Log("trap-sequence sound-failed session=" ..
                tostring(sessionId) .. " error=trap-effects-unavailable")
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
