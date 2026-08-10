# TRAE 多设备配置同步技能

在 Mac 和 Windows 之间双向同步 TRAE 的技能、MCP 配置和插件开关状态。

## 文件结构

```
trae-multidevice-agent-skill/
├── SKILL.md                          # 技能定义文件（TRAE 可加载）
├── README.md                         # 本文件
├── scripts/
│   ├── sync.sh                       # Mac 同步脚本（init/push/pull/sync/status）
│   └── sync.ps1                      # Windows 同步脚本（同上）
└── desktop/
    ├── mac-pull.sh                   # Mac 桌面快捷脚本：拉取配置
    ├── mac-push.sh                   # Mac 桌面快捷脚本：推送配置
    ├── win-first-setup.ps1           # Windows 首次设置脚本
    ├── win-pull.ps1                  # Windows 桌面快捷脚本：拉取配置
    └── win-push.ps1                  # Windows 桌面快捷脚本：推送配置
```

## 快速开始

### Mac 端

```bash
# 1. 克隆同步仓库（如果还没有）
git clone git@github.com:<你的用户名>/<你的仓库>.git ~/trae-sync

# 2. 安装技能到本地
cp SKILL.md ~/.trae-cn/skills/trae-multidevice-agent-skill/

# 3. 日常使用桌面脚本
~/Desktop/mac-pull.sh   # 任务前：拉取其他设备的配置
~/Desktop/mac-push.sh   # 任务后：推送本机配置
```

### Windows 端

```powershell
# 1. 首次设置（克隆仓库 + SSH 密钥 + 首次同步）
.\win-first-setup.ps1

# 2. 日常使用桌面脚本
.\win-pull.ps1   # 任务前：拉取其他设备的配置
.\win-push.ps1   # 任务后：推送本机配置
```

## 运行时机说明

| 脚本 | 运行时机 | 是否需要开启 TRAE |
|------|----------|-------------------|
| mac-pull.sh / win-pull.ps1 | 任务开始前（每天首次打开 TRAE 前） | ❌ 不需要（建议关闭 TRAE） |
| mac-push.sh / win-push.ps1 | 任务结束后（关闭 TRAE 后） | ❌ 不需要（建议关闭 TRAE） |
| win-first-setup.ps1 | Windows 首次使用 TRAE 前 | ❌ 不需要 |
| sync（sync.sh/ps1） | 随时，推荐任务前后各一次 | ❌ 不需要 |

## 技术细节

详见 [SKILL.md](SKILL.md)
