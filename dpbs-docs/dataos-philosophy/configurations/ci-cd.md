# CI/CD

## **Why CI/CD Is Non-Negotiable for Data Products**

Data that is deployed without review is hosted in a system that trusts its own assumptions. And as we've established, a defensive system trusts nothing (inputs, dependencies, or even its future self).

Software engineering solved this problem a decade ago. CI/CD is not a DevOps ritual borrowed from software engineering just for credibility. It is the natural extension of defensive design into the deployment phase. When a model changes, something downstream depends on it.

That dependency may be a dashboard, an ML feature, a business metric, an agent, or another product in the chain. Deploying without a plan is not moving fast, but moving blind, and blind movement in a connected system is how one team's change becomes another team's nightmare at 3 AM.

A data product is software: It has dependencies, it has consumers, and changes to it can break things downstream in ways that aren't immediately visible. That's precisely the profile of a system that needs CI/CD.

The `vulcan plan` command exists to make the implicit explicit before anything ships. It shows you the **full blast radius of a change**: which models are affected, what will be rebuilt, and what the execution order is.

Ownership demands that you know who depends on your data and what you owe them. You cannot honour that contract if you don't know what your change touches before it touches it. **CI/CD is how ownership becomes operational**.

## **Deployment as a Product Discipline**

When software teams introduced release cycles, versioning, and deprecation windows, they weren't making engineering harder. They were building a way to make promises that they could keep.

A consumer of an API can plan around a versioned contract and a communicated deprecation window. They cannot plan around a table that changed schema on a Tuesday undetected. The discipline of deployment (plan, review, approve, ship) is what converts a one-time engineering act into a repeatable product commitment.

This is what separates pipeline-first teams from product-first teams at the deployment layer. A pipeline gets pushed when it's ready. A product gets deployed when its **consumers are protected.**

That means the schema hasn't broken undetected, the quality checks have passed, and the change has been reviewed by someone other than the person who wrote it. *Vulcan*'s CI/CD enforces this, and the same validation that governs data quality governs deployment quality.

## CI/CD in *Vulcan*

[https://tmdc-io.github.io/vulcan-book/ci-cd/ci-cd/](https://tmdc-io.github.io/vulcan-book/ci-cd/ci-cd/)
