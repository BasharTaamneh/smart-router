---
description: Dispatch a task to the OpenCode Go model pool (18 models). Auto-picks the best model, or force one with @<model-id> or @<family>.
argument-hint: [@model-or-family] <task description>
---

Invoke the `go-executor` subagent to handle the following task.

If the task begins with `@<model-id>` (e.g. `@glm-5.1`, `@kimi-k2.6`, `@qwen3.5-plus`, `@minimax-m2.5`) or `@<family>` (e.g. `@glm`, `@kimi`, `@mimo`, `@qwen`, `@minimax`), force that model / family choice and skip auto-selection.

Otherwise, auto-select the best Go model for the task based on complexity, speed needs, and rate-limit budget.

The executor returns code. YOU (main Sonnet) apply edits using Edit/Write tools — the executor does not write files directly.

Before acting, print one transparency line:
```
→ Routing: @go-executor:<model-id> — <one-sentence reason>
```

Task:
$ARGUMENTS
