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
        reason = "DiedUnknown",
    },

    trapSequence = {
        enabled = true,
        gameOverEnabled = true,
        soundAtMs = 550,
        gameOverAtMs = 2000,
    },

    trapBuffExperiment = {
        enabled = false,
        maxBuffs = 20,
        buffs = {
            { id = "25bb8ae5-4b2a-4d82-aeef-0309d885f147", name = "trappedstashes_blood_screen" },
            { id = "117fe105-5c31-4e45-9e77-50993dae4472", name = "quest_utokNebakov_blur_short" },
            { id = "87b33bd6-c3bc-4974-8c34-01fd14ad7a36", name = "quest_utokNebakov_blur_long" },
            { id = "62eeb23f-ccbf-4af9-8f8d-de57da75c50e", name = "test_fading" },
            { id = "6b5db01c-0e65-4b5f-b9f6-f091f3bea121", name = "test_poison_visual" },
            { id = "7a7f5bdf-2b9d-4d84-9290-e09d3ce8d3d8", name = "test_bane_visual" },
            { id = "e211967c-e1de-4041-a0ea-d48d99ddb62b", name = "test_berserker_visual" },
            { id = "eca9aa28-9c54-4af1-9fac-c10b439c5a8b", name = "test_witch_visual" },
            { id = "0c903899-fcc9-4cf2-9ee3-1130ac08b0fc", name = "bleeding" },
            { id = "b0247507-ca18-4277-a037-ee3a9274e625", name = "test_bleeding" },
            { id = "3e9b2099-d1e5-493d-8fe4-8de9ea9e9e8a", name = "bleeding_thickblooded" },
            { id = "a2261902-5204-4e9d-b15e-b3b8d8495f40", name = "melee_hit_debuff" },
            { id = "10fc25ca-c095-44c6-b88b-d54ad58ab0a6", name = "injured_left_leg" },
            { id = "34f0885b-7287-4881-907f-f19751a5e831", name = "injured_left_arm" },
            { id = "37d59205-3782-446d-b32e-89a9f786725d", name = "injured_torso" },
            { id = "738f8a07-c5fd-4687-9408-34ffb0bcd17e", name = "injured_right_leg" },
            { id = "c48e48e2-ae85-4429-9dd6-4fb94c388001", name = "injured_head" },
            { id = "ce3737db-b0a3-459d-8d47-d58695d58be3", name = "injured_right_arm" },
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
