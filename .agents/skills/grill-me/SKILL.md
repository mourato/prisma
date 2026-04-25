---
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
---

# Grill Me

## Role

Use this skill as the canonical owner for adversarial plan review and design stress-testing conversations.

- Own the questioning mode where the goal is to expose assumptions, trade-offs, and hidden dependencies.
- Ask one question at a time and keep pressure on unresolved branches until they are explicit.
- Prefer codebase exploration over asking the user for facts that can be verified locally.

## Scope Boundary

- Use this skill for interactive plan interrogation and decision-tree walkthroughs.
- Do not use it for routine code implementation or passive explanation.

## When to Use

Use this skill when the user wants to stress-test a plan, get grilled on a design, or explicitly says "grill me".

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time.

If a question can be answered by exploring the codebase, explore the codebase instead.
