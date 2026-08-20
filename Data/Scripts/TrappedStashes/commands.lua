TrappedStashes = TrappedStashes or {}
TrappedStashes.Commands = TrappedStashes.Commands or {}

local Commands = TrappedStashes.Commands
local Debug = TrappedStashes.Debug
local Audio = TrappedStashes.Audio

local DEFAULT_SOUND_PATH = "Libs/Audio/TrappedStashes/crossbow-shot1.wav"

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

local function parseUserdataHex(value)
    local text = tostring(value or "")
    local hex = string.match(text, "userdata:%s*([0-9A-Fa-f]+)")
    if hex == nil then
        return nil
    end
    return tonumber(hex, 16)
end

local function playerId()
    local user = rawget(_G, "player")
    if type(user) == "table" and type(user.GetRawId) == "function" then
        local ok, value = pcall(user.GetRawId, user)
        if ok and type(value) == "number" then
            return value, "player:GetRawId()"
        end
    end

    if type(user) == "table" and user.id ~= nil then
        if type(user.id) == "number" then
            return user.id, "player.id"
        end

        local parsed = parseUserdataHex(user.id)
        if parsed ~= nil then
            return parsed, "player.id:userdata"
        end
    end

    if type(Game) == "table" and type(Game.GetPlayerId) == "function" then
        local ok, value = pcall(Game.GetPlayerId)
        if ok then
            if type(value) == "number" then
                return value, "Game.GetPlayerId()"
            end

            local parsed = parseUserdataHex(value)
            if parsed ~= nil then
                return parsed, "Game.GetPlayerId():userdata"
            end
        end
    end

    return nil, "unavailable"
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

function Commands.MinigameExitTest()
    local native = rawget(_G, "Minigame")
    if type(native) ~= "table" or type(native.RequestExit) ~= "function" then
        Debug.Log("minigame-exit-test attempted=true result=false error=RequestExit-unavailable")
        return false
    end

    local id, source = playerId()
    Debug.Log("minigame-exit-test attempted=true playerId=" ..
        tostring(id) .. " source=" .. tostring(source))

    if id == nil then
        Debug.Log("minigame-exit-test attempted=true result=false error=missing-player-id")
        return false
    end

    local ok, result = pcall(native.RequestExit, id)
    if not ok then
        Debug.Log("minigame-exit-test attempted=true result=false error=" ..
            tostring(result))
        return false
    end

    Debug.Log("minigame-exit-test attempted=true result=" .. tostring(result))
    return result == true
end

local function registerCommand(name, callback, description)
    System.AddCCommand(name, callback, description)
end

function Commands.Register()
    if Commands._registered then
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
        "ts_minigame_exit",
        "TrappedStashes.Commands.MinigameExitTest()",
        "Trapped Stashes: request exit from the active minigame"
    )

    Commands._registered = true
    Debug.Log("commands registered names=ts_sound_file_test,ts_minigame_exit")
    return true
end
