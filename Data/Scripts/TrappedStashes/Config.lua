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
