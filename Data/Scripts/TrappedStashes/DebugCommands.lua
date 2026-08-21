TrappedStashes = TrappedStashes or {}
TrappedStashes.Commands = TrappedStashes.Commands or {}

local Commands = TrappedStashes.Commands
local Debug = TrappedStashes.Debug
local Audio = TrappedStashes.Audio
local TrapEffects = TrappedStashes.TrapEffects

local DEFAULT_SOUND_PATH = "Sounds/crossbow-shot1.wav"
local COMMAND_SET_VERSION = "cleanup-v1"

local function trim(value)
    local text = tostring(value or "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    text = string.gsub(text, '^"(.*)"$', "%1")
    text = string.gsub(text, "^'(.*)'$", "%1")
    return text
end

local function defaultSoundPath()
    local config = TrappedStashes.Config and TrappedStashes.Config.trapDeathAudio or {}
    return config.path or DEFAULT_SOUND_PATH
end

function Commands.SoundFileTest(line)
    local path = trim(line)
    if path == "" then
        path = defaultSoundPath()
    end

    Debug.Log("sound-file-test path=" .. tostring(path) .. " attempted=true")

    if Audio == nil or type(Audio.PlaySoundFile) ~= "function" then
        Debug.Log("sound-file-test path=" .. tostring(path) ..
            " attempted=true result=false error=audio-module-unavailable")
        return false
    end

    local ok, result = Audio.PlaySoundFile(path)
    Debug.Log("sound-file-test path=" .. tostring(path) ..
        " attempted=true result=" .. tostring(ok) ..
        " detail=" .. tostring(result))
    return ok
end

function Commands.RagdollAuthoredTest()
    if TrapEffects == nil or
            type(TrapEffects.TestAuthoredRagdoll) ~= "function" then
        Debug.Log("ragdoll-authored attempted=true result=false error=trap-effects-unavailable")
        return false
    end

    return TrapEffects.TestAuthoredRagdoll()
end

function Commands.BloodScreenTest()
    if TrapEffects == nil or type(TrapEffects.TestBloodScreen) ~= "function" then
        Debug.Log("blood-screen-test attempted=true result=false error=trap-effects-unavailable")
        return false
    end

    return TrapEffects.TestBloodScreen()
end

local function registerCommand(name, callback, description)
    System.AddCCommand(name, callback, description)
end

function Commands.Register()
    if Commands._registered and Commands._registeredVersion == COMMAND_SET_VERSION then
        Debug.Trace("commands already-registered")
        return true
    end

    if type(System) ~= "table" or type(System.AddCCommand) ~= "function" then
        Debug.Log("commands unavailable")
        return false
    end

    registerCommand(
        "ts_sound_file_test",
        "TrappedStashes.Commands.SoundFileTest([[%line]])",
        "Trapped Stashes: play the configured WAV/OGG sound file"
    )

    registerCommand(
        "ts_ragdoll_authored",
        "TrappedStashes.Commands.RagdollAuthoredTest()",
        "Trapped Stashes: apply the authored ragdoll test buff"
    )

    registerCommand(
        "ts_blood_screen_test",
        "TrappedStashes.Commands.BloodScreenTest()",
        "Trapped Stashes: apply the custom blood screen test buff"
    )

    Commands._registered = true
    Commands._registeredVersion = COMMAND_SET_VERSION
    Debug.Log("commands registered names=ts_sound_file_test,ts_ragdoll_authored,ts_blood_screen_test")
    return true
end
