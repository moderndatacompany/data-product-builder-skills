# Overview

## **Semantic Layer as Business Interface**

The semantic layer emerged because the alternatives failed in sequence.

- Data cubes pre-calculated everything and left no room for novel queries: every new business question required a new engineering cycle.
- BI tools freed analysts from those boundaries but trapped semantics inside vendor ecosystems: a metric defined in Tableau was inaccessible to a product team building a custom application, and the same revenue definition had to be rebuilt from scratch across every tool that needed it.

The fundamental problem was about where semantics was hosted and whether it could be reused.

A semantic layer solves this by **decoupling context from the systems that consume it**. You define meaning once, at a layer between the physical data and every surface that needs to understand it (dashboards, APIs, applications, AI models), and every consumer draws from the same source.

But a semantic layer placed directly over unvalidated physical data replicates its problems at a higher altitude. [Semantic mistrust](https://moderndata101.substack.com/i/144240703/be-wary-of-semantic-mistrust), the condition where metrics look credible but are built on unstable foundations, is **the semantic layer's most dangerous risk**.

A sales analyst who finds the right measure and gets a wrong answer has a problem that is harder to diagnose than one who cannot find the measure at all.

This is why *Vulcan*'s semantic layer sits downstream of the validation barrier, not parallel to it. The models feeding the semantic layer have been tested, audited, and certified. The dimensions, measures, and metrics built on top of them inherit that certification.

The semantic layer is not just a business interface, but the point where validated data products become accessible to every consumer, in every tool, through every API, without re-deriving from scratch.

## Semantic Layer Overview

[https://tmdc-io.github.io/vulcan-book/components/semantics/overview/](https://tmdc-io.github.io/vulcan-book/components/semantics/overview/)
