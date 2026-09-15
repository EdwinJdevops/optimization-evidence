# ADR-0002: AWS-first validation, provider-neutral core

Status: accepted

## Context

Testing every provider immediately would prevent rigorous validation. AWS provides the required first-party surfaces for a controlled proof: EKS/EC2 runtime state plus CUR 2.0 hourly resource-level billing evidence.

## Decision

EXP-001 will run on AWS/EKS. Core domain names and state transitions will not embed AWS/EKS assumptions. Provider-specific fields live in adapters and evidence payloads.

## Consequences

The first implementation stays small while preserving a path to databases, GPUs, and other providers. Multi-cloud support will not be claimed until independent adapters and experiments exist.
