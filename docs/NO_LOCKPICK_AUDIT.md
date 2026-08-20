# No-Lockpick Interaction Audit

Status: temporary diagnostics only. No gameplay behavior is changed.

## Instrumentation

The audit wraps the earliest narrow Lua entry points that call lockpicking:

- `Stash.OnUsedHold`
- `Stash.OnUsed`, only when the stash is still locked
- `AnimDoor.Lockpick`

It then observes the existing Trapped Stashes lifecycle:

- `Minigame.StartLockPicking(target)` wrapper
- `LockpickSession.BeginFromStart`
- `Eligibility.Classify`
- `LockpickingResultTrigger.OnFailed`
- `LockpickingResultTrigger.OnInterrupted`
- `LockpickingResultTrigger.OnLockpicked`

No lockpick inventory count accessor was obvious from the proven code paths, so
the audit logs `lockpickCount=unknown`.

## Expected Log Shape

With at least one lockpick:

```text
[TrappedStashes] noLockpickAudit start id=1 source=Stash.OnUsedHold target=... lockpickCount=unknown StartLockPicking observed=false eligibility evaluated=false
[TrappedStashes] noLockpickAudit StartLockPicking observed=true id=1 target=...
[TrappedStashes] eligibility ... eligible=...
[TrappedStashes] noLockpickAudit eligibility evaluated=true id=1 target=...
```

Then one of:

```text
[TrappedStashes] noLockpickAudit result=failed id=1 ...
[TrappedStashes] noLockpickAudit result=interrupted id=1 ...
[TrappedStashes] noLockpickAudit result=lockpicked id=1 ...
```

With zero lockpicks, compare the same chest:

```text
[TrappedStashes] noLockpickAudit start id=2 source=Stash.OnUsedHold|Stash.OnUsed target=... lockpickCount=unknown StartLockPicking observed=false eligibility evaluated=false
```

If no later Start/result lines appear, the delayed summary should say:

```text
[TrappedStashes] noLockpickAudit summary id=2 target=... StartLockPicking observed=false eligibility evaluated=false result=none lockpickCount=unknown
```

If `StartLockPicking observed=true` appears with zero lockpicks, future
trap/warning logic can probably stay attached to `StartLockPicking`.

If only the `start` and `summary` lines appear, vanilla rejected the attempt
before `Minigame.StartLockPicking`, and future zero-lockpick handling will need
an earlier interaction hook.

## Test Matrix

Use the same locked eligible bandit chest:

```text
A. Henry has at least one lockpick.
B. Henry has zero lockpicks.
```

Record the exact sequence for both cases.
