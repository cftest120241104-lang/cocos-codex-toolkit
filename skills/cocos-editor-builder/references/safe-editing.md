# Safe Editing

Use this checklist before editor-side writes:

1. Confirm the correct project is selected.
2. Confirm the target scene or prefab is open.
3. Confirm the target node exists with `get_scene_hierarchy`.
4. Confirm existing component state with `manage_components` before add or update.
5. Use UUIDs for assets such as prefabs, sprite frames, materials, and Spine data.
6. Save after meaningful edits.
7. Re-read hierarchy or component state after writes.

## Common mistakes

Guessing component property names
- Avoid this. Read the current component payload first.

Editing scene JSON directly
- Avoid this for editor content work. Use cocos-mcp scene and component tools.

Mixing content edits with acceptance
- Keep content creation separate from final validation.
- Use `cocos-engine-qa` only after the requested edits are complete.

Writing to the wrong Creator instance
- Always bind the target project first when multiple editor windows are open.
