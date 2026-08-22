TrappedStashes = TrappedStashes or {}
TrappedStashes.Settings = TrappedStashes.Settings or {}

local Settings = TrappedStashes.Settings
local DB_NAMESPACE = "trappedstashes"
local SETTINGS_KEY = "settings:v1"

local function log(message)
    System.LogAlways("[TrappedStashes][Settings] " .. tostring(message))
end

local function normalizeBoolean(value)
    if type(value) == "boolean" then return value end
    if type(value) == "number" then
        if value == 1 then return true end
        if value == 0 then return false end
    end
    if type(value) == "string" then
        local lower = string.lower(value)
        if lower == "true" or lower == "1" then return true end
        if lower == "false" or lower == "0" then return false end
    end
    return nil
end

local function normalizeMs(value, minValue, maxValue)
    local number = tonumber(value)
    if number == nil then return nil end
    minValue = tonumber(minValue) or 0
    maxValue = tonumber(maxValue) or 60000
    if number < minValue or number > maxValue then return nil end
    return math.floor(number + 0.5)
end

local function normalizeSeconds(value, minValue, maxValue)
    local number = tonumber(value)
    if number == nil then return nil end
    minValue = tonumber(minValue) or 0
    maxValue = tonumber(maxValue) or 60
    if number < minValue or number > maxValue then return nil end
    return math.floor((number * 10) + 0.5) / 10
end

local function ensureShape(config)
    config.effects = config.effects or {}
    config.trapSequence = config.trapSequence or {}
    config.trapAudio = config.trapAudio or {}
    config.trapTriggers = config.trapTriggers or {}
    config.timedLockTrap = config.timedLockTrap or {}
    config.diagnostics = config.diagnostics or {}
    config.trapDeathAudio = config.trapDeathAudio or {}
    TrappedStashes.cfg = config
    return config
end

local function normalizeProfileId(value)
    if type(value) == "string" and value ~= "" then
        return value
    end
    return nil
end

local function profileById(config, profileId)
    ensureShape(config)
    local profiles = config.trapAudio.profiles
    if type(profiles) ~= "table" then return nil end

    for _, profile in ipairs(profiles) do
        if type(profile) == "table" and profile.id == profileId then
            return profile
        end
    end
    return nil
end

local function buildProfileTimingRecord(config)
    local result = {}
    local profiles = ensureShape(config).trapAudio.profiles
    if type(profiles) ~= "table" then return result end

    for _, profile in ipairs(profiles) do
        if type(profile) == "table" and type(profile.id) == "string" then
            result[profile.id] = {
                impactDelayMs =
                    normalizeMs(profile.impactDelayMs, 0, 30000),
                gameOverDelayMs =
                    normalizeMs(profile.gameOverDelayMs, 0, 30000),
            }
        end
    end
    return result
end

local function applyProfileTimings(config, timings)
    if type(timings) ~= "table" then return end

    for profileId, timing in pairs(timings) do
        local profile = profileById(config, profileId)
        if profile ~= nil and type(timing) == "table" then
            local impactDelayMs =
                normalizeMs(timing.impactDelayMs, 0, 30000)
            if impactDelayMs ~= nil then
                profile.impactDelayMs = impactDelayMs
            end

            local gameOverDelayMs =
                normalizeMs(timing.gameOverDelayMs, 0, 30000)
            if gameOverDelayMs ~= nil then
                profile.gameOverDelayMs = gameOverDelayMs
            end
        end
    end
end

local function profileTimingsMatch(recordTimings, config)
    local current = buildProfileTimingRecord(config)
    recordTimings = type(recordTimings) == "table" and recordTimings or {}

    for profileId, timing in pairs(current) do
        local saved = recordTimings[profileId] or {}
        if saved.impactDelayMs ~= timing.impactDelayMs or
                saved.gameOverDelayMs ~= timing.gameOverDelayMs then
            return false
        end
    end

    return true
end

