# 2026-09-15 AWS evidence foundation

## Verified observations

AWS account inspection found an existing `ai-lifecycle-eks` EKS 1.34 cluster in `us-east-1` with no active managed node group or Fargate profile. Its eksctl CloudFormation stack still contained an EKS control plane, VPC, NAT Gateway, Elastic IP, subnets, route tables, security groups, and IAM role. Cleanup was explicitly authorized because the environment was no longer needed.

Cleanup is now complete: the nodegroup stack no longer exists, the cluster stack no longer exists, `DescribeCluster` returns `ResourceNotFoundException`, and the former NAT Gateway `nat-0f29a9d8e00385b7c` reports `deleted`.

No existing AWS Budget or legacy CUR report definition was present before this work. Cost Explorer API access was not enabled for the calling identity/account configuration.

## Billing foundation

Created CloudFormation stack `optimization-evidence-billing-foundation` in `us-east-1`.

Verified stack status: `CREATE_COMPLETE`.

It provisions:

- private S3 evidence bucket with public access blocked;
- bucket-owner-enforced ownership;
- AES-256 server-side encryption;
- 180-day expiration and 7-day incomplete multipart cleanup;
- scoped bucket policy allowing `bcm-data-exports.amazonaws.com` to write for this account;
- CUR 2.0 Data Export with hourly granularity, resource IDs, capacity-reservation data, Parquet format, and overwrite delivery mode.

## Failure retained as engineering evidence

The first deployment attempted `SELECT * FROM COST_AND_USAGE_REPORT`. AWS BCM Data Exports rejected it because `SELECT *` is not supported. CloudFormation rolled back correctly. The failed retained bucket was verified empty and removed. The current CUR schema was then obtained through `GetTable`, an explicit column list was generated, and the stack was redeployed successfully.

This failure is intentionally documented because reproducibility includes rejected assumptions, not only the final green path.

## Budget

Created `optimization-evidence-exp-001` as an account-wide gross-spend guardrail. Credits and refunds are excluded from the budget calculation so promotional credits do not hide gross consumption.

On 2026-09-18, before any EXP-001 workload phase ran, AWS Budgets reported monthly calculated actual spend of `52.851 USD`. The budget had no cost filters, so that value is account-wide and cannot be attributed to EXP-001. Because the original USD 20 ceiling was already breached, the EXP-001 runbook stop condition fired and the freshly created lab stack was immediately deleted before baseline execution.

The monthly ceiling was then rebased to `70 USD`, preserving approximately `17.149 USD` of gross-spend headroom from the observed account baseline. ACTUAL-cost notification thresholds are now 80%, 90%, and 100%; all were verified `OK` immediately after the update.

This budget is an alerting guardrail, not a hard cap and not an experiment cost meter. EXP-001 cost attribution is performed later from CUR 2.0 resource-level records and experiment timestamps.

## Promotional-credit balance

The available AWS APIs used here do not expose the console's promotional-credit remaining-balance view. AWS documentation directs customers to Billing and Cost Management -> Credits for exact remaining amount, expiration, and eligible services. Therefore the previously stated approximately USD 158 remaining credit has not been independently verified by this automation and must not be treated as a verified value.
