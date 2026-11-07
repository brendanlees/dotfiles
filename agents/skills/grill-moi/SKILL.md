---
name: grill-moi
description: Interview the user relentlessly about a plan, design, decision or idea until there is a shared understanding. Use when the user asks to be grilled, to stress-test their thinking, or to poke holes in a plan before building it.
---

Interview the user until you reach a shared understanding. Map it as a **design tree**: every decision branches into the decisions that depend on it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask now without guessing at answers you haven't heard yet. Ask the whole frontier in one round, number each question and give your recommended answer. Then wait for the user's answers before the next round.

Format a round like so:

```
❓ **Q1** - **<question title>**: <question body, including any choices>

➡️ <your recommended answer>

---

❓ **Q2** - **<question title>**: <question body, including any choices>

➡️ <your recommended answer>
```

Word each question so "yes" accepts your recommended answer.

Each round of answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a later round.

Finding facts is your job, never the user's. Before asking a round, look up anything the environment can answer (files, code, docs, tools) yourself. The decisions are the user's: put each to them and wait.

The session is done when the frontier is empty: every branch visited, nothing silently assumed. Do not act on the outcome until the user confirms you have reached a shared understanding.

<!-- Adapted from the `grilling` skill in mattpocock/skills. Copyright (c) 2026 Matt Pocock, MIT License. -->
