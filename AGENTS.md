# AGENTS.md

## Documentation Memory

This repo uses `memories/` to preserve architecture and planning snapshots over time.

Before analysis, planning, or code edits:

- Read `README.md` for the current product direction.
- Read `memories/index.md` before reading individual memory snapshots.
- Use the memory index to choose task-relevant memory files. Do not bulk-read every snapshot by default.
- If `memories/index.md` is missing or appears stale, list `memories/*.md` in chronological order and read filenames/headings before choosing files.
- Search `memories/` for task-relevant terms before touching code. Prioritize terms related to touched paths, Swift APIs, XPC, LaunchAgents, power assertions, leases, hooks, controller state, and testing.
- In the first substantive response, include a short "Memory context" note listing memory files read, current decisions that apply, and stale or conflicting older decisions when present.
- Treat older memories as historical. Current `README.md`, current source, and newer memories override older snapshots.
- Verify memory claims against current source before editing.
- If a durable decision, Swift gotcha, testing constraint, or repeated correction is discovered, propose an update to `memories/index.md` or `memories/inbox.md` before final handoff.

When making a meaningful README or architecture change:

- Create `memories/` if it does not exist.
- Snapshot the existing `README.md` before replacing it.
- Name snapshots as `<date>_vN.md`.
- Use the commit date of the content when it is known.
- If the new content is not committed yet, use the current local date and mention that assumption in the final response.
- After writing the new `README.md`, copy the new version into `memories/` with the next version number.
- Do not delete old memories unless explicitly asked.
- Be proactive about making sure that the readme reflects what we are currently trying to implement

Example:

```text
memories/2026-05-19_v1.md
memories/2026-05-26_v2.md
```

## Coding Style

- Match existing codebase patterns.
- Use Swift and native macOS APIs unless there is a strong reason not to.
- Keep comments minimal and contextual.
- Prefer explicit intent over cleverness.
- Avoid broad refactors while implementing narrow behavior.
- Remove redundant exports and avoid barrel-style forwarding modules.

## Verification

- Define success criteria before substantial implementation.
- Verify behavior directly when possible.
- If tests or checks are skipped, say so explicitly.
- For power-management behavior, prefer fail-closed behavior that restores normal sleep state.
