# Overview

## **Models as Units of Value**

Most data teams think of a model as a transformation: SQL that reads from one place and writes to another. That framing is technically accurate but insufficient.

A transformation is a process, but **a model, in the data product sense, is a unit of value**: a self-contained artifact with a name, an owner, a schema, a schedule, and a defined purpose it was built to serve. It is the difference between code that runs and code that can be depended upon.

When you define a model in *Vulcan,* with its name, grain, tags, terms, column descriptions, and materialization strategy, you are making the model legible to everyone who comes after you: the analyst who builds a dashboard on top of it, the engineer who inherits it, the system that catalogs it, and the consumer who **depends on it without knowing how it was built**.

A transformation that nobody can find, trust, or build on is infrastructure that generates no value. A model that is named, described, owned, and validated is a unit that compounds by getting reused, extended, and composed into higher-order products. That compounding is where the data team's leverage and value attribution come alive.

## **Model as a Contract**

Every model you ship makes an implicit promise to its downstream consumers: this schema will be here, these columns will mean what they say, this data will arrive on schedule. Most data teams have never made that promise explicitly, and so when the schema changes, the grain shifts, or the pipeline breaks, **the consumer finds out the hard way and bears the burden of resolution**.

The model was always a contract, it just wasn't written down. *Vulcan*'s model structure is how you write it down.

- The `MODEL` block is comparable to a contract header.
- The `name` and `grain` define the identity of what you're delivering.
- The `kind` and `cron` define the terms of delivery.
- The `column_descriptions`, `column_tags`, and `column_terms` define what each field means, so consumers don't have to reverse-engineer intent from column names.

The validation layer (tests, assertions, checks) is what backs the contract with enforcement rather than goodwill. A model that passes its assertions is a certified output that a downstream consumer can depend on without inspecting its internals. That is what separates a model from a query, and a data product from a pipeline.

## Model in Vulcan

[https://tmdc-io.github.io/vulcan-book/components/model/overview/](https://tmdc-io.github.io/vulcan-book/components/model/overview/)
