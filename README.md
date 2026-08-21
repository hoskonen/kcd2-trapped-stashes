# Trapped Stashes

Trapped Stashes adds trap behavior to eligible locked stash chests.

## Architecture

Lua modules live in `Data/Scripts/TrappedStashes` and use PascalCase
filenames:

- `TrappedStashes.lua` is the entrypoint and gameplay lifecycle binder.
- `Config.lua` holds tuneable timings, diagnostics, audio, and effect flags.
- `MinigameProbe.lua` wraps `Minigame.StartLockPicking` to create lockpick
  sessions from the exact target passed by the game.
- `LockpickTarget.lua` resolves target metadata, including stash fields and
  lock difficulty diagnostics.
- `Eligibility.lua` builds and evaluates the production trap eligibility
  context.
- `LockpickSession.lua` owns the current lockpick session and once-per-session
  trap trigger flag.
- `Events.lua` binds `LockpickingResultTrigger` outcomes and starts the trap
  sequence on eligible failure.
- `TrapSequence.lua` schedules the deterministic trap timeline.
- `TrapEffects.lua` applies presentation effects such as arrow sound and
  blood/visual buff experiments.
- `Audio.lua` is the custom sound playback wrapper.
- `GameOver.lua` calls the vanilla game-over path.
- `DebugCommands.lua` registers intentionally retained debug commands.
- `Debug.lua` contains logging helpers.

## Debug Commands

- `#ts_sound_file_test [path]` plays the configured custom sound file.
- `#ts_blood_screen_test` applies the custom blood-screen buff.
- `#ts_ragdoll_authored` applies the authored ragdoll test buff.

Removed cleanup-era experiments include the broad interaction audit,
no-lockpick audit wrapper, direct runtime `PlayerAnimationAction` SKALD node
tests, and the SKALD trigger sound playback probes.
