# EXP-001 review checklist

The PR implementing EXP-001 must be reviewed against this checklist before merge.

- [ ] CloudFormation template validated by AWS.
- [ ] Non-executed change set reaches `CREATE_COMPLETE` and contains only expected creates.
- [ ] No NAT Gateway or unrelated paid service is introduced.
- [ ] EKS control plane version and Cluster Autoscaler version are aligned.
- [ ] Managed node group starts at desired=2, min=1, max=2.
- [ ] Baseline requests require two workers; optimized requests can fit on one worker with system overhead.
- [ ] CodeBuild runner cannot mutate Auto Scaling groups.
- [ ] Cluster Autoscaler role is constrained by experiment discovery tags.
- [ ] Runtime performs server-side manifest dry-runs before mutation.
- [ ] Evidence upload path is isolated to `experiments/EXP-001/`.
- [ ] Arm A explicitly forbids capacity change.
- [ ] Arm B proves capacity removal before any financial classification.
- [ ] `REALIZED` remains impossible until billing evidence arrives.
- [ ] CI is green.
- [ ] Full PR diff reviewed after final commit.
