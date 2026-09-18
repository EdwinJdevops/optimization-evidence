# 2026-09-15 EXP-001 AWS cost model

Updated 2026-09-17 after the first live deployment exposed an account-level EC2 launch restriction.

This document separates verified price observations from calculated experiment forecasts. It is not a cloud-bill claim.

## Verified observations

Region: `us-east-1`.

AWS EKS currently reports Kubernetes `1.36` as the default EKS version and in `STANDARD_SUPPORT`. AWS documentation prices a cluster running a Kubernetes version in standard support at **USD 0.10 per cluster-hour**.

The first deployment attempted `t3.medium` because it preserved a simple 2-vCPU/4-GiB x86_64 worker shape. Auto Scaling rejected every launch with `InvalidParameterCombination` because this account only permits Free Tier eligible instance types. The experiment was stopped rather than substituting an unreviewed type at runtime.

A fresh EC2 `DescribeInstanceTypes` query using `free-tier-eligible=true` returned the following eligible types in this account:

| Instance | vCPU | Memory | Architecture |
| --- | ---: | ---: | --- |
| t3.micro | 2 | 1 GiB | x86_64 |
| t4g.micro | 2 | 1 GiB | arm64 |
| t3.small | 2 | 2 GiB | x86_64 |
| t4g.small | 2 | 2 GiB | arm64 |
| c7i-flex.large | 2 | 4 GiB | x86_64 |
| m7i-flex.large | 2 | 8 GiB | x86_64 |

AWS Price List API results for Linux, shared-tenancy, On-Demand EC2 in US East (N. Virginia) verified:

| Instance | vCPU | Memory | Architecture | Price/hour |
| --- | ---: | ---: | --- | ---: |
| t3.small | 2 | 2 GiB | x86_64 | USD 0.0208 |
| c7i-flex.large | 2 | 4 GiB | x86_64 | USD 0.08479 |

The corrected experiment uses `c7i-flex.large`. It is the smallest eligible x86_64 option in the returned set that preserves the intended 4-GiB worker-memory envelope. This avoids turning memory pressure into the experimental variable. `m7i-flex.large` would double worker memory unnecessarily; `t3.small` halves it; `t4g.*` adds an ARM64 architecture variable.

AWS Price List API results for gp3 in US East (N. Virginia): **USD 0.08 per GB-month** for storage before any chargeable IOPS or throughput above the gp3 included baseline.

AWS Price List API results for an in-use public IPv4 address in US East (N. Virginia): **USD 0.005 per address-hour**.

AWS Price List API results for CodeBuild `general1.small` Linux On-Demand in US East (N. Virginia): **USD 0.005 per build minute**. The catalog record used for this verification was published 2026-09-11.

The account's EKS service quota currently permits 100 clusters and 30 managed node groups per cluster, so EXP-001 does not require a quota increase.

## Selected lab shape

- 1 EKS 1.36 control plane
- 2 x `c7i-flex.large` while establishing the baseline
- 1 x `c7i-flex.large` after successful capacity realization
- 20 GiB gp3 per worker
- 1 public IPv4 per worker
- no NAT Gateway
- no load balancer required for the synthetic workload
- no EKS control-plane log export by default; experiment evidence is collected explicitly
- 1 idle CodeBuild project whose `general1.small` runner exists only while a phase is executing

## Forecast calculation

For hourly forecasting, monthly gp3 storage is normalized using 730 hours/month:

```text
20 GiB gp3 hourly equivalent
= 20 * USD 0.08 / 730
= USD 0.00219178/hour per worker
```

Two-worker baseline:

```text
EKS control plane          0.10000000
2 x c7i-flex.large         0.16958000
2 x 20 GiB gp3             0.00438356
2 x public IPv4            0.01000000
-------------------------------------
forecast                   0.28396356 USD/hour
```

One-worker capacity-realized state:

```text
EKS control plane          0.10000000
1 x c7i-flex.large         0.08479000
1 x 20 GiB gp3             0.00219178
1 x public IPv4            0.00500000
-------------------------------------
forecast                   0.19198178 USD/hour
```

