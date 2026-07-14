# Adapter: Windows / PowerShell

> 技术栈适配规则。项目按需启用；不属于通用核心。
> 来源：Windows 开发环境实践蒸馏，不含任何项目事实。

## 编码与换行

1. 所有文本文件统一 UTF-8；PowerShell 读写显式指定编码（`-Encoding UTF8` / `[System.IO.File]::ReadAllText($p,[Text.Encoding]::UTF8)`），不依赖系统默认代码页。
2. 中文内容脚本注意 PowerShell 5.1 与 7 的默认编码差异；必要时脚本开头设置 `$OutputEncoding` 与 `[Console]::OutputEncoding`。
3. CRLF/LF 由 git autocrlf 管理；`git diff --check` 的换行 warning 不作为错误，但尾随空格是错误。

## 路径

4. 路径可能含空格与中文：一律加引号；拼接用 `Join-Path`，不手拼反斜杠。
5. 脚本内定位自身用 `$PSScriptRoot`，不依赖当前工作目录。
6. 与 Git Bash 混用时注意 `/e/work/...` 与 `E:\work\...` 两种路径形态的转换。

## 执行纪律

7. 有副作用的脚本必须支持 `-WhatIf`（SupportsShouldProcess）与执行前计划输出。
8. 修改用户文件前先备份；默认"检查与建议"，写操作必须显式开启。
9. 长时间任务与真实环境操作分开：脚本默认只读审计，写动作单独参数化。

## 进程与产物

10. 排查"改了代码没生效"先查旧进程 / 旧 exe / 旧打包产物是否仍在运行。
11. PyInstaller 等打包产物目录不进测试 collection、不进 git。
