# 2026-10-11 AWS account migration

## Context

The predecessor AWS account used for the September EXP-001 work is no longer available to the project after an account suspension reported by the account owner. The current AWS connection points to a replacement account.

This is an infrastructure-account migration, not a project reset. GitHub remains the source of truth for the domain model, state machine, experiment design, CloudFormation, Kubernetes manifests, runner, ADRs, cost model, and prior failure records.

No prior cloud execution result is being copied forward. In particular, no baseline, Arm A, Arm B, capacity-realization, billing-observation, attribution, or realized-savings state from the predecessor account is assumed in the replacement account.

## Replacement-account preflight

Verified on 2026-10-11 in `us-east-1`:

- no existing `optimization-evidence` CloudFormation stack;
- no existing optimization-evidence EKS cluster;
- no existing optimization-evidence CodeBuild project;
- no existing AWS Budget for EXP-001;
- no existing BCM Data Export;
- EKS 1.36 is in standard support;
- `c7i-flex.large` is offered in `us-east-1`;
- `c7i-flex.large` reports as Free Tier eligible for this account;
- the account has a 16-vCPU quota for standard On-Demand EC2 families, which is sufficient for the planned two 2-vCPU workers;
- Cost Explorer API access is not enabled for the current identity/account configuration.

## Migration rule

Recreate only infrastructure that is defined by reviewed source in this repository. Do not manually reconstruct predecessor-account resources from memory.

The migration sequence is:

1. recreate the retained billing/evidence foundation from `infra/aws/billing-foundation.yaml`;
2. create a low monthly gross-spend AWS Budget guardrail;
3. verify the new evidence bucket and CUR 2.0 export;
4. create the EXP-001 lab from the reviewed CloudFormation template;
5. re-run baseline, Arm A, and Arm B from the beginning;
6. tear down the short-lived lab immediately after operational evidence is captured;
7. wait for billing data from the replacement account and perform attribution there.

## Evidence discontinuity

The predecessor account and the replacement account are distinct billing domains. Evidence from them must never be merged as if it came from one continuous experiment.

Historical repository records remain valid as engineering-history records. Financial and operational evidence for the replacement-account run begins at the replacement-account foundation deployment and must carry new timestamps and AWS resource identities.

## Claim boundary

This migration preserves project continuity, but it does not preserve cloud-resource identity or billing continuity. EXP-001 must be executed again from baseline in the replacement account before any experiment outcome is classified.


## Replacement-account foundation deployment

After the preflight, the replacement account was bootstrapped from the existing reviewed repository rather than reconstructed manually.

A new monthly AWS Budget named `optimization-evidence-exp-001` was created at **USD 20**. Credits and refunds are excluded from its calculation. Immediately after creation AWS Budgets reported:

- health: `HEALTHY`;
- calculated actual spend: `0.0 USD`;
- monthly ceiling: `20.0 USD`.

The budget currently exists as the runtime stop-condition source. No email subscriber was inferred or invented during migration.

The existing repository template `infra/aws/billing-foundation.yaml` was validated by CloudFormation in the replacement account. A reviewed create change set contained exactly three additions:

- `AWS::S3::Bucket`;
- `AWS::S3::BucketPolicy`;
- `AWS::BCMDataExports::Export`.

The change set was executed and the stack reached `CREATE_COMPLETE`.

Read-after-write verification confirmed:

- all S3 public-access blocks enabled;
- bucket-owner-enforced object ownership;
- AES-256 default encryption;
- 180-day evidence expiration;
- 7-day incomplete multipart-upload cleanup;
- CUR 2.0 Data Export present and `HEALTHY`;
- only the AWS programmatic-access test object present immediately after creation, so no actual CUR delivery had arrived yet.

The evidence bucket physical name and account identifiers are intentionally omitted from this public research log.