Forecast worker-removal delta:

```text
0.28396356 - 0.19198178
= 0.09198178 USD/hour
```

That delta is only a **forecast**. EXP-001 must not call it realized savings. The billable result is evaluated later from CUR 2.0 resource-level records and must survive the attribution rules in the evidence state machine.

## Experiment-runner cost

The CodeBuild project has no continuously running build host. A runner is created only while a build is executing. At the verified `general1.small` rate:

```text
5 minute phase  = 0.025 USD
10 minute phase = 0.050 USD
20 minute phase = 0.100 USD
```

A baseline phase, Arm A phase, and Arm B phase that each consumed ten billed minutes would therefore add approximately **USD 0.15** of CodeBuild compute. This is a forecast, not a claim about actual billed build duration.

CodeBuild is intentionally kept outside the worker-capacity savings calculation. It is experiment-control overhead, not the resource being optimized.

## Time envelope

If the corrected lab accidentally stayed in the two-worker baseline state for the entire period, the modeled core infrastructure exposure would be approximately:

| Elapsed time | Core forecast |
| ---: | ---: |
| 6 hours | USD 1.70 |
| 12 hours | USD 3.41 |
| 24 hours | USD 6.82 |

These figures exclude CodeBuild phase minutes, variable data transfer, container-registry traffic, possible CloudWatch usage, taxes, and any service pricing not listed above. They are therefore planning bounds for the known continuously running core resources, not invoices.

The AWS Budget `optimization-evidence-exp-001` is an **account-wide gross-spend alert guardrail**, not an allowed burn target, not a hard shutdown mechanism, and not EXP-001 cost attribution.

On 2026-09-18, before baseline, AWS Budgets reported monthly actual spend of USD 52.851 with no cost filters. The original USD 20 ceiling was therefore already breached by account-wide gross spend before any workload phase ran. The run was stopped and the lab was deleted.

The ceiling was rebased to **USD 70**, leaving approximately **USD 17.149** of gross-spend headroom from that observed baseline. ACTUAL-cost notifications are configured at 80%, 90%, and 100%. Before baseline and before every later phase, execution requires at least **USD 5.00** of remaining headroom.

The budget value must never be presented as EXP-001 spend. Resource-level CUR 2.0 records and experiment timestamps are the billing evidence used for attribution.

## Spend policy for EXP-001

The expected experiment should complete far below the USD 20 budget. The operational target is a single short session, not a persistent cluster.

Hard engineering behavior:

1. Do not create a NAT Gateway.
2. Do not use Spot for EXP-001; an interruption would contaminate node-removal attribution.
3. Use the smallest CodeBuild class that can reliably run the orchestration (`general1.small`).
4. Do not leave the EKS experiment stack running for convenience after the operational evidence is captured.
5. If the experiment cannot identify the exact managed node group, EC2 instance IDs, timestamps, and mutation cause, stop rather than collect ambiguous evidence.
6. Delete the experiment stack after Kubernetes/EC2/Auto Scaling evidence is persisted. Keep the separate billing-foundation stack so delayed CUR 2.0 records can be correlated later.
7. Never silently substitute an instance type after a launch failure. Change the source-of-truth, re-run CI/preflight, create a new reviewed change set, and only then redeploy.
8. Before baseline and before every subsequent phase, verify the account-wide budget is healthy, below its ceiling, and has at least USD 5.00 of remaining gross-spend headroom.
9. If a budget gate fails, delete the experiment stack before changing the guardrail; do not raise a live-run ceiling merely to keep already-running infrastructure alive.

## Claim boundary

A reduction in Kubernetes requests is not a cash saving.

A Cluster Autoscaler decision is not a cash saving.

An EC2 worker termination establishes capacity realization, but is still not sufficient for a final cash claim.

Only after the relevant billing records are observed and the causal attribution checks pass may the experiment transition to `REALIZED`.
