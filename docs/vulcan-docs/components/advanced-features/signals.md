# Signals

Vulcan's built-in scheduler knows when to run your models based on their `cron` schedules. For a model set to run `@daily`, it checks whether a day has passed since the last run and evaluates the model when needed.

Real-world data doesn't always follow schedules. Data arrives late: upstream systems have issues, batch jobs run behind schedule. When that happens, your daily model might have already run for the day, and the late data won't be processed until tomorrow's scheduled run.

Signals solve this by adding custom conditions that must be met before a model runs. They're extra gates the scheduler checks, beyond "has enough time passed?" and "are upstream dependencies done?"

## What is a signal?

By default, Vulcan's scheduler uses 2 criteria to decide if a model should run:

1. Has the model's `cron` interval elapsed since the last evaluation?
2. Have all upstream dependencies finished running?

Signals add a third criterion: your custom check. A signal is a Python function that examines a batch of time intervals and decides whether they're ready for evaluation.

Under the hood: the scheduler doesn't evaluate "a model"; it evaluates a model over specific time intervals. For incremental models, you're processing a date range. Non-temporal models like `FULL` and `VIEW` are also evaluated based on time intervals; their `cron` frequency determines the interval.

The scheduler looks at candidate intervals, groups them into batches (controlled by your model's `batch_size` parameter), and checks signals to see if those batches are ready. Your signal function receives a batch of time intervals and can return:

- `True` if all intervals in the batch are ready.

- `False` if none are ready.

- A list of specific intervals if only some are ready.

{% hint style="info" %}
**One model, multiple signals**

Specify multiple signals for a single model. Vulcan requires that **all** signal functions agree an interval is ready before evaluating it. It works like an AND gate: every signal must give the green light.
{% endhint %}

## Defining a signal

Add a `signals` directory to your project and create your signal function in `__init__.py`. You can organize signals across multiple Python files.

A signal function must:

- Accept a batch of time intervals (`DateTimeRanges: t.List[t.Tuple[datetime, datetime]]`).

- Return either a boolean or a list of intervals.

- Use the `@signal` decorator.

Examples follow, from simple to more complex.

### Simple example

A basic signal that randomly decides whether intervals are ready (useful for testing, not production):

```python
import random
import typing as t
from vulcan import signal, DatetimeRanges


@signal()
def random_signal(batch: DatetimeRanges, threshold: float) -> t.Union[bool, DatetimeRanges]:
    return random.random() > threshold
```

This signal takes a `threshold` argument (passed from your model definition) and returns `True` if a random number exceeds that threshold. The function signature includes `threshold: float`; Vulcan extracts this from your model definition and passes it to the function. Type inference works the same way as [Vulcan macros](./macros/built_in.md#typed-macros).

Add the signal to the `signals` key in your `MODEL` block:

```sql hl_lines="4-6"
MODEL (
  name example.signal_model,
  kind FULL,
  signals (
    random_signal(threshold := 0.5), # specify threshold value
  )
);

SELECT 1
```

The `signals` key accepts a list of signal calls, each with its own arguments. When you run `vulcan run`, this signal checks if a random number is greater than 0.5. If yes, the model runs; otherwise, it waits.

### Advanced example

For fine-grained control, return specific intervals from the batch instead of "all intervals are ready" or "none are ready." This example allows only intervals from at least 1 week ago:

```python
import typing as t

from vulcan import signal, DatetimeRanges
from vulcan.utils.date import to_datetime


# signal that returns only intervals that are <= 1 week ago
@signal()
def one_week_ago(batch: DatetimeRanges) -> t.Union[bool, DatetimeRanges]:
    dt = to_datetime("1 week ago")

    return [
        (start, end)
        for start, end in batch
        if start <= dt
    ]
```

Instead of returning `True` or `False` for the entire batch, this function filters the batch and returns only intervals that meet the criteria. It compares each interval's start time to "1 week ago" and includes only those old enough.

Use it in an incremental model:

```sql hl_lines="7-10"
MODEL (
  name example.signal_model,
  kind INCREMENTAL_BY_TIME_RANGE (
    time_column ds,
  ),
  start '2 week ago',
  signals (
    one_week_ago(),
  )
);

SELECT @start_ds AS ds
```

Only data from at least a week ago is processed. Use this to wait for late-arriving data to stabilize before processing it.

### Accessing execution context

To check something in your database or access the execution context, add a `context` parameter to your signal function:

```python
import typing as t

from vulcan import signal, DatetimeRanges, ExecutionContext


# add the context argument to your function
@signal()
def one_week_ago(batch: DatetimeRanges, context: ExecutionContext) -> t.Union[bool, DatetimeRanges]:
    return len(context.engine_adapter.fetchdf("SELECT 1")) > 1
```

The `context` parameter gives you access to the engine adapter, so you can query your warehouse, check whether tables exist, verify data freshness, or perform other checks.

### Testing signals

Signals only evaluate when you run `vulcan run` or use the `check_intervals` command. To test signals without running models:

1. Deploy your changes to an environment: `vulcan plan my_dev`.
2. Check which intervals would be evaluated: `vulcan check_intervals my_dev`.
   - Use `--select-model` to check specific models.

   - Use `--no-signals` to see what would run without signal checks.
3. Iterate by changing your signal and redeploying.

{% hint style="info" %}
The `check_intervals` command works only with remote models deployed to an environment. Local signal changes aren't tested until you deploy them.
{% endhint %}

Use this workflow to verify signal logic before it affects model runs.
