# The Data Product Doctrine

---

Adopting the data product way or the product mindset for data development does not mean disrupting your entire code, tooling ecosystem, or communication channels. The technology you have is almost certainly sufficient. What is insufficient is the layer of intent and accountability sitting on top of it, and that is not a tooling problem.

At its core, the product mindset is a single discipline applied consistently: every data asset you build has a known owner, a known consumer, and a known contract between the two. That discipline does not require a new tool, but rather a new way of thought and work. It requires a new question asked before you build: *who is this for, and what do I owe them?*

> **The compounding effect of asking that question is what transforms a data engineering team into a data product team**.

It's the steady, deliberate practice of treating the people who depend on your data the same way a good engineer treats the consumers of their API: with ownership, versioning, and the honesty to communicate when something breaks.

The shift to a data product ecosystem is gradual, and it compounds. None of the steps in data product development is a large engineering project. They are small, deliberate acts of ownership, and over time, they are what separates organisations that trust their data from organisations that are still arguing about which metric is accurate.

---

## The Reason We Build Products

Data gets collected everywhere (transactions, clicks, signups, logs), but when someone needs to make a decision, they spend weeks just figuring out which number to trust and where it came from. The data exists, but nobody owns it, nobody guarantees it, and nobody can tell you if it was correct three days ago when the pipeline broke.

> The cost of it is not just time. **It is bad decisions made confidently on bad data.**

The reason we make products out of data is the same reason we make products out of anything: to make something **reliably usable by someone who did not build it**.

When data is a product,

- it has an owner who is accountable for its quality,
- a consumer who can depend on it,
- and a contract between the two.

You do not need to reverse-engineer how a table was built or pray that nobody changed the schema. You just use it, the same way you call an API without reading the source code.

The alternative, which is where most organisations are right now, is every team rebuilding the same datasets independently, nobody agreeing on the same numbers, and analysts spending seventy percent of their time cleaning data instead of thinking about it.

---

## Data Product Developers Create Direct Business Impact

If you have built software products before, you already understand what it means to care about a consumer. You think about interfaces, reliability, versioning, and backwards compatibility. You lose sleep when your API goes down because someone on the other end is experiencing something broken and raising tickets. And this is happening so many times that the data team is choked with maintenance tickets.

Data product development asks you to carry that exact same user-first mindset, but point it at data. This document is to build that instinct from the ground up, because most data developers have been asked to move data, store data, and transform data.

> This is the first time they will be *owning* and wielding it **for the business to reflect direct business outcomes. Directly attributed to the data team.**

### The Attribution Bridge

Data has historically been treated as exhaust: the byproduct of systems doing real work. And data teams have been the back office, burning the midnight oil for customer-facing teams that tend to absorb all value attribution, not by their own doing, but because of how the systems, processes, and attribution measures have been drawn up since forever.

Data teams have never been at the forefront of business enablement since data was **never directly tied** to measurable changes in niche business metrics or goals.

And that's what a data product does. It is made FOR these measurable metrics. Any changes are directly attributed to the product. Low business impact requires data product evolution, while high business growth indicates the presence of a star data product in the organisation, owned broadly by the data team, and most directly and most importantly, by the data product owner.

### Inherently Higher Data Adoption

The right attributions also encourage data teams to push for wider adoption of data products and data by business domains.

In usual settings, a user signs up, and a row gets recorded. An order is placed, and a log is emitted. The data just accumulates, and periodically, someone builds a pipeline to move it somewhere more useful. The pipeline breaks, nobody notices for three days, and a business decision gets made on irrelevant numbers.

The philosophy of data products exists to end this pattern by forcing a single, mostly uncomfortable question:

> **If data were a product you had to sell, would anyone buy yours?**

If your data has no clear owner, no quality guarantees, no versioning, and no defined consumer, the answer is no. And yet most organisations are making critical decisions on exactly this kind of data every day. Considering it the norm, never pushing beyond for a better experience for their business domains.

However, when we build data as a product, it's built *for* the consumer and built by developers who have put themselves in the user's shoes by always keeping the business user at the forefront. Naturally, the data product aligns with the user's data consumption patterns, tooling ecosystem, and analytics preferences. **Adoption accelerates exponentially.**

---

## What is a Data Product

The term "data product" gets used loosely. Let us be precise about what it means, because precision here will change how we build them.

