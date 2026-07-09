# Overview

SQL is a [declarative language](https://en.wikipedia.org/wiki/Declarative_programming), which means you describe what you want, not how to get it. This provides clarity, but SQL doesn't have built-in features like variables or control flow (if-then statements, loops) that let your queries adapt to different situations.

The problem? Data models are dynamic. You need different behavior depending on context, maybe filter by a different date each day, or include different columns based on configuration. That's where macros come in.

Macros let you make your SQL dynamic. Instead of hardcoding values, you can use variables that get substituted at runtime. Instead of writing repetitive code, you can use functions that generate SQL for you.

Vulcan supports two macro systems, each with its own strengths:

- **Vulcan macros**: Built specifically for SQL, with semantic understanding of your queries

- **Jinja macros**: The popular templating system, useful if you're already familiar with it

Both systems can use the same [pre-defined variables](./variables.md) that Vulcan provides, like `@execution_ds` for the current execution date or `@this_model` for the current model name.

Next steps:

- [Pre-defined macro variables](./variables.md) - Built-in variables available in both systems

- [Vulcan macros](./built_in.md) - Vulcan's native macro system with SQL-aware features

- [Jinja macros](./jinja.md) - The Jinja templating system for SQL
