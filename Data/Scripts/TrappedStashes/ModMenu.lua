TrappedStashes = TrappedStashes or {}
TrappedStashes.ModMenu = TrappedStashes.ModMenu or {}

local MM = TrappedStashes.ModMenu
local MOD_ID = "trappedstashes"
local MOD_NAME = "Trapped Stashes"

local function log(message)
    System.LogAlways("[TrappedStashes][MCM] " .. tostring(message))
end

local function cfg()
    return TrappedStashes.Config or {}
end

local function settings()
    return TrappedStashes.Settings
end

local function toggleValue(value)
    local number = tonumber(value)
    if number ~= nil then return number ~= 0 end
    if type(value) == "boolean" then return value end
    return nil
end

local function sliderMs(value, minValue, maxValue)
    local number = tonumber(value)
    if number == nil then return nil end
    minValue = tonumber(minValue) or 0
    maxValue = tonumber(maxValue) or 30000
    if number < minValue or number > maxValue then return nil end
    return math.floor(number + 0.5)
end

local function uiAssetsAvailable()
    if not (System and type(System.IsFileExist) == "function") then
        return false
    end

    local ok, exists = pcall(
        System.IsFileExist,
        "Libs/UI/UIElements/MCM.xml"
    )
    return ok and (exists == true or exists == 1)
end

local function apiAvailable()
    return uiAssetsAvailable()
        and MCM
        and type(MCM.AddMod) == "function"
        and type(MCM.AddCategory) == "function"
        and type(MCM.AddToggle) == "function"
        and type(MCM.AddSlider) == "function"
        and type(MCM.RegisterBuildSettingsListener) == "function"
        and type(MCM.RegisterValueChangeListener) == "function"
end

local function addToggle(settingId, label, description, value)
    MCM.AddToggle(
        MOD_ID,
        settingId,
        label,
        description,
        value and 1 or 0
    )
end

local function addSlider(settingId, label, description, minValue, maxValue,
        step, value, suffix)
    MCM.AddSlider(
        MOD_ID,
        settingId,
        label,
        description,
        minValue,
        maxValue,
        step,
        value,
        suffix or ""
    )
end

function MM.BuildSettings()
    local config = cfg()
    local effects = config.effects or {}
    local trapSequence = config.trapSequence or {}
    local diagnostics = config.diagnostics or {}

    MCM.AddMod(MOD_ID, MOD_NAME)

    MCM.AddCategory(MOD_ID, "General", "General Trapped Stashes settings.")
    addToggle(
        "enabled",
        "Enable Trapped Stashes",
        "Enable or disable automatic trapped stash behavior.",
        config.enabled ~= false
    )

    MCM.AddCategory(
        MOD_ID,
        "Trap Effects",
        "Presentation effects used when a trapped stash fires."
    )
    addToggle(
        "effect_sound",
        "Trap sound",
        "Play the configured arrow trap sound.",
        effects.sound ~= false
    )
    addToggle(
        "effect_blood",
        "Blood effect",
        "Apply the trapped stash blood screen effect.",
        effects.blood ~= false
    )
    addToggle(
        "effect_blur",
        "Blur effect",
        "Apply the retained blur/visual buff experiment.",
        effects.blur ~= false
    )

    if config.devToggles == true then
        MCM.AddCategory(
            MOD_ID,
            "Developer - Sequence",
            "Development controls for trap timing."
        )
        addSlider(
            "sound_at_ms",
            "Sound delay",
            "Milliseconds from trap trigger to arrow sound.",
            0,
            5000,
            50,
            tonumber(trapSequence.soundAtMs) or 250,
            " ms"
        )
        addSlider(
            "gameover_at_ms",
            "GameOver delay",
            "Milliseconds from trap trigger to GameOver.",
            0,
            10000,
            50,
            tonumber(trapSequence.gameOverAtMs) or 1250,
            " ms"
        )

        MCM.AddCategory(
            MOD_ID,
            "Developer - Diagnostics",
            "Development-only diagnostics and experiments."
        )
        addToggle(
            "debug",
            "Debug logging",
            "Enable verbose Trapped Stashes diagnostic logging.",
            config.debug == true
        )
        addToggle(
            "minigame_dump_native",
            "Native minigame dump",
            "Dump Minigame native table capabilities at registration.",
            diagnostics.minigameDumpNative == true
        )
        addToggle(
            "effect_ragdoll",
            "Ragdoll experimental path",
            "Apply the authored ragdoll experiment when a trap fires.",
            effects.ragdoll == true
        )
    end
