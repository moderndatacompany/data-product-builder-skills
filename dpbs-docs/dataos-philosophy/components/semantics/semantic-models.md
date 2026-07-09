# Semantic Models

Physical models are organised around engineering constraints (normalization, incremental processing, storage efficiency) while business understanding is organised around entities, relationships, and concepts that span multiple tables and exist in a context that no single schema can express.

A semantic model is the artifact that reconstructs that context. It maps what engineers optimised for computation onto what analysts need for comprehension.

The absence of context boundaries means every table, metric, and dimension floats in isolation, becoming fragments of truth without a shared narrative. Cataloguing these fragments tells you what exists, but not why it matters, how it relates, or what it means in a business domain.

Semantic models address this at the layer where it can actually be resolved: at the point of definition, **before consumption begins**. When you define an `active_customers` segment once in a semantic model, you are not just saving analysts from writing the same WHERE clause, but you are making a deduction: this is what "active" means in this domain, and **this definition is authoritative.**

Every consumer who queries against that segment receives the same answer, derived from the same logic, without negotiating what "active" means with a colleague first. The semantic model is where institutional knowledge about data, the kind that currently lives in Slack threads and tribal memory, gets formalised into something the system can enforce and every consumer can trust.

## Semantic Models in *Vulcan*

[https://tmdc-io.github.io/vulcan-book/components/semantics/models/](https://tmdc-io.github.io/vulcan-book/components/semantics/models/)