A data product is an independent unit of data designed to directly serve a specific business objective, goal, or metric. It is not merely a dataset, but a productised data asset that is quality-verified, reliable, and ready for direct consumption by its intended users, whether humans or machines.

Because it is built for use, a data product is inherently both governed and user-driven. Governance ensures trust, consistency, and compliance. User-centricity ensures relevance and usability. The product exists at the intersection of control and utility.

Its independence and reusability are enabled by packaging the data together with its metadata, transformation logic, and supporting infrastructure. In this way, the data product becomes a self-contained quantum: an autonomous, interoperable unit that can be discovered, trusted, and reused without re-engineering its foundations.

### Product Conditions that Data Needs to Meet

Something qualifies as a product, data, or otherwise, only when three conditions are simultaneously true:

- **There is an owner** who is accountable for its existence, quality, and evolution
- **There is a consumer** who depends on it and derives value from it
- **There is a contract** between the two that defines expectations, format, and reliability

Remove any one of these three, and you do not have a product. You have an artifact which decay while products get maintained.

### What Ownership Demands

Ownership is the hardest pill for developer teams to swallow, because it extends beyond code. When you own a data product, you are accountable for:

- The accuracy and freshness of the data
- The schema evolving without breaking downstream consumers
- Communicating when something changes or breaks
- Understanding *who* depends on your data and *how*

This is not a part-time responsibility. This is what separates teams that produce data infrastructure from teams that produce data products.

### The Consumer Is Not an Afterthought

In most data pipelines, the consumer is whoever shows up at the end and queries the table. In a data product, the consumer is known *before* the product is built. You design for them, talk to them, and version for them.

Think about how you would build a REST API differently if you knew exactly which three clients would use it, versus building it blindly and hoping someone finds it. That is the difference between a data pipeline and a data product.

---

## Data Product as an Economic Construct

This is where the data product philosophy gets teeth. Productisation is not just a metaphor for caring more about the customer/user/consumer, it is an economic forcing function that **changes incentive structures inside an organisation**.

### The Cost-Value Asymmetry

In a traditional data pipeline model, the team that produces data and the team that consumes it are decoupled in accountability. The producing team ships the pipeline and the consuming team builds on top of it. When the data breaks:

- The consuming team **bears** the cost (broken dashboards, bad models, wrong decisions)
- The producing team has **no visibility** into the damage
- No feedback loop exists to **correct the producing team's incentives**

This is the core dysfunction. The people experiencing the cost of poor quality are not the people responsible for fixing it. Productisation fixes this by **coupling ownership to accountability**.

### Data Products Create Internal Markets

When data is treated as a product, something interesting happens: teams start to act like vendors and customers. The team producing the customer dataset becomes answerable to the analytics team consuming it.

SLAs get written, quality gets measured. The producing team starts to care because the consuming team now has standing to demand better. This is market mechanics applied internally. And it works, because it aligns incentives in a way that goodwill and documentation never could.

### Data and the Data Ecosystem Becomes Measurable

A product can be evaluated. When your data has a defined schema, a known refresh cadence, a declared owner, and a versioned contract, and most importantly a measure against which it was conceived, you now have surface area for measurement. You can track:

**Product Values**

These determine whether the data product behaves like a real product, not just a dataset, pipeline, or table.

- **Direct Business Impact:** Does the data product measurably improve a defined business objective, goal, or KPI? Its existence should be economically justified, not technically convenient.
- **Reusability:** Is the product lean, modular, and reusable across multiple consumption nodes (dashboards, ML models, APIs, operational systems) without duplication or rework?
- **Intrinsic Value:** Does the data product generate value on its own, without requiring downstream teams to perform heavy transformations or corrective engineering? A true product minimizes consumer-side effort.
- **Interoperability:** Can the data product integrate and interact with other products, domains, or use cases? Does it emit structured metadata and standard interfaces that allow composition, federation, and cross-domain intelligence?
- **Composability:** Can it serve as a building block in higher-order products? Strong data products are atomic yet extensible.
- **Observability:** Is its performance, usage, and reliability measurable? A product must be observable to be improved.

**Governance Values**

These ensure the product is trustworthy, controllable, and manageable at scale.

