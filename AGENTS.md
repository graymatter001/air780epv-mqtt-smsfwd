# AGENTS

## Lua Development

- Do not `require("json")`; the module is preloaded.
- Check with the user before requiring other libs—many load automatically.
- Reference LuatOS APIs in `references/LuatOS-api`.

## Bark Message Transforms

1. Inspect existing payload examples before writing EMQX SQL.
2. Review `references/bark-api.md` for Bark payload fields and limits.
3. Build clear notifications: meaningful title, detailed body, fitting icon, and useful context.
4. Prioritize clarity and completeness so notifications are actionable.
