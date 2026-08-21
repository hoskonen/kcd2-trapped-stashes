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

    timedLockTrap = {
        enabled = true,
        minFuseSeconds = 8,
        maxFuseSeconds = 14,
    },

    trapBuffExperiment = {
        enabled = true,
        maxBuffs = 20,
        buffs = {
            { id = "25bb8ae5-4b2a-4d82-aeef-0309d885f147", name = "trappedstashes_blood_screen" },
            { id = "eca9aa28-9c54-4af1-9fac-c10b439c5a8b", name = "test_witch_visual" },
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
