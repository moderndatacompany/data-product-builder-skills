# Business Metrics

## Working with Economic Consequences

Every business metric is ultimately a claim about economic reality. When a metric is defined, it is to formalize the numbers that drive decisions: where to invest, what to cut, which customers to prioritise, and whether the business is growing or contracting.

The economic weight of that is considerable. A metric that is wrong, inconsistently defined, or drifting undetected from its intended calculation is a decision-quality problem. And decisions made confidently on wrong numbers have a cost that accumulates (again, mostly undetected for a long time) in budgets allocated to the wrong segments, in growth levers left unpulled, in problems diagnosed too late because the signal was corrupted at source.

This is the key argument for defining metrics in the semantic layer rather than embedding them in dashboards, reports, or ad hoc SQL.

- When a metric exists in a dashboard, its **economic consequences are local:** confined to whoever reads that dashboard.
- When it exists in the semantic layer, backed by validated models and owned by a named team, its economic consequences are explicit, and its definition is a shared organisational commitment.

Changing the definition of "active customer" is no longer a one-line SQL edit that shifts a chart undetected; it is a versioned change to a contract that downstream consumers depend on, communicated and reviewed before it ships.

The `meta` fields (business owner, calculation method, benchmark) are the answer to the question every decision-maker should be asking before they act on a number: who is accountable for this, how was it derived, and what should I expect it to be?

### Enabling AI with Measurable Economic Returns

Today's semantic layer powers human consumers: analysts querying dashboards, product managers reviewing KPIs, and finance teams pulling reports. Tomorrow's semantic layer must also be legible to AI agents that need to act on data, not just observe it.

An agent reasoning over whether to approve a discount, trigger a reorder, or escalate an anomaly needs to know not just the current value of a metric but what it means, who owns it, how it was calculated, and whether it is trustworthy.

The `meta` fields on a business metric are the beginning of the context layer that separates metrics an agent can act on from metrics it can only read.

Every business metric defined in *Vulcan* today is a node in the context architecture of tomorrow: a unit of meaning that the organisation can build on, reason from, and eventually activate across every system that needs to understand what the business knows about itself.

## Business Metrics on *Vulcan*

[https://tmdc-io.github.io/vulcan-book/components/semantics/business_metrics/](https://tmdc-io.github.io/vulcan-book/components/semantics/business_metrics/)
