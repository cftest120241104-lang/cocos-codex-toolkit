---
name: cocos-editor-builder
description: "Build or modify Cocos Creator 2.x scene and prefab content through cocos-mcp. Use when the user wants Codex to operate the Creator editor itself: open scenes, inspect hierarchy, create nodes, attach or update components, instantiate or save prefabs, or edit scene content in a running Cocos project."
---

# Cocos Editor Builder

Use this skill for editor-side content creation and modification. Do not use it as a final acceptance gate.

This skill is intended to be installed from the shared `cocos-codex-toolkit` repository so the same editing workflow can be reused across machines and projects.
Prefer the toolkit CLI for repeatable editor actions when possible:
`cocos-toolkit scene-open`
`cocos-toolkit prefab-open`
`cocos-toolkit scene-hierarchy`
`cocos-toolkit components-get`
`cocos-toolkit node-create`
`cocos-toolkit component-add`
`cocos-toolkit component-update`
`cocos-toolkit scene-save`

## Workflow

1. Bind the correct project instance.
   Use `cocos-cc-manager` when the target project is not already selected or when multiple Creator windows are open.
   Confirm the selected project before changing anything.

2. Inspect before writing.
   Before node edits, call `get_scene_hierarchy`.
   Before component edits, call `manage_components` with `action: "get"`.
   Before prefab work, open the prefab or inspect the target parent first.

3. Modify through cocos-mcp tools, not by guessing JSON.
   Prefer:
   `open_scene`
   `open_prefab`
   `create_node`
   `update_node_transform`
   `manage_components`
   `prefab_management`
   `create_prefab`
   `save_scene`

4. Follow strict safety rules.
   Never update a node or component that you have not just confirmed exists.
   Never guess property names on components.
   Always assign asset references by UUID, not by path-like strings.
   Keep scene edits and script edits separate; use file editing only for source files.

5. Save and verify.
   Save the scene or prefab after meaningful edits.
   Re-read hierarchy or component state to confirm the editor accepted the change.
   If the user asks for confidence that the project still runs cleanly, hand off to `cocos-engine-qa`.

## Task Patterns

Scene layout work:
open the scene
inspect the target parent
create or move nodes
update transforms
save

Component wiring:
inspect the node
inspect existing components
add or update the component
verify referenced assets use UUIDs

Prefab work:
open the prefab or instantiate into a scene
modify nodes and components
save prefab or create a new prefab

## References

Read `references/safe-editing.md` for the concise checklist and common pitfalls before performing larger editor changes.
