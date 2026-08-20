TrappedStashes = TrappedStashes or {}
TrappedStashes.LockpickSession = TrappedStashes.LockpickSession or {}

local Session = TrappedStashes.LockpickSession
local Target = TrappedStashes.LockpickTarget
local Eligibility = TrappedStashes.Eligibility
local NoLockpickAudit = TrappedStashes.NoLockpickAudit

Session._nextId = tonumber(Session._nextId) or 0
Session.current = Session.current or nil

local function nextId()
    Session._nextId = Session._nextId + 1
    return Session._nextId
end

function Session.Reset(reason)
    Session.current = nil
    TrappedStashes.Debug.Trace("lockpick-session-reset reason=" ..
        tostring(reason or "unknown"))
end

function Session.BeginFromStart(targetId, nativeEvent)
    local target = Target.Resolve(targetId)
    local eligibility = nil
    local eligibilityContext = nil
    local okEligibility, errEligibility = pcall(function()
        eligibility, eligibilityContext = Eligibility.Classify(target)
    end)
    if not okEligibility then
        TrappedStashes.Debug.Log("ERROR eligibility failed error=" ..
            tostring(errEligibility))
        eligibility = {
            eligible = false,
            reasons = { "classifier-error" },
        }
    end

    Session.current = {
        id = nextId(),
        active = true,
        startKnown = true,
        breakCount = 0,
        startNativeEvent = nativeEvent or "Minigame.StartLockPicking",
        targetId = targetId,
        target = target,
        targetCategory = target.category,
        targetResolved = target.resolved,
        eligibility = eligibility,
        eligibilityContext = eligibilityContext,
    }

    TrappedStashes.Debug.Log("lockpick-session-start session=" ..
        tostring(Session.current.id) ..
        " source=" .. tostring(Session.current.startNativeEvent) ..
        " startKnown=true")
    if okEligibility and NoLockpickAudit and
            type(NoLockpickAudit.ObserveEligibility) == "function" then
        NoLockpickAudit.ObserveEligibility(Session.current)
    end
    Target.Log(target)

    return Session.current
end

function Session.EnsureFromResult(nativeEvent)
    if Session.current == nil then
        Session.current = {
            id = nextId(),
            active = true,
            startKnown = false,
            breakCount = 0,
            firstNativeEvent = nativeEvent,
        }
    end

    Session.current.lastNativeEvent = nativeEvent
    return Session.current
end

function Session.RecordBroken(nativeEvent)
    local session = Session.EnsureFromResult(nativeEvent)
    session.breakCount = (tonumber(session.breakCount) or 0) + 1
    return session
end

function Session.MarkTrapTriggered()
    local session = Session.current
    if session == nil then return false end
    if session.trapTriggered then return false end

    session.trapTriggered = true
    return true
end

function Session.End(reason)
    local session = Session.current
    Session.current = nil
    return session, reason
end
