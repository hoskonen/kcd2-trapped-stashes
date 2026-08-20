# Lockpick Events

Project name: Trapped Stashes (`TrappedStashes`).

This audit used the shared local projects as source of truth:

- `Mods/LuaUtils`
- `Mods/skaldlab`
- `Mods/entityinspector`

## Current Findings

The concrete SKALD node available through LuaUtils is:

```lua
wh.playermodule.LockpickingResultTrigger
```

Generated LuaUtils file:

```text
Mods/LuaUtils/data/Scripts/LuaUtils/skald/generated/types/wh/playermodule/LockpickingResultTrigger.lua
```

Create inputs:

```text
IsActive
LockpickableEntity
```

Outputs:

```text
OnFailed
OnLockpicked
OnInterrupted
```

The generated `BindOutput` overloads expose callbacks with no documented
arguments. The logger still records runtime argument count as `args=N` so this
can be confirmed in `kcd.log`.

`LockpickableEntity` is a create input and an RTTR property on the node, not a
SKALD data output. The current logger samples `node:LockpickableEntity()` inside
each outcome callback and writes `lockpickable=...`; this is diagnostic only.
With no input supplied when creating the global result trigger, expect this to
remain `nil`, `unavailable`, or a port-ref handle until proven otherwise.

The strongest start-path clue found in vanilla scripts is:

```text
Data/Scripts.pak:Scripts/Entities/WH/Others/Lockpickable.lua
```

`Lockpickable:OnUsedHold(user, slot)` calls:

```lua
Minigame.StartLockPicking(self.id)
```

The same entity script documents `nUserId` as "set from C_Minigame::Start and
C_Minigame::Stop". Runtime testing confirmed `StartLockPicking` as the reliable
start signal. That gives two start/end surfaces:

- authoritative Lua call hook for lockpicking start:
  `Minigame.StartLockPicking(targetId)`
- lightweight native-state end probe: while that target is active, watch the
  lockpickable entity's `nUserId` transition back to `0`

LuaUtils generated RTTR exposes `wh.playermodule.E_MinigameType.LockPicking`
with enum value `5`, plus empty `I_Minigame` / `C_Minigame` wrappers. No direct
`IsActive`, `CurrentMinigame`, lockpicking UI screen, or minigame start/stop
SKALD trigger was found in the generated wrappers.

`wh.guimodule.ApseViewTrigger` exists with `OnEnter` / `OnLeave`, but its
`wh.framework.UIApseView` enum only covers apse tabs such as `Inventory`, `Map`,
`QuestLog`, and related views. It does not appear to represent the lockpicking
minigame UI.

## Event Table

| Desired lifecycle point | Native SKALD output | Current status | Notes |
| --- | --- | --- | --- |
| Lockpicking started | `Minigame.StartLockPicking(targetId)` Lua call | Authoritative source | Creates the `LockpickSession`, resolves the target entity immediately, and stores target metadata. |
| Lockpicking ended | `Lockpickable.nUserId` returning to `0` | Diagnostic poll added | Only polls while a hooked `StartLockPicking` session is active. Needs in-game confirmation across cancel, success, and lockpick break/game-over. |
| Lockpick broken / failure | `OnFailed` | Confirmed by SkaldLab | SkaldLab README reports this fired in-game after lockpick failure. Trapped Stashes logs it as `lockpick-broken`. |
| Lockpicking successful | `OnLockpicked` | Available, needs in-game confirmation | SkaldLab lists this as needing a success-case test. Trapped Stashes logs it as `lockpick-success`. |
| Lockpicking cancelled/interrupted | `OnInterrupted` | Available, needs in-game confirmation | SkaldLab lists this as needing an interruption-case test. Trapped Stashes logs it as `lockpick-interrupted`. |

## Implemented Logs

Expected lines from the current diagnostic implementation:

```text
[TrappedStashes] Initialized
[TrappedStashes] lockpick-events-bound count=3 outputs=OnFailed,OnLockpicked,OnInterrupted
[TrappedStashes] lockpick-session-start session=1 source=Minigame.StartLockPicking startKnown=true
[TrappedStashes] lockpick-target category=Stash targetId=... cryEntityId=... name=... class=... lockType=... nUserId=... lock.bLocked=... lock.bCanLockPick=... lock.fLockDifficulty=... lockDifficultyRaw=... lockDifficultyTier=... lockDifficultyPrompt=... lock.esLockFanciness=... lock.guidItemClassId=... stash.sGeneratedInventory=... stash.esChestContextLabel=... stash.inventoryWuid=...
[TrappedStashes] eligibility target=... class=Stash locked=true lockpickable=true chestLike=true forest=true socialClass bandit=true ruffian=false cuman=false faction bandit=true ruffian=false cuman=false lockDifficultyRaw=... lockDifficultyTier=... lockDifficultyPrompt=... generatedInventory=... context=... stashWuid=... ownerWuid=... homeWuid=... eligible=true reasons=
[TrappedStashes] lockpick-broken count=1 session=1 startKnown=true native=OnFailed args=0 lockpickable=...
[TrappedStashes] lockpick-success breakCount=1 session=1 startKnown=true native=OnLockpicked args=0 lockpickable=...
[TrappedStashes] lockpick-interrupted breakCount=0 session=1 startKnown=true native=OnInterrupted args=0 lockpickable=...
```

