# Trap Death Audio

Status: file playback prepared through LuaUtils `AudioManager`.

The configured sound is:

```lua
trapDeathAudio = {
    enabled = true,
    path = "Sounds/crossbow-shot1.wav",
    bus = "bus:/dieg/w_obj",
    volume = 1.0,
    pitch = 1.0,
}
```

The file is played by the timed arrow trap sequence:

```text
LockpickingResultTrigger.OnFailed
  -> TrappedStashes.TrapSequence.Start(session)
  -> soundAtMs
  -> TrappedStashes.Audio.PlayArrowTrapSound(session)
  -> gameOverAtMs
  -> TrappedStashes.GameOver.Trigger("DiedUnknown")
```

Timing is tuned in `Data/Scripts/TrappedStashes/Config.lua`:

```lua
trapSequence = {
    enabled = true,
    soundAtMs = 250,
    gameOverAtMs = 1250,
}
```

Both offsets are absolute milliseconds from sequence start.

Debug test command:

```text
ts_sound_file_test
ts_sound_file_test Sounds/crossbow-shot1.wav
```

This route does not use SKALD/ATL trigger names. It requires a LuaUtils build
that exposes the `AudioManager` global with `LoadSound` and `PlaySound`.

GameOver still fires even if the audio call fails.
