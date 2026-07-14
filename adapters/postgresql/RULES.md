# Adapter: PostgreSQL（含 SQLite 双轨期）

> 技术栈适配规则。项目按需启用；不属于通用核心。
> 来源：SQLite → PostgreSQL 迁移与双轨运行实践蒸馏，不含任何项目事实。

## 双轨期纪律

1. 双轨期（开发 SQLite / 生产 PostgreSQL）新增代码必须跨方言：禁止扩散 SQLite 专属写法（无 ELSE 的 CASE、隐式布尔、字符串拼日期等）。
2. 判断某组连接池 / 引擎配置是否生效，必须追到引擎工厂函数的实际分支，不能靠 grep 局部命中。
3. 本地库与代码 schema 可能漂移：使用全局引擎的测试失败先排查漂移，再怀疑代码。

## 迁移纪律

4. PostgreSQL 下禁止 ORM create_all 建表；必须先跑迁移（Alembic 等）。
5. 数据迁移脚本默认 dry-run；apply 必须有环境放行门（production 需显式批准）。
6. 切库必须走 Runbook：备份 → preflight → 建库 → 迁移 → dry-run → apply → 切换 → 冒烟 → 可回滚；禁止跳步。
7. 常见跨方言修复点提前自查：库名/空串默认值/varchar 长度/datetime 时区/bool/bigint/jsonb。

## 平台坑

8. Windows 本机连 PG 用 `127.0.0.1` 而非 `localhost`（localhost 可能解析 IPv6 导致连接重置；驱动表现不一）。
9. WAL 模式下数据库文件 hash 不能作为"数据未变化"的证据。
