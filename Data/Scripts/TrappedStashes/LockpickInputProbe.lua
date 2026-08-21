TrappedStashes = TrappedStashes or {}
TrappedStashes.LockpickInputProbe =
    TrappedStashes.LockpickInputProbe or {}

local Probe = TrappedStashes.LockpickInputProbe
local Debug = TrappedStashes.Debug
local MinigameProbe = TrappedStashes.MinigameProbe
local Session = TrappedStashes.LockpickSession

Probe._original = Probe._original or nil

local ACTIONS = {
    lock_dir_fwd = "turn",
}

local function cfg()
    return (TrappedStashes.Config and TrappedStashes.Config.diagnostics) or {}
end

local function lifecycleLogEnabled()
    return TrappedStashes.Config and
        TrappedStashes.Config.devToggles == true and
        cfg().lockpickInputLifecycleLog == true
end

local function valueText(value)
    if value == nil then return "nil" end
    if type(value) == "table" then return Debug.Handle(value) end
    return tostring(value)
end

local function logLifecycle(action, activation, value)
    if not lifecycleLogEnabled() then return end
    if activation ~= "press" and activation ~= "release" then return end
    if not (MinigameProbe and MinigameProbe._active == true) then return end

    local session = Session and Session.current or nil
    Debug.Log("lock-input-lifecycle action=" .. valueText(action) ..
        " activation=" .. valueText(activation) ..
        " value=" .. valueText(value) ..
        " session=" .. tostring(session and session.id) ..
        " targetId=" .. valueText(MinigameProbe._targetId))
end

local function handleAction(action, activation, value)
    local kind = ACTIONS[action]
    if kind == nil then return end
    logLifecycle(action, activation, value)
    if activation == "release" then
        if not (MinigameProbe and MinigameProbe._active == true) then return end
        if Session and type(Session.TriggerFromTurnRelease) == "function" then
            Session.TriggerFromTurnRelease()
        end
        return
    end
    if activation ~= "press" then return end
    if tonumber(value) ~= nil and tonumber(value) <= 0 then return end
    if not (MinigameProbe and MinigameProbe._active == true) then return end

    if Session and type(Session.StartFuseFromTurnInput) == "function" then
        Session.StartFuseFromTurnInput()
    end
end

function Probe.Reset(reason)
    if Probe._original ~= nil and type(Player) == "table" then
        Player.OnAction = Probe._original
    end

    Debug.Trace("lock-input-probe reset reason=" .. tostring(reason))
end

function Probe.Register()
    if cfg().lockpickInputProbe ~= true then
        Debug.Trace("lock-input-probe disabled")
        return false
    end

    if type(Player) ~= "table" or type(Player.OnAction) ~= "function" then
        Debug.Log("ERROR lock-input-probe unavailable: Player.OnAction missing")
        return false
    end

    Probe._original = Probe._original or Player.OnAction
    local original = Probe._original

    Player.OnAction = function(self, action, activation, value, ...)
        handleAction(action, activation, value)
        return original(self, action, activation, value, ...)
    end

    Debug.Log("lock-input-signal-bound actions=lock_dir_fwd")
    return true
end
