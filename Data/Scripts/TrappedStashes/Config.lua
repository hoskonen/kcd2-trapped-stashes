TrappedStashes = TrappedStashes or {}

TrappedStashes.Config = {
    enabled = true,
    debug = true,
    devToggles = true,

    effects = {
        sound = true,
        blood = true,
        blur = true,
        ragdoll = false,
    },

    lifecycle = {
        bindMaxTries = 50,
        bindRetryMs = 100,
    },

    gameOverProof = {
        enabled = true,
        reason = "trappedstashes_gameover_trap1",
    },

    trapSequence = {
        enabled = true,
        gameOverEnabled = true,
        soundAtMs = 350,
        gameOverAtMs = 2000,
    },

    trapAudio = {
        randomEnabled = true,
        forcedProfile = false,
        defaultProfile = "crossbow",
        profiles = {
            {
                id = "crossbow",
                type = "crossbow",
                enabled = true,
                files = {
                    "Sounds/crossbow-shot1.wav",
                    "Sounds/crossbow-shot2.wav",
                },
                impactDelayMs = 350,
                gameOverDelayMs = 2000,
            },
            {
                id = "pistole",
                type = "pistole",
                enabled = true,
                files = {
                    "Sounds/pistole-shot1.wav",
                },
                impactDelayMs = 900,
                gameOverDelayMs = 2600,
            },
        },
    },

    trapTriggers = {
        onLockpickBreak = true,
        onTurnRelease = false,
    },

    timedLockTrap = {
        enabled = true,
        minFuseSeconds = 8,
        maxFuseSeconds = 14,
    },

    trapBuffExperiment = {
        enabled = true,
        maxBuffs = 20,
        buffs = {
            { id = "62eeb23f-ccbf-4af9-8f8d-de57da75c50e", name = "test_fading" },
        },
    },

    trapDeathAudio = {
        enabled = true,
        path = "Sounds/crossbow-shot1.wav",
        bus = "bus:/dieg/w_obj",
        volume = 1.0,
        pitch = 1.0,
    },

    diagnostics = {
        minigameProbe = true,
        minigameEntityStatePoll = true,
        minigamePollMs = 250,
        minigameStateSampleMs = 100,
        minigameDumpNative = false,
        lockpickInputProbe = true,
        lockpickInputLifecycleLog = false,
        minigameDumpDepth = 1,
        minigameDumpKeys = 32,
        minigameDumpLines = 80,
    },
}

return TrappedStashes.Config
