TrappedStashes = TrappedStashes or {}
TrappedStashes._lifecycleBindGeneration =
    tonumber(TrappedStashes._lifecycleBindGeneration) or 0

Script.ReloadScript("Scripts/TrappedStashes/Config.lua")
Script.ReloadScript("Scripts/TrappedStashes/Debug.lua")
Script.ReloadScript("Scripts/TrappedStashes/LockpickTarget.lua")
Script.ReloadScript("Scripts/TrappedStashes/Eligibility.lua")
Script.ReloadScript("Scripts/TrappedStashes/LockpickSession.lua")
Script.ReloadScript("Scripts/TrappedStashes/Audio.lua")
Script.ReloadScript("Scripts/TrappedStashes/GameOver.lua")
Script.ReloadScript("Scripts/TrappedStashes/TrapEffects.lua")
Script.ReloadScript("Scripts/TrappedStashes/TrapSequence.lua")
Script.ReloadScript("Scripts/TrappedStashes/Events.lua")
Script.ReloadScript("Scripts/TrappedStashes/DebugCommands.lua")
Script.ReloadScript("Scripts/TrappedStashes/MinigameProbe.lua")

function TrappedStashes.OnGameplayStarted()
    if TrappedStashes.Config and TrappedStashes.Config.enabled == false then
        return
    end

    TrappedStashes.Events.Reset("OnGameplayStarted")
    TrappedStashes.MinigameProbe.Reset("OnGameplayStarted")
    TrappedStashes.TrapSequence.Reset("OnGameplayStarted")
    TrappedStashes.TrapEffects.Reset("OnGameplayStarted")
    TrappedStashes.Debug.Log("Initialized")
    TrappedStashes.Commands.Register()
    TrappedStashes.Events.RegisterLockpicking()
    TrappedStashes.MinigameProbe.Register()
end

function TrappedStashes.BindLifecycleEvents(maxTries, delayMs)
    if TrappedStashes._lifecycleBound then
        return true
    end

    local lifecycle = TrappedStashes.Config.lifecycle or {}
    maxTries = tonumber(maxTries) or tonumber(lifecycle.bindMaxTries) or 50
    delayMs = tonumber(delayMs) or tonumber(lifecycle.bindRetryMs) or 100

    TrappedStashes._lifecycleBindGeneration =
        TrappedStashes._lifecycleBindGeneration + 1
    local bindGeneration = TrappedStashes._lifecycleBindGeneration
    local tries = 0

    local function attempt()
        if TrappedStashes._lifecycleBound or
                bindGeneration ~= TrappedStashes._lifecycleBindGeneration then
            return
        end

        tries = tries + 1
        local available = UIAction and
            type(UIAction.RegisterEventSystemListener) == "function"

        if available then
            local ok, result = pcall(
                UIAction.RegisterEventSystemListener,
                TrappedStashes,
                "System",
                "OnGameplayStarted",
                "OnGameplayStarted"
            )

            if ok then
                TrappedStashes._lifecycleBound = true
                return true
            end

            System.LogAlways("[TrappedStashes] listener bind failed: " ..
                tostring(result))
        end

        if tries < maxTries and Script and type(Script.SetTimer) == "function" then
            Script.SetTimer(delayMs, attempt)
            return false
        end

        System.LogAlways("[TrappedStashes] listener unavailable")
        return false
    end

    attempt()
    return TrappedStashes._lifecycleBound == true
end

function TrappedStashes.Bootstrap()
    TrappedStashes._booted = true
end
