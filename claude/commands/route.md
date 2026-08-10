---
description: Force an explicit routing decision before acting. Shows the routing plan and waits for user approval.
argument-hint: <task description>
---

For the following task, do NOT execute yet. Instead:

1. Classify the task (trivial / complex / hard architectural / bulk mechanical).
2. State which worker you would route to (`self`, `@go-executor:<specific-model>`, or `@opus-advisor`) and why.
3. If routing to `@go-executor`, name the specific Go model you'd pick and the fallback.
4. State the estimated Claude limit cost (none / low / medium / high).
5. Wait for user approval before proceeding.

Format:
```
→ Proposed routing: <worker>
→ Reason: <one sentence>
→ Claude limit cost: <level>
→ Approve? (y / change / cancel)
```

Task:
$ARGUMENTS
