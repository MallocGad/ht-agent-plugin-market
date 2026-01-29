# Changelog

All notable changes to the notification-system plugin will be documented in this file.

## [1.0.2] - 2026-01-29

### Changed
- **重大目录结构重构**：将所有运行时文件集中到 `~/.claude/scripts/system-notify/` 目录
  - 主脚本：`~/.claude/scripts/system-notify/` （原 `~/.claude/scripts/`）
  - 通知器：`~/.claude/scripts/system-notify/notifiers/` （原 `~/.claude/scripts/notifiers/`）
  - 日志文件：`~/.claude/scripts/system-notify/logs/` （原 `~/.claude/logs/`）
  - 临时状态文件：`~/.claude/scripts/system-notify/tmp/` （原 `/tmp/`）
- 更新所有脚本中的路径引用以匹配新的目录结构
- 更新文档中的所有安装和测试路径示例
- 更新 hooks 配置示例以使用新路径

### Benefits
- 所有相关文件集中在一个子目录中，更易于管理和备份
- 日志和临时文件与插件代码放在一起，更清晰的组织结构
- 避免污染 `~/.claude` 根目录和系统 `/tmp` 目录

## [1.0.1] - 2026-01-29

### Fixed
- 修复 `task-complete.sh` 从环境变量获取 session_id 的问题，改为从 Stop hook 的 JSON payload 中读取
- 修复 `task-start.sh` 从环境变量获取 session_id 的问题，改为优先从 payload 中读取
- 修复 `utils.sh` 安全检查阻止读取 `/tmp/` 目录状态文件的问题
- 修复 `install.sh` 未复制测试脚本的问题
- 正确处理 hook payload 中的所有字段（session_id、transcript_path、cwd、permission_mode、hook_event_name、stop_hook_active）

### Added
- 从 transcript 文件中智能提取最后一条 assistant 消息作为通知摘要
- 新增 `test-hook-payload.sh` 测试脚本，用于测试完整的 hook payload 处理
- 新增 `examples/complete-payload-example.sh` 示例脚本，展示如何处理完整的 hook payload
- `utils.sh` 现在允许读取 `/tmp/` 和 `/private/tmp/` 目录（用于状态文件）
- `install.sh` 现在自动复制测试脚本到 `~/.claude/scripts/`

### Changed
- 更新 `install.sh` 中的 hooks 配置说明，使用正确的嵌套结构格式
- 增强 `task-complete.sh` 和 `task-start.sh` 的错误处理和日志记录
- 更新 README，添加 hook payload 格式说明和高级用法文档
- 安装说明中添加了两个测试脚本的使用方法

## [1.0.0] - 2026-01-28

### Added
- 初始版本
- 支持 Mac 系统通知
- 支持钉钉和飞书 IM 通知
- 可配置的时间阈值
- 完整的日志系统