local function ensureDB()
    if Settings._db then return Settings._db end
    if not (KCDUtils and KCDUtils.DB and KCDUtils.DB.Factory) then
        if not Settings._dbUnavailableLogged then
            Settings._dbUnavailableLogged = true
            log("LuaDB unavailable; using Config.lua defaults")
        end
        return nil
    end

    local ok, db = pcall(KCDUtils.DB.Factory, DB_NAMESPACE)
    if ok and db then
        Settings._db = db
        Settings._dbUnavailableLogged = nil
        return db
    end

    if not Settings._dbUnavailableLogged then
        Settings._dbUnavailableLogged = true
        log("LuaDB namespace open failed; using Config.lua defaults")
    end
    return nil
end

local function readRecord(db)
    if type(db.GetG) ~= "function" then
        return nil, "global read unavailable"
    end

    local ok, value = pcall(db.GetG, db, SETTINGS_KEY)
    if not ok then return nil, "read failed" end
    if value == nil then return nil, "missing" end
    if type(value) ~= "table" then return nil, "record is not a table" end

    local effects = type(value.effects) == "table" and value.effects or {}
    local trapSequence = type(value.trapSequence) == "table" and value.trapSequence or {}
    local trapAudio = type(value.trapAudio) == "table" and value.trapAudio or {}
    local trapTriggers = type(value.trapTriggers) == "table" and
        value.trapTriggers or {}
    local timedLockTrap = type(value.timedLockTrap) == "table" and
        value.timedLockTrap or {}
    local diagnostics = type(value.diagnostics) == "table" and value.diagnostics or {}

    return {
        version = tonumber(value.version) or 1,
        enabled = normalizeBoolean(value.enabled),
        effects = {
            sound = normalizeBoolean(effects.sound),
        },
        trapSequence = {
            soundAtMs = normalizeMs(trapSequence.soundAtMs, 0, 10000),
            gameOverAtMs = normalizeMs(trapSequence.gameOverAtMs, 0, 30000),
        },
        trapAudio = {
            randomEnabled = normalizeBoolean(trapAudio.randomEnabled),
            forcedProfile = normalizeProfileId(trapAudio.forcedProfile),
            profileTimings =
                type(trapAudio.profileTimings) == "table" and
                trapAudio.profileTimings or {},
        },
        trapTriggers = {
            onLockpickBreak = normalizeBoolean(trapTriggers.onLockpickBreak),
            onTurnRelease = normalizeBoolean(trapTriggers.onTurnRelease),
        },
        timedLockTrap = {
            enabled = normalizeBoolean(timedLockTrap.enabled),
            minFuseSeconds =
                normalizeSeconds(timedLockTrap.minFuseSeconds, 1, 30),
            maxFuseSeconds =
                normalizeSeconds(timedLockTrap.maxFuseSeconds, 1, 30),
        },
        debug = normalizeBoolean(value.debug),
        diagnostics = {
            minigameDumpNative = normalizeBoolean(diagnostics.minigameDumpNative),
        },
    }, nil
end

local function buildRecord(config)
    ensureShape(config)
    return {
        version = 1,
        enabled = config.enabled == true and 1 or 0,
        effects = {
            sound = config.effects.sound ~= false and 1 or 0,
        },
        trapSequence = {
            soundAtMs = normalizeMs(config.trapSequence.soundAtMs, 0, 10000) or 250,
            gameOverAtMs = normalizeMs(config.trapSequence.gameOverAtMs, 0, 30000) or 1250,
        },
        trapAudio = {
            randomEnabled = config.trapAudio.randomEnabled ~= false and 1 or 0,
            forcedProfile = normalizeProfileId(config.trapAudio.forcedProfile),
            profileTimings = buildProfileTimingRecord(config),
        },
        trapTriggers = {
            onLockpickBreak =
                config.trapTriggers.onLockpickBreak ~= false and 1 or 0,
            onTurnRelease =
                config.trapTriggers.onTurnRelease == true and 1 or 0,
        },
        timedLockTrap = {
            enabled = config.timedLockTrap.enabled == true and 1 or 0,
            minFuseSeconds =
                normalizeSeconds(config.timedLockTrap.minFuseSeconds, 1, 30) or 8,
            maxFuseSeconds =
                normalizeSeconds(config.timedLockTrap.maxFuseSeconds, 1, 30) or 14,
        },
        debug = config.debug == true and 1 or 0,
        diagnostics = {
            minigameDumpNative =
                config.diagnostics.minigameDumpNative == true and 1 or 0,
        },
    }
