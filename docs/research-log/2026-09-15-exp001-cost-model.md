# 2026-09-15 EXP-001 AWS cost model

This document separates verified price observations from calculated experiment forecasts. It is not a cloud-bill claim.

## Verified observations

Region: `us-east-1`.

AWS EKS currently reports Kubernetes `1.36` as the default EKS version and in `STANDARD_SUPPORT`. AWS documentation prices a cluster running a Kubernetes version in standard support at **USD 0.10 per cluster-hour**.

AWS Price List API results for Linux, shared-tenancy, On-Demand EC2 in US East (N. Virginia):

| Instance | vCPU | Memory | Architecture | Price/hour |
| --- | ---: | ---: | --- | ---: |
| t3.small | 2 | 2 GiB | x86_64 | USD 0.0208 |
| t3.medium | 2 | 4 GiB | x86_64 | USD 0.0416 |
| t4g.small | 2 | 2 GiB | arm64 | USD 0.0168 |
| t4g.medium | 2 | 4 GiB | arm64 | USD 0.0336 |

AWS Price List API results for gp3 in US East (N. Virginia): **USD 0.08 per GB-month** for storage before any chargeable IOPS or throughput above the gp3 included baseline.

AWS Price List API results for an in-use public IPv4 address in US East (N. Virginia): **USD 0.005 per address-hour**.

AWS Price List API results for CodeBuild `general1.small` Linux On-Demand in US East (N. Virginia): **USD 0.005 per build minute**. The catalog record used for this verification was published 2026-09-11.

The account's EKS service quota currently permits 100 clusters and 30 managed node groups per cluster, so EXP-001 does not require a quota increase.

## Selected lab shape

- 1 EKS 1.36 control plane
- 2 x `t3.medium` while establishing the baseline
- 1 x `t3.medium` after successful capacity realization
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
EKS control plane         0.10000000
2 x t3.medium             0.08320000
2 x 20 GiB gp3            0.00438356
2 x public IPv4           0.01000000
------------------------------------
forecast                  0.19758356 USD/hour
```

One-worker realized-capacity state:

```text
EKS control plane         0.10000000
1 x t3.medium             0.04160000
1 x 20 GiB gp3            0.00219178
1 x public IPv4           0.00500000
------------------------------------
forecast                  0.14879178 USD/hour
```

Forecast worker-removal delta:

```text
0.19758356 - 0.14879178
= 0.04879178 USD/hour
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

If the lab accidentally stayed in the two-worker baseline state for the entire period, the modeled core infrastructure exposure would be approximately:

| Elapsed time | Core forecast |
| ---: | ---: |
| 6 hours | USD 1.19 |
| 12 hours | USD 2.37 |
| 24 hours | USD 4.74 |

These figures exclude CodeBuild phase minutes, variable data transfer, container-registry traffic, possible CloudWatch usage, taxes, and any service pricing not listed above. They are therefore planning bounds for the known continuously running core resources, not invoices.

The separate AWS Budget `optimization-evidence-exp-001` remains a **USD 20 monthly alert guardrail**, not an allowed burn target and not an automatic shutdown mechanism. ACTUAL-cost notifications are configured at 50%, 80%, and 100%.

## Spend policy for EXP-001

The expected experiment should complete far below the USD 20 budget. The operational target is a single short session, not a persistent cluster.

Hard engineering behavior:

1. Do not create a NAT Gateway.
2. Do not use Spot for EXP-001; an interruption would contaminate node-removal attribution.
3. Use the smallest CodeBuild class that can reliably run the orchestration (`general1.small`).
4. Do not leave the EKS experiment stack running for convenience after the operational evidence is captured.
5. If the experiment cannot identify the exact managed node group, EC2 instance IDs, timestamps, and mutation cause, stop rather than collect ambiguous evidence.
6. Delete the experiment stack after Kubernetes/EC2/Auto Scaling evidence is persisted. Keep the separate billing-foundation stack so delayed CUR 2.0 records can be correlated later.

## Claim boundary

A reduction in Kubernetes requests is not a cash saving.

A Cluster Autoscaler decision is not a cash saving.

An EC2 worker termination establishes capacity realization, but is still not sufficient for a final cash claim.

Only after the relevant billing records are observed and the causal attribution checks pass may the experiment transition to `REALIZED`.
