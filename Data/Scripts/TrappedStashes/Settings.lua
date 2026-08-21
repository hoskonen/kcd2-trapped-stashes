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
    config.timedLockTrap = config.timedLockTrap or {}
    config.diagnostics = config.diagnostics or {}
    config.trapDeathAudio = config.trapDeathAudio or {}
    TrappedStashes.cfg = config
    return config
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
    local timedLockTrap = type(value.timedLockTrap) == "table" and
        value.timedLockTrap or {}
    local diagnostics = type(value.diagnostics) == "table" and value.diagnostics or {}

    return {
        version = tonumber(value.version) or 1,
        enabled = normalizeBoolean(value.enabled),
        effects = {
            sound = normalizeBoolean(effects.sound),
            blood = normalizeBoolean(effects.blood),
            blur = normalizeBoolean(effects.blur),
        },
        trapSequence = {
            soundAtMs = normalizeMs(trapSequence.soundAtMs, 0, 10000),
            gameOverAtMs = normalizeMs(trapSequence.gameOverAtMs, 0, 30000),
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
            blood = config.effects.blood ~= false and 1 or 0,
            blur = config.effects.blur ~= false and 1 or 0,
        },
        trapSequence = {
            soundAtMs = normalizeMs(config.trapSequence.soundAtMs, 0, 10000) or 250,
            gameOverAtMs = normalizeMs(config.trapSequence.gameOverAtMs, 0, 30000) or 1250,
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
        if record.effects.blood ~= nil then config.effects.blood = record.effects.blood end
        if record.effects.blur ~= nil then config.effects.blur = record.effects.blur end
    end

    if record.trapSequence then
        if record.trapSequence.soundAtMs ~= nil then
            config.trapSequence.soundAtMs = record.trapSequence.soundAtMs
        end
        if record.trapSequence.gameOverAtMs ~= nil then
            config.trapSequence.gameOverAtMs = record.trapSequence.gameOverAtMs
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
        and record.effects.blood == (config.effects.blood ~= false)
        and record.effects.blur == (config.effects.blur ~= false)
        and record.trapSequence.soundAtMs == config.trapSequence.soundAtMs
        and record.trapSequence.gameOverAtMs == config.trapSequence.gameOverAtMs
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
    if effectName ~= "sound" and effectName ~= "blood" and
            effectName ~= "blur" then
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