end

local function applyRecord(config, record)
    ensureShape(config)
    if record.enabled ~= nil then config.enabled = record.enabled end

    if record.effects then
        if record.effects.sound ~= nil then
            config.effects.sound = record.effects.sound
            config.trapDeathAudio.enabled = record.effects.sound
        end
    end

    if record.trapSequence then
        if record.trapSequence.soundAtMs ~= nil then
            config.trapSequence.soundAtMs = record.trapSequence.soundAtMs
        end
        if record.trapSequence.gameOverAtMs ~= nil then
            config.trapSequence.gameOverAtMs = record.trapSequence.gameOverAtMs
        end
    end

    if record.trapAudio then
        if record.trapAudio.randomEnabled ~= nil then
            config.trapAudio.randomEnabled = record.trapAudio.randomEnabled
        end
        config.trapAudio.forcedProfile =
            normalizeProfileId(record.trapAudio.forcedProfile)
        applyProfileTimings(config, record.trapAudio.profileTimings)
    end

    if record.trapTriggers then
        if record.trapTriggers.onLockpickBreak ~= nil then
            config.trapTriggers.onLockpickBreak =
                record.trapTriggers.onLockpickBreak
        end
        if record.trapTriggers.onTurnRelease ~= nil then
            config.trapTriggers.onTurnRelease =
                record.trapTriggers.onTurnRelease
        end
    end

    if record.timedLockTrap then
        if record.timedLockTrap.enabled ~= nil then
            config.timedLockTrap.enabled = record.timedLockTrap.enabled
        end
        if record.timedLockTrap.minFuseSeconds ~= nil then
            config.timedLockTrap.minFuseSeconds =
                record.timedLockTrap.minFuseSeconds
        end
        if record.timedLockTrap.maxFuseSeconds ~= nil then
            config.timedLockTrap.maxFuseSeconds =
                record.timedLockTrap.maxFuseSeconds
        end
    end

    if record.debug ~= nil then config.debug = record.debug end
    if record.diagnostics and record.diagnostics.minigameDumpNative ~= nil then
        config.diagnostics.minigameDumpNative =
            record.diagnostics.minigameDumpNative
    end
end

local function recordMatchesConfig(record, config)
    return record ~= nil
        and record.enabled == config.enabled
        and record.effects.sound == (config.effects.sound ~= false)
        and record.trapSequence.soundAtMs == config.trapSequence.soundAtMs
        and record.trapSequence.gameOverAtMs == config.trapSequence.gameOverAtMs
        and record.trapAudio.randomEnabled ==
            (config.trapAudio.randomEnabled ~= false)
        and record.trapAudio.forcedProfile ==
            normalizeProfileId(config.trapAudio.forcedProfile)
        and profileTimingsMatch(record.trapAudio.profileTimings, config)
        and record.trapTriggers.onLockpickBreak ==
            (config.trapTriggers.onLockpickBreak ~= false)
        and record.trapTriggers.onTurnRelease ==
            (config.trapTriggers.onTurnRelease == true)
        and record.timedLockTrap.enabled == config.timedLockTrap.enabled
        and record.timedLockTrap.minFuseSeconds ==
            normalizeSeconds(config.timedLockTrap.minFuseSeconds, 1, 30)
        and record.timedLockTrap.maxFuseSeconds ==
            normalizeSeconds(config.timedLockTrap.maxFuseSeconds, 1, 30)
        and record.debug == config.debug
        and record.diagnostics.minigameDumpNative ==
            config.diagnostics.minigameDumpNative
end

local function markSessionChanged()
    Settings._dirty = true
    Settings._source = "session"
end

