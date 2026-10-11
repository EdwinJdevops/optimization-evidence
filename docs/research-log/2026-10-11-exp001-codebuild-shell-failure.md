# 2026-10-11 EXP-001 CodeBuild shell failure

## What failed

The first replacement-account baseline build failed before repository checkout and before any Kubernetes mutation.

CodeBuild entered the `INSTALL` phase and executed:

`set -Eeuo pipefail`

The runtime shell was `/bin/sh`, which returned:

`set: Illegal option -o pipefail`

The build stopped with `COMMAND_EXECUTION_ERROR`.

## Scope

No baseline workload was applied. No Arm A or Arm B action occurred. The managed node group remained at two healthy workers and no experiment result was produced.

## Root cause

The embedded CodeBuild buildspec relied on Bash-specific shell options but did not explicitly select Bash. The repository runner itself is a Bash script, but the pre-run CodeBuild commands were interpreted by the default shell.

## Correction

The buildspec now declares:

```yaml
env:
  shell: bash
```

A CI regression check verifies that the EXP-001 buildspec continues to select Bash explicitly.

This correction changes only runner execution semantics. It does not change workload resources, autoscaling policy, experiment topology, or outcome criteria.

## Claim boundary

This is a runner bootstrap failure, not an experiment failure and not evidence about optimization effectiveness.
