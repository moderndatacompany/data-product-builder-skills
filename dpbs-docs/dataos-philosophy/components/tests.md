# Tests

## What Tests Actually Guarantee

Data that cannot be trusted does not get used, or worse, it gets used without anyone knowing it shouldn't be. The cost of the second scenario is a business decision made confidently on numbers that were wrong.

Tests exist to make that scenario structurally unlikely by making correctness a **property that the system enforces rather than assumes**. Not by making engineers more careful.

Tests can be described as a safety net, which is accurate but undersells the mechanism. A test is a formal statement about what a model promises to produce. When you write input fixtures and expected outputs, you are not just checking whether the SQL runs; you are ensuring the contract the model holds with its consumers.

> Every test that passes is **evidence** that the contract is intact.

Every test that fails is the system catching a broken promise before a consumer does. That distinction (catching it before the consumer, not after) is what converts testing from a development practice into a trust infrastructure.

It is surprising how the simplest quality assurance factors go missing when it comes to data handling. And it is **often because of the nature of data,** which can be independently reproduced, viewed, duplicated, sliced and diced, or downloaded in disconnected units.

But data products change that. Trust, for a data product, is the feature that **determines whether business users build on your data or route around it.**

## Who Owns the Test Owns the Contract

**Quality is Product Responsibility**. But in a pipeline-first world, quality is someone else's problem. The pipeline runs, the data lands, and if something is wrong, the analyst who finds it three days later raises a ticket. A model without tests is a model that asks its consumers to absorb the risk of its author's assumptions.

The feedback loop between the person who caused the problem and the person who experienced it is long, indirect, and **structurally designed to decouple accountability from consequence**.

Tests close that loop by making the model author responsible for **correctness at the point of authorship** instead of at the point of discovery.

This is what the data product doctrine means when it says ownership extends beyond code. A data product owner who does not test their models has made an implicit choice: they have decided that the cost of writing tests is higher than the cost of their consumers encountering bad data.

That calculation is almost always wrong, and it becomes more wrong as the number of consumers grows. Tests are not overhead on top of the work, but are the work and the part that converts a transformation into a deliverable someone can depend on.

## Tests in *Vulcan*

[https://tmdc-io.github.io/vulcan-book/components/tests/tests/](https://tmdc-io.github.io/vulcan-book/components/tests/tests/)