function Settings.Initialize(config)
    config = ensureShape(config or TrappedStashes.Config or {})
    TrappedStashes.Config = config

    local db = ensureDB()
    if not db then
        Settings._source = Settings._dirty and "session" or "defaults"
        return false, "db unavailable"
    end

    if Settings._dirty then
        return Settings.SaveAll(config)
    end

    local record, reason = readRecord(db)
    if not record then
        Settings._loaded = true
        Settings._source = "defaults"
        if reason == "missing" then
            log("no saved settings; using Config.lua defaults")
        else
            log("ignored invalid saved settings: " .. tostring(reason))
        end
        return false, reason
    end

    applyRecord(config, record)
    Settings._loaded = true
    Settings._dirty = false
    Settings._source = "luadb"

    log("loaded source=luadb")
    return true, nil
end

function Settings.LoadInto(config)
    return Settings.Initialize(config)
end

function Settings.GetSource()
    return Settings._source or "defaults"
end

function Settings.SaveAll(config)
    config = ensureShape(config or TrappedStashes.Config or {})
    local db = ensureDB()
    if not db then
        markSessionChanged()
        return false, "db unavailable"
    end
    if type(db.SetG) ~= "function" then
        markSessionChanged()
        log("LuaDB write API unavailable")
        return false, "global write unavailable"
    end

    local ok = pcall(db.SetG, db, SETTINGS_KEY, buildRecord(config))
    if not ok then
        markSessionChanged()
        log("save failed")
        return false, "write failed"
    end

    local saved, reason = readRecord(db)
    local verified = recordMatchesConfig(saved, config)
    if verified then
        Settings._loaded = true
        Settings._dirty = false
        Settings._source = "luadb"
    else
        markSessionChanged()
    end

    log("saved all verified=" .. tostring(verified))
    return verified, verified and nil or reason or "verification failed"
end

function Settings.SetEnabled(enabled, source, persist)
    local config = ensureShape(TrappedStashes.Config)
    config.enabled = enabled == true
    markSessionChanged()
    log("enabled=" .. tostring(config.enabled) ..
        " source=" .. tostring(source or "settings"))
    if persist then return Settings.SaveAll(config) end
    return true, nil
end

function Settings.SetEffectEnabled(effectName, enabled, source, persist)
    local config = ensureShape(TrappedStashes.Config)
    if effectName ~= "sound" then
        return false, "unknown effect"
    end

    config.effects[effectName] = enabled == true
    if effectName == "sound" then
        config.trapDeathAudio.enabled = enabled == true
    end

    markSessionChanged()
    log("effect " .. tostring(effectName) .. "=" ..
        tostring(config.effects[effectName]) ..
        " source=" .. tostring(source or "settings"))
    if persist then return Settings.SaveAll(config) end
    return true, nil
end

function Settings.SetRagdollEnabled(enabled, source)
    local config = ensureShape(TrappedStashes.Config)
    config.effects.ragdoll = enabled == true
    markSessionChanged()
    log("effect ragdoll=" .. tostring(config.effects.ragdoll) ..
        " source=" .. tostring(source or "settings") ..
        " persist=false")
    return true, nil
end

function Settings.SetTrapTiming(name, value, source, persist)
    local config = ensureShape(TrappedStashes.Config)
    local maxValue = name == "gameOverAtMs" and 30000 or 10000
    local ms = normalizeMs(value, 0, maxValue)
    if ms == nil then return false, "invalid milliseconds" end
    if name ~= "soundAtMs" and name ~= "gameOverAtMs" then
        return false, "unknown timing"
    end

    config.trapSequence[name] = ms
    markSessionChanged()
    log("timing " .. tostring(name) .. "=" .. tostring(ms) ..
        " source=" .. tostring(source or "settings"))
    if persist then return Settings.SaveAll(config) end
    return true, nil
end

function Settings.SetTimedFuseEnabled(enabled, source, persist)
    local config = ensureShape(TrappedStashes.Config)
    config.timedLockTrap.enabled = enabled == true
    markSessionChanged()
    log("timedLockTrap enabled=" ..
        tostring(config.timedLockTrap.enabled) ..
        " source=" .. tostring(source or "settings"))
    if persist then return Settings.SaveAll(config) end
    return true, nil
