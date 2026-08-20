TrappedStashes = TrappedStashes or {}
TrappedStashes.NoLockpickAudit = TrappedStashes.NoLockpickAudit or {}

local Audit = TrappedStashes.NoLockpickAudit
local Debug = TrappedStashes.Debug

Audit._nextId = tonumber(Audit._nextId) or 0
Audit._current = Audit._current or nil
Audit._originals = Audit._originals or {}

local function cfg()
    return (TrappedStashes.Config and TrappedStashes.Config.diagnostics) or {}
end

local function valueText(value)
    if value == nil then return "nil" end
    if type(value) == "table" then return Debug.Handle(value) end
    return tostring(value)
end

local function safeGet(root, key)
    if type(root) ~= "table" then return nil end

    local ok, value = pcall(function()
        return root[key]
    end)

    if ok then return value end
    return nil
end

local function entityName(entity)
    if type(entity) == "table" and type(entity.GetName) == "function" then
        local ok, value = pcall(entity.GetName, entity)
        if ok then return value end
    end

    return safeGet(entity, "name") or safeGet(entity, "Name")
end

local function entityClass(entity)
    return safeGet(entity, "class") or safeGet(entity, "Class") or
        safeGet(entity, "className") or safeGet(entity, "ClassName")
end

local function targetLine(target)
    if type(target) == "table" then
        return "target=" .. valueText(target.id) ..
            " entity=" .. valueText(target) ..
            " name=" .. valueText(entityName(target)) ..
            " class=" .. valueText(entityClass(target)) ..
            " lockpickCount=unknown"
    end

    return "target=" .. valueText(target) .. " lockpickCount=unknown"
end

local function targetLocked(target)
    if type(target) ~= "table" then return false end
    if target.bLocked == true then return true end

    local properties = safeGet(target, "Properties")
    local lock = safeGet(properties, "Lock")
    return safeGet(lock, "bLocked") == true
end

local function currentMatchesTarget(targetId)
    if Audit._current == nil then return false end
    if targetId == nil then return true end
    return tostring(Audit._current.targetId) == tostring(targetId)
end

local function summary(audit)
    if audit == nil then return end

    Debug.Log("noLockpickAudit summary id=" .. tostring(audit.id) ..
        " target=" .. valueText(audit.targetId) ..
        " StartLockPicking observed=" .. tostring(audit.startObserved == true) ..
        " eligibility evaluated=" .. tostring(audit.eligibilityEvaluated == true) ..
        " result=" .. valueText(audit.result or "none") ..
        " lockpickCount=unknown")
end

local function scheduleSummary(audit)
    if not Script or type(Script.SetTimer) ~= "function" then return end

    local delay = tonumber(cfg().noLockpickAuditSummaryMs) or 1000
    Script.SetTimer(delay, function()
        if Audit._current == audit and audit.summaryLogged ~= true then
            audit.summaryLogged = true
            summary(audit)
        end
    end)
end

function Audit.Reset(reason)
    if type(Stash) == "table" and Audit._originals.Stash_OnUsedHold ~= nil then
        Stash.OnUsedHold = Audit._originals.Stash_OnUsedHold
    end
    if type(Stash) == "table" and Audit._originals.Stash_OnUsed ~= nil then
        Stash.OnUsed = Audit._originals.Stash_OnUsed
    end
    if type(AnimDoor) == "table" and Audit._originals.AnimDoor_Lockpick ~= nil then
        AnimDoor.Lockpick = Audit._originals.AnimDoor_Lockpick
    end

    Audit._current = nil
    Audit._originals = {}
    Debug.Trace("noLockpickAudit reset reason=" .. tostring(reason))
end

function Audit.Begin(source, target)
    Audit._nextId = Audit._nextId + 1
    Audit._current = {
        id = Audit._nextId,
        source = source,
        targetId = type(target) == "table" and target.id or target,
        startObserved = false,
        eligibilityEvaluated = false,
        result = nil,
        summaryLogged = false,
    }

    Debug.Log("noLockpickAudit start id=" .. tostring(Audit._current.id) ..
        " source=" .. tostring(source) ..
        " " .. targetLine(target) ..
        " StartLockPicking observed=false eligibility evaluated=false")

    scheduleSummary(Audit._current)
    return Audit._current
end

function Audit.ObserveStart(targetId)
    local audit = Audit._current
    if audit == nil or not currentMatchesTarget(targetId) then
        audit = Audit.Begin("Minigame.StartLockPicking", targetId)
    end

    audit.startObserved = true
    audit.targetId = targetId or audit.targetId
    Debug.Log("noLockpickAudit StartLockPicking observed=true id=" ..
        tostring(audit.id) .. " target=" .. valueText(audit.targetId))
end

function Audit.ObserveEligibility(session)
    local audit = Audit._current
    if audit == nil then return end
    if session and session.targetId ~= nil and
            not currentMatchesTarget(session.targetId) then
        return
    end

    audit.eligibilityEvaluated = true
    Debug.Log("noLockpickAudit eligibility evaluated=true id=" ..
        tostring(audit.id) .. " target=" .. valueText(audit.targetId))
end

function Audit.ObserveResult(resultName, session)
    local audit = Audit._current
    if audit == nil then return end
    if session and session.targetId ~= nil and
            not currentMatchesTarget(session.targetId) then
        return
    end

    audit.result = resultName
    Debug.Log("noLockpickAudit result=" .. tostring(resultName) ..
        " id=" .. tostring(audit.id) ..
        " target=" .. valueText(audit.targetId) ..
        " StartLockPicking observed=" .. tostring(audit.startObserved == true) ..
        " eligibility evaluated=" ..
            tostring(audit.eligibilityEvaluated == true))

    if audit.summaryLogged ~= true then
        audit.summaryLogged = true
        summary(audit)
    end
end

local function wrapMethod(owner, key, source, shouldBegin)
    if type(owner) ~= "table" or type(owner[key]) ~= "function" then
        return false
    end

    local originalKey = source:gsub("%.", "_")
    if Audit._originals[originalKey] == nil then
        Audit._originals[originalKey] = owner[key]
    end

    local original = Audit._originals[originalKey]
    owner[key] = function(self, ...)
        if shouldBegin == nil or shouldBegin(self, ...) == true then
            Audit.Begin(source, self)
        end
        return original(self, ...)
    end

    return true
end

function Audit.Register()
    if cfg().noLockpickAudit ~= true then
        Debug.Trace("noLockpickAudit disabled")
        return false
    end

    local wrapped = 0
    if wrapMethod(rawget(_G, "Stash"), "OnUsedHold", "Stash.OnUsedHold") then
        wrapped = wrapped + 1
    end
    if wrapMethod(rawget(_G, "Stash"), "OnUsed", "Stash.OnUsed",
            targetLocked) then
        wrapped = wrapped + 1
    end
    if wrapMethod(rawget(_G, "AnimDoor"), "Lockpick", "AnimDoor.Lockpick") then
        wrapped = wrapped + 1
    end

    Debug.Log("noLockpickAudit-bound wrapped=" .. tostring(wrapped) ..
        " sources=Stash.OnUsedHold,Stash.OnUsedLocked,AnimDoor.Lockpick lockpickCount=unknown")
    return wrapped > 0
end
