# EXP-001 non-executed CloudFormation change-set gate

A non-executed change set must be created from the exact `infra/aws/exp001-cluster.yaml` template before deployment. This gate exists to force AWS to resolve the resource graph and surface create-time validation issues before any resources are provisioned.

Acceptance criteria:

- change set status reaches `CREATE_COMPLETE`;
- change set execution status is `AVAILABLE`;
- no replacement/update action exists because the target stack must not yet exist;
- all changes are creates for the documented EXP-001 lab resources;
- no NAT Gateway, load balancer, database, or unrelated paid resource appears;
- IAM capabilities are explicitly acknowledged;
- the change set is not executed until PR review and CI succeed.

If the change set fails, the failure reason is documented and the template is corrected before proceeding.
