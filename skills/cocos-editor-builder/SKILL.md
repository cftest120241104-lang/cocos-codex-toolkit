---
name: cocos-editor-builder
description: "通过 cocos-mcp 构建或修改 Cocos Creator 2.x 的场景与预制件内容。适用于用户希望 Codex 直接操作 Creator 编辑器本身的情况，例如打开场景、查看层级、创建节点、挂载或更新组件、实例化或保存预制件，以及修改运行中的 Cocos 项目内容。"
---

# Cocos 编辑器搭建

这个 skill 用于编辑器侧的内容创建和修改，不负责最终验收。

这个 skill 设计为从共享的 `cocos-codex-toolkit` 仓库安装，这样跨机器、跨项目时都能复用同一套编辑器工作流。
如果是可重复执行的编辑器动作，优先使用 toolkit CLI：
`cocos-toolkit scene-open`
`cocos-toolkit prefab-open`
`cocos-toolkit prefab-instantiate`
`cocos-toolkit prefab-create`
`cocos-toolkit scene-hierarchy`
`cocos-toolkit components-get`
`cocos-toolkit node-create`
`cocos-toolkit component-add`
`cocos-toolkit component-update`
`cocos-toolkit component-remove`
`cocos-toolkit node-rename`
`cocos-toolkit references-find`
`cocos-toolkit console-read`
`cocos-toolkit scene-save`

## 工作流

1. 绑定正确的项目实例。
   当目标项目尚未选中，或者存在多个 Creator 窗口时，先使用 `cocos-cc-manager`。
   在任何修改前，先确认当前项目就是目标项目。

2. 写入前先检查。
   改节点前，先调用 `get_scene_hierarchy`。
   改组件前，先调用 `manage_components` 且 `action: "get"`。
   做预制件相关操作前，先打开预制件或先确认目标父节点。

3. 通过 cocos-mcp 工具修改，不要靠猜 JSON 结构。
   优先使用：
   `open_scene`
   `open_prefab`
   `create_node`
   `update_node_transform`
   `manage_components`
   `prefab_management`
   `create_prefab`
   `save_scene`

4. 遵守严格的安全规则。
   不要修改一个你刚才没有确认存在的节点或组件。
   不要猜测组件属性名。
   资源引用一律使用 UUID，不要用伪路径字符串。
   场景编辑和脚本编辑分开处理；文件编辑只用于源码文件。

5. 保存并验证。
   做完有意义的改动后保存场景或预制件。
   再次读取层级或组件状态，确认编辑器真的接受了修改。
   如果用户要求确认项目仍然能干净运行，交给 `cocos-engine-qa`。

## 常见任务模式

场景布局：
打开场景
检查目标父节点
创建或移动节点
更新变换
保存

组件挂接：
检查节点
检查现有组件
添加或更新组件
确认资源引用使用的是 UUID

预制件操作：
打开预制件，或者先实例化到场景
修改节点和组件
保存预制件，或创建新的预制件

## 参考

在进行较大的编辑器修改前，先阅读 `references/safe-editing.md`，里面有简洁的检查清单和常见陷阱。
