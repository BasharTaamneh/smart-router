---
description: METERED escalation to Fable 5. Requires cost confirmation.
---
Invoke @fable-advisor for: $ARGUMENTS

Run the four-condition gate in agents/fable-advisor.md FIRST.
If any condition fails, route to @advisor instead and say which one failed.
If all pass, emit the cost estimate and WAIT for an explicit y.
On any failure or unavailability, fall back to @advisor and continue.
