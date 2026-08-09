---
name: trae-multidevice-agent-skill
description: 多设备间同步 TRAE 的技能(Skills)、MCP 配置和插件开关状态。支持 Mac 与 Windows 双向合并同步，处理多设备并发冲突。当用户需要跨设备保持 TRAE 配置一致、同步技能或 MCP 配置时使用。
---

# TRAE 多设备配置同步技能

## 适用场景

- 在 Mac 和 Windows 之间保持 TRAE 技能、MCP 配置、插件开关一致
- 多台设备同时使用 TRAE，需要配置双向同步
- 换设备工作时，快速拉取另一台设备的最新配置

## 配置存储位置

| 平台 | 用户级根目录 |
|------|-------------|
| macOS / Linux | `~/.trae-cn/` |
| Windows | `%USERPROFILE%\.trae-cn\` |

## 同步层级

| 层级 | 内容 | 同步方式 |
|------|------|----------|
| 用户级 | `skills/` 目录（自定义技能） | 专用 Git 仓库 + sync 脚本 |
| 用户级 | `skill-config.json`（技能启用状态） | 专用 Git 仓库 + sync 脚本 |
| 用户级 | `plugin-config.json`（插件开关） | 专用 Git 仓库 + sync 脚本 |
| 项目级 | `.trae/skills/`（项目技能） | 项目自己的 Git 仓库 |
| 项目级 | `.mcp.json`（MCP Server 配置） | 项目自己的 Git 仓库 |

## 不同步的内容（平台自动管理）

- `builtin/` — 内置技能，随应用版本下发
- `plugins/` — 市场插件文件，登录账号自动拉取
- `installed-plugins.json` — 插件市场缓存
- `mcps/` — MCP 工具描述符（会话级，自动生成）
- `extensions/` — VS Code 扩展
- OAuth 授权状态 — 需在每台设备重新授权

## sync 命令工作流程

```
1. git fetch origin          ← 获取远程最新
2. git reset --hard origin/main  ← 回到远程状态（安全：user-config 由合并重建）
3. 双向合并：
   - 本地独有 → 复制到仓库
   - 仓库独有 → 复制到本地
   - 两端都有但不同：
     · 技能文件 → 保留本地版本
     · JSON 配置 → 深度合并（union keys，冲突保留本地）
4. git commit + push         ← 推送合并结果
```

## 并发处理

多台设备同时 sync 时，push 可能失败（non-fast-forward）：
- 自动重试最多 3 次，退避间隔 2s → 4s → 6s
- 每次重试重新 fetch + reset + merge（幂等，不丢数据）
- 3 次失败后手动重跑即可

## 使用方法

### 首次设置

```bash
# Mac
cd ~/trae-sync
./sync.sh init
git remote add origin git@github.com:<user>/<repo>.git
./sync.sh push

# Windows
git clone git@github.com:<user>/<repo>.git %USERPROFILE%\trae-sync
cd $env:USERPROFILE\trae-sync
.\sync.ps1 sync
```

### 日常使用

```bash
# Mac — 任务开始前和结束后各跑一次
./sync.sh sync

# Windows — 同上
.\sync.ps1 sync
```

### 命令一览

| 命令 | Mac | Windows | 说明 |
|------|-----|---------|------|
| `init` | `./sync.sh init` | `.\sync.ps1 init` | 初始化仓库 |
| `sync` | `./sync.sh sync` | `.\sync.ps1 sync` | 双向合并（推荐） |
| `push` | `./sync.sh push` | `.\sync.ps1 push` | 单向：本地→仓库 |
| `pull` | `./sync.sh pull` | `.\sync.ps1 pull` | 单向：仓库→本地（覆盖） |
| `status` | `./sync.sh status` | `.\sync.ps1 status` | 查看差异 |

## MCP 跨平台注意事项

`.mcp.json` 中 stdio 类型的 MCP Server 若含绝对路径，换平台会失效：
- 用 `npx` / `uvx` 等跨平台启动器，不写绝对路径
- 敏感 token 用环境变量：`"API_KEY": "${API_KEY}"`
- 必须写路径时，两端分别维护

## 项目级配置

项目级 `.trae/skills/` 和 `.mcp.json` 直接提交到项目 Git 仓库：

```bash
mkdir -p .trae/skills
git add .trae/skills/ .mcp.json
git commit -m "add trae project config"
```

`.gitignore` 只放行 skills：
```
.trae/*
!.trae/skills/
```

## 最佳实践

1. **任务开始前** sync 一次（拉取其他设备的最新配置）
2. **任务结束后** sync 一次（推送本机变更）
3. 避免任务运行中频繁 sync（减少冲突）
4. 换设备前 push，到新设备后 sync
5. 定期检查 `status` 确认两端一致
