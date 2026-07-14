# Adapter: Python / FastAPI

> 技术栈适配规则。项目按需启用（在 project-rule-profile 中登记）；不属于通用核心。
> 来源：多项目 FastAPI 实践蒸馏，不含任何项目事实。

## 结构与调用链

1. 遵循项目既有分层（router → service → repository/CRUD → database），禁止在 router 里直接写业务与 SQL。
2. 新增接口先看相邻 router 的鉴权依赖、响应模型和错误处理方式，保持一致。
3. Pydantic schema 是对外契约：改字段先查全部消费方（前端 / 其他服务 / 导出）。

## 配置与环境

4. 配置只从统一的 config 模块读取；禁止在业务代码中散落 `os.getenv`。
5. 注意 `.env` 自动加载的污染面：config 模块被 import 时可能加载本地 env 文件，测试与诊断要先确认实际生效的配置分支。
6. 环境判定（development / staging / production）必须显式；生产不允许静默回退到开发默认值。

## 异步边界

7. 同步 / 异步引擎、同步 / 异步路由不得混用同一会话对象；确认依赖注入给的是哪种 Session。
8. async 路径中禁止调用阻塞 IO（同步 requests、time.sleep、大文件同步读写）。

## 测试

9. 回归入口统一 `python -m pytest`；语法级验证可用 `python -m py_compile <入口文件>` 兜底。
10. FastAPI 测试优先 TestClient + 依赖 override（鉴权、DB session），不起真实服务。
11. 打包产物目录（dist / build / PyInstaller 输出）必须从 pytest collection 排除，避免污染。
