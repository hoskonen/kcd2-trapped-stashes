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

local function sliderSeconds(value, minValue, maxValue)
    local number = tonumber(value)
    if number == nil then return nil end
    minValue = tonumber(minValue) or 0
    maxValue = tonumber(maxValue) or 60
    if number < minValue or number > maxValue then return nil end
    return math.floor((number * 10) + 0.5) / 10
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

local function profileById(config, profileId)
    local trapAudio = config.trapAudio or {}
    local profiles = trapAudio.profiles
    if type(profiles) ~= "table" then return nil end

    for _, profile in ipairs(profiles) do
        if type(profile) == "table" and profile.id == profileId then
            return profile
        end
    end
    return nil
end

function MM.BuildSettings()
    local config = cfg()
    local effects = config.effects or {}
    local trapSequence = config.trapSequence or {}
    local trapAudio = config.trapAudio or {}
    local trapTriggers = config.trapTriggers or {}
    local timedLockTrap = config.timedLockTrap or {}
    local diagnostics = config.diagnostics or {}
    local crossbowProfile = profileById(config, "crossbow") or {}
    local pistoleProfile = profileById(config, "pistole") or {}

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
    if config.devToggles == true then
        MCM.AddCategory(
            MOD_ID,
            "Developer - Audio",
            "Development controls for trap audio profile selection."
        )
        addToggle(
            "random_trap_audio",
            "Random trap audio",
            "Randomly select one enabled source-defined audio profile per trap.",
            trapAudio.randomEnabled ~= false
        )
        addToggle(
            "force_crossbow_audio",
            "Test crossbow only",
            "Force the crossbow profile for trap audio testing.",
            trapAudio.forcedProfile == "crossbow"
        )
        addToggle(
            "force_pistole_audio",
            "Test pistole only",
            "Force the pistole profile for trap audio testing.",
            trapAudio.forcedProfile == "pistole"
        )

        MCM.AddCategory(
            MOD_ID,
            "Crossbow Trap",
            "Development timing controls for the crossbow trap profile."
        )
        addSlider(
            "crossbow_impact_ms",
            "Impact delay",
            "Milliseconds from crossbow audio start to impact effects.",
            0,
            5000,
            50,
            tonumber(crossbowProfile.impactDelayMs) or 350,
            " ms"
        )
        addSlider(
            "crossbow_gameover_ms",
            "GameOver delay",
            "Milliseconds from crossbow trap trigger to GameOver.",
            0,
            10000,
            50,
            tonumber(crossbowProfile.gameOverDelayMs) or
                tonumber(trapSequence.gameOverAtMs) or 2000,
            " ms"
        )

        MCM.AddCategory(
            MOD_ID,
            "Pistole Trap",
            "Development timing controls for the pistole trap profile."
        )
        addSlider(
            "pistole_impact_ms",
            "Impact delay",
            "Milliseconds from pistole audio start to impact effects.",
            0,
            5000,
            50,
            tonumber(pistoleProfile.impactDelayMs) or 900,
            " ms"
        )
        addSlider(
            "pistole_gameover_ms",
            "GameOver delay",
            "Milliseconds from pistole trap trigger to GameOver.",
            0,
            10000,
            50,
            tonumber(pistoleProfile.gameOverDelayMs) or
                tonumber(trapSequence.gameOverAtMs) or 2600,
            " ms"
        )

        MCM.AddCategory(
            MOD_ID,
            "Timed Lock Trap",
            "Development controls for the hidden lock-turning fuse."
        )
        addToggle(
            "timed_fuse_enabled",
            "Timed fuse enabled",
            "Start a hidden trap fuse when lock turning begins.",
            timedLockTrap.enabled == true
        )
        addSlider(
            "min_fuse_seconds",
            "Minimum fuse time",
            "Shortest randomized fuse duration after lock turning begins.",
            1,
            30,
            0.5,
            tonumber(timedLockTrap.minFuseSeconds) or 8,
            " s"
        )
        addSlider(
            "max_fuse_seconds",
            "Maximum fuse time",
            "Longest randomized fuse duration after lock turning begins.",
            1,
            30,
            0.5,
            tonumber(timedLockTrap.maxFuseSeconds) or 14,
            " s"
        )
        addToggle(
            "trigger_on_lockpick_break",
            "Trigger on lockpick break",
            "Trigger an eligible trap when the lockpick breaks.",
            trapTriggers.onLockpickBreak ~= false
        )
        addToggle(
            "trigger_on_turn_release",
            "Trigger on turn release",
            "Trigger an eligible trap when lock turning is released after it began.",
            trapTriggers.onTurnRelease == true
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
    elseif settingId == "random_trap_audio" then
        local enabled = toggleValue(value)
        if enabled == nil then return end
        Settings.SetRandomTrapAudioEnabled(enabled, "mcm", true)
    elseif settingId == "force_crossbow_audio" then
        local enabled = toggleValue(value)
        if enabled == nil then return end
        Settings.SetForcedTrapAudioProfile(
            enabled and "crossbow" or nil,
            "mcm",
            true
        )
    elseif settingId == "force_pistole_audio" then
        local enabled = toggleValue(value)
        if enabled == nil then return end
        Settings.SetForcedTrapAudioProfile(
            enabled and "pistole" or nil,
            "mcm",
            true
        )
    elseif settingId == "crossbow_impact_ms" then
        local ms = sliderMs(value, 0, 5000)
        if ms == nil then return end
        Settings.SetTrapAudioProfileTiming(
            "crossbow",
            "impactDelayMs",
            ms,
            "mcm",
            true
        )
    elseif settingId == "crossbow_gameover_ms" then
        local ms = sliderMs(value, 0, 10000)
        if ms == nil then return end
        Settings.SetTrapAudioProfileTiming(
            "crossbow",
            "gameOverDelayMs",
            ms,
            "mcm",
            true
        )
    elseif settingId == "pistole_impact_ms" then
        local ms = sliderMs(value, 0, 5000)
        if ms == nil then return end
        Settings.SetTrapAudioProfileTiming(
            "pistole",
            "impactDelayMs",
            ms,
            "mcm",
            true
        )
    elseif settingId == "pistole_gameover_ms" then
        local ms = sliderMs(value, 0, 10000)
        if ms == nil then return end
        Settings.SetTrapAudioProfileTiming(
            "pistole",
            "gameOverDelayMs",
            ms,
            "mcm",
            true
        )
    elseif settingId == "timed_fuse_enabled" then
        local enabled = toggleValue(value)
        if enabled == nil then return end
        Settings.SetTimedFuseEnabled(enabled, "mcm", true)
    elseif settingId == "min_fuse_seconds" then
        local seconds = sliderSeconds(value, 1, 30)
        if seconds == nil then return end
        Settings.SetTimedFuseSeconds("minFuseSeconds", seconds, "mcm", true)
    elseif settingId == "max_fuse_seconds" then
        local seconds = sliderSeconds(value, 1, 30)
        if seconds == nil then return end
        Settings.SetTimedFuseSeconds("maxFuseSeconds", seconds, "mcm", true)
    elseif settingId == "trigger_on_lockpick_break" then
        local enabled = toggleValue(value)
        if enabled == nil then return end
        Settings.SetTrapTriggerEnabled("onLockpickBreak", enabled, "mcm", true)
    elseif settingId == "trigger_on_turn_release" then
        local enabled = toggleValue(value)
        if enabled == nil then return end
        Settings.SetTrapTriggerEnabled("onTurnRelease", enabled, "mcm", true)
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
