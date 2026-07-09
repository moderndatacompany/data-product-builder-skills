# Signals

## **Event-Driven Data Products**

The default mental model for data pipelines is a chain of schedules. Model A runs at midnight, Model B runs at 1 AM, Model C runs at 2 AM: each one assumes the previous one finished and the data is ready. This is a pipeline-first design: execution order is defined by time, not by the state of the data itself. It works until it doesn't.

When something is off, the entire chain produces incomplete output or fails, because nothing in the design checked whether the data was actually ready. The **schedule was a proxy for readiness**.

But what happens when you put data in the middle instead of the clock? Rather than asking "has enough time passed?", a *Signal* asks "is the data in the right state?"

That inversion is not a scheduling feature anymore, but an architectural shift in what the model treats as its **execution precondition**. The model becomes responsive to its inputs rather than oblivious to them.

It waits not because a cron told it to wait, but because the data it depends on has not yet **met the condition it declared**. When that condition is met, execution proceeds. Not a moment before or after. This is what it means to build a data product that is genuinely data-driven.

## Signals Overview

[https://tmdc-io.github.io/vulcan-book/components/advanced-features/signals/](https://tmdc-io.github.io/vulcan-book/components/advanced-features/signals/)
