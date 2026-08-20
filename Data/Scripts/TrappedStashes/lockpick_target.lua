TrappedStashes = TrappedStashes or {}
TrappedStashes.LockpickTarget = TrappedStashes.LockpickTarget or {}

local Target = TrappedStashes.LockpickTarget
local Debug = TrappedStashes.Debug

local FIELD_SPECS = {
    {
        key = "generatedInventory",
        label = "sGeneratedInventory",
        names = { "sGeneratedInventory", "generatedInventory", "GeneratedInventory" },
    },
    {
        key = "chestContextLabel",
        label = "esChestContextLabel",
        names = { "esChestContextLabel", "chestContextLabel", "ChestContextLabel" },
    },
    {
        key = "inventoryWuid",
        label = "inventoryWuid",
        names = {
            "inventoryId",
            "InventoryId",
            "inventoryWuid",
            "InventoryWuid",
            "inventoryWUID",
            "InventoryWUID",
            "GetInventoryId",
            "GetInventoryWuid",
            "GetInventoryWUID",
            "GetInventoryToOpen",
        },
    },
}

local LOCK_SPECS = {
    { key = "bLocked", names = { "bLocked", "locked", "Locked", "IsLocked" } },
    { key = "bCanLockPick", names = { "bCanLockPick", "canLockPick", "CanLockPick" } },
    { key = "fLockDifficulty", names = { "fLockDifficulty", "lockDifficulty", "GetLockDifficulty" } },
    { key = "bLockDifficultyOverride", names = { "bLockDifficultyOverride", "lockDifficultyOverride" } },
    { key = "esLockFanciness", names = { "esLockFanciness", "lockFanciness", "LockFanciness" } },
    { key = "bLockFancinessOverride", names = { "bLockFancinessOverride", "lockFancinessOverride" } },
    { key = "guidItemClassId", names = { "guidItemClassId", "keyGuid", "KeyGuid" } },
}

local LOCK_DIFFICULTY_TIERS = {
    { min = 0.8, tier = "veryHard", prompt = "ui_hud_lockpick_difficulty_5" },
    { min = 0.6, tier = "hard", prompt = "ui_hud_lockpick_difficulty_4" },
    { min = 0.4, tier = "medium", prompt = "ui_hud_lockpick_difficulty_3" },
    { min = 0.2, tier = "easy", prompt = "ui_hud_lockpick_difficulty_2" },
    { min = 0.0, tier = "veryEasy", prompt = "ui_hud_lockpick_difficulty_1" },
}

local ROOTS = {
    { label = "entity", path = {} },
    { label = "entity.Properties", path = { "Properties" } },
    { label = "entity.Properties.Lock", path = { "Properties", "Lock" } },
    { label = "entity.Properties.Database", path = { "Properties", "Database" } },
    { label = "entity.PropertiesInstance", path = { "PropertiesInstance" } },
    { label = "entity.PropertiesInstance.Lock", path = { "PropertiesInstance", "Lock" } },
    { label = "entity.PropertiesInstance.Database", path = { "PropertiesInstance", "Database" } },
    { label = "entity.stash", path = { "stash" } },
    { label = "entity.stash.Properties", path = { "stash", "Properties" } },
    { label = "entity.stash.PropertiesInstance", path = { "stash", "PropertiesInstance" } },
    { label = "entity.lockBase", path = { "lockBase" } },
    { label = "entity.lockBase.Properties", path = { "lockBase", "Properties" } },
    { label = "entity.lockBase.PropertiesInstance", path = { "lockBase", "PropertiesInstance" } },
    { label = "entity.inventory", path = { "inventory" } },
    { label = "entity.inventory.Properties", path = { "inventory", "Properties" } },
    { label = "entity.inventory.PropertiesInstance", path = { "inventory", "PropertiesInstance" } },
}

local function safeGet(root, key)
    if type(root) ~= "table" then return nil end

    local ok, value = pcall(function()
        return root[key]
    end)

    if ok then return value end
    return nil
end

local function safeCall(object, methodName)
    if type(object) ~= "table" then return nil end

    local method = safeGet(object, methodName)
    if type(method) ~= "function" then return nil end

    local ok, value = pcall(method, object)
    if ok then return value end
    return nil
end

local function readPath(root, path)
    local value = root
    for _, key in ipairs(path) do
        value = safeGet(value, key)
        if value == nil then return nil end
    end
    return value
end

local function findNamedValue(entity, names)
    for _, root in ipairs(ROOTS) do
        local object = readPath(entity, root.path)
        if object ~= nil then
            for _, name in ipairs(names) do
                local value = safeGet(object, name)
                if value ~= nil then
                    return value, root.label .. "." .. name
                end

                value = safeCall(object, name)
                if value ~= nil then
                    return value, root.label .. ":" .. name .. "()"
                end
            end
        end
    end

    return nil, nil
end

local function valueText(value)
    if value == nil then return "nil" end
    if type(value) == "table" then return Debug.Handle(value) end
    return tostring(value)
end

local function entityName(entity)
    local value = safeCall(entity, "GetName")
    if value ~= nil then return value end
    return safeGet(entity, "name") or safeGet(entity, "Name")
end

local function entityClass(entity)
    return safeGet(entity, "class") or safeGet(entity, "Class") or
        safeGet(entity, "className") or safeGet(entity, "ClassName")
end