- **Discoverable:** Can users easily find the product through cataloging, search, or domain indexing?
- **Addressable:** Does it have a unique, stable identifier and versioning scheme? Can it be reliably referenced across systems?
- **Understandable:** Is the business meaning, schema, lineage, ownership, and intended usage clearly documented?
- **Natively Accessible:** Can users comfortably use the data product in their familiar tech stacks or domain ecosystems? Can authorized users access it through standard protocols (SQL, API, streaming, etc.) without custom pipelines?
- **Secure:** Are access controls, privacy policies, and compliance mechanisms embedded by design?
- **Owned:** Is there a clearly defined product owner accountable for its lifecycle, quality, and evolution?

**Quality Values**

These define the operational integrity of the product.

- **Freshness:** Is the data arriving and updating within the expected SLA or temporal boundary?
- **Completeness:** Are all expected rows, columns, partitions, and dimensions present?
- **Accuracy:** Does the data reflect reality within agreed tolerance thresholds?
- **Consistency:** Does the same entity or metric behave uniformly across products and domains?
- **Validity:** Does the data conform to defined schemas, constraints, and business rules?
- **Reliability:** Does the product meet uptime and availability expectations for its consumers?

Together, Product, Governance, and Quality values define whether a data asset truly deserves to be called a *data product*. Remove one dimension, and you regress back to a pipeline artifact.

These become KPIs for your data product team, the same way uptime and latency are KPIs for a platform team.

---

## Data Products Act as Process Infrastructure

### The Roads-Before-Commerce Principle

Infrastructure does not generate value directly. Roads do not make goods, but they make it possible for goods to move. Power grids do not manufacture products, but they make manufacturing possible. Data infrastructure follows the same logic.

It is the necessary and non-negotiable factor. But they are not the destination. The destination is what gets built *on top of them*. The mistake most data teams make is optimising roads forever and never building the commerce.

Note that even the data product is not the data developer's destination. The data product is the road, while the commerce activities occur when value is exchanged between the system and the data consumers, be it humans or machines. The destination is an increase in business impact, growth, and high value attribution.

### What Data Infrastructure Actually Includes

Like all software systems, data or AI use cases are supported by deep underlying infrastructures. But why has the infrastructure specific to data evolved into one of the most overwhelming of the lot?

The brief answer is the transient element of data, which isn't such a dominating presence in general software systems. Data is varied, dynamic, and always surprising.

As humans, we are tuned to invent as challenges come our way, and we did the same with data infrastructures: we added a new branch every time data acted a little moody, leading to uber-complex data pipelines and legacy structures that are impossible to demystify.

> ***The solution seems simple: Data itself needs to be built into the data infrastructure instead of just passing through pre-built nuts and bolts (which are decoupled from data). Data needs to be an influence on the data stack to stabilise it or manage reactive evolution.***

All along the evolution of data systems, if you really observe, data has never been an active part of the architecture. It has been passively ***managed*** by all the blocks and cubes built around it. It's time to cut that passive cord and realise that what makes data infrastructures quickly lose relevance (and overly complex) is that data itself is not built into the architectures.

But how can data be part of the process infrastructure when it's neither a tool nor a resource? **Short answer: Data Products**.

### **What's "Important"**

We'd like to resurface an excerpt from a great thinker of our time:

