# Trap Death Audio

Status: prepared only. No sound plays until an ATL trigger name is configured.

Trapped Stashes uses the LuaUtils global sound helper:

```lua
wh.soundmodule.AudioOneShot(AtlTriggerName, LinkableObject)
```

The call is made from the existing eligible lockpick-break GameOver path:

```text
LockpickingResultTrigger.OnFailed
  -> triggerGameOverProof(session)
  -> TrappedStashes.Audio.PlayTrapDeath(session)
  -> TrappedStashes.GameOver.Trigger(reason)
```

Configuration lives in `Data/Scripts/TrappedStashes/Config.lua`:

```lua
trapDeathAudio = {
    enabled = true,
    trigger = "",
    linkable = "player",
}
```

Set `trigger` to the arrow/impact ATL trigger when available. With an empty
trigger, the module logs `audio skipped reason=missing-trigger` and does not
change gameplay.

`linkable` can be:

- `player`: play on Henry/player linkable object.
- `target`: play on the trapped target if available, otherwise player.

GameOver still fires even if the audio call fails.
