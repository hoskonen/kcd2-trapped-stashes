TrappedStashes = TrappedStashes or {}
TrappedStashes.TrapEffects = TrappedStashes.TrapEffects or {}

local TrapEffects = TrappedStashes.TrapEffects
local Debug = TrappedStashes.Debug
local Audio = TrappedStashes.Audio

local BLOOD_SCREEN_BUFF_ID = "25bb8ae5-4b2a-4d82-aeef-0309d885f147"
local CROSSBOW_HIT_SCREEN_BUFF_ID = "d2869698-6eaf-4d3e-952c-22143344d8a2"
local AUTHORED_RAGDOLL_BUFF_ID = "15875b20-6a75-47e2-89fc-5c5f2173a4a8"

local function log(message)
    if Debug and type(Debug.Log) == "function" then
        Debug.Log(message)
    elseif System and type(System.LogAlways) == "function" then
        System.LogAlways("[TrappedStashes] " .. tostring(message))
    end
end

local function cfg()
    return TrappedStashes.Config or {}
end

local function effectsCfg()
    return cfg().effects or {}
end

local function buffExperimentCfg()
    return cfg().trapBuffExperiment or {}
end

local function getPlayerSoul()
    local user = rawget(_G, "player")
    if type(user) == "table" and type(user.soul) == "table" then
        return user.soul
    end

    return nil
end

local function addPlayerBuff(sessionId, buffId, name, index)
    if type(buffId) ~= "string" or buffId == "" then
        log("trap-effect buff failed session=" .. tostring(sessionId) ..
            " index=" .. tostring(index) .. " error=missing-buff-id")
        return false, "missing-buff-id"
    end

    local soul = getPlayerSoul()
    if soul == nil or type(soul.AddBuff) ~= "function" then
        log("trap-effect buff failed session=" .. tostring(sessionId) ..
            " index=" .. tostring(index) .. " name=" .. tostring(name) ..
            " buff=" .. tostring(buffId) ..
            " error=player-soul-addbuff-unavailable")
        return false, "player-soul-addbuff-unavailable"
    end

    local ok, result = pcall(function()
        return soul:AddBuff(buffId)
    end)

    if not ok then
        log("trap-effect buff failed session=" .. tostring(sessionId) ..
            " index=" .. tostring(index) .. " name=" .. tostring(name) ..
            " buff=" .. tostring(buffId) .. " error=" .. tostring(result))
        return false, result
    end

    log("trap-effect buff applied session=" .. tostring(sessionId) ..
        " index=" .. tostring(index) .. " name=" .. tostring(name) ..
        " buff=" .. tostring(buffId) .. " result=" .. tostring(result))
    return true, result
end

function TrapEffects.Reset(reason)
    if Debug and type(Debug.Trace) == "function" then
        Debug.Trace("trap-effects reset reason=" .. tostring(reason or "unknown"))
    end
end

function TrapEffects.PlayArrowSound(session)
    if Audio == nil or type(Audio.PlayArrowTrapSound) ~= "function" then
        log("trap-effect sound result=false error=audio-function-unavailable")
        return false, "audio-function-unavailable"
    end

    return Audio.PlayArrowTrapSound(session)
end

function TrapEffects.ApplyBloodEffect(sessionId)
    if effectsCfg().blood == false then
        log("trap-effect blood skipped session=" .. tostring(sessionId) ..
            " reason=disabled")
        return false, "disabled"
    end

    local ok, result = addPlayerBuff(
        sessionId,
        BLOOD_SCREEN_BUFF_ID,
        "trappedstashes_blood_screen",
        "blood"
    )

    if ok then
        log("trap-effect blood session=" .. tostring(sessionId) ..
            " buff=" .. BLOOD_SCREEN_BUFF_ID)
    end

    return ok, result
end

function TrapEffects.ApplyCrossbowHitEffect(sessionId, audioProfile)
    if effectsCfg().crossbowHitBlood == false then
        log("trap-effect crossbow-hit skipped session=" .. tostring(sessionId) ..
            " reason=disabled")
        return false, "disabled"
    end

    if audioProfile ~= nil and tostring(audioProfile.type) ~= "crossbow" then
        return false, "not-crossbow"
    end

    local ok, result = addPlayerBuff(
        sessionId,
        CROSSBOW_HIT_SCREEN_BUFF_ID,
        "trappedstashes_crossbow_hit_screen",
        "crossbow-hit"
    )

    if ok then
        log("trap-effect crossbow-hit session=" .. tostring(sessionId) ..
            " buff=" .. CROSSBOW_HIT_SCREEN_BUFF_ID)
    end

    return ok, result
end

function TrapEffects.ApplyBuffExperiment(sessionId)
    local config = buffExperimentCfg()
    if config.enabled ~= true then
        return false, "disabled"
    end

    local buffs = config.buffs
    if type(buffs) ~= "table" then
        log("trap-buff-experiment skipped session=" .. tostring(sessionId) ..
            " reason=no-buffs")
        return false, "no-buffs"
    end

    local maxBuffs = tonumber(config.maxBuffs) or 20
    if maxBuffs < 0 then maxBuffs = 0 end

    local applied = 0
    log("trap-buff-experiment start session=" .. tostring(sessionId) ..
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

    log("trap-buff-experiment done session=" .. tostring(sessionId) ..
        " applied=" .. tostring(applied))
    return true, applied
end

function TrapEffects.ApplyRagdollEffect(sessionId)
    if effectsCfg().ragdoll ~= true then
        return false, "disabled"
    end

    return addPlayerBuff(
        sessionId,
        AUTHORED_RAGDOLL_BUFF_ID,
        "trappedstashes_ragdoll_authored",
        "ragdoll"
    )
end

function TrapEffects.TestAuthoredRagdoll()
    local ok, result = addPlayerBuff(
        "debug",
        AUTHORED_RAGDOLL_BUFF_ID,
        "trappedstashes_ragdoll_authored",
        "debug"
    )
    log("ragdoll-authored buff=" .. tostring(AUTHORED_RAGDOLL_BUFF_ID) ..
        " attempted=true result=" .. tostring(ok) ..
        " detail=" .. tostring(result))
    return ok
end

function TrapEffects.TestBloodScreen()
    local ok, result = addPlayerBuff(
        "debug",
        BLOOD_SCREEN_BUFF_ID,
        "trappedstashes_blood_screen",
        "debug"
    )
    log("blood-screen-test buff=" .. tostring(BLOOD_SCREEN_BUFF_ID) ..
        " attempted=true result=" .. tostring(ok) ..
        " detail=" .. tostring(result))
    return ok
end

function TrapEffects.TestCrossbowHitScreen()
    local ok, result = addPlayerBuff(
        "debug",
        CROSSBOW_HIT_SCREEN_BUFF_ID,
        "trappedstashes_crossbow_hit_screen",
        "debug"
    )
    log("crossbow-hit-screen-test buff=" ..
        tostring(CROSSBOW_HIT_SCREEN_BUFF_ID) ..
        " attempted=true result=" .. tostring(ok) ..
        " detail=" .. tostring(result))
    return ok
end
