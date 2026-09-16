# EXP-001 operations runbook

This runbook is the execution contract for the first controlled optimization experiment.

## Deployment order

1. Merge the reviewed infrastructure PR.
2. Create a fresh CloudFormation change set from the merged template. Inspect every resource action before execution.
3. Execute the approved change set.
4. Verify stack status, EKS control plane, managed node group, CodeBuild project, IAM roles, Pod Identity association, log group, VPC routes, and absence of NAT gateways.
5. Inspect the managed node group Auto Scaling Group. Record its name, desired/min/max capacity, instances, and Cluster Autoscaler discovery tags.
6. If required discovery tags are absent, stop. Do not run Arm B until tags and IAM conditions are aligned and re-reviewed.

## Phase order

Run phases separately. Never combine them into one opaque build.

### Baseline

Expected state:
- 2 Ready worker nodes.
- managed node group desired capacity = 2.
- 4 app replicas distributed across both worker nodes.
- Cluster Autoscaler absent.
- load generator continuously probes the service.

Evidence must be uploaded before proceeding.

### Arm A — efficiency without capacity realization

Apply the optimized requests while Cluster Autoscaler remains absent.

Expected state:
- application remains available.
- 2 Ready worker nodes remain.
- ASG desired capacity remains 2.

Interpretation: resource efficiency changed, but billable worker capacity did not. The experiment must not claim realized compute savings from this phase.

### Arm B — capacity realization

Keep the optimized workload and deploy Cluster Autoscaler.

Expected state:
- Cluster Autoscaler discovers only the EXP-001 managed node group.
- desired capacity transitions from 2 to 1.
- one worker terminates.
- application returns to Ready on the remaining worker.

This establishes `CAPACITY_REALIZED`, not `REALIZED` financial savings. Financial realization remains pending until billing evidence is observed and attributed.

## Stop conditions

Stop immediately and preserve evidence if any of the following occurs:
- workload availability fails materially;
- the Autoscaler can see or mutate an unrelated ASG;
- expected ASG discovery tags are absent or inconsistent with IAM conditions;
- node group capacity changes during Arm A;
- evidence upload fails;
- any unexpected paid resource appears outside the documented lab topology;
- AWS budget guardrail is breached.

## Teardown

After operational evidence is complete, delete `optimization-evidence-exp001-lab` and verify deletion of EKS, node group/ASG, EC2 instances, EBS volumes, CodeBuild project, log group, IAM roles created by the stack, VPC, subnets, route table, and internet gateway. Do not delete the retained billing/evidence foundation stack or evidence bucket.
