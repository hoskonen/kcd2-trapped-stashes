TrappedStashes = TrappedStashes or {}
TrappedStashes.MinigameProbe = TrappedStashes.MinigameProbe or {}

local Probe = TrappedStashes.MinigameProbe
local Debug = TrappedStashes.Debug
local Session = TrappedStashes.LockpickSession
local Target = TrappedStashes.LockpickTarget

Probe._active = Probe._active or false
Probe._targetId = Probe._targetId or nil
Probe._startCount = tonumber(Probe._startCount) or 0
Probe._pollGeneration = tonumber(Probe._pollGeneration) or 0
Probe._originals = Probe._originals or {}

local function cfg()
    return (TrappedStashes.Config and TrappedStashes.Config.diagnostics) or {}
end

local function pack(...)
    return { n = select("#", ...), ... }
end

local function unpackPacked(values)
    return unpack(values, 1, values.n)
end

local function valueText(value)
    if value == nil then return "nil" end
    if type(value) == "table" then return Debug.Handle(value) end
    return tostring(value)
end

local function targetText(targetId)
    if targetId == nil then return "nil" end
    local entity = nil

    if System and type(System.GetEntity) == "function" then
        local ok, value = pcall(System.GetEntity, targetId)
        if ok then entity = value end
    end

    local name = nil
    local class = nil
    local nUserId = nil

    if type(entity) == "table" then
        if type(entity.GetName) == "function" then
            local okName, value = pcall(entity.GetName, entity)
            if okName then name = value end
        end
        if name == nil then name = entity.name end
        class = entity.class or entity.className
        nUserId = entity.nUserId
    end

    return "id=" .. tostring(targetId) ..
        " entity=" .. valueText(entity) ..
        " name=" .. tostring(name) ..
        " class=" .. tostring(class) ..
        " nUserId=" .. tostring(nUserId)
end

local function getTargetNUserId(targetId)
    if targetId == nil or not System or type(System.GetEntity) ~= "function" then
        return nil, "System.GetEntity unavailable"
    end

    local ok, entityOrError = pcall(System.GetEntity, targetId)
    if not ok then
        return nil, entityOrError
    end

    if type(entityOrError) ~= "table" then
        return nil, "entity unavailable"
    end

    return entityOrError.nUserId, nil
end

local function sampleDelayMs()
    return tonumber(cfg().minigameStateSampleMs) or 100
end

local function logLifecycleState(phase, targetId)
    if Target and type(Target.LogLifecycleState) == "function" then
        return Target.LogLifecycleState(phase, targetId)
    end

    Debug.Log("lockpick-lifecycle-state phase=" .. tostring(phase) ..
        " targetId=" .. tostring(targetId) ..
        " error=LockpickTarget-unavailable")
    return nil
end

local function scheduleLifecycleSample(phase, targetId)
    if targetId == nil or type(Script) ~= "table" or
            type(Script.SetTimer) ~= "function" then
        return
    end

    Script.SetTimer(sampleDelayMs(), function()
        logLifecycleState(phase, targetId)
    end)
end

local function markInactive(source, detail)
    local targetId = Probe._targetId
    if not Probe._active then
        Debug.Trace("minigame-probe inactive-event source=" ..
            tostring(source) .. " detail=" .. tostring(detail))
        scheduleLifecycleSample(source .. "+sample", targetId)
        return
    end

    Debug.Log("minigame-probe state active->inactive source=" ..
            tostring(source) .. " targetId=" .. tostring(targetId) ..
        " detail=" .. tostring(detail))
    logLifecycleState(source, targetId)
    scheduleLifecycleSample(source .. "+sample", targetId)

    Probe._active = false
    Probe._targetId = nil
    Probe._seenNonZeroUser = false
    Probe._pollGeneration = Probe._pollGeneration + 1
end

local function pollTarget(generation)
    if generation ~= Probe._pollGeneration or not Probe._active then
        return
    end

    local nUserId, err = getTargetNUserId(Probe._targetId)
    if nUserId ~= nil then
        if Probe._lastNUserId ~= nUserId then
            Debug.Log("minigame-probe target-state targetId=" ..
                tostring(Probe._targetId) .. " nUserId=" .. tostring(nUserId))
            Probe._lastNUserId = nUserId
        end

        if tonumber(nUserId) ~= nil and tonumber(nUserId) ~= 0 then
            Probe._seenNonZeroUser = true
        elseif Probe._seenNonZeroUser then
            markInactive("Lockpickable.nUserId", "returned-to-zero")
            return
        end
    elseif Probe._lastPollError ~= tostring(err) then
        Probe._lastPollError = tostring(err)
        Debug.Log("minigame-probe target-state-unavailable targetId=" ..
            tostring(Probe._targetId) .. " error=" .. tostring(err))
    end

    if Script and type(Script.SetTimer) == "function" then
        Script.SetTimer(tonumber(cfg().minigamePollMs) or 250, function()
            pollTarget(generation)
        end)
    end
