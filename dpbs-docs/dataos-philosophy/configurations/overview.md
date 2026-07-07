# Overview

## **Why Configuration Is Power: One Point of Change**

The pathology of most data stacks is configuration drift. A business use case arrives, a model gets written, and then config files multiply: one for each resource, each environment, each deployment target.

The developer is now managing the plumbing instead of opening the tap. Over time, the gap between what the config says and what the system actually does becomes the real source of production failures.

> *Vulcan*'s configuration is designed around a single principle: every point of change should collapse into one. You declare what you want, and the **stack propagates that declaration** across the dependency chain.

When something changes, you change it in one place, and the rest follows.

## **Declarative Configuration as Workload-Centric Design**

There's a better way to describe what declarative configuration actually achieves: **it shifts the developer's job** from specifying *how infrastructure runs* to specifying *what the workload needs*.

You don't provision resources manually and then wire them together. You describe the workload (this model, this dialect, this schedule, this warehouse) and the system resolves the infrastructure required to satisfy it.

The config file is the workload specification, and everything beneath it is an implementation detail. This is what makes *Vulcan*'s `config.yaml` more than a settings file. It encodes the contract between your data product and the infrastructure that runs it.

When you onboard a new environment or switch from Postgres to Snowflake, you do NOT have to rewrite logic. You're updating the specification and letting the system adapt. This way, developers are able to stay focused on the data product while *Vulcan* handles the rest.

## Configurations in *Vulcan*

[https://tmdc-io.github.io/vulcan-book/configurations/overview/](https://tmdc-io.github.io/vulcan-book/configurations/overview/)