local function cryEntityId(entity, targetId)
    return safeGet(entity, "id") or safeGet(entity, "Id") or
        safeCall(entity, "GetId") or safeCall(entity, "GetEntityId") or targetId
end

local function classify(entity)
    local class = tostring(entityClass(entity) or ""):lower()
    local lockType = tostring(safeGet(entity, "LockType") or ""):lower()

    if class == "animdoor" or lockType == "door" then
        return "AnimDoor"
    end

    if class == "stash" or class == "cartstash" or
            class == "destrostash" or class == "shootablestashbase" or
            lockType == "chest" or lockType == "cartchest" or
            safeGet(entity, "stash") ~= nil or
            safeGet(safeGet(entity, "Properties"), "Database") ~= nil then
        return "Stash"
    end

    return "other"
end

local function readLockMetadata(entity)
    local lock = {
        fields = {},
    }

    for _, spec in ipairs(LOCK_SPECS) do
        local value, source = findNamedValue(entity, spec.names)
        lock[spec.key] = value
        lock.fields[spec.key] = {
            value = value,
            source = source,
        }
    end

    local raw = tonumber(lock.fLockDifficulty)
    lock.difficultyRaw = raw
    lock.difficultyTier = "unknown"
    lock.difficultyPrompt = "unknown"

    if raw ~= nil then
        for _, tier in ipairs(LOCK_DIFFICULTY_TIERS) do
            if raw >= tier.min then
                lock.difficultyTier = tier.tier
                lock.difficultyPrompt = tier.prompt
                break
            end
        end
    end

    return lock
end

function Target.Resolve(targetId)
    local entity = nil
    local errorText = nil

    if System and type(System.GetEntity) == "function" then
        local ok, entityOrError = pcall(System.GetEntity, targetId)
        if ok then
            entity = entityOrError
        else
            errorText = tostring(entityOrError)
        end
    else
        errorText = "System.GetEntity unavailable"
    end

    local snapshot = {
        targetId = targetId,
        entity = entity,
        resolved = type(entity) == "table",
        resolveError = errorText,
        entityName = entityName(entity),
        entityClass = entityClass(entity),
        cryEntityId = cryEntityId(entity, targetId),
        nUserId = safeGet(entity, "nUserId"),
        lockType = safeGet(entity, "LockType"),
        category = classify(entity),
        lock = readLockMetadata(entity),
        stash = nil,
    }

    if snapshot.category == "Stash" then
        snapshot.stash = {
            fields = {},
        }
        for _, spec in ipairs(FIELD_SPECS) do
            local value, source = findNamedValue(entity, spec.names)
            snapshot.stash[spec.key] = value
            snapshot.stash.fields[spec.key] = {
                label = spec.label,
                value = value,
                source = source,
            }
        end
    end

    return snapshot
end

function Target.SummaryLine(snapshot)
    snapshot = snapshot or {}
    local lock = snapshot.lock or {}
    local stash = snapshot.stash or {}

    local line = "lockpick-target" ..
        " category=" .. valueText(snapshot.category) ..
        " targetId=" .. valueText(snapshot.targetId) ..
        " cryEntityId=" .. valueText(snapshot.cryEntityId) ..
        " name=" .. valueText(snapshot.entityName) ..
        " class=" .. valueText(snapshot.entityClass) ..
        " lockType=" .. valueText(snapshot.lockType) ..
        " nUserId=" .. valueText(snapshot.nUserId) ..
        " lock.bLocked=" .. valueText(lock.bLocked) ..
        " lock.bCanLockPick=" .. valueText(lock.bCanLockPick) ..
        " lock.fLockDifficulty=" .. valueText(lock.fLockDifficulty) ..
        " lockDifficultyRaw=" .. valueText(lock.difficultyRaw) ..
        " lockDifficultyTier=" .. valueText(lock.difficultyTier) ..
        " lockDifficultyPrompt=" .. valueText(lock.difficultyPrompt) ..
        " lock.esLockFanciness=" .. valueText(lock.esLockFanciness) ..
        " lock.guidItemClassId=" .. valueText(lock.guidItemClassId)

    if snapshot.category == "Stash" then
        line = line ..
            " stash.sGeneratedInventory=" ..
                valueText(stash.generatedInventory) ..
            " stash.esChestContextLabel=" ..
                valueText(stash.chestContextLabel) ..
            " stash.inventoryWuid=" ..
                valueText(stash.inventoryWuid)
    end

    return line
end

function Target.Log(snapshot)
    Debug.Log(Target.SummaryLine(snapshot))

    if snapshot and snapshot.category == "Stash" then
        local stash = snapshot.stash or {}
        Debug.Log("id-domains cryEntityId=" ..
            valueText(snapshot.cryEntityId) ..
            " inventoryWuid=" .. valueText(stash.inventoryWuid) ..
            " note=inventoryWuid-is-not-CryEntityId")

        for _, spec in ipairs(FIELD_SPECS) do
            local info = stash.fields and stash.fields[spec.key]
            if info and info.source ~= nil then
                Debug.Log("stash-field key=" .. spec.label ..
                    " source=" .. info.source ..
                    " value=" .. valueText(info.value))
            end
        end
    end

    local lock = snapshot and snapshot.lock or {}
    for _, spec in ipairs(LOCK_SPECS) do
        local info = lock.fields and lock.fields[spec.key]
        if info and info.source ~= nil then
            Debug.Log("lock-field key=" .. spec.key ..
                " source=" .. info.source ..
                " value=" .. valueText(info.value))
        end
    end
end
