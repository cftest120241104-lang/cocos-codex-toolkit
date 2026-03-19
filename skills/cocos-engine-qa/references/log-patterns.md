# Log Patterns

Use CDP logs as the source of truth. The same editor run may emit the same warning more than once during scene reloads, so deduplicate by normalized message text plus missing UUID when applicable.

## High-priority patterns

`The Asset used by component "..."`
- Treat as a real acceptance failure.
- Extract:
  component
  scene or prefab name
  node path
  asset url
  missing uuid
- Usually route next to `cocos-uuid-debug` or static asset reconstruction.

`TypeError`, `ReferenceError`, `SyntaxError`
- Treat as a runtime or import-time script failure.
- Capture the full exception text and the scene/prefab that triggered it.

`load script ... failed`
- Treat as a hard failure.
- Check script meta UUIDs, importer type, and generated TypeScript output.

## Medium-priority patterns

`object already destroyed`
- Usually indicates lifecycle or stale async callbacks.
- Keep it in the report, but separate it from asset-missing failures.

`Cannot set property 'lineWidth' of null`
- Usually indicates editor-side rendering code touching a missing/invalid object.
- Report it with the scene/prefab currently being replayed.

## Usually ignorable editor noise

`Timer 'scene:reloading' does not exist`
- Common editor noise during reload cycles.

`Port 3768 is in use, trying ...`
- MCP server startup noise, not a project failure.

`ipc failed to send`
- Ignore only if it happens while the panel is still loading and no asset failure follows.
- If it persists after the scene is ready, keep it as an editor stability issue.
