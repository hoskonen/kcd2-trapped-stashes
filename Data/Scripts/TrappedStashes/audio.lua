TrappedStashes = TrappedStashes or {}
TrappedStashes.Audio = TrappedStashes.Audio or {}

local Audio = TrappedStashes.Audio
local Debug = TrappedStashes.Debug

local function cfg()
    return TrappedStashes.Config and TrappedStashes.Config.trapDeathAudio or {}
end

local function valueText(value)
    if value == nil then return "nil" end
    if type(value) == "table" then return Debug.Handle(value) end
    return tostring(value)
end

local function targetEntity(session)
    return session and session.target and session.target.entity or nil
end

local function playerLinkable()
    if type(player) == "table" then
        if type(player.this) == "table" then return player.this end
        return player
    end

    return nil
end

local function configuredLinkable(session)
    local mode = tostring(cfg().linkable or "player")

    if mode == "target" then
        return targetEntity(session) or playerLinkable(), mode
    end

    if mode == "player" then
        return playerLinkable() or targetEntity(session), mode
    end

    return playerLinkable() or targetEntity(session), mode
end

function Audio.PlayOneShot(triggerName, linkableObject)
    if type(triggerName) ~= "string" or triggerName == "" then
        Debug.Trace("audio skipped reason=missing-trigger")
        return false, "missing-trigger"
    end

    if type(wh) ~= "table" or type(wh.soundmodule) ~= "table" or
            type(wh.soundmodule.AudioOneShot) ~= "function" then
        Debug.Log("ERROR audio unavailable api=wh.soundmodule.AudioOneShot")
        return false, "AudioOneShot unavailable"
    end

    if linkableObject == nil then
        Debug.Log("ERROR audio unavailable reason=missing-linkable trigger=" ..
            tostring(triggerName))
        return false, "missing-linkable"
    end

    local okCall, okOrError, extra = pcall(
        wh.soundmodule.AudioOneShot,
        triggerName,
        linkableObject
    )

    if not okCall then
        Debug.Log("ERROR audio exception trigger=" .. tostring(triggerName) ..
            " linkable=" .. valueText(linkableObject) ..
            " error=" .. tostring(okOrError))
        return false, okOrError
    end

    if okOrError then
        Debug.Log("audio oneshot trigger=" .. tostring(triggerName) ..
            " linkable=" .. valueText(linkableObject))
        return true, extra
    end

    Debug.Log("ERROR audio failed trigger=" .. tostring(triggerName) ..
        " linkable=" .. valueText(linkableObject) ..
        " error=" .. tostring(extra))
    return false, extra
end

function Audio.PlayTrapDeath(session)
    local config = cfg()
    if config.enabled ~= true then
        Debug.Trace("audio trap-death skipped reason=disabled")
        return false, "disabled"
    end

    local linkable, mode = configuredLinkable(session)
    Debug.Trace("audio trap-death begin trigger=" ..
        tostring(config.trigger) .. " linkableMode=" .. tostring(mode))
    return Audio.PlayOneShot(config.trigger, linkable)
end
