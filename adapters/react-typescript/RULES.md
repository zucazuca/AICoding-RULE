# Adapter: React / TypeScript

> 技术栈适配规则。项目按需启用；不属于通用核心。
> 来源：多项目 React + TS + Vite 实践蒸馏，不含任何项目事实。

## TS 配置锁定

1. tsconfig 系列（tsconfig.json / tsconfig.app.json / tsconfig.node.json）视为**锁定配置**：
   禁止自动升级或重构；IDE 语言服务提示的"建议值"可能与项目构建器版本不兼容，以 `npm run build` 实际通过为准。
2. 项目必须在 05_PROJECT_CONTEXT.md 登记锁定项清单（如 ignoreDeprecations 值、composite、emitDeclarationOnly、路径别名），修改前逐项核对。

## 环境变量与 API 基址

3. 前端环境变量（VITE_* 等）区分环境模板维护；局域网 / 多机场景禁止使用 `127.0.0.1` 作为 API 基址（访问者的 127.0.0.1 是访问者自己）。
4. 前端不得持有任何 internal token / 服务间凭证；身份上下文以后端解析为准。

## 结构与状态

5. 新页面 / 新组件先看相邻实现的 API 层组织（client / types / 按域拆分文件）与状态管理方式，保持一致。
6. 禁止为单页需求引入新的全局状态库。

## 验证

7. 最低回归：`npm run build` 必须通过；lint 既有历史问题登记为基线，以"零新增"放行。
8. Mock 数据替换为真实 API 时，逐页替换并保留类型对齐（前端 types 与后端 schema 对应）。
