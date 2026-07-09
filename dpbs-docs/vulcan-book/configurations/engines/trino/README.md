# Trino

Trino is a distributed SQL query engine for analytics across data lakes, databases, and object storage. Vulcan connects to Trino with the `trino` engine adapter.

There are two ways to think about Trino connectivity in Vulcan.

| Path                                                                     | Use when                                                                                               | Status      |
| ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------ | ----------- |
| [External Trino](external-trino.md) | You already have a Trino-compatible endpoint, such as DataOS Minerva, Starburst, or self-hosted Trino. | Supported   |
| [Managed Trino](managed-trino.md)  | The Trino cluster is attached to, or managed with, your data product deployment.                       | Supported   |

## Common Rules

* Use `type: trino` in the gateway connection.
* Use `dialect: trino` in `model_defaults`.
* Use `vde: false`; Trino does not support `vde: true`.
* Store passwords and tokens in environment variables while working locally, and use DataOS secrets when deploying to an environment.
* Choose the guide based on who owns the Trino cluster.

## Which Guide Should I Use?

Use [External Trino](external-trino.md) if the Trino cluster already exists and Vulcan only needs to connect to it. This is the right guide for Minerva, Starburst, and self-hosted Trino.

Use [Managed Trino](managed-trino.md) if the Trino cluster should be part of the data product deployment itself.