> His [Ralph Johnson's] conclusion was that **"Architecture is about the important stuff. Whatever that is"**. On first blush, that sounds trite, but I find it carries a lot of richness. It means that the heart of thinking architecturally about software is to **decide what is important…and then expend energy on keeping those architectural elements in good condition**.
>
> For a developer to become an architect, **they need to be able to recognise what elements are important, recognising what elements are likely to result in serious problems** should they not be controlled.
>
> [***~ Martin Fowler***](https://www.martinfowler.com/architecture/)

The unmanageable tech debt of our times is a result of prioritisation inefficiencies, among other concerns. While it sounds simple, being able to decide what's important is of primary value for any team, individual, or organisation.

It's no different with Data. While it would be nice to have data power everything in our businesses, the pursuit of the same is immediately a lost cause.

### **"Importance" as a Cultural Metric**

While we can write down a dozen metrics that quantitatively "measure" priorities and importance, the big picture of what takes precedence boils down to cultural dynamics.

> ***We HAVE to view Data Products with this same lens.***

We cannot afford to cage it within strict technical boundaries. Otherwise, we risk failing at the problem we have set out to solve: reduce the data infra and volume overwhelm (instead of adding more clunky customisations every time there's a novel query).

As the history of software goes, Applications have loosely been defined as such:

> *([Excerpt](https://www.martinfowler.com/bliki/ApplicationBoundary.html))*
>
> - A body of code that's seen by developers as a single unit
> - A group of functionality that business customers see as a single unit
> - An initiative that those with the money see as a single budget

How different are applications and products really? While ***Data Products*** make a good phrase to easily summarise things in the context of data, there is little reinvention we need here.

Applications: Used for a purpose

Product: Used to omit/diminish the effort spent on a purpose

When it came to the tussle of defining data products, the industry has taken a shot at each of the above. Some said data products were a single independent unit of code, data, metadata, and resources (infra). Some said data products were the fundamental unit necessary to serve a single business purpose. Some said it was both from two different angles. And some compromised on what made a data product a data product based on budget constraints.

From a 10,000 ft. view, all ultimately boils down to cultural influences.

- How do developers work in the org? What do they consider as a single unit?
- How do businesses consume data, and who decides what makes a good use case and how?
- Who holds the financial freedom in the org, and how do they exercise it?

For perspective, here's a data developer's POV who works day in and out with data:

> *Within any organisation, the needs and expectations of various groups of consumers around data availability and timeliness (among other issues) will vary. This variance highlights the importance of Service Level Agreements (SLAs) in defining the boundaries of data products. SLAs help identify the appropriate split of data products within a cluster, ensuring they meet the needs of different data consumers.*~ Ayush Sharma in [***"Understanding the Clear Bounds for Data Products***](https://moderndata101.substack.com/p/understanding-the-clear-bounds-for)"

There are hundreds of other data teams approaching the problem very differently.

### **How to take account of "Importance" as a Metric**

Data goes through multiple layers of people, processes, and transformations before reaching the actual consumer. Every layer of people and processes **comes with its own cultural bias.**

We can never take the risk of ignoring this bias. Ignoring it adds inefficiencies and frustrations in every layer, making the seemingly perfect theory a painstaking undertaking that suddenly adds unbelievable friction to the data-to-consumption flow.

!!! tip
    **Data Products dispersed across layers take into account the concerns of users located in different layers.**

In other words, they consider how Analysts/Data Scientists prefer to ingest and explore data in their workspaces, how the data engineering team operates, or how governance stewards prefer to disperse policies. **What all these roles consider important as users = direct feedback for product development.**

Let's see how the priorities of both users and operators are considered by the product framework.

Data products are meant to be made or come up on demand, and the use case or purpose is at the forefront at all times. Let's break this down a little.

1. First, a conceptual prototype or the Data Product Model is drawn up closest to the use cases, which is inclusive of all the requirements necessary to fulfil 'n' use cases. This set of use cases has been pre-decided as "**important"** by the business domain or the broader business.
2. Based on the conceptual model, analytics or data engineers start mapping sources to activate the conceptual model, creating source-aligned data products in the process.
3. Over time, query patterns and clusters emerge depending on **how users interact with source products (what users find important)**. This enables data developers to create aggregated data products that are able to answer queries more efficiently.

Again, the aggregate products depend on how the team operates and decides to manage the constant stream of queries. **How and what do data developers prioritise to quench user demands**?

> Complex source-to-consumption transform code gets broken down into more manageable units depending on the team's approach to code and caching. Aggregates come into the picture over time where the team realises that a conglomerate is better able to serve a broad band of queries instead of direct iteration with source products.
>
> This becomes a new product in its own right with a separate set of objectives, resources, SLAs, and greater context given its closeness to downstream consumers.

These aggregates are now directly powering the consumer-facing data product (say, Sales 360) and enabling it more effectively than source products.

Over time, all the necessary source and aggregate products are mapped out based on consumers' usage patterns and data developers' operational comforts until you have a solid network of reliable data going up and down product funnels.

### **Why and how is this process infrastructure different from any other tiered architecture?**

The key difference is **Product Influence,** which enables teams to actually implement a right-to-left or user-to-sources journey instead of the traditional left-to-right data management (where the user gets what upstream teams send their way or consider "important").

The key difference with the Product framework embedded in the architecture is that teams are able to not just drive efforts based on actual business goals, but are effectively able to work through priority gaps and tussles across multiple layers. All because every layer is now practically able to face the same direction. User User User.

### **Impact Overview of Data Product Process Infrastructure**

The business directly interacts with the Consumer-Aligned Data Product (CADP) or the logical Data Product Model. Based on changing requirements, they can create, update, or delete the Data Product. The distance between this CADP and the data progressively diminishes as more intermediate products pop up.

The journey from raw sources is significantly cut down to the distance between an aggregate product and a consumer data product.

It is interesting to note that all products are independent and serve multiple aggregates or CADPs across different domains and use cases. Each has a lifecycle well within the bounds of the limited and well-defined purpose it serves.

This enables higher-level products to comfortably (with high transparency) rely on the inputs from lower-level products and essentially reduces the complexity and management overwhelm of the path between raw sources and consumer endpoint(s).

## **Summing Up: Data as the Active Ingredient of Process Infrastructure**

Let's go back to the question: How can data be embedded into the infrastructure as an active influence that can stabilise and control the spreading wildfire of pipelines and model branches?

Data Products cut through to the last strand of the data stack, from source to consumption. They are like **vertical infrastructure slices** (imagine Greek columns supporting a huge pediment), inclusive of the data itself.

Data Products are vertical slices of the data architecture, cutting across the stack, from data sources and infrastructure resources to the final consumption points.

***Every element in the stack gets to be influenced by data and CONTEXT (DATA ON DATA).*** And the "Product" approach enables this influence by carrying downstream context all the way up (right-to-left).

Let's take a look at the collective influence of data and product approach from source to consumption (the traditional direction and how it's reversed):

### **Sources: Data & Product Influence**

Any mid-to-large org is burdened with an overwhelming number of data sources. Data Products cut down this complexity by **bringing downstream context into the picture**.

- What has been decided as "important" by downstream functions that are closer to data consumption?
- Combined with upstream context on "what else is important" to enable a smooth experience of delivering this data.

This gives us Source-Aligned Data Products- A combination of context, SLAs, transparent impact, and a clear set of input ports (**only ingesting what's in demand**).

### **Transformations: Data & Product Influence**

Based on how the data team operates and what ***they view*** as aggregates that serve downstream purposes more easily, complex source-to-consumption transform code gets broken down into more manageable units (depending on the team's approach to code and caching).

Aggregate Data Products come into the picture over time, where the team realises that **a conglomerate is reusable and better able to serve** a broad band of queries instead of direct iteration with source products.

For example, source tables like "***Sales***" and "***Orders***" might need more complex queries compared to the aggregate "***Accounts***". This becomes a new product in its own right with a separate set of objectives, SLAs, and richer context due to its closeness to users.

The Data Product is independent with a separate set of infra resources and code, with source products as input ports and isolated from disruption from other product engines.

### **SLAs: Data & Product Influence**

SLAs are highly dependent on consumption patterns and organisational hierarchies. Who should get access and why? While a bare-bones quality structure works for one, another might find it essential to have higher quality demands.

The Data Product slices are built to influence a **right-to-left flow of context**: from users to source. What's Level A of the requirements? How can we boil down the requirements from Level A to different touch points of the data across the source-to-consumption stack? Do upstream SLAs conflict with downstream necessities or standards? How can we get a clear picture of these conflicts without corruption from other unassociated tracks (which might be challenging given how pipelines overlap with little isolation of context)?

### **Consumption: Data & Product Influence**

Products, by nature, are always facing the users. They're built for purpose. Data Products enable the ability to define consumption while keeping in mind the user's preferences. The user shouldn't bend to the data product; the data product must bend to the user's native environment.

The data product is able to furnish multiple output ports based on the user's requirements. We call these Experience Ports, which can serve a wide band of demands without any additional processing or transformation effort (ejects the same data through different channels).

This may include HTTP, GraphQL, Postgres, Data APIs, LLM Interface, Iris Dashboards, and more for seamless integration with data applications and AI workspaces.

---

## Upgrading from Pipelines to Products

This is the crossing that most data organisations have never made. Understanding why it is hard is as important as understanding what lies on the other side.

### What a Pipeline Is

A pipeline is an engineering artifact. It has:

- A source
- A transformation
- A destination
- A schedule or trigger

It answers one question: ***how does data move from here to there***? It does not ask why, or for whom, or what happens when it breaks, or who needs to be told when the schema changes.

Pipelines are necessary upto a certain point. They are also insufficient.

### What a Product Adds

A product inherits everything a pipeline has, and adds a layer of organisational intent on top:

| Dimension | Pipeline | Product |
| --- | --- | --- |
| Orientation | Engineering | Consumer |
| Ownership | Team that built it | Named individual/team with accountability |
| Contract | Implicit | Explicit (schema, SLA, versioning) |
| Failure response | Fix when noticed | Alerting, SLA breach, consumer notification |
| Evolution | Breaking changes happen | Versioning, deprecation cycles |
| Discovery | Hard to find | Catalogued, documented, searchable |

### Why Teams Get Stuck

Most data teams build pipelines because pipelines are solvable with code. You write a transformation, run a test, and deploy it. Done. Products require something pipelines do not: organisational agreement. Someone has to say, "I own this." Someone has to agree to the SLA. Someone has to be woken up at 2 am when it breaks.

This is why the pipeline-to-product crossing is a cultural challenge as much as a technical one. The technology to build data products has existed for years. The organisational willingness to own them is what most teams lack.

### What the Crossing Looks Like in Practice

If you are a developer reading this and trying to understand concretely what changes, here is the delta:

**Before (pipeline thinking):**
You build a dbt model that joins orders and customers, runs nightly, and lands in a table called `orders_enriched`. Someone finds it in the warehouse and starts using it. You have no idea who.

**After (product thinking):**
You build the same model, but you document it in your data catalog with a description, owner, and refresh SLA. You version the schema. You define the downstream consumers explicitly. You set up quality checks that alert you if the row count drops or a key column goes null. When you need to change the schema, you communicate the change with a deprecation window.

The data is the same. The posture around it is completely different.

### **Curing the Pre-Cloud Hangover**

When you start putting pipelines first, what we call a "Pipeline-first" approach, you're effectively working with a **pre-cloud mindset**. That era, the data centre era, was defined by physical hardware. Machines were stable and rarely failed. **Failures were exceptions, not norms.** The system was, therefore, built around it: to handle the exception.

Even in Amazon's early days, the large hardware rarely went down. But that's not the whole story. Virtual machines (VMs) would come and go on those machines. They'd move around.

> **What changed with the cloud era wasn't the nodes; it was how we used them.** We began scheduling workloads on ephemeral resources. Suddenly, your code had to be **ready to fail, quickly and gracefully.**

The cloud is designed around this. It expects things to fail, and fail often, but in small, isolated, recoverable ways. So instead of pretending nothing breaks, you build systems that *expect* it. You try. You catch. You retry. You defend.

Which means: **pipelines *will* fail. Not because something went wrong in the traditional sense, but because resources weren't available *right then*.** That's not failure; that's design. Try again later.

### **Mindset shift to product-first weighs in**

If you take a pipeline-first view: P1 runs, then P2, then P3, and so on; you've built a **tower of dependencies**. If P1 fails, the whole chain waits. You've introduced **artificial coupling**. A cascade of failures, not because the data isn't there, but because your orchestration is rigid.

**But let's flip it: Put *data* at the centre, not processes.**

Say you're enriching transactional data with weather info. Let's say the weather data comes from [weather.com](http://weather.com/). P1 pulls the weather data. P2 enriches the transactions. In pipeline-first logic, if P1 fails, P2 fails. Then everything else waits.

***But if you think in data-first terms, P2 becomes intelligent.***

- P2 says: "Was there fresh weather data this past hour?"
- If yes → enrich and proceed.
- If no → skip, wait, recheck later.

No panic. No failure. Just… pause. A calm system that has not burnt itself out.

P2 didn't fail. It just didn't find the input it needed yet. It'll try again. **It's decoupled from P1's timing or retry logic. It behaves more like a thinking agent than a dumb task on a schedule.**

Pipeline-first thinking leads to brittle orchestration. Data-first thinking leads to adaptive, fault-tolerant systems. It's a way of thinking: you're putting data first instead of processes first.

### **We're NOT Writing Off Pipelines**

**Let's reframe the way we think about data work.** Before you ever get to *processing*, you're in the world of *preprocessing*. This is the unglamorous but necessary part. Maybe it's a mess of CSVs. Maybe PDFs. Maybe images.

- **Connecting the Dots: Preprocessing -** You're not building data products yet; you're staging. Preprocessing is about shaping raw material. You might extract EXIF metadata from images, grab GPS coordinates, timestamps, and structure chaos into something usable. That's your *source-aligned data product*.
- **The First Viable Connection: Source-Aligned Data Products -** It's not yet for consumers, but it's aligned to the source, clean, structured, and auditable. From there, you move to the *consumer-aligned data product:* something a downstream user or system can actually act on. This is where pipelines show up. In some cases, especially early on, you *do* need to think left-to-right: take input, do something, move it forward.
- **The Shift: Where Pipeline-First Thinking Disappears -** Once your data has been shaped into a source-aligned format, the need to think "pipeline-first" disappears. That's why we're not spending time glorifying preprocessing. It's table stakes. We acknowledge it, we support it, and we retain the construct in the unified platform spec.

But the conversation we *want* to have is: **What if you didn't have to think about pipelines at all?**

> **The goal isn't to ensure pipelines don't exist or never fail. The goal is to ensure *the system doesn't care if they do*.**

But how do we make a system that doesn't get impacted by failing events? Or even succeeding events? ***The whole design we build is more defensive, more guardrailled.***

### **What is Defensive Design**

The word *defense* comes from the Latin *defensare*, meaning *to ward off, to protect persistently*. Defensive programming, then, is the persistent act of protecting your system from collapse; not just technical failure, but **epistemic failure**: wrong assumptions, vague specs, or future changes in context.

Defensive programming begins with a simple premise: **never trust the world. A system designed not to trust and work around mistrust.** And in defending against mistrust, the system creates a more trustworthy, reliable, or resilient layer for citizens operating on top of it.

***In other words, you delegate the brunt of mistrust to the foundational platform to have the luxury of a trusting and relaxing experience.***

The system wouldn't spare any entity in its mistrust. Not your users. Not your dependencies. Not even your future self. Because somewhere, somehow, assumptions will break. Systems will lie. Users will be lazy. Inputs will surprise. And in those moments, the code that *survives* is the code that was written with doubt, with discipline, and with design for failure.

Here's a recent conversation on the same topic that adds good perspective on the value of defensive design for data systems, such as ones that could host data or AI apps at scale for cross-domain operations.

### **The Best Defence: Separation of Data Extraction and Data Transformation**

**Let's go back to the conversation of pipeline-first vs. data-first.** In pipeline-first, the failure of P1 implies the inevitable failure of P2, P3, P4, and so on…

In data first, as we saw earlier, P2 doesn't fail on the failure of an upstream pipeline, but instead checks the freshness of the output from upstream pipelines.

**Case 1:** There's fresh data. P2 carries on.

**Case 2:** There's no fresh data. P2 waits. P2 doesn't fail and trigger a chain of failures in downstream pipelines. It avoids sending a pulse of panic and anxiety across the stakeholder chain.

### **What Does this Mean for the Data Value Chain**

In data systems, defensive programming is not just about protecting your pipelines from the cascading impact of failure, but also **protecting your system from assumptions**.

And one of the most detrimental assumptions in modern data systems? That **extraction and transformation** belong in the same pipeline. They don't.

The implication is that transformation shouldn't be tightly coupled with extraction jobs or pipelines because of the same reasons we've discussed so far. Defending against cascading failures because one job failed.

**Extraction and transformation are not the same unit.** Writing them together in a tight little script may feel efficient. However, efficiency is not measured in lines of code but in resilience. This script is potentially failing far more times than a decoupled script. Sometimes, writing **more code** buys you **more reliability**.

A defensive guardrailled system would furnish tools for extraction and transformation accordingly. The toolkit for extraction will not give you transformation options. Transform tools wouldn't provide an extraction option.

> ***So it'll enforce the guardrail in a way that you're propelled to think in this logic, and consequently, bask in the luxury of trust built on a defensive foundation.***

### **Separation by Bringing Data In the Middle**

In this defensive platform ecosystem, **data is the decoupling layer**. We don't tie transformation logic to the act of extraction. We don't let transformation fail just because data didn't arrive at 3:07 AM. Instead, our transformation pipelines ask a straightforward question: **"Is the data ready?"**

If yes, they run. If not, they wait. They don't trigger a failure cascade. **They don't tank SLOs.**

## **Becoming a Better Data Organisation**

Most tooling today nudges people toward pipeline-first design. Where one failure ripples through dozens of downstream steps. Not because the logic is wrong, but because the design **didn't defend itself**.

Your architecture mirrors your product. Your product mirrors your organisational thinking. So if your platform is pipeline-first, you end up with a pipeline-chained org.
