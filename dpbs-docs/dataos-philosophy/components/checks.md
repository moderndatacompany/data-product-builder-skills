# Checks

## **Guardrails as Platform Enforcement**

There is a measurable difference between a team that follows good practices because they care and a team that follows good practices because the platform makes it structurally difficult to do otherwise.

- The first depends on **individual discipline, which is unscalable and unevenly distributed**.
- The second is a property of the system, which **holds regardless of who** is on the team, what they know, or how much time they have.

Checks are how *Vulcan* builds the second quality: Instead of blocking enforcement like audits, it ensures persistent, instrumented visibility that makes the cost of **ignoring quality problems progressively harder to justify**.

The data product doctrine's argument about defensive design is useful here. A defensive system delegates the brunt of mistrust to the foundational platform, so the users operating on top of it can trust what they receive.

Checks are the mechanism at the quality layer. They are the platform's way of watching what data teams would otherwise have to watch manually and surfacing problems without requiring anyone to think to look.

The value compounds as the suite of checks grows: each new check is a commitment encoded in the platform rather than buried in someone's head. When that person leaves, **the commitment stays**. When the team grows, **new members inherit it automatically**. Almost poetic justice.

The non-blocking nature of checks is also a deliberate design choice.

- *Audits* block because certain quality violations are structurally incompatible with downstream trust.
- *Checks* watch because many quality questions require context, like historical trends, proportional thresholds, and statistical distributions that cannot be reduced to a binary pass or fail at the moment of execution.

A check that flags a 40% drop in row count is not failing a pipeline but surfacing a signal that the pipeline owner is now accountable for investigating. That accountability (the feedback loop between the person who caused the problem and the system that detected it) is exactly what the data product doctrine sticks to when it argues that productisation fixes the cost-value asymmetry in data pipelines.

## Checks on Vulcan

[https://tmdc-io.github.io/vulcan-book/components/checks/checks/](https://tmdc-io.github.io/vulcan-book/components/checks/checks/)
