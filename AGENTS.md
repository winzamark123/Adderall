# AGENTS.md

## Documentation Memory

This repo uses `memories/` to preserve architecture and planning snapshots over time.

When making a meaningful README or architecture change:

- Create `memories/` if it does not exist.
- Snapshot the existing `README.md` before replacing it.
- Name snapshots as `<date>_vN.md`.
- Use the commit date of the content when it is known.
- If the new content is not committed yet, use the current local date and mention that assumption in the final response.
- After writing the new `README.md`, copy the new version into `memories/` with the next version number.
- Do not delete old memories unless explicitly asked.

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
