# EXP-001 preflight log — 2026-09-16

This log records the pre-deployment gates for EXP-001. It intentionally separates verified facts from planned actions.

## Verified before PR

- AWS CloudFormation `ValidateTemplate` succeeded for `infra/aws/exp001-cluster.yaml` in `us-east-1`.
- Validation reported the expected five parameters and `CAPABILITY_IAM` requirement.
- The retained billing foundation stack `optimization-evidence-billing-foundation` is `CREATE_COMPLETE`.
- Its evidence bucket is `optimization-evidence-billing-found-evidencebucket-zshf0e8akp0w`.
- No `optimization-evidence-exp001-lab` CloudFormation stack existed at verification time.
- Current EXP-001 branch is based on `main` with no divergence from main at the time of comparison.

## Safety gates added before deployment

- CI parses every EXP-001 Kubernetes YAML document and verifies `apiVersion` and `kind` are present.
- CI runs `bash -n` and `shellcheck` against `scripts/exp001/run.sh`.
- The runtime runner performs Kubernetes API server-side dry-runs of all three EXP-001 manifests before any phase mutates the cluster.
- Kubernetes authorization is checked in quiet/fail-closed mode before execution.
- CodeBuild executes only an exact 40-character Git commit SHA.
- The runner role has no Auto Scaling mutation permissions; only the Cluster Autoscaler role can change desired capacity or terminate instances.
- Evidence is written under the retained `experiments/EXP-001/` S3 prefix.

## Known design tradeoff

The EKS public API endpoint is enabled because the short-lived CodeBuild runner is outside the experiment VPC and needs direct API connectivity without a NAT gateway. Authentication and EKS access policy remain mandatory. This is acceptable for the controlled lab but is not the target production deployment posture.

## Required remaining gates

1. Create and inspect a non-executed CloudFormation change set from the exact branch template.
2. Open the infrastructure PR and require CI to pass.
3. Inspect the complete PR diff and any CI failures.
4. Merge only after the above pass.
5. Create a fresh post-merge change set from the merged commit and inspect it before execution.
6. Deploy the lab.
7. Verify the managed node group Auto Scaling Group auto-discovery tags before starting Cluster Autoscaler.
8. Run baseline, Arm A, and Arm B separately, preserving evidence after every phase.
9. Do not classify any modeled reduction as realized savings until corresponding billing evidence arrives.
