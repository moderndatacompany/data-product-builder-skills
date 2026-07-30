# Audits

## **Observability vs. Auditability**

Auditability is what converts observability from a reporting tool into a quality guarantee.

- Observability is the ability to see what your system is doing over time. It answers the question: *What is happening?*
- Auditability is the ability to verify that your data meets a defined standard before it is used. It answers a different question: *Is this data correct enough to act on?*

Both matter, but they operate at different points in the data lifecycle, and substituting one for the other is how bad data reaches production with a green light.

Most data teams have observability. They have monitoring, alerting, and lineage graphs (even though not end-to-end) that tell them when a pipeline runs and whether it succeeded. What they often don't have is auditability: a formal, enforced standard that the data itself must meet before it is promoted.

The distinction is not subtle in its consequences. Observability tells you the pipeline ran. Auditability tells you the output was valid. Passive vs Active. A pipeline can run successfully and produce wrong data. An audit catches that while a monitoring dashboard does not.

*Vulcan*'s audit layer sits at precisely that gap, between execution and promotion, and it is blocking by design. Of course, blocking is not convenient and may cause intermediate downstream stress, but it's better than a system that continues on bad data, which is a system that cannot be trusted. It's a loss of long-term trust as well as prolonged downstream distress.

## Audits in *Vulcan*

[https://tmdc-io.github.io/vulcan-book/components/audits/audits/](https://tmdc-io.github.io/vulcan-book/components/audits/audits/)
