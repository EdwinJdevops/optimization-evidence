# ADR-0003: EXP-001 uses a controlled, short-lived EKS lab

- Status: Accepted
- Date: 2026-09-15

## Context

EXP-001 must distinguish an optimization that only reduces Kubernetes requests from one that removes billable worker capacity and later appears in billing evidence. The environment therefore has to make a two-node to one-node transition observable without introducing unrelated infrastructure behavior.

The experiment is evidence collection, not a benchmark of autoscaler sophistication. The infrastructure should minimize cost and confounders while remaining representative of a managed Kubernetes production primitive.

## Decision

Use one short-lived Amazon EKS cluster in `us-east-1` with the following fixed baseline:

- Kubernetes `1.36`, which AWS currently reports as the default EKS version and in standard support.
- One EKS managed node group using `t3.medium`, On-Demand capacity, 20 GiB gp3 root volumes, minimum 1, desired 2, maximum 2.
- Two public subnets in separate Availability Zones, an Internet Gateway, and no NAT Gateway.
- Public and private EKS API endpoints enabled. The public endpoint exists so an ephemeral AWS CodeBuild experiment runner can authenticate without introducing a NAT Gateway or a persistent bastion. Kubernetes authentication still gates access.
- No EC2 SSH key and no EKS node-group remote access configuration.
- Kubernetes Cluster Autoscaler `v1.36.0`, pinned to the upstream release that matches the cluster minor version.
- Cluster Autoscaler AWS permissions are isolated to Auto Scaling groups carrying the standard Cluster Autoscaler discovery tags for this cluster.
- EKS Pod Identity is used for the in-cluster autoscaler role.
- Experiment orchestration runs in AWS CodeBuild using `BUILD_GENERAL1_SMALL`, `aws/codebuild/standard:8.0`, no privileged mode, and a short timeout. The runner is ephemeral: the project itself is idle when no build is running.
- The CodeBuild service role can mutate Kubernetes through an EKS access entry, but it cannot directly resize the EC2 Auto Scaling group. Direct worker-capacity mutation remains isolated to the Cluster Autoscaler role. This preserves the causal boundary of Arm B.
- The CodeBuild role may read EKS, EC2, and Auto Scaling state and write raw experiment evidence only under the EXP-001 prefix of the retained evidence bucket.
- Each build checks out an exact repository commit SHA before executing the experiment harness. The build does not execute mutable branch contents by name.

All experiment resources carry:

- `Project=optimization-evidence`
- `Experiment=EXP-001`
- `Environment=research`

## Why `t3.medium`

Verified current us-east-1 Linux On-Demand prices are:

- `t3.small`: USD 0.0208/hour, 2 vCPU, 2 GiB RAM
- `t3.medium`: USD 0.0416/hour, 2 vCPU, 4 GiB RAM
- `t4g.small`: USD 0.0168/hour, 2 vCPU, 2 GiB RAM
- `t4g.medium`: USD 0.0336/hour, 2 vCPU, 4 GiB RAM

`t3.small` is cheaper, but 2 GiB is unnecessarily tight for EKS system workloads, the autoscaler, and experiment telemetry. Memory pressure would become a confounder. `t4g.medium` is cheaper than `t3.medium`, but ARM64 would add image-architecture compatibility to an experiment whose causal variable is capacity realization. The approximately USD 0.008/hour/node difference is not worth that extra variable for a short-lived lab.

## Why On-Demand

Spot is rejected for EXP-001. A Spot interruption could remove a node independently of the optimization and make capacity attribution invalid. The experiment must be able to say why a worker disappeared.

## Why Cluster Autoscaler instead of Karpenter

Karpenter is a strong production option, but EXP-001 only needs one managed node group to move from desired capacity 2 to 1. Karpenter introduces instance selection, provisioning policy, EC2 Fleet behavior, and an additional execution model. Those are useful in later experiments, but they weaken the causal isolation of EXP-001.

Cluster Autoscaler directly changes the desired capacity of the known managed node group, which gives us a narrow mutation surface and a simple chain of evidence.

## Why CodeBuild instead of a persistent runner or GitHub-hosted runner

A persistent EC2 runner would add another continuously billed instance and public IPv4 address to the experiment. A GitHub-hosted runner would require a repository-level OIDC role reference or repository secret/variable management outside the current AWS-native experiment boundary.

CodeBuild gives us an ephemeral AWS-native command runner that can be started and inspected through AWS APIs, can be represented in the same CloudFormation stack, and can use an EKS access entry tied directly to its service role. Current AWS Price List data for `general1.small` in us-east-1 is USD 0.005 per build minute. A ten-minute build is therefore approximately USD 0.05 before any unrelated service charges.

The runner role intentionally has no `autoscaling:SetDesiredCapacity` or `autoscaling:TerminateInstanceInAutoScalingGroup` permission. If capacity changes during Arm B, the AWS-side actor should be the Cluster Autoscaler role rather than the orchestration runner.

## Why no NAT Gateway

A NAT Gateway has a fixed hourly charge and data-processing charges that do not help this experiment. Workers instead run in public subnets with public IPv4 addresses and no inbound SSH. Current AWS price-catalog data for us-east-1 shows USD 0.005/hour per in-use public IPv4 address. For a two-node, short-duration lab, that is materially cheaper than introducing a NAT Gateway.

The security tradeoff is explicit: the nodes have public addresses but receive no arbitrary inbound access. The cluster is disposable and exists only for the controlled experiment window.

## Experiment semantics

Arm A keeps two billable workers present while application requests are reduced. Service health can remain good, but the evidence engine must terminate the arm as `NO_CASH_SAVING` because no billable EC2 worker capacity is removed.

Arm B enables the node-capacity transition. The same request reduction must make the workload schedulable on one node, Cluster Autoscaler must remove one managed worker, EC2/Auto Scaling evidence must confirm that removal, and later CUR 2.0 evidence must show the billing effect before `REALIZED` is reachable.

A Kubernetes-success signal alone is never sufficient for `REALIZED`.

## Rejected alternatives

- `t3.small`: lower price, higher memory-pressure risk.
- `t4g.*`: lower price, but ARM64 is an unnecessary experiment variable.
- Spot capacity: interruption is an attribution confounder.
- Karpenter: wider decision surface than EXP-001 requires.
- EKS Auto Mode: adds a separately priced management mechanism and changes the capacity-control path.
- NAT Gateway: avoidable fixed cost.
- Direct SSH access: unnecessary and contrary to the experiment's minimum-access requirement.
- Persistent EC2 experiment runner: adds continuously billed capacity and another attribution exclusion.
- GitHub-hosted execution for EXP-001: workable, but less directly automatable through the connected AWS control plane than an ephemeral CodeBuild runner and would add an external OIDC credential path.

## Consequences

The lab is not a recommendation for every production EKS architecture. Public worker subnets and a public API endpoint are deliberate short-lived experiment choices made to minimize cost and enable the ephemeral runner. Production guidance must not be inferred from this ADR.

The public EKS endpoint is not treated as sufficient authorization; EKS authentication and the access entry remain required. The runner and autoscaler have separate roles so orchestration and capacity mutation do not share the same AWS permissions.

The experiment must be torn down immediately after operational evidence is captured. Billing evidence can arrive later because the CUR 2.0 export is maintained by the separate retained billing-foundation stack.
