# Problem definition

## Problem

Infrastructure optimization systems routinely estimate savings from configuration changes such as Kubernetes request reductions, node consolidation, database resizing, storage cleanup, or commitment changes. A modeled opportunity is not equivalent to a cash outcome.

For shared infrastructure, the causal chain crosses independent systems:

`change -> runtime object -> schedulable capacity -> billable resource -> pricing/commitment context -> invoice evidence`

Operational health is a separate chain:

`change -> application behavior -> SLI/SLO evidence`

A team can therefore make a technically correct optimization that produces zero immediate cash savings. Example: reducing pod requests creates free schedulable capacity but does not remove an EC2 node. Conversely, a node may disappear for unrelated reasons, so a lower bill is not automatically attributable to the optimization.

## Primary users

- FinOps engineers who need defensible realized-value reporting.
- Platform/cloud engineers who execute or enable infrastructure optimizations.
- SREs who need safety evidence around optimization changes.
- Engineering/FinOps leadership consuming outcome evidence.

The first design partner profile is a team already using native cloud cost tooling, Kubecost/OpenCost, CAST AI, StormForge, or internal automation and still performing manual reconciliation between recommendations, runtime effects, and billing outcomes.

## Falsifiable product hypothesis

A team will install an independent evidence layer if it can answer, with source-level provenance:

1. Did the optimization remain operationally safe?
2. Did it remove or change billable capacity?
3. Did the bill reflect that capacity change?
4. Can the financial delta be attributed to this optimization with sufficient confidence?

## Kill criteria

Do not rationalize failure. Reconsider or kill the thesis if design-partner research shows that mature teams already obtain this evidence accurately enough from existing tooling, or if they will not grant the read access needed to correlate infrastructure and billing evidence, or if attribution confidence is too weak to improve existing manual processes.

## What we explicitly refuse to call realized savings

- lower Kubernetes requests by themselves;
- a successful deployment;
- a recommendation marked accepted;
- estimated list-price deltas;
- released but still-billed node capacity;
- vendor-reported savings without independent billing evidence.