`startKnown=false` is now only a fallback. It means an outcome arrived without
the `StartLockPicking` hook creating a session first.

Additional expected diagnostic lines from `minigame_probe.lua`:

```text
[TrappedStashes] minigame-probe native-capabilities count=N keys=...
[TrappedStashes] minigame-probe-bound wrapped=N start=StartLockPicking end-candidates=StopLockPicking,Stop,End,Close,RequestExit
[TrappedStashes] minigame-probe call StartLockPicking args=1
[TrappedStashes] minigame-probe state inactive->active source=Minigame.StartLockPicking startCount=1 id=... entity=... name=... class=... nUserId=... detail=returns=N
[TrappedStashes] minigame-probe target-state targetId=... nUserId=...
[TrappedStashes] minigame-probe state active->inactive source=Lockpickable.nUserId targetId=... detail=returned-to-zero
```

If native functions named `StopLockPicking`, `Stop`, `End`, `Close`, or
`RequestExit` exist on the runtime `Minigame` table, the probe wraps them too
and logs them as end candidates. Those are diagnostic only until tested.

For the zero-lockpick edge case audit, see `docs/NO_LOCKPICK_AUDIT.md`.

## Next In-Game Test

Run these cases and compare against `kcd.log`:

1. Start lockpicking, cancel/back out.
2. Start lockpicking, break one pick, continue.
3. Start lockpicking, successfully open the lock.

Questions to answer:

- Does `nUserId` become non-zero during the lockpicking UI and return to `0`
  when lockpicking ends?
- Does this active/inactive signal behave correctly for cancel, success, and a
  broken lockpick followed by GameOver?
- Does `lockpick-target category=Stash` appear for stash lockpicking and
  `category=AnimDoor` for door lockpicking?
- For stashes, are `sGeneratedInventory`, `esChestContextLabel`, CryEntityId,
  and `inventoryWuid` populated consistently?
- Does `OnFailed` fire exactly once per broken lockpick?
- Does `OnInterrupted` fire on cancel/back-out?
- Does `OnLockpicked` fire after successful opening?
- Does any callback report `args` greater than `0`?
- Does `lockpickable=...` ever become a concrete lockpickable entity, or is it
  only the unset input port/ref on this node?
- Is there any separate log or behavior that can reveal a true start event?

## InteractionTriggerNode Probe

`wh.entitymodule.InteractionTriggerNode` is being tested as a possible
lockpick-session start signal. It is not integrated into `LockpickSession`.

Generated LuaUtils surface:

```lua
wh.entitymodule.InteractionTriggerNode
```

Create inputs:

```text
IsActive
Interactors
Type
```

Outputs:

```text
OnInteraction
Interactor
```

The current diagnostic creates the broadest safe instance:

```lua
wh.entitymodule.InteractionTriggerNode.Create({
    IsActive = true,
})
```

`Interactors` and `Type` are intentionally unset so the first test does not
filter out unknown interaction kinds. On every `OnInteraction`, it logs:

```text
[TrappedStashes] interaction-probe event=N args=... holder=... nodeType=... nodeInteractors=...
[TrappedStashes] interaction-probe interactor-summary event=N handle=... type=... rttr=... cpp=... id=... name=...
```

It also emits bounded dumps for:

```text
interaction-probe.interactor[N]
interaction-probe.interactorMeta[N]
interaction-probe.type[N]
interaction-probe.interactors[N]
```

The summary line checks common direct fields/getters for `id`, `name`, and
`class`, and records the source when one is readable.

Test cases:

1. Open an unlocked chest.
2. Start lockpicking.
3. Open a door.
4. Talk to an NPC.
5. Pick up an item.

Research question:

Does starting lockpicking fire `OnInteraction`, and can `Type` or `Interactor`
distinguish lockpicking from ordinary chest opening?

## Game Over Proof

The original lethal proof path used the implicit `OnFailed` session. When
`TrappedStashes.Config.gameOverProof.enabled` is `true`, the first `OnFailed`
for a session calls:

```lua
wh.playermodule.GameOver("trappedstashes_gameover_trap1")
```

`trappedstashes_gameover_trap1` is the Trapped Stashes custom row:

```text
game_over_id=1000
game_over_name=trappedstashes_gameover_trap1
game_over_ui_message=trappedstashes_gameover_trap1_text
```

The localized message key is:

```text
trappedstashes_gameover_trap1_text = "Ooops! You died from the arrow!"
```

This is temporary proof behavior for testing the custom Trapped Stashes game
over row. In the current test build,
`TrappedStashes.Config.gameOverProof.enabled` is `true`, so `OnFailed` should
trigger GameOver with `trappedstashes_gameover_trap1`.

This should be replaced by the real trap execution path before production trap
selection/probability work.
