TrappedStashes = TrappedStashes or {}
TrappedStashes.TrapAudioProfiles = TrappedStashes.TrapAudioProfiles or {}

local Profiles = TrappedStashes.TrapAudioProfiles
local Debug = TrappedStashes.Debug

local DEFAULT_PROFILE = {
    id = "crossbow",
    type = "crossbow",
    enabled = true,
    files = { "Sounds/crossbow-shot1.wav" },
    impactDelayMs = 350,
    gameOverDelayMs = 2000,
}

local function cfg()
    return TrappedStashes.Config and TrappedStashes.Config.trapAudio or {}
end

local function log(message)
    if Debug and type(Debug.Log) == "function" then
        Debug.Log(message)
    elseif System and type(System.LogAlways) == "function" then
        System.LogAlways("[TrappedStashes] " .. tostring(message))
    end
end

local function normalized(profile)
    if type(profile) ~= "table" then return nil end

    local id = profile.id or profile.type
    if type(id) ~= "string" or id == "" then return nil end

    local files = {}
    if type(profile.files) == "table" then
        for _, file in ipairs(profile.files) do
            if type(file) == "string" and file ~= "" then
                files[#files + 1] = file
            end
        end
    end

    local file = profile.file or profile.path
    if type(file) == "string" and file ~= "" then
        files[#files + 1] = file
    end
    if #files == 0 then return nil end

    local impactDelayMs = tonumber(profile.impactDelayMs)
    if impactDelayMs == nil then impactDelayMs = 0 end
    if impactDelayMs < 0 then impactDelayMs = 0 end

    local gameOverDelayMs = tonumber(profile.gameOverDelayMs)
    if gameOverDelayMs ~= nil and gameOverDelayMs < 0 then
        gameOverDelayMs = 0
    end

    return {
        id = id,
        type = profile.type or id,
        enabled = profile.enabled ~= false,
        files = files,
        file = files[1],
        impactDelayMs = math.floor(impactDelayMs + 0.5),
        gameOverDelayMs = gameOverDelayMs and
            math.floor(gameOverDelayMs + 0.5) or nil,
    }
end

local function profiles()
    local result = {}
    local configured = cfg().profiles
    if type(configured) ~= "table" then
        result[#result + 1] = normalized(DEFAULT_PROFILE)
        return result
    end

    for _, profile in ipairs(configured) do
        local entry = normalized(profile)
        if entry ~= nil then
            result[#result + 1] = entry
        end
    end

    if #result == 0 then
        result[#result + 1] = normalized(DEFAULT_PROFILE)
    end
    return result
end

local function enabledProfiles()
    local result = {}
    for _, profile in ipairs(profiles()) do
        if profile.enabled then
            result[#result + 1] = profile
        end
    end
    if #result == 0 then
        result[#result + 1] = normalized(DEFAULT_PROFILE)
    end
    return result
end

local function defaultProfile()
    local wanted = cfg().defaultProfile or DEFAULT_PROFILE.id
    local all = profiles()
    for _, profile in ipairs(all) do
        if profile.id == wanted then
            return profile
        end
    end
    return enabledProfiles()[1]
end

local function forcedProfile()
    local wanted = cfg().forcedProfile
    if type(wanted) ~= "string" or wanted == "" then
        return nil
    end

    for _, profile in ipairs(profiles()) do
        if profile.id == wanted and profile.enabled then
            return profile
        end
    end

    log("trap-audio forced-profile unavailable id=" .. tostring(wanted))
    return nil
end

local function selectProfile()
    local forced = forcedProfile()
    if forced ~= nil then
        return forced
    end

    local candidates = enabledProfiles()
    if cfg().randomEnabled == false then
        return defaultProfile()
    end

    if #candidates <= 1 then
        return candidates[1]
    end

    return candidates[math.random(#candidates)]
end

local function selectFile(profile)
    local files = profile and profile.files or nil
    if type(files) ~= "table" or #files == 0 then
        return profile and profile.file or nil
    end

    if cfg().randomEnabled == false or #files == 1 then
        return files[1]
    end

    return files[math.random(#files)]
end

function Profiles.SelectForSession(session)
    if session ~= nil and type(session.trapAudioProfile) == "table" then
        return session.trapAudioProfile
    end

    local profile = selectProfile()
    profile.file = selectFile(profile)
    if session ~= nil then
        session.trapAudioProfile = profile
    end

    log("trap-audio selected type=" .. tostring(profile.type) ..
        " file=" .. tostring(profile.file) ..
        " fileCount=" .. tostring(profile.files and #profile.files or 1) ..
        " impactDelayMs=" .. tostring(profile.impactDelayMs) ..
        " gameOverDelayMs=" .. tostring(profile.gameOverDelayMs))
    return profile
end
