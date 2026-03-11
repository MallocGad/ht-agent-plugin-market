# Daemon Lifecycle Optimization Design

**Date**: 2026-02-02
**Status**: Implemented
**Version**: 2.0.4

## Overview

优化 notification-system 插件的守护进程生命周期管理，减少不必要的资源占用，提升系统资源利用效率。

## Background

当前守护进程在无活动任务时会持续运行 1 小时才退出，状态文件保留 24 小时，这导致：
- 守护进程长时间占用系统资源
- 用户关闭 Claude Code 后守护进程仍在运行
- 状态文件清理不及时

## Requirements

### Functional Requirements

1. 缩短守护进程无活动超时时间
2. Claude Code 退出时自动停止守护进程
3. 加快状态文件清理速度
4. 保持现有通知功能完全正常

### Non-Functional Requirements

1. 向后兼容：不影响现有功能
2. 自动化：用户无需手动配置
3. 可靠性：优雅处理各种边缘情况

## Design Decisions

### 1. 无活动超时时间

**决策**: 从 3600 秒（1 小时）缩短到 600 秒（10 分钟）

**理由**:
- 10 分钟足够用户思考和处理其他事情
- 下次任务会自动重启守护进程
- 大幅减少资源占用

### 2. SessionEnd Hook

**决策**: 添加 SessionEnd hook 自动停止守护进程

**理由**:
- 用户关闭 Claude Code 时应该清理所有后台进程
- 避免孤儿进程
- 提升用户体验

**实现方式**: 自动配置（在 install.sh 中）

### 3. 状态文件清理

**决策**: 从 24 小时缩短到 30 分钟

**理由**:
- 状态文件主要用于当前活跃任务
- 30 分钟后的状态文件基本无价值
- 与守护进程超时时间（10分钟）保持合理比例

## Implementation

### Modified Files

1. **task-monitor-daemon.sh**
   - `INACTIVITY_TIMEOUT`: 3600 → 600

2. **utils.sh**
   - `cleanup_old_state_files()`: `-mtime +1` → `-mmin +30`

3. **stop-daemon.sh** (新建)
   - SessionEnd hook 处理脚本
   - 调用 `stop_daemon()` 停止守护进程

4. **install.sh**
   - 复制 `stop-daemon.sh`
   - 自动配置 SessionEnd hook
   - 更新文档说明

5. **README.md**
   - 更新守护进程管理说明
   - 添加 SessionEnd hook 配置
   - 更新版本号到 2.0.4

6. **CHANGELOG.md**
   - 添加 2.0.4 版本变更记录

## Error Handling

### stop-daemon.sh 执行失败
- 守护进程 PID 文件损坏：安全清理
- 进程已不存在：清理 stale PID 文件
- 所有错误记录到日志

### install.sh 配置失败
- jq 不可用：提示用户手动配置
- settings.json 格式错误：备份原文件
- 配置失败不影响其他功能

### 边缘情况
- 用户快速重启 Claude Code：正常处理
- 守护进程清理时被停止：不会崩溃
- 多实例场景：共享守护进程（当前实现）

## Testing

### Manual Testing

1. 安装插件，验证 SessionEnd hook 自动配置
2. 启动任务，验证守护进程启动
3. 等待 10 分钟无活动，验证守护进程自动退出
4. 关闭 Claude Code，验证守护进程停止
5. 验证状态文件 30 分钟后清理

### Verification Commands

```bash
# 检查守护进程状态
ps aux | grep task-monitor-daemon

# 检查 PID 文件
cat ~/.claude/scripts/system-notify/state/daemon.pid

# 检查状态文件
ls -lh ~/.claude/scripts/system-notify/state/*.state

# 查看日志
tail -f ~/.claude/scripts/system-notify/logs/daemon.log
```

## Benefits

1. **资源优化**: 守护进程运行时间减少 83%（1小时 → 10分钟）
2. **更快清理**: 状态文件清理速度提升 48 倍（24小时 → 30分钟）
3. **更好体验**: Claude Code 退出时自动清理，无孤儿进程
4. **向后兼容**: 完全兼容现有功能，用户无感知

## Migration

### 对现有用户的影响

- **无需手动操作**: 重新运行 `install.sh` 即可
- **功能完全兼容**: 通知功能不受影响
- **配置自动更新**: SessionEnd hook 自动添加

### 升级步骤

```bash
cd plugins/notification-system/skills/notification-system/scripts
./install.sh
```

## Future Enhancements

1. 添加系统空闲检测（检测用户长时间无操作）
2. 添加最大运行时间限制（防止永久运行）
3. 多实例场景优化（引用计数）
4. 可配置的超时时间（通过配置文件）

## Approval

- [x] 设计方案已确认
- [x] 实现已完成
- [x] 文档已更新
- [x] 测试已通过
