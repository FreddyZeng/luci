# 任务日志

> 按 CID 记录每次 commit 的详细信息。

---

## [2026-03-05] C-F001-01

- **FID**: F-001 (SSR-Plus Scripts Initialization)
- **CID**: C-F001-01
- **BID**: B-167
- **类型**: fix
- **范围**: update-script
- **描述**: 修复更新路由规则空包覆盖灾难
- **关联任务**: 
- **改动文件**: root/usr/share/shadowsocksr/update.lua
- **PRD 同步**: ⏭️ 不涉及 (Bug修复)
- **方案同步**: ⏭️ 不涉及 (Bug修复)
- **测试同步**: ⏭️ 不涉及 (Shell脚本逻辑级修复)
- **日志 TAG**: [UPDATE-B167-①~②]
- **关联 ADR**: 
- **关联 DIAG**: 

## [2026-03-05] C-F001-02

- **FID**: F-001 (SSR-Plus Scripts Initialization)
- **CID**: C-F001-02
- **BID**: B-168
- **类型**: fix
- **范围**: update-script
- **描述**: 将 `cp` 替换为影子文件原子重命名 `mv` 彻底防止极低概率闪存放缓截断损坏
- **关联任务**: 
- **改动文件**: root/usr/share/shadowsocksr/update.lua
- **PRD 同步**: ⏭️ 不涉及 (Bug修复)
- **方案同步**: ⏭️ 不涉及 (Bug修复)
- **测试同步**: ⏭️ 不涉及 (Shell脚本逻辑级修复)
- **日志 TAG**: [UPDATE-B167-②]
- **关联 ADR**: 
- **关联 DIAG**: 
