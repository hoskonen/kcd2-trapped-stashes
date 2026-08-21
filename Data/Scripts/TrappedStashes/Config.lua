TrappedStashes = TrappedStashes or {}

TrappedStashes.Config = {
    enabled = true,
    debug = true,

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
        gameOverEnabled = false,
        soundAtMs = 350,
        gameOverAtMs = 2000,
    },

    trapBuffExperiment = {
        enabled = true,
        maxBuffs = 20,
        buffs = {
            { id = "25bb8ae5-4b2a-4d82-aeef-0309d885f147", name = "trappedstashes_blood_screen" },
            { id = "6b5db01c-0e65-4b5f-b9f6-f091f3bea121", name = "test_poison_visual" },
            { id = "7a7f5bdf-2b9d-4d84-9290-e09d3ce8d3d8", name = "test_bane_visual" },
            { id = "e211967c-e1de-4041-a0ea-d48d99ddb62b", name = "test_berserker_visual" },
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
        interactionProbe = true,
        interactionDumpDepth = 2,
        interactionDumpKeys = 16,
        interactionDumpLines = 80,
        minigameProbe = true,
        minigameEntityStatePoll = true,
        minigamePollMs = 250,
        minigameDumpDepth = 1,
        minigameDumpKeys = 32,
        minigameDumpLines = 80,
        noLockpickAudit = true,
        noLockpickAuditSummaryMs = 1000,
    },
}

return TrappedStashes.Config
