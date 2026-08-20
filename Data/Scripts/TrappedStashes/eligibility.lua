TrappedStashes = TrappedStashes or {}
TrappedStashes.Eligibility = TrappedStashes.Eligibility or {}

local Eligibility = TrappedStashes.Eligibility
local Debug = TrappedStashes.Debug

local AUDIO_CLASSES = {
    AudioAreaAmbience = true,
    AudioAreaEntity = true,
    AudioAreaRandom = true,
}

local REASON_ORDER = {
    "not-stash",
    "not-locked",
    "not-lockpickable",
    "not-chest-like",
    "no-forest",
    "no-bandit-or-ruffian-social-class",
}

local function valueText(value)
    if value == nil then return "nil" end
    return tostring(value)
end

local function lowerText(value)
    return string.lower(tostring(value or ""))
end

local function containsText(value, needle)
    return string.find(lowerText(value), needle, 1, true) ~= nil
end

local function boolValue(value)
    if value == true or value == 1 then return true end
    if value == false or value == 0 then return false end
    local lower = lowerText(value)
    if lower == "true" or lower == "1" then return true end
    if lower == "false" or lower == "0" then return false end
    return value == true
end

local function asNumber(value)
    if type(value) == "number" then return value end
    return tonumber(value)
end

local function safeGet(object, key)
    if type(object) ~= "table" then return nil end
    local ok, value = pcall(function()
        return object[key]
    end)
    if ok then return value end
    return nil
end

local function safeCall(object, name)
    if type(object) ~= "table" then return nil end
    local fn = safeGet(object, name)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, object)
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

local function readFromRoots(entity, names)
    local roots = {
        entity,
        safeGet(entity, "Properties"),
        safeGet(entity, "PropertiesInstance"),
        readPath(entity, { "Properties", "Lock" }),
        readPath(entity, { "PropertiesInstance", "Lock" }),
        readPath(entity, { "Properties", "Database" }),
        readPath(entity, { "PropertiesInstance", "Database" }),
    }

    for _, root in ipairs(roots) do
        if type(root) == "table" then
            for _, name in ipairs(names) do
                local value = safeGet(root, name)
                if value ~= nil and type(value) ~= "function" then
                    return value
                end
                value = safeCall(root, name)
                if value ~= nil then return value end
            end
        end
    end

    return nil
end

local function readNestedFromRoots(entity, paths)
    local roots = {
        entity,
        safeGet(entity, "Properties"),
        safeGet(entity, "PropertiesInstance"),
    }

    for _, root in ipairs(roots) do
        if type(root) == "table" then
            for _, path in ipairs(paths) do
                local value = root
                local ok = true
                for _, key in ipairs(path) do
                    if type(value) ~= "table" then ok = false break end
                    value = safeGet(value, key)
                    if value == nil then ok = false break end
                end
                if ok then return value end
            end
        end
    end

    return nil
end

local function entityName(entity)
    return safeCall(entity, "GetName") or safeGet(entity, "name") or
        safeGet(entity, "Name")
end

local function entityClass(entity)
    return safeGet(entity, "class") or safeGet(entity, "Class") or
        safeCall(entity, "GetClass")
end

local function entityId(entity)
    return safeGet(entity, "id") or safeGet(entity, "Id") or
        safeCall(entity, "GetId") or safeCall(entity, "GetEntityId")
end

local function positionOf(entity)
    return safeCall(entity, "GetWorldPos") or safeCall(entity, "GetPos") or
        safeGet(entity, "position") or safeGet(entity, "pos")
end

local function playerEntity()
    for _, name in ipairs({ "player", "g_localActor", "LocalPlayer" }) do
        local value = rawget(_G, name)
        if type(value) == "table" then return value end
    end
    return nil
end

