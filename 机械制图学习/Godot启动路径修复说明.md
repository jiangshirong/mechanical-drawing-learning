# Godot 启动路径修复

2026-10-10：Godot AI 4.1.0 使用固定环境 `C:/Users/12968/.codex/tools/godot-ai-realpath/venv`。环境底层直接指向 `C:/Users/12968/AppData/Roaming/uv/python/cpython-3.12.13-windows-x86_64-none`，不使用 `cpython-3.12-windows-x86_64-none` 目录联接，也不通过 uvx 查找解释器。

Codex 的 Godot MCP 启动命令和本工程的 `addons/godot_ai/client_configurator.gd` 已同步修改。编辑器重新配置客户端时仍生成固定环境的命令，环境丢失时报错，不自动回退到旧发现路径。Godot 原缓存环境和微信工具环境的 `pyvenv.cfg` 中的 Python home 也改为同版本真实目录；其余工具配置未变。

原配置和插件文件已备份在固定环境旁的 `backups` 目录，准确位置记录在 `qa/godot-runtime-path-fix.json`。该迁移脚本是一次性脚本，不需重新运行。插件整体升级可能覆盖本工程补丁，升级后应重新核对启动命令。

`qa/godot-runtime-verification.json` 记录通过新命令进行的 MCP 初始化、46项工具发现、编辑器注册、实际进程路径和退出核验。本次测试创建的进程均已结束。已有客户端连接需重新加载才能采用新启动命令；应用设置中的 MCP 连接重启方式见 [官方配置说明](https://learn.chatgpt.com/docs/extend/mcp?surface=cli)。

这次验证的是启动链绕开目录联接，没有重做 NtFC 压力测试，也不代表 Windows 内核缺陷已修复。历史积累和系统整体内存变化需另行观察。
