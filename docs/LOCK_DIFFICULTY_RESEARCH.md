# Lock Difficulty Research

Phase 1.5 status: a reproducible diagnostic accessor is implemented in
Trapped Stashes, but lock difficulty still does not affect eligibility or
gameplay behavior.

## Proven Vanilla Accessor

The exact entity passed to `Minigame.StartLockPicking(target)` exposes the same
lock difficulty that vanilla uses for the interaction prompt:

- `Scripts/Entities/WH/Stash/AnimStash.lua`
  - `Stash:OnUsedHold()` calls `Minigame.StartLockPicking(self.id)`.
  - The lockpick action hint calls
    `Crime.BuildLockpickPromptStrName(self.Properties.Lock.fLockDifficulty)`.
  - `Stash:GetLockDifficulty()` returns `self.Properties.Lock.fLockDifficulty`.
- `Scripts/Entities/Doors/AnimDoor.lua`
  - `AnimDoor:Lockpick()` calls `Minigame.StartLockPicking(self.id)`.
  - The lockpick action hint calls
    `Crime.BuildLockpickPromptStrName(self.Properties.Lock.fLockDifficulty)`.
  - `AnimDoor:GetLockDifficulty()` returns
    `self.Properties.Lock.fLockDifficulty`.

Trapped Stashes reads this through the existing bounded target resolver:

```text
entity.Properties.Lock.fLockDifficulty
entity:GetLockDifficulty()
```

The source is also emitted as a `lock-field` diagnostic line.

## Vanilla Prompt Thresholds

`Scripts/Systems/Crime.lua` maps the numeric value to prompt keys:

```text
>= 0.8 -> ui_hud_lockpick_difficulty_5 -> veryHard
>= 0.6 -> ui_hud_lockpick_difficulty_4 -> hard
>= 0.4 -> ui_hud_lockpick_difficulty_3 -> medium
>= 0.2 -> ui_hud_lockpick_difficulty_2 -> easy
>= 0.0 -> ui_hud_lockpick_difficulty_1 -> veryEasy
```

The vanilla comment says these thresholds must match the native
`LockPicking.h` constants, so they are the best available Lua-side mapping.

## Trapped Stashes Logging

`lockpick-target` and `eligibility` now include:

```text
lockDifficultyRaw=...
lockDifficultyTier=veryEasy|easy|medium|hard|veryHard|unknown
lockDifficultyPrompt=ui_hud_lockpick_difficulty_N|unknown
```

These values are diagnostic only. They do not affect:

- eligibility
- trap probability
- lockpick cancellation
- Game Over
- persistence

## In-Game Comparison Pass

Compare several lockable targets against the visible UI label:

```text
visible easy chest      -> logged raw/tier/prompt
visible medium chest    -> logged raw/tier/prompt
visible hard chest      -> logged raw/tier/prompt
visible very hard chest -> logged raw/tier/prompt
```

Evidence to record:

- whether `lockDifficultyRaw` is exact and stable for the same target
- whether `lockDifficultyTier` matches the visible UI wording
- whether any target logs `unknown`
- whether doors and stashes both report the same style of value
