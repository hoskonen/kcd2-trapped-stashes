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
- `LockpickInputProbe.lua` observes the proven `lock_dir_fwd` press signal and
  starts the hidden timed trap fuse for eligible sessions.
- `TrapAudioProfiles.lua` selects one source-defined audio profile per
  triggered trap and keeps it stable for the sequence.
- `LockpickTarget.lua` resolves target metadata, including stash fields and
  lock difficulty diagnostics.
- `Eligibility.lua` builds and evaluates the production trap eligibility
  context.
- `LockpickSession.lua` owns the current lockpick session and once-per-session
  trap/fuse state.
- `Events.lua` binds `LockpickingResultTrigger` outcomes. Lockpick failure
  triggers an eligible trap immediately; success and interruption cancel any
  active fuse.
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

`timedLockTrap` controls the hidden fuse started by the first real lock-turning
input. `minFuseSeconds` and `maxFuseSeconds` are persisted through LuaDB/MCM and
can be tuned independently of the presentation delays in `trapSequence`.

`trapAudio` contains source-defined audio profiles. Each profile has an id/type,
one or more files, an enabled flag, `impactDelayMs`, and optional
`gameOverDelayMs`. When a trap fires the mod selects one enabled profile and one
file from that profile once, starts that audio, then applies impact effects and
GameOver using that profile's timing. MCM can toggle random profile selection
and force a single profile for testing, but profile paths remain source
configuration.

The older global trap sequence timings remain internal fallbacks only. Current
developer tuning should use the Crossbow Trap and Pistole Trap profile timings.

`trapTriggers` controls developer gameplay experiments. Lockpick-break traps are
enabled by default. Turn-release traps are disabled by default and only fire
after lock turning has already begun.

Future research may replace the wall-clock fuse with active-turn-only timing,
but the current implementation intentionally uses one randomized timer from the
first `lock_dir_fwd` press.

For future active-turn-only countdown work, `lock_dir_fwd` exposes both `press`
and `release` transitions during a single lockpick session. A disabled-by-default
developer diagnostic can log those transitions without changing the production
fuse, which still starts only on the first press.

## Debug Commands

- `#ts_sound_file_test [path]` plays the configured custom sound file.
- `#ts_blood_screen_test` applies the custom blood-screen buff.
- `#ts_ragdoll_authored` applies the authored ragdoll test buff.

Removed cleanup-era experiments include the broad interaction audit,
no-lockpick audit wrapper, direct runtime `PlayerAnimationAction` SKALD node
tests, and the SKALD trigger sound playback probes.