end

local function startTargetPoll()
    if cfg().minigameEntityStatePoll ~= true then
        return
    end
    if not Script or type(Script.SetTimer) ~= "function" then
        Debug.Log("ERROR minigame-probe poll unavailable: Script.SetTimer missing")
        return
    end

    Probe._pollGeneration = Probe._pollGeneration + 1
    local generation = Probe._pollGeneration
    Probe._seenNonZeroUser = false
    Probe._lastNUserId = nil
    Probe._lastPollError = nil

    Script.SetTimer(tonumber(cfg().minigamePollMs) or 250, function()
        pollTarget(generation)
    end)
end

local function markActive(source, targetId, detail)
    Probe._startCount = Probe._startCount + 1
    local session = Session.BeginFromStart(targetId, source)
    logLifecycleState(source, targetId)
    scheduleLifecycleSample(source .. "+sample", targetId)

    if Probe._active then
        Debug.Log("minigame-probe state active->active source=" ..
            tostring(source) .. " previousTargetId=" ..
            tostring(Probe._targetId) .. " " .. targetText(targetId) ..
            " session=" .. tostring(session.id) ..
            " detail=" .. tostring(detail))
    else
        Debug.Log("minigame-probe state inactive->active source=" ..
            tostring(source) .. " startCount=" ..
            tostring(Probe._startCount) .. " " .. targetText(targetId) ..
            " session=" .. tostring(session.id) ..
            " detail=" .. tostring(detail))
    end

    Probe._active = true
    Probe._targetId = targetId
    startTargetPoll()
end

local function dumpNativeTable(native)
    local names = {}
    for key in pairs(native) do
        names[#names + 1] = tostring(key) .. ":" .. type(native[key])
    end
    table.sort(names)

    Debug.Log("minigame-probe native-capabilities count=" ..
        tostring(#names) .. " keys=" .. table.concat(names, ","))

    Debug.DumpBounded("minigame-probe.native", native,
        cfg().minigameDumpDepth, cfg().minigameDumpKeys,
        cfg().minigameDumpLines)
end

local function wrapNative(native, name, afterCall)
    if type(native[name]) ~= "function" then
        return false
    end

    if Probe._originals[name] == nil then
        Probe._originals[name] = native[name]
    end

    local original = Probe._originals[name]
    native[name] = function(...)
        local args = pack(...)
        Debug.Log("minigame-probe call " .. tostring(name) ..
            " args=" .. tostring(args.n))
        local ok, result = pcall(function()
            return pack(original(unpackPacked(args)))
        end)

        if not ok then
            Debug.Log("ERROR minigame-probe call-failed " ..
                tostring(name) .. " error=" .. tostring(result))
            error(result)
        end

        if afterCall then
            local okAfter, errAfter = pcall(function()
                return afterCall(result, unpackPacked(args))
            end)
            if not okAfter then
                Debug.Log("ERROR minigame-probe after-call-failed " ..
                    tostring(name) .. " error=" .. tostring(errAfter))
            end
        end

        return unpackPacked(result)
    end

    return true
end

function Probe.Reset(reason)
    local native = rawget(_G, "Minigame")
    if type(native) == "table" then
        for name, original in pairs(Probe._originals or {}) do
            if type(original) == "function" then
                native[name] = original
            end
        end
    end

    Probe._active = false
    Probe._targetId = nil
    Probe._seenNonZeroUser = false
    Probe._pollGeneration = Probe._pollGeneration + 1
    Debug.Trace("minigame-probe reset reason=" .. tostring(reason))
end

function Probe.Register()
    if cfg().minigameProbe ~= true then
        Debug.Trace("minigame-probe disabled")
        return false
    end

    local native = rawget(_G, "Minigame")
    if type(native) ~= "table" then
        Debug.Log("ERROR minigame-probe unavailable: global Minigame is " ..
            type(native))
        return false
    end

    if cfg().minigameDumpNative == true then
        dumpNativeTable(native)
    end

    local wrapped = 0
    if wrapNative(native, "StartLockPicking", function(result, targetId)
        markActive("Minigame.StartLockPicking", targetId,
            "returns=" .. tostring(result.n))
    end) then
        wrapped = wrapped + 1
    end

    for _, name in ipairs({
        "StopLockPicking",
        "Stop",
        "End",
        "Close",
        "RequestExit",
    }) do
        if wrapNative(native, name, function(result, ...)
            markInactive("Minigame." .. name,
                "args=" .. tostring(select("#", ...)) ..
                " returns=" .. tostring(result.n))
        end) then
            wrapped = wrapped + 1
        end
    end

    Debug.Log("minigame-probe-bound wrapped=" .. tostring(wrapped) ..
        " start=StartLockPicking end-candidates=StopLockPicking,Stop,End,Close,RequestExit")
    return wrapped > 0
end
