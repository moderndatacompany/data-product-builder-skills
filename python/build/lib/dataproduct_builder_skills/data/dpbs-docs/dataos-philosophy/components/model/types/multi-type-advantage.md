# Multi-Type Advantage

## **Why Polyglot Modeling Matters**

The history of data tooling is a history of **forced choices.**

Pick a warehouse, learn its dialect. Pick a transformation framework, write everything in its paradigm. The implicit assumption behind every one of these choices was that a single language, if expressive enough, should be sufficient for everything a data team needs to do.

That assumption has never been true, and the technical debt of teams trying to make it true is visible in every SQL file that has a CASE WHEN stack where a function call should be, and every Python script stitched onto the side of a pipeline because the transformation layer couldn't handle what the business actually needed.

The four model types in *Vulcan* (SQL, Python, External, and Managed) are not four ways to do the same thing. They are four distinct tools for four distinct categories of work, and the **ability to mix them in a single project** is what makes the difference between a stack that fits your problem and one you're constantly working around.

- **SQL** is the right tool for set-based transformations against data that already exists in your warehouse: joins, aggregations, filters, window functions.
- **Python** is the right tool when the transformation requires logic that SQL handles poorly or not at all: calling an external API, running an ML model, applying complex business rules that would take a hundred lines of SQL to express imperfectly.
- **External models** are how you bring data that exists outside your warehouse into *Vulcan*'s dependency graph without rewriting the systems that produce it.
- **Managed models** give you control over data *Vulcan* owns end-to-end, without an external source driving it.

The point of polyglot modeling is not to give you more options, but to **expose the right tool for each unit of work**, so you **stop bending your logic to fit your tooling**.

A data team that can write the model in the language the problem calls for, and have all of it participate in the same validation barrier, the same dependency graph, the same CI/CD pipeline, is a team that spends its time on the problem by saving time that would otherwise be spent on the constraints of the stack.
