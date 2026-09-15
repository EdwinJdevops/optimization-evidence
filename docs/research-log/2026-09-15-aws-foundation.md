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

Created `optimization-evidence-exp-001` with a USD 20 monthly limit. Credits and refunds are excluded from the budget calculation so promotional credits do not hide gross experimental consumption.

AWS Budgets reports the budget `HEALTHY`. Three ACTUAL-cost notifications are configured at 50%, 80%, and 100%, all currently `OK`, with delivery to the project owner's email address.

At verification time AWS Budgets reported current calculated actual spend `0.0 USD`. This is the budget service's current value, not a claim that the account has never incurred cost.

## Promotional-credit balance

The available AWS APIs used here do not expose the console's promotional-credit remaining-balance view. AWS documentation directs customers to Billing and Cost Management -> Credits for exact remaining amount, expiration, and eligible services. Therefore the previously stated approximately USD 158 remaining credit has not been independently verified by this automation and must not be treated as a verified value.
