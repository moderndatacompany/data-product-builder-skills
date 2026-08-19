# Macros

## **Symbiotic Pillars: Abstraction and Reusability**

SQL is deliberately simple, which makes it powerful. It is readable, reviewable, and accessible to people who are not professional software engineers. But simplicity has a cost when your models start to share logic.

At a small scale, it is tolerable, but as the project grows, it becomes the primary source of inconsistency. Reusability is one of the most important capabilities in data management: the more reusable you make any logic or data asset, the simpler and more cost-effective the data product becomes. Macros are how *Vulcan* applies that principle at the transformation layer.

The philosophy is the same one that makes good software maintainable: don't embed logic directly in every place it is needed, encode it once where it can be trusted and referenced everywhere it is relevant.

When the business rule changes, you change it in one place. Every model that references it picks up the change automatically, without a search-and-replace across the project. This is the same principle and design pattern that powers the semantic layer: define metrics once, use them everywhere, own them centrally.

> With Macros, the pattern is applied one layer down, where the transformation logic that feeds those metrics is built. **Even before modeling begins, existing assets and logic should be discovered for reusability.**

Macros make the mechanism that makes transformation logic discoverable and reusable by design rather than by convention. The two systems *Vulcan* supports, native Vulcan macros and Jinja, serve different working styles, but both exist in service of the same goal: logic that lives in one authoritative place, carries forward cleanly as the project scales, and never has to be reconciled across the files that duplicated it.

## Macros in *Vulcan*

See the reference documentation for:

- [Overview](https://tmdc-io.github.io/vulcan-book/components/advanced-features/macros/overview/)
- [Variables](https://tmdc-io.github.io/vulcan-book/components/advanced-features/macros/variables/)
- [Built-in Macros](https://tmdc-io.github.io/vulcan-book/components/advanced-features/macros/built_in/)
- [Jinja](https://tmdc-io.github.io/vulcan-book/components/advanced-features/macros/jinja/)
