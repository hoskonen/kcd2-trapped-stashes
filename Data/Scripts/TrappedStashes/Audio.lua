TrappedStashes = TrappedStashes or {}
TrappedStashes.Audio = TrappedStashes.Audio or {}

local Audio = TrappedStashes.Audio
local Debug = TrappedStashes.Debug

local DEFAULT_SOUND_PATH = "Sounds/crossbow-shot1.wav"

Audio._loadedSounds = Audio._loadedSounds or {}

local function cfg()
    return TrappedStashes.Config and TrappedStashes.Config.trapDeathAudio or {}
end

local function effectsCfg()
    return TrappedStashes.Config and TrappedStashes.Config.effects or {}
end

local function manager()
    if type(AudioManager) == "table" then
        return AudioManager
    end
    return nil
end

local function soundPath(path)
    if type(path) == "string" and path ~= "" then
        return path
    end
    return tostring(cfg().path or DEFAULT_SOUND_PATH)
end

local function appendField(parts, name, value)
    if value ~= nil then
        parts[#parts + 1] = name .. "=" .. tostring(value)
    end
end

local function logManagerStatus(audioManager, prefix)
    if type(audioManager.GetStatus) ~= "function" then
        return
    end

    local ok, status = pcall(audioManager.GetStatus)
    if not ok or type(status) ~= "table" then
        Debug.Trace(prefix .. " status-unavailable detail=" .. tostring(status))
        return
    end

    local parts = { prefix }
    appendField(parts, "ready", status.ready)
    appendField(parts, "backendReady", status.backendReady)
    appendField(parts, "studioReady", status.studioReady)
    appendField(parts, "coreReady", status.coreReady)
    appendField(parts, "loadedSounds", status.loadedSounds)
    appendField(parts, "latestError", status.latestError)
    Debug.Trace(table.concat(parts, " "))
end

local function logSoundInfo(audioManager, sound)
    if type(audioManager.GetSoundInfo) ~= "function" then
        return
    end

    local ok, info = pcall(audioManager.GetSoundInfo, sound)
    if not ok or type(info) ~= "table" then
        Debug.Trace("audio-file sound-info unavailable detail=" .. tostring(info))
        return
    end

    local parts = { "audio-file sound-info" }
    appendField(parts, "path", info.path)
    appendField(parts, "duration", info.duration)
    appendField(parts, "codec", info.codec)
    appendField(parts, "container", info.container)
    appendField(parts, "channels", info.channels)
    appendField(parts, "bits", info.bits)
    appendField(parts, "activeChannels", info.activeChannels)
    Debug.Trace(table.concat(parts, " "))
end

local function logSoundState(audioManager, instance)
    if type(audioManager.GetSoundState) ~= "function" then
        return
    end

    local ok, state = pcall(audioManager.GetSoundState, instance)
    if not ok or type(state) ~= "table" then
        Debug.Trace("audio-file state unavailable detail=" .. tostring(state))
        return
    end

    local parts = { "audio-file state" }
    appendField(parts, "bus", state.bus)
    appendField(parts, "playing", state.playing)
    appendField(parts, "paused", state.paused)
    appendField(parts, "looping", state.looping)
    appendField(parts, "volume", state.volume)
    appendField(parts, "pitch", state.pitch)
    appendField(parts, "attached", state.attached)
    Debug.Trace(table.concat(parts, " "))
end

local function loadSound(path)
    local audioManager = manager()
    if audioManager == nil or type(audioManager.LoadSound) ~= "function" then
        return nil, "AudioManager.LoadSound unavailable"
    end

    local cached = Audio._loadedSounds[path]
    if cached ~= nil then
        return cached, nil
    end

    local ok, handleOrError, err = pcall(audioManager.LoadSound, path)
    if not ok then
        return nil, handleOrError
    end
    if handleOrError == nil then
        return nil, err or "LoadSound returned nil"
    end

    Audio._loadedSounds[path] = handleOrError
    return handleOrError, nil
end

local function playOptions(options)
    local config = cfg()
    options = options or {}

    local result = {
        loop = false,
        volume = tonumber(options.volume or config.volume) or 1.0,
        pitch = tonumber(options.pitch or config.pitch) or 1.0,
    }

    local bus = options.bus
    if bus == nil then
        bus = config.bus
    end
    if type(bus) == "string" and bus ~= "" then
        result.bus = bus
    end

    return result
end

function Audio.PlaySoundFile(path, options)
    path = soundPath(path)

    local audioManager = manager()
    if audioManager == nil or type(audioManager.PlaySound) ~= "function" then
        Debug.Log("ERROR audio-file unavailable api=AudioManager.PlaySound path=" ..
            tostring(path))
        return false, "AudioManager.PlaySound unavailable"
    end

    logManagerStatus(audioManager, "audio-file status")

    if type(audioManager.IsReady) == "function" then
        local okReady, ready = pcall(audioManager.IsReady)
        if okReady and ready ~= true then
            Debug.Log("ERROR audio-file unavailable reason=AudioManager-not-ready path=" ..
                tostring(path))
            return false, "AudioManager not ready"
        end
    end

    local sound, loadErr = loadSound(path)
    if sound == nil then
        Debug.Log("ERROR audio-file load failed path=" .. tostring(path) ..
            " error=" .. tostring(loadErr))
        return false, loadErr
    end

    logSoundInfo(audioManager, sound)

    local optionsTable = playOptions(options)
    local okPlay, instanceOrError, err = pcall(
        audioManager.PlaySound,
        sound,
        optionsTable
    )

    if not okPlay then
        Debug.Log("ERROR audio-file play exception path=" .. tostring(path) ..
            " error=" .. tostring(instanceOrError))
        return false, instanceOrError
    end
    if instanceOrError == nil then
        Debug.Log("ERROR audio-file play failed path=" .. tostring(path) ..
            " error=" .. tostring(err))
        return false, err
    end

    Debug.Log("audio-file play path=" .. tostring(path) ..
        " bus=" .. tostring(optionsTable.bus) ..
        " volume=" .. tostring(optionsTable.volume) ..
        " pitch=" .. tostring(optionsTable.pitch) ..
        " instance=" .. tostring(instanceOrError))
    logSoundState(audioManager, instanceOrError)
    return true, instanceOrError
end

function Audio.PlayArrowTrapSound(_session)
    local config = cfg()
    if config.enabled ~= true or effectsCfg().sound == false then
        Debug.Trace("audio arrow-trap skipped reason=disabled")
        return false, "disabled"
    end

    local profile = _session and _session.trapAudioProfile or nil
    local path = profile and profile.file or config.path
    Debug.Trace("audio arrow-trap begin type=" ..
        tostring(profile and profile.type or "default") ..
        " path=" .. soundPath(path))
    return Audio.PlaySoundFile(path)
end
