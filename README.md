# Trapped Stashes

Trapped Stashes adds trap behavior to eligible locked stash chests.

## Architecture

Lua modules live in `Data/Scripts/TrappedStashes` and use PascalCase
filenames:

- `TrappedStashes.lua` is the entrypoint and gameplay lifecycle binder.
- `Config.lua` holds tuneable timings, diagnostics, audio, and effect flags.
- `Settings.lua` overlays validated LuaDB settings onto `Config.lua`, mutates
  runtime config from menu changes, and saves when KCDUtils/LuaDB is available.
- `ModMenu.lua` is the optional MCM adapter. The mod still runs without MCM.
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

## Configuration

Built-in defaults in `Config.lua` are always enough to run the mod. Optional
LuaDB persistence uses the `trappedstashes` namespace and `settings:v1` key when
KCDUtils DB support is available. Optional MCM integration builds a small player
menu for enabling the mod and toggling trap sound, blood, and blur effects.

Development-only MCM categories are controlled by the source flag
`devToggles` in `Config.lua`. Set `devToggles = false` for release builds to
omit developer controls entirely. The `devToggles` flag is not persisted and is
not exposed in MCM.

## Debug Commands

- `#ts_sound_file_test [path]` plays the configured custom sound file.
- `#ts_blood_screen_test` applies the custom blood-screen buff.
- `#ts_ragdoll_authored` applies the authored ragdoll test buff.

Removed cleanup-era experiments include the broad interaction audit,
no-lockpick audit wrapper, direct runtime `PlayerAnimationAction` SKALD node
tests, and the SKALD trigger sound playback probes.