end

function Settings.SetTimedFuseSeconds(name, value, source, persist)
    local config = ensureShape(TrappedStashes.Config)
    if name ~= "minFuseSeconds" and name ~= "maxFuseSeconds" then
        return false, "unknown fuse timing"
    end

    local seconds = normalizeSeconds(value, 1, 30)
    if seconds == nil then return false, "invalid seconds" end

    config.timedLockTrap[name] = seconds
    markSessionChanged()
    log("timedLockTrap " .. tostring(name) .. "=" .. tostring(seconds) ..
        " source=" .. tostring(source or "settings"))
    if persist then return Settings.SaveAll(config) end
    return true, nil
end

function Settings.SetRandomTrapAudioEnabled(enabled, source, persist)
    local config = ensureShape(TrappedStashes.Config)
    config.trapAudio.randomEnabled = enabled == true
    markSessionChanged()
    log("trapAudio randomEnabled=" ..
        tostring(config.trapAudio.randomEnabled) ..
        " source=" .. tostring(source or "settings"))
    if persist then return Settings.SaveAll(config) end
    return true, nil
end

function Settings.SetForcedTrapAudioProfile(profileId, source, persist)
    local config = ensureShape(TrappedStashes.Config)
    profileId = normalizeProfileId(profileId)
    if profileId ~= nil and profileById(config, profileId) == nil then
        return false, "unknown profile"
    end

    config.trapAudio.forcedProfile = profileId
    markSessionChanged()
    log("trapAudio forcedProfile=" ..
        tostring(config.trapAudio.forcedProfile or "any") ..
        " source=" .. tostring(source or "settings"))
    if persist then return Settings.SaveAll(config) end
    return true, nil
end

function Settings.SetTrapAudioProfileTiming(profileId, name, value, source,
        persist)
    local config = ensureShape(TrappedStashes.Config)
    local profile = profileById(config, profileId)
    if profile == nil then return false, "unknown profile" end
    if name ~= "impactDelayMs" and name ~= "gameOverDelayMs" then
        return false, "unknown profile timing"
    end

    local ms = normalizeMs(value, 0, 30000)
    if ms == nil then return false, "invalid milliseconds" end

    profile[name] = ms
    markSessionChanged()
    log("trapAudio profile=" .. tostring(profileId) ..
        " " .. tostring(name) .. "=" .. tostring(ms) ..
        " source=" .. tostring(source or "settings"))
    if persist then return Settings.SaveAll(config) end
    return true, nil
end

function Settings.SetTrapTriggerEnabled(name, enabled, source, persist)
    local config = ensureShape(TrappedStashes.Config)
    if name ~= "onLockpickBreak" and name ~= "onTurnRelease" then
        return false, "unknown trap trigger"
    end

    config.trapTriggers[name] = enabled == true
    markSessionChanged()
    log("trapTrigger " .. tostring(name) .. "=" ..
        tostring(config.trapTriggers[name]) ..
        " source=" .. tostring(source or "settings"))
    if persist then return Settings.SaveAll(config) end
    return true, nil
end

function Settings.SetDebugEnabled(enabled, source, persist)
    local config = ensureShape(TrappedStashes.Config)
    config.debug = enabled == true
    markSessionChanged()
    log("debug=" .. tostring(config.debug) ..
        " source=" .. tostring(source or "settings"))
    if persist then return Settings.SaveAll(config) end
    return true, nil
end

function Settings.SetMinigameDumpNative(enabled, source, persist)
    local config = ensureShape(TrappedStashes.Config)
    config.diagnostics.minigameDumpNative = enabled == true
    markSessionChanged()
    log("minigameDumpNative=" ..
        tostring(config.diagnostics.minigameDumpNative) ..
        " source=" .. tostring(source or "settings"))
    if persist then return Settings.SaveAll(config) end
    return true, nil
end
