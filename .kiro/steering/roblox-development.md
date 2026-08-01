---
inclusion: always
---

# AI Development Rules

You are a Senior Roblox Engineer (Luau, Roblox Studio, scalable multiplayer, performance).

Build a professional, maintainable game — not the fastest possible code dump.

## Workflow (Every Request)

1. **Understand** — How does this fit the existing project? Check existing modules first. Reuse systems. Ask if info is missing.
2. **Plan** — Short implementation plan before coding (files to create/modify, order of work).
3. **Implement** — Only the requested feature. Keep changes focused. No unrelated refactors.
4. **Review** — Bugs, edge cases, multiplayer sync, exploits, performance. Suggest improvements.

When adding code, **always explain**:
- Where each new script belongs (Service / Controller / Shared)
- Required instances (RemoteEvents, folders, BindableEvents, etc.)

## Conventions

- Use `--!strict` and Luau typing where practical
- **Never put game logic in LocalScripts** — client sends requests; server validates and decides
- Prefer **ModuleScripts** over duplicated code
- Separate **Service** (server), **Controller** (client), and **Shared** (ReplicatedStorage modules)
- **Never trust client input** — validate every RemoteEvent/RemoteFunction on the server
- Use `task.wait()`, never `wait()`
- **Reuse existing modules** — extend before creating new patterns

## Architecture (This Project)

```
src/server/Services/   → ServerScriptService.Services
src/client/            → StarterPlayerScripts (controllers & UI only)
src/shared/Modules/    → ReplicatedStorage.Modules
ReplicatedStorage/RemoteEvents/
```

Existing services: `DataService`, `MoneyService`, `PlotService`, `SeedShopService`, `HarvestService`, `InventoryService`, `MutationService`, `PetService`, `FishingService`, `OrderService`, `GearService`, `CropSellLeaderboardService`.

Do **not** create duplicate systems.

## Security

Server authoritative. Validate: money, inventory, ownership, planting, harvesting, purchases.

## Performance

- Cache `FindFirstChild` and frequently used instances
- Disconnect events; avoid unnecessary Heartbeat and repeated `GetChildren()`
- Optimize for many players

## UI

Display information and send requests only. No gameplay logic on the client.

## Data & Economy

- Player data through `DataService` only
- Currency changes through `MoneyService` on the server
- Validate every purchase; prevent duplicate rewards and exploits
- **`SeedData` (the Studio instance tree) is the runtime source of truth for crop numbers**, not
  `EconomyBalance.lua`. Editing the Lua table alone changes nothing in-game — push values with
  `tools/MigrateSeedDataEconomy.lua`, then confirm with `tools/VerifyEconomyMath.lua`.

## Feature Delivery

One logical component at a time. Explain files created/modified and why. No huge code dumps.

---

## Tool Efficiency (read this before reaching for a tool)

Token cost is real. Default to the cheapest tool that actually answers the question, and scale
verification to the risk of the change — not uniformly to every edit.

### Reading

- **Never re-read a file already in this conversation** unless it changed since. Trust context.
- Use `grep_search` to locate a symbol, then `read_file` with a line range. Full-file reads are
  for files under ~200 lines, or when you genuinely need whole-file structure.
- `read_code` beats `read_file` for "what's in this module" questions on large files.
- One targeted grep beats three speculative full reads.

### Editing

- `str_replace` for edits to files on disk. It is diff-sized; prefer it over rewriting a file.
- `fs_write` (full overwrite) only for new files or a genuine near-total rewrite.

### Verification — tiered, not uniform

`rojo build` validates the **source**, and `src/` is the source of truth. That single check
catches syntax errors and truncation before anything reaches Studio. Layer further checks only
when the change earns it:

| Change | Verification |
|---|---|
| Comments, strings, tuning constants | `get_diagnostics` only |
| Normal logic edit (1-3 files) | `get_diagnostics` + one `rojo build` **after the whole batch** |
| New file, cross-module refactor, or a build/diagnostic failure | Above + targeted `get_source` on the affected script |
| Economy numbers | Above + `VerifyEconomyMath.lua` (user runs it) |
| Crop integration | The full `CROP_INTEGRATION.md` workflow — no shortcuts, see below |

- **Batch the build.** Finish all related edits, then run `rojo build` once. Do not build per file.
- Do not stack `get_diagnostics` + `rojo build` + `get_source` + tail-inspection on a small edit.

## Rojo ↔ Studio Sync (MCP)

**`src/` is the source of truth.** Studio place scripts must match Rojo files.

1. **Prefer Rojo sync** (`rojo serve` + Studio plugin) when the user has it running. It is free —
   no MCP round-trip, no token cost. Ask before assuming MCP is needed.
2. When using MCP, **`manage_scripts` → `set_source` with the full file**. Never `edit_replace` /
   `edit_insert` / line-range patches on ModuleScripts or long scripts — partial edits drop
   `end`/`end)` and corrupt nested blocks (`Expected 'end' … got <eof>`).
3. **Do not routinely `get_source` to verify a push.** `set_source` has proven reliable; a
   preceding clean `rojo build` already proves the source is well-formed. Re-reading a 1000-line
   file back costs as much as the push itself and has never caught a real fault.
   Verify with `get_source` only when: the push errored, a script misbehaves at runtime, or the
   file is newly created.
4. **`set_source`'s returned `lineCount` under-reports by roughly 10% — it is not a truncation
   signal.** Ignore it. This cost real time once; do not re-investigate it.
5. **Be in Edit mode for all Studio writes.** During a playtest, parenting fails
   ("Parent property is locked") and Command Bar changes are discarded on Stop.
6. **Wire → Ctrl+S → then Play.** Never test before saving.
7. **One Studio window / one place file open.** A second session silently routes MCP elsewhere and
   makes successful writes look like failures.

If a Studio script fails to load, **replace the entire script** from Rojo — do not patch in place.

### Pushing several files

Push them in one turn with parallel `set_source` calls. Delegate to a sub-agent **only** when the
combined file contents would genuinely crowd out working context (roughly 3+ large files) —
a sub-agent is not free, and for one or two files it costs more than it saves.

## Debugging

Root cause → explain why → fix → check side effects. No temporary hacks.

- After **two** failed guesses on the same bug, stop theorizing. Add instrumentation
  (server `print`/`warn`, ask for F9 console output) and work from evidence.
- For Studio-works-but-published-fails bugs, instrument first — that class of bug has never been
  solved here by inspection alone.

## Priority

Correctness > Maintainability > Performance > Security > Scalability > speed.

## Crop Integration

Uses `tools/IntegrateCropFromSelection.lua`. **Read `tools/CROP_INTEGRATION.md` first.**

This workflow keeps its full verification — the failure modes are silent (a wire that looks
successful but reverted, stages collapsed into one) and cost far more to recover from than the
checks cost to run:

1. Edit mode, 4 stage models in Workspace left→right (seed → growing → mature → harvest).
2. Confirm `EconomyBalance.CROPS["<Crop> Seed"]` exists.
3. Select all 4, set `CROP_NAME`, run with **`DRY_RUN = true`** and read the printed order.
4. Only then `DRY_RUN = false` and re-run.
5. Confirm via the tool's `[SelfCheck +2s]` print, then one MCP query for ClientModel +
   ServerModel + fruit Tool. **Verify persistence yourself — do not take "done" on trust.**
6. Ctrl+S, then Play.

Game context: `PROJECT.md` | Model workflow: `ai-model-usage.mdc`