end

function MM.OnValueChanged(settingId, value)
    local Settings = settings()
    if not Settings then
        log("settings module unavailable; change ignored")
        return
    end

    if settingId == "enabled" then
        local enabled = toggleValue(value)
        if enabled == nil then return end
        Settings.SetEnabled(enabled, "mcm", true)
    elseif settingId == "effect_sound" then
        local enabled = toggleValue(value)
        if enabled == nil then return end
        Settings.SetEffectEnabled("sound", enabled, "mcm", true)
    elseif settingId == "effect_blood" then
        local enabled = toggleValue(value)
        if enabled == nil then return end
        Settings.SetEffectEnabled("blood", enabled, "mcm", true)
    elseif settingId == "effect_blur" then
        local enabled = toggleValue(value)
        if enabled == nil then return end
        Settings.SetEffectEnabled("blur", enabled, "mcm", true)
    elseif settingId == "sound_at_ms" then
        local ms = sliderMs(value, 0, 5000)
        if ms == nil then return end
        Settings.SetTrapTiming("soundAtMs", ms, "mcm", true)
    elseif settingId == "gameover_at_ms" then
        local ms = sliderMs(value, 0, 10000)
        if ms == nil then return end
        Settings.SetTrapTiming("gameOverAtMs", ms, "mcm", true)
    elseif settingId == "debug" then
        local enabled = toggleValue(value)
        if enabled == nil then return end
        Settings.SetDebugEnabled(enabled, "mcm", true)
    elseif settingId == "minigame_dump_native" then
        local enabled = toggleValue(value)
        if enabled == nil then return end
        Settings.SetMinigameDumpNative(enabled, "mcm", true)
    elseif settingId == "effect_ragdoll" then
        local enabled = toggleValue(value)
        if enabled == nil then return end
        Settings.SetRagdollEnabled(enabled, "mcm")
    else
        return
    end

    log(tostring(settingId) .. "=" .. tostring(value))
end

MM._buildListener = MM._buildListener or function()
    local ok, err = pcall(MM.BuildSettings)
    if not ok then log("build failed: " .. tostring(err)) end
end

MM._valueListener = MM._valueListener or function(settingId, value)
    local ok, err = pcall(MM.OnValueChanged, settingId, value)
    if not ok then log("value change failed: " .. tostring(err)) end
end

MM._buildRegistered = MM._buildRegistered or MM._registered or false
MM._valueRegistered = MM._valueRegistered or MM._registered or false

function MM.Register()
    if not apiAvailable() then
        if not MM._unavailableLogged then
            MM._unavailableLogged = true
            log("unavailable; menu integration disabled")
        end
        return false
    end

    if not MM._buildRegistered then
        local ok, result = pcall(
            MCM.RegisterBuildSettingsListener,
            MM._buildListener
        )
        if not ok or result == false then
            log("build-listener registration failed: " .. tostring(result))
            return false
        end
        MM._buildRegistered = true
    end

    if not MM._valueRegistered then
        local ok, result = pcall(
            MCM.RegisterValueChangeListener,
            MOD_ID,
            MM._valueListener
        )
        if not ok or result == false then
            log("value-listener registration failed: " .. tostring(result))
            return false
        end
        MM._valueRegistered = true
    end

    MM._registered = MM._buildRegistered and MM._valueRegistered
    MM._unavailableLogged = nil
    if MM._registered and not MM._registrationLogged then
        MM._registrationLogged = true
        log("listeners registered")
    end
    return MM._registered
end
