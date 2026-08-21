TrappedStashes = TrappedStashes or {}
TrappedStashes.LockpickSession = TrappedStashes.LockpickSession or {}

local Session = TrappedStashes.LockpickSession
local Target = TrappedStashes.LockpickTarget
local Eligibility = TrappedStashes.Eligibility

Session._nextId = tonumber(Session._nextId) or 0
Session._fuseGeneration = tonumber(Session._fuseGeneration) or 0
Session.current = Session.current or nil

local function nextId()
    Session._nextId = Session._nextId + 1
    return Session._nextId
end

local function debug()
    return TrappedStashes.Debug
end

local function timedConfig()
    return (TrappedStashes.Config and TrappedStashes.Config.timedLockTrap) or {}
end

local function modEnabled()
    return not (TrappedStashes.Config and TrappedStashes.Config.enabled == false)
end

local function isEligible(session)
    return session ~= nil and session.eligibility ~= nil and
        session.eligibility.eligible == true
end

local function difficultyText(session)
    local target = session and session.target or nil
    local lock = target and target.lock or nil
    if lock and lock.difficultyRaw ~= nil then
        return tostring(lock.difficultyRaw)
    end
    return "nil"
end

local function normalizeSeconds(value, fallback)
    local number = tonumber(value)
    if number == nil then return fallback end
    if number < 0 then return 0 end
    return number
end

local function fuseRange()
    local config = timedConfig()
    local minSeconds = normalizeSeconds(config.minFuseSeconds, 8)
    local maxSeconds = normalizeSeconds(config.maxFuseSeconds, 14)
    if maxSeconds < minSeconds then
        debug().Log("lock-trap fuse-config maxBelowMin minFuseSeconds=" ..
            tostring(minSeconds) .. " maxFuseSeconds=" .. tostring(maxSeconds))
        minSeconds, maxSeconds = maxSeconds, minSeconds
    end
    return minSeconds, maxSeconds
end

local function rollFuseSeconds()
    local minSeconds, maxSeconds = fuseRange()
    if maxSeconds <= minSeconds then return minSeconds end
    return minSeconds + (math.random() * (maxSeconds - minSeconds))
end

local function scheduleFuse(session, durationSeconds)
    if type(Script) ~= "table" or type(Script.SetTimer) ~= "function" then
        return false, "Script.SetTimer unavailable"
    end

    Session._fuseGeneration = Session._fuseGeneration + 1
    local generation = Session._fuseGeneration
    session.fuseGeneration = generation

    Script.SetTimer(math.floor((durationSeconds * 1000) + 0.5), function()
        local current = Session.current
        if current == nil or current.id ~= session.id or
                current.fuseGeneration ~= generation then
            debug().Trace("lock-trap stale-fuse ignored session=" ..
                tostring(session.id))
            return
        end

        if current.fuseStarted == true and current.armed == true and
                current.trapTriggered ~= true and isEligible(current) then
            Session.TriggerTrap("fuse_timeout")
        end
    end)

    return true, nil
end

function Session.Reset(reason)
    Session.current = nil
    Session._fuseGeneration = Session._fuseGeneration + 1
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
        armed = false,
        fuseStarted = false,
        fuseDuration = nil,
        fuseGeneration = nil,
        trapTriggered = false,
    }

    TrappedStashes.Debug.Log("lockpick-session-start session=" ..
        tostring(Session.current.id) ..
        " source=" .. tostring(Session.current.startNativeEvent) ..
        " startKnown=true")
    Target.Log(target)

    if isEligible(Session.current) then
        Session.current.armed = true
        debug().Log("lock-trap armed session=" ..
            tostring(Session.current.id) ..
            " target=" .. tostring(Session.current.targetId) ..
            " difficulty=" .. difficultyText(Session.current))
    end

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
            armed = false,
            fuseStarted = false,
            fuseDuration = nil,
            fuseGeneration = nil,
            trapTriggered = false,
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
    session.armed = false
    session.fuseStarted = false
    session.fuseDuration = nil
    session.fuseGeneration = nil
    Session._fuseGeneration = Session._fuseGeneration + 1
    return true
end

function Session.CancelFuse(reason)
    local session = Session.current
    if session == nil then return false end

    local hadFuse = session.fuseStarted == true
    session.armed = false
    session.fuseStarted = false
    session.fuseGeneration = nil
    Session._fuseGeneration = Session._fuseGeneration + 1

    if hadFuse then
        debug().Log("lock-trap fuse-cancel session=" ..
            tostring(session.id) .. " reason=" .. tostring(reason))
    end

    return hadFuse
end

function Session.StartFuseFromTurnInput()
    local session = Session.current
    if not modEnabled() or session == nil then return false, "inactive" end
    if timedConfig().enabled ~= true then return false, "disabled" end
    if session.armed ~= true or not isEligible(session) then
        return false, "not-armed"
    end
    if session.fuseStarted == true then return false, "already-started" end
    if session.trapTriggered == true then return false, "already-triggered" end

    local duration = rollFuseSeconds()
    session.fuseStarted = true
    session.fuseDuration = duration

    local ok, err = scheduleFuse(session, duration)
    if not ok then
        session.fuseStarted = false
        session.fuseGeneration = nil
        debug().Log("lock-trap fuse-start-failed session=" ..
            tostring(session.id) .. " error=" .. tostring(err))
        return false, err
    end

    debug().Log("lock-trap fuse-start session=" ..
        tostring(session.id) ..
        " duration=" .. string.format("%.1f", duration) ..
        " reason=lock_dir_fwd")
    return true, nil
end

function Session.TriggerTrap(reason)
    local session = Session.current
    if not modEnabled() then return false, "mod-disabled" end
    if session == nil then return false, "no-session" end
    if session.trapTriggered == true then return false, "already-triggered" end
    if not isEligible(session) then return false, "not-eligible" end

    debug().Log("lock-trap trigger session=" .. tostring(session.id) ..
        " reason=" .. tostring(reason))

    local TrapSequence = TrappedStashes.TrapSequence
    if TrapSequence == nil or type(TrapSequence.Start) ~= "function" then
        debug().Log("ERROR trap-sequence unavailable session=" ..
            tostring(session.id))
        return false, "trap-sequence-unavailable"
    end

    session.triggerReason = reason
    return TrapSequence.Start(session)
end

function Session.End(reason)
    local session = Session.current
    Session.current = nil
    Session._fuseGeneration = Session._fuseGeneration + 1
    return session, reason
end
