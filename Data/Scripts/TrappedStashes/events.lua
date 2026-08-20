TrappedStashes = TrappedStashes or {}
TrappedStashes.Events = TrappedStashes.Events or {}

local Events = TrappedStashes.Events
local Debug = TrappedStashes.Debug
local Session = TrappedStashes.LockpickSession
local GameOver = TrappedStashes.GameOver
local NoLockpickAudit = TrappedStashes.NoLockpickAudit

Events._nodes = Events._nodes or {}
Events._connections = Events._connections or {}

local function argCount(...)
    return select("#", ...)
end

local function requireSkald()
    if type(wh) ~= "table" or type(wh.playermodule) ~= "table" then
        Debug.Log("ERROR LuaUtils wh.playermodule unavailable")
        return false
    end

    if type(Skald) ~= "table" or type(SKALD) ~= "table" then
        Debug.Log("ERROR LuaUtils SKALD helpers unavailable")
        return false
    end

    return true
end

local function bindTrigger(node, outputName, callback)
    local ok, connectionOrError, err = pcall(function()
        return node:BindOutput(outputName, callback)
    end)

    if not ok then
        err = connectionOrError
        connectionOrError = nil
    end

    if connectionOrError == nil then
        Debug.Log("ERROR bind-failed output=" .. tostring(outputName) ..
            " error=" .. tostring(err))
        return nil
    end

    Events._connections[#Events._connections + 1] = connectionOrError
    return connectionOrError
end

local function createNode(classTable, args)
    if type(classTable) ~= "table" or type(classTable.Create) ~= "function" then
        Debug.Log("ERROR missing LockpickingResultTrigger class")
        return nil
    end

    local ok, nodeOrError, err = pcall(function()
        return classTable.Create(args or {})
    end)

    if not ok then
        err = nodeOrError
        nodeOrError = nil
    end

    if nodeOrError == nil then
        Debug.Log("ERROR create-failed node=LockpickingResultTrigger error=" ..
            tostring(err))
        return nil
    end

    Events._nodes[#Events._nodes + 1] = nodeOrError
    return nodeOrError
end

local function activateNode(node)
    local okCall, ok, err = pcall(function()
        return node:Activate()
    end)

    if not okCall then
        err = ok
        ok = nil
    end

    if ok then
        Debug.Trace("lockpick-events-activated")
        return true
    end

    Debug.Log("ERROR activate-failed node=LockpickingResultTrigger error=" ..
        tostring(err))
    return false
end

local function lockpickableEntityText(node)
    if type(node) ~= "table" or type(node.LockpickableEntity) ~= "function" then
        return "unavailable"
    end

    local ok, valueOrError = pcall(node.LockpickableEntity, node)
    if not ok then
        return "error:" .. tostring(valueOrError)
    end
    if valueOrError == nil then
        return "nil"
    end

    return Debug.Handle(valueOrError)
end

local function triggerGameOverProof(session)
    local config = TrappedStashes.Config.gameOverProof or {}
    if config.enabled ~= true then
        return
    end
    if session == nil or session.eligibility == nil or
            session.eligibility.eligible ~= true then
        local reasons = session and session.eligibility and
            session.eligibility.reasons or nil
        Debug.Log("trap-test skipped session=" ..
            tostring(session and session.id) ..
            " reason=not-eligible targetCategory=" ..
            tostring(session and session.targetCategory) ..
            " targetId=" .. tostring(session and session.targetId) ..
            " eligibilityReasons=" ..
            tostring(reasons and table.concat(reasons, ",") or "nil"))
        return
    end
    if not Session.MarkTrapTriggered() then
        Debug.Trace("gameover-proof skipped=session-already-triggered session=" ..
            tostring(session and session.id))
        return
    end

    local reason = config.reason or GameOver.TrapReason
    Debug.Log("trap-test trigger session=" .. tostring(session.id) ..
        " reason=" .. tostring(reason))
    GameOver.Trigger(reason)
end

local function sessionTargetText(session)
    if session == nil then
        return " targetCategory=nil targetId=nil"
    end

    return " targetCategory=" .. tostring(session.targetCategory) ..
        " targetId=" .. tostring(session.targetId)
end

function Events.Reset(reason)
    for _, connection in ipairs(Events._connections or {}) do
        if connection and type(connection.Disconnect) == "function" then
            pcall(connection.Disconnect, connection)
        end
    end

    for _, node in ipairs(Events._nodes or {}) do
        if node then
            if type(node.Deactivate) == "function" then
                pcall(node.Deactivate, node)
            end
            if type(node.Destroy) == "function" then
                pcall(node.Destroy, node)
            elseif type(node.Release) == "function" then
                pcall(node.Release, node)
            end
        end
    end

    Events._connections = {}
    Events._nodes = {}
    Session.Reset(reason)
end

function Events.RegisterLockpicking()
    if not requireSkald() then
        return false
    end

    local node = createNode(wh.playermodule.LockpickingResultTrigger, {
        IsActive = true,
    })
    if not node then return false end

    local bound = 0

    if bindTrigger(node, "OnFailed", function(...)
        local session = Session.RecordBroken("OnFailed")
        if NoLockpickAudit and
                type(NoLockpickAudit.ObserveResult) == "function" then
            NoLockpickAudit.ObserveResult("failed", session)
        end
        Debug.Log("lockpick-broken count=" .. tostring(session.breakCount) ..
            " session=" .. tostring(session.id) ..
            " startKnown=" .. tostring(session.startKnown) ..
            sessionTargetText(session) ..
            " native=OnFailed args=" .. tostring(argCount(...)) ..
            " lockpickable=" .. lockpickableEntityText(node))
        triggerGameOverProof(session)
    end) then
        bound = bound + 1
    end

    if bindTrigger(node, "OnLockpicked", function(...)
        local session = Session.EnsureFromResult("OnLockpicked")
        if NoLockpickAudit and
                type(NoLockpickAudit.ObserveResult) == "function" then
            NoLockpickAudit.ObserveResult("lockpicked", session)
        end
        Debug.Log("lockpick-success breakCount=" ..
            tostring(session.breakCount or 0) ..
            " session=" .. tostring(session.id) ..
            " startKnown=" .. tostring(session.startKnown) ..
            sessionTargetText(session) ..
            " native=OnLockpicked args=" .. tostring(argCount(...)) ..
            " lockpickable=" .. lockpickableEntityText(node))
        Session.End("success")
    end) then
        bound = bound + 1
    end

    if bindTrigger(node, "OnInterrupted", function(...)
        local session = Session.EnsureFromResult("OnInterrupted")
        if NoLockpickAudit and
                type(NoLockpickAudit.ObserveResult) == "function" then
            NoLockpickAudit.ObserveResult("interrupted", session)
        end
        Debug.Log("lockpick-interrupted breakCount=" ..
            tostring(session.breakCount or 0) ..
            " session=" .. tostring(session.id) ..
            " startKnown=" .. tostring(session.startKnown) ..
            sessionTargetText(session) ..
            " native=OnInterrupted args=" .. tostring(argCount(...)) ..
            " lockpickable=" .. lockpickableEntityText(node))
        Session.End("interrupted")
    end) then
        bound = bound + 1
    end

    if not activateNode(node) then
        return false
    end

    Debug.Log("lockpick-events-bound count=" .. tostring(bound) ..
        " outputs=OnFailed,OnLockpicked,OnInterrupted")
    return bound == 3
end
