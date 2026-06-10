# Memory Index

Read this file before using individual memories. The memory files are mostly README snapshots, so they are useful for architectural history but should not override the current `README.md` or current source.

## Current Direction

- Current product direction lives in `README.md`.
- The latest snapshot, `2026-06-07_v21.md`, is byte-for-byte identical to the current `README.md` as of June 7, 2026.
- `2026-06-07_v21.md` records the project rename from Adderall/`adderall` to Adderail/`adderail` using the `com.adderail` identifier base.
- Older snapshots are historical and use the former Adderall/`adderall` naming.
- The current proof is controller-first normal-awake behavior plus Claude Code, Codex, and Pi CLI installation, not a polished menu bar app and not privileged closed-lid behavior.
- Runtime shape: agent hook/extension -> `adderail` CLI -> XPC -> user LaunchAgent/controller -> `IOPMAssertion`.
- `adderail install claude` installs the user LaunchAgent/controller and Claude Code hooks; `adderail uninstall claude` removes those integration points.
- `adderail install codex` installs the user LaunchAgent/controller and Codex hooks in `~/.codex/hooks.json`; `adderail uninstall codex` removes those hooks.
- `adderail install pi` installs the user LaunchAgent/controller and an Adderail-owned Pi extension; `adderail uninstall pi` removes that extension.
- Claude, Codex, and Pi are implemented integrations.
- The CLI is a fast, non-interactive bridge during hook execution. It does not own power state, mutate the lease store directly, or hold power assertions.
- The controller owns live lease state, lease expiry, recovery snapshots, and normal awake assertions.
- The lease store is for recovery, diagnostics, and `status --json`; it is not IPC and not a command bus.
- Closed-lid `pmset` behavior belongs to a later privileged-helper milestone and must not be introduced during MVP 1.

## Always Check For Swift Work

- `README.md`
- `Package.swift`
- Relevant files under `Sources/AdderailCLI/`, `Sources/AdderailController/`, and `Sources/AdderailShared/`
- Relevant tests under `Tests/`

## Snapshot Map

- `2026-05-19_v1.md`: earliest product brief and planning snapshot.
- `2026-05-26_v2.md`: early README snapshot before the controller-first architecture was fully settled.
- `2026-05-27_v3.md`: introduces lifecycle hooks, leases, `IOPMAssertion`, helper safety rules, and early MVP sequencing.
- `2026-05-28_v4.md`: expands the controller-first direction and README structure.
- `2026-05-30_v5.md`: establishes current major architecture: controller-first proof, XPC, LaunchAgent, controller-owned lease state, no polling, no `sudo`, no closed-lid behavior in MVP 1.
- `2026-05-30_v6.md`: updates package/dependency direction around controller process lifecycle work.
- `2026-05-30_v7.md`: clarifies that shared lease/status data does not imply shared live state ownership; `LeaseManager` belongs in `AdderailController`.
- `2026-05-30_v8.md`: includes `swift-service-lifecycle` as process lifecycle scaffolding only.
- `2026-05-30_v9.md` through `2026-05-30_v12.md`: intermediate controller split, LaunchAgent, and smoke-test planning snapshots.
- `2026-05-30_v13.md`: records the first Claude Code hook entrypoint and development script installer direction.
- `2026-05-30_v14.md`: records the script-based Claude hook installer before it was promoted into the CLI.
- `2026-05-30_v15.md`: snapshot taken before replacing development scripts with product CLI install/uninstall commands.
- `2026-05-30_v16.md`: README snapshot where former `adderall install claude` / `adderall uninstall claude` are the user-facing integration commands.
- `2026-06-04_v17.md`: adds native Pi integration through former `adderall install pi` / `adderall uninstall pi` and documents shared LaunchAgent uninstall behavior.
- `2026-06-04_v18.md`: cleans up current state, documents Claude/Pi user-visible release/status behavior, and marks Codex as the next planned integration pass.
- `2026-06-06_v19.md`: pre-Codex README snapshot, preserved before updating the README for implemented Codex support.
- `2026-06-06_v20.md`: final pre-rename README snapshot; documents Codex as an implemented user-level hook integration using the former Adderall/`adderall` naming.
- `2026-06-07_v21.md`: current README snapshot; renames the project, package, CLI, controller, storage paths, hooks, and generated Pi extension from Adderall/`adderall` to Adderail/`adderail`.

## Current Decisions To Preserve

- Use Swift Package Manager for the proof until Xcode materially helps with signing, app bundles, ServiceManagement, helpers, or notarization.
- Keep the Xcode toolchain installed, but do not force an Xcode project before it is useful.
- Use native macOS APIs and Swift where possible.
- Use `swift-service-lifecycle` only to start the XPC listener, wait for graceful shutdown signals, and invalidate the listener on exit.
- Keep lease state, snapshots, timers, and power assertions as explicit controller-owned logic.
- Use scheduled expiry timers, not polling loops, for lease expiration.
- Treat hooks and Pi extension events as best-effort signals and TTL expiry as the safety net.
- Keep Claude, Codex, and Pi setup in explicit user-facing commands, not loose development scripts.
- Codex hooks require review/trust through Codex `/hooks` before non-managed Adderail hooks run.
- Do not treat "Codex session exists" as "Codex is actively working"; use turn and tool events.
- Prefer fail-closed behavior that restores normal sleep state.
- Never call `sudo` from hooks.
- Never expose a generic command execution API from the future privileged helper.

## Superseded Or Risky Older Ideas

- A standalone `caffeinate`-managed CLI is not the goal.
- The lease store must not be used as a command bus.
- Shared model types in `AdderailShared` do not mean live lease management belongs there.
- The menu bar app should not be the only process responsible for power state.
- Closed-lid `pmset` changes must wait for the privileged-helper milestone.

## Memory Maintenance

- When README architecture changes meaningfully, preserve the previous README snapshot and then snapshot the new README using the next `memories/<date>_vN.md` name.
- Update this index when a snapshot adds, supersedes, or clarifies a durable decision.
- If a useful lesson is discovered but not yet organized, add or propose `memories/inbox.md`.
- Keep this index short enough to load at the start of every session.