local function vectorDistance(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return nil end
    if type(a.x) ~= "number" or type(a.y) ~= "number" or type(a.z) ~= "number" then return nil end
    if type(b.x) ~= "number" or type(b.y) ~= "number" or type(b.z) ~= "number" then return nil end
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function distanceText(distance)
    if type(distance) ~= "number" then return "nil" end
    return string.format("%.2f", distance)
end

local function audioActive(bIsPlaying, fFadeValue, nState)
    if bIsPlaying == true then return true end
    local fade = asNumber(fFadeValue)
    if fade ~= nil and fade > 0 then return true end
    local state = asNumber(nState)
    if state ~= nil and state > 0 then return true end
    if bIsPlaying == false or fade == 0 or state == 0 then return false end
    return nil
end

local function normalizeAudioArea(entity, distance)
    local bIsPlaying = readFromRoots(entity, { "bIsPlaying", "isPlaying", "IsPlaying" })
    local fFadeValue = readFromRoots(entity, { "fFadeValue", "fade", "Fade", "fadeValue" })
    local nState = readFromRoots(entity, { "nState", "state", "State" })
    local audioTriggerPlayTrigger = readNestedFromRoots(entity, {
        { "audioTrigger", "PlayTrigger" },
        { "audioTrigger", "playTrigger" },
        { "audioTrigger", "sPlayTrigger" },
        { "AudioTrigger", "PlayTrigger" },
        { "AudioTrigger", "playTrigger" },
    }) or readFromRoots(entity, {
        "audioTriggerPlayTrigger",
        "audioTrigger_PlayTrigger",
        "sPlayTrigger",
        "playTrigger",
        "PlayTrigger",
        "triggerName",
        "audioTrigger",
    })
    local audioEnvironmentEnvironment = readNestedFromRoots(entity, {
        { "audioEnvironment", "Environment" },
        { "audioEnvironment", "environment" },
        { "AudioEnvironment", "Environment" },
        { "AudioEnvironment", "environment" },
    }) or readFromRoots(entity, {
        "audioEnvironmentEnvironment",
        "audioEnvironment_Environment",
        "sEnvironment",
        "environment",
        "Environment",
        "audioEnvironment",
    })
    local fRtpcDistance = readFromRoots(entity, {
        "fRtpcDistance",
        "rtpcDistance",
        "RtpcDistance",
        "distanceRtpc",
    })

    return {
        class = entityClass(entity),
        name = entityName(entity),
        distance = distance,
        bIsPlaying = bIsPlaying,
        fFadeValue = fFadeValue,
        nState = nState,
        active = audioActive(bIsPlaying, fFadeValue, nState),
        audioTriggerPlayTrigger = audioTriggerPlayTrigger,
        audioEnvironmentEnvironment = audioEnvironmentEnvironment,
        fRtpcDistance = fRtpcDistance,
    }
end

local function collectNearbyAudio(radius)
    local center = positionOf(playerEntity())
    if type(center) ~= "table" or type(System) ~= "table" then
        return {}
    end

    local entities = nil
    if type(System.GetEntitiesInSphere) == "function" then
        local ok, result = pcall(System.GetEntitiesInSphere, center, radius)
        if ok then entities = result end
    end
    if entities == nil and type(System.GetEntities) == "function" then
        local ok, result = pcall(System.GetEntities)
        if ok then entities = result end
    end
    if type(entities) ~= "table" then return {} end

    local audio = {}
    local seen = {}
    for _, entity in pairs(entities) do
        if type(entity) == "table" and not seen[entity] then
            seen[entity] = true
            local className = tostring(entityClass(entity) or "")
            if AUDIO_CLASSES[className] then
                local distance = vectorDistance(center, positionOf(entity))
                if distance == nil or distance <= radius then
                    audio[#audio + 1] = normalizeAudioArea(entity, distance)
                end
            end
        end
    end

    table.sort(audio, function(a, b)
        if a.distance == nil and b.distance == nil then return valueText(a.name) < valueText(b.name) end
        if a.distance == nil then return false end
        if b.distance == nil then return true end
        return a.distance < b.distance
    end)

    return audio
end

local function isValidWuid(value)
    if value == nil then return false end
    if type(Framework) == "table" and type(Framework.IsValidWUID) == "function" then
        local ok, valid = pcall(Framework.IsValidWUID, value)
        return ok and valid == true
    end
    return true
end

local function xgenCall(name, ...)
    if type(XGenAIModule) ~= "table" then return nil, "XGenAIModule unavailable" end
    local fn = XGenAIModule[name]
    if type(fn) ~= "function" then return nil, "XGenAIModule." .. tostring(name) .. " unavailable" end
    local ok, value = pcall(fn, ...)
    if ok then return value, nil end
    return nil, value
end

local function firstLink(wuid, linkName)
    local links, err = xgenCall("FindLinks", wuid, linkName)
    if type(links) == "table" then return links[1], nil end
    return nil, err
end

local function allLinks(wuid, linkName)
    local links, err = xgenCall("FindLinks", wuid, linkName)
    if type(links) == "table" then return links, nil end
    return {}, err
end

local function npcInfo(npcWuid)
    if not isValidWuid(npcWuid) then return nil end

    local npcEntity = xgenCall("GetEntityByWUID", npcWuid)
    if type(npcEntity) ~= "table" then
        return { wuid = npcWuid, name = nil, socialClass = nil, factionID = nil }
    end

    local socialClass = nil
    local factionID = nil
    local soul = npcEntity.soul
    if soul ~= nil then
        local classInfo = safeCall(soul, "GetSocialClass")
        if type(classInfo) == "table" then socialClass = classInfo.Name end
        factionID = safeCall(soul, "GetFactionID")
    end

    return {
        wuid = npcWuid,
        name = entityName(npcEntity),
        socialClass = socialClass,
        factionID = factionID,
    }
end

local function ownerEvidenceFlags(npcs)
    local flags = {
        socialClass = { bandit = false, ruffian = false, cuman = false },
        faction = { bandit = false, ruffian = false, cuman = false },
    }

    for _, npc in ipairs(npcs or {}) do
        if containsText(npc and npc.socialClass, "bandit") then flags.socialClass.bandit = true end
        if containsText(npc and npc.socialClass, "ruffian") then flags.socialClass.ruffian = true end
        if containsText(npc and npc.socialClass, "cuman") then flags.socialClass.cuman = true end
        if containsText(npc and npc.factionID, "bandit") then flags.faction.bandit = true end
        if containsText(npc and npc.factionID, "ruffian") then flags.faction.ruffian = true end
        if containsText(npc and npc.factionID, "cuman") then flags.faction.cuman = true end
    end

    return flags
end

local function buildOwnership(entity)
    local stashWuid, stashErr = xgenCall("GetMyWUID", entity)
    if not isValidWuid(stashWuid) then stashWuid = nil end

    local ownerWuid = nil
    local ownerErr = nil
    if stashWuid ~= nil then
        ownerWuid, ownerErr = xgenCall("GetOwner", stashWuid)
        if not isValidWuid(ownerWuid) then ownerWuid = nil end
    end

    local homeWuid = nil
    local homeErr = nil
    if ownerWuid ~= nil then
        homeWuid, homeErr = firstLink(ownerWuid, "home")
        if not isValidWuid(homeWuid) then homeWuid = nil end
    end

    local npcs = {}
    if homeWuid ~= nil then
        local inhabitants = allLinks(homeWuid, "home_inhabitant")
        for _, npcWuid in pairs(inhabitants) do
            local info = npcInfo(npcWuid)
            if info ~= nil then npcs[#npcs + 1] = info end
        end
    elseif ownerWuid ~= nil then
        local info = npcInfo(ownerWuid)
        if info ~= nil then npcs[#npcs + 1] = info end
    end

    return {
        stashWuid = stashWuid,
        ownerWuid = ownerWuid,
        homeWuid = homeWuid,
        stashErr = stashErr,
        ownerErr = ownerErr,
        homeErr = homeErr,
        npcs = npcs,
        flags = ownerEvidenceFlags(npcs),
    }
end

local function modelPath(target)
    return readFromRoots(target and target.entity, {
        "object_Model",
        "model",
        "Model",
        "sModel",
        "fileModel",
        "fileModelPath",
    })
end

local function chestLike(model)
    local lower = lowerText(model)
    if lower == "" then return false end
    for _, term in ipairs({ "sack", "barrel", "pile", "shelf", "shelves" }) do
        if string.find(lower, term, 1, true) then return false end
    end
    return string.find(lower, "chest_", 1, true) ~= nil
end

local function activeForest(audio)
    for _, item in ipairs(audio or {}) do
        if item.class == "AudioAreaAmbience" and item.active == true and
                containsText(item.name, "forest") then
            return true
        end
    end
    return false
end

function Eligibility.BuildContext(target)
    target = target or {}
    local lock = target.lock or {}
    local stash = target.stash or {}
    local model = modelPath(target)
    local audio = collectNearbyAudio(5.0)
    local ownership = buildOwnership(target.entity)

    return {
        target = target,
        class = target.category,
        locked = boolValue(lock.bLocked),
        lockpickable = boolValue(lock.bCanLockPick),
        model = model,
        chestLike = chestLike(model),
        audio = audio,
        forest = activeForest(audio),
        ownership = ownership,
        lockDifficultyRaw = lock.difficultyRaw,
        lockDifficultyTier = lock.difficultyTier,
        lockDifficultyPrompt = lock.difficultyPrompt,
        generatedInventory = stash.generatedInventory,
        chestContextLabel = stash.chestContextLabel,
        stashWuid = ownership.stashWuid,
        ownerWuid = ownership.ownerWuid,
        homeWuid = ownership.homeWuid,
    }
end

function Eligibility.Evaluate(context)
    local flags = context.ownership and context.ownership.flags or {}
    local social = flags.socialClass or {}
    local reasons = {}

    local checks = {
        ["not-stash"] = context.class ~= "Stash",
        ["not-locked"] = context.locked ~= true,
        ["not-lockpickable"] = context.lockpickable ~= true,
        ["not-chest-like"] = context.chestLike ~= true,
        ["no-forest"] = context.forest ~= true,
        ["no-bandit-or-ruffian-social-class"] =
            not (social.bandit == true or social.ruffian == true),
    }

    for _, reason in ipairs(REASON_ORDER) do
        if checks[reason] then reasons[#reasons + 1] = reason end
    end

    return {
        eligible = #reasons == 0,
        reasons = reasons,
    }
end

function Eligibility.Log(context, result)
    local flags = context.ownership and context.ownership.flags or {}
    local social = flags.socialClass or {}
    local faction = flags.faction or {}
    local target = context.target or {}

    Debug.Log("eligibility" ..
        " target=" .. valueText(target.cryEntityId or target.targetId) ..
        " class=" .. valueText(context.class) ..
        " locked=" .. tostring(context.locked == true) ..
        " lockpickable=" .. tostring(context.lockpickable == true) ..
        " chestLike=" .. tostring(context.chestLike == true) ..
        " forest=" .. tostring(context.forest == true) ..
        " socialClass bandit=" .. tostring(social.bandit == true) ..
        " ruffian=" .. tostring(social.ruffian == true) ..
        " cuman=" .. tostring(social.cuman == true) ..
        " faction bandit=" .. tostring(faction.bandit == true) ..
        " ruffian=" .. tostring(faction.ruffian == true) ..
        " cuman=" .. tostring(faction.cuman == true) ..
        " lockDifficultyRaw=" .. valueText(context.lockDifficultyRaw) ..
        " lockDifficultyTier=" .. valueText(context.lockDifficultyTier) ..
        " lockDifficultyPrompt=" .. valueText(context.lockDifficultyPrompt) ..
        " generatedInventory=" .. valueText(context.generatedInventory) ..
        " context=" .. valueText(context.chestContextLabel) ..
        " stashWuid=" .. valueText(context.stashWuid) ..
        " ownerWuid=" .. valueText(context.ownerWuid) ..
        " homeWuid=" .. valueText(context.homeWuid) ..
        " eligible=" .. tostring(result.eligible == true) ..
        " reasons=" .. table.concat(result.reasons or {}, ","))

    for index, item in ipairs(context.audio or {}) do
        Debug.Trace("eligibility-audio[" .. tostring(index) .. "]" ..
            " class=" .. valueText(item.class) ..
            " name=" .. valueText(item.name) ..
            " distance=" .. distanceText(item.distance) ..
            " active=" .. valueText(item.active) ..
            " bIsPlaying=" .. valueText(item.bIsPlaying) ..
            " fFadeValue=" .. valueText(item.fFadeValue) ..
            " nState=" .. valueText(item.nState) ..
            " audioTriggerPlayTrigger=" .. valueText(item.audioTriggerPlayTrigger) ..
            " audioEnvironmentEnvironment=" .. valueText(item.audioEnvironmentEnvironment) ..
            " fRtpcDistance=" .. valueText(item.fRtpcDistance))
    end
end

function Eligibility.Classify(target)
    local context = Eligibility.BuildContext(target)
    local result = Eligibility.Evaluate(context)
    Eligibility.Log(context, result)
    return result, context
end
