#!/usr/bin/env bash
set -Eeuo pipefail

PHASE="${1:-${PHASE:-}}"
CLUSTER_NAME="${CLUSTER_NAME:-optimization-evidence-exp001}"
NODEGROUP_NAME="${NODEGROUP_NAME:-optimization-evidence-exp001-workers}"
EVIDENCE_BUCKET="${EVIDENCE_BUCKET:?EVIDENCE_BUCKET is required}"
REPO_SHA="${REPO_SHA:?REPO_SHA is required}"
AWS_REGION="${AWS_REGION:-us-east-1}"
RUN_ID_RAW="${CODEBUILD_BUILD_ID:-local-$(date -u +%Y%m%dT%H%M%SZ)}"
RUN_ID="${RUN_ID_RAW//[:\/]/-}"
EVIDENCE_ROOT="/tmp/optimization-evidence/${RUN_ID}/${PHASE:-unknown}"
SNAPSHOT_WRITTEN=0

case "${PHASE}" in
  baseline|arm-a|arm-b|snapshot) ;;
  *) echo "unsupported phase: ${PHASE}" >&2; exit 64 ;;
esac

mkdir -p "${EVIDENCE_ROOT}"

ready_node_count() {
  kubectl get nodes --no-headers 2>/dev/null | awk '$2 == "Ready" {n++} END {print n+0}'
}

nodegroup_asg() {
  aws eks describe-nodegroup \
    --region "${AWS_REGION}" \
    --cluster-name "${CLUSTER_NAME}" \
    --nodegroup-name "${NODEGROUP_NAME}" \
    --query 'nodegroup.resources.autoScalingGroups[0].name' \
    --output text
}

asg_desired_capacity() {
  local asg="$1"
  aws autoscaling describe-auto-scaling-groups \
    --region "${AWS_REGION}" \
    --auto-scaling-group-names "${asg}" \
    --query 'AutoScalingGroups[0].DesiredCapacity' \
    --output text
}

collect_evidence() {
  local reason="${1:-snapshot}"
  local ts asg instance_ids
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  asg="$(nodegroup_asg 2>/dev/null || true)"

  cat > "${EVIDENCE_ROOT}/metadata.json" <<EOF
{
  "experiment": "EXP-001",
  "phase": "${PHASE}",
  "reason": "${reason}",
  "captured_at": "${ts}",
  "repository_sha": "${REPO_SHA}",
  "codebuild_build_id": "${RUN_ID_RAW}",
  "cluster_name": "${CLUSTER_NAME}",
  "nodegroup_name": "${NODEGROUP_NAME}",
  "aws_region": "${AWS_REGION}"
}
EOF

  kubectl version -o yaml > "${EVIDENCE_ROOT}/kubectl-version.yaml" 2>&1 || true
  kubectl get nodes -o wide > "${EVIDENCE_ROOT}/nodes-wide.txt" 2>&1 || true
  kubectl get nodes -o json > "${EVIDENCE_ROOT}/nodes.json" 2>&1 || true
  kubectl get pods -A -o wide > "${EVIDENCE_ROOT}/pods-all-wide.txt" 2>&1 || true
  kubectl get pods -n optimization-evidence -o json > "${EVIDENCE_ROOT}/workload-pods.json" 2>&1 || true
  kubectl get deployments -A -o yaml > "${EVIDENCE_ROOT}/deployments.yaml" 2>&1 || true
  kubectl get events -A --sort-by=.lastTimestamp > "${EVIDENCE_ROOT}/events.txt" 2>&1 || true
  kubectl logs -n optimization-evidence deployment/exp001-loadgen --tail=-1 > "${EVIDENCE_ROOT}/loadgen.log" 2>&1 || true
  kubectl logs -n kube-system deployment/cluster-autoscaler --tail=-1 > "${EVIDENCE_ROOT}/cluster-autoscaler.log" 2>&1 || true

  aws eks describe-cluster \
    --region "${AWS_REGION}" \
    --name "${CLUSTER_NAME}" > "${EVIDENCE_ROOT}/eks-cluster.json" 2>&1 || true
  aws eks describe-nodegroup \
    --region "${AWS_REGION}" \
    --cluster-name "${CLUSTER_NAME}" \
    --nodegroup-name "${NODEGROUP_NAME}" > "${EVIDENCE_ROOT}/eks-nodegroup.json" 2>&1 || true

  if [[ -n "${asg}" && "${asg}" != "None" ]]; then
    printf '%s\n' "${asg}" > "${EVIDENCE_ROOT}/asg-name.txt"
    aws autoscaling describe-auto-scaling-groups \
      --region "${AWS_REGION}" \
      --auto-scaling-group-names "${asg}" > "${EVIDENCE_ROOT}/asg.json" 2>&1 || true
    aws autoscaling describe-scaling-activities \
      --region "${AWS_REGION}" \
      --auto-scaling-group-name "${asg}" \
      --max-records 50 > "${EVIDENCE_ROOT}/asg-activities.json" 2>&1 || true

    instance_ids="$(aws autoscaling describe-auto-scaling-groups \
      --region "${AWS_REGION}" \
      --auto-scaling-group-names "${asg}" \
      --query 'AutoScalingGroups[0].Instances[].InstanceId' \
      --output text 2>/dev/null || true)"
    if [[ -n "${instance_ids}" ]]; then
      # shellcheck disable=SC2086
      aws ec2 describe-instances --region "${AWS_REGION}" --instance-ids ${instance_ids} > "${EVIDENCE_ROOT}/ec2-instances.json" 2>&1 || true
    fi
  fi

  if [[ -f "${EVIDENCE_ROOT}/loadgen.log" ]]; then
    {
      printf 'ok_count='
      grep -c 'status=ok' "${EVIDENCE_ROOT}/loadgen.log" || true
      printf 'fail_count='
      grep -c 'status=fail' "${EVIDENCE_ROOT}/loadgen.log" || true
    } > "${EVIDENCE_ROOT}/loadgen-summary.txt"
  fi

  aws s3 cp "${EVIDENCE_ROOT}" \
    "s3://${EVIDENCE_BUCKET}/experiments/EXP-001/${RUN_ID}/${PHASE}/" \
    --recursive --only-show-errors
  SNAPSHOT_WRITTEN=1
}

on_exit() {
  local rc=$?
  trap - EXIT
  if [[ "${SNAPSHOT_WRITTEN}" -eq 0 ]]; then
    collect_evidence "exit-${rc}" || true
  fi
  exit "${rc}"
}
trap on_exit EXIT

wait_for_ready_nodes() {
  local expected="$1" timeout_seconds="$2" deadline count
  deadline=$(( $(date +%s) + timeout_seconds ))
  while (( $(date +%s) < deadline )); do
    count="$(ready_node_count)"
    if [[ "${count}" -eq "${expected}" ]]; then
      return 0
    fi
    sleep 10
  done
  echo "timed out waiting for ${expected} Ready nodes; observed $(ready_node_count)" >&2
  return 1
}

wait_for_asg_desired() {
  local expected="$1" timeout_seconds="$2" asg deadline desired
  asg="$(nodegroup_asg)"
  deadline=$(( $(date +%s) + timeout_seconds ))
  while (( $(date +%s) < deadline )); do
    desired="$(asg_desired_capacity "${asg}")"
    if [[ "${desired}" == "${expected}" ]]; then
      return 0
    fi
    sleep 10
  done
  echo "timed out waiting for ASG desired capacity ${expected}" >&2
  return 1
}

validate_two_node_distribution() {
  local host_count pod_count
  pod_count="$(kubectl get pods -n optimization-evidence -l app=exp001-app --field-selector=status.phase=Running --no-headers | wc -l | tr -d ' ')"
  host_count="$(kubectl get pods -n optimization-evidence -l app=exp001-app -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sed '/^$/d' | sort -u | wc -l | tr -d ' ')"
  [[ "${pod_count}" -eq 4 ]] || { echo "expected 4 running app pods, observed ${pod_count}" >&2; return 1; }
  [[ "${host_count}" -eq 2 ]] || { echo "expected app pods across 2 worker nodes, observed ${host_count}" >&2; return 1; }
}

aws eks update-kubeconfig --region "${AWS_REGION}" --name "${CLUSTER_NAME}" >/dev/null
kubectl auth can-i '*' '*' >/dev/null

case "${PHASE}" in
  baseline)
    kubectl delete deployment cluster-autoscaler -n kube-system --ignore-not-found=true
    kubectl apply -f infra/k8s/exp001/workload-baseline.yaml
    kubectl rollout status deployment/exp001-app -n optimization-evidence --timeout=5m
    kubectl rollout status deployment/exp001-loadgen -n optimization-evidence --timeout=3m
    wait_for_ready_nodes 2 300
    wait_for_asg_desired 2 300
    validate_two_node_distribution
    sleep 120
    [[ "$(ready_node_count)" -eq 2 ]]
    collect_evidence "baseline-stable"
    ;;

  arm-a)
    kubectl delete deployment cluster-autoscaler -n kube-system --ignore-not-found=true
    kubectl apply -f infra/k8s/exp001/workload-optimized.yaml
    kubectl rollout status deployment/exp001-app -n optimization-evidence --timeout=5m
    kubectl rollout status deployment/exp001-loadgen -n optimization-evidence --timeout=3m
    wait_for_ready_nodes 2 300
    sleep 180
    [[ "$(ready_node_count)" -eq 2 ]] || { echo "Arm A lost worker capacity unexpectedly" >&2; exit 2; }
    [[ "$(asg_desired_capacity "$(nodegroup_asg)")" == "2" ]] || { echo "Arm A ASG desired capacity changed unexpectedly" >&2; exit 2; }
    collect_evidence "arm-a-no-capacity-change"
    ;;

  arm-b)
    kubectl apply -f infra/k8s/exp001/workload-optimized.yaml
    kubectl rollout status deployment/exp001-app -n optimization-evidence --timeout=5m
    kubectl rollout status deployment/exp001-loadgen -n optimization-evidence --timeout=3m
    wait_for_ready_nodes 2 300
    wait_for_asg_desired 2 300
    kubectl apply -f infra/k8s/exp001/cluster-autoscaler.yaml
    kubectl rollout status deployment/cluster-autoscaler -n kube-system --timeout=5m
    wait_for_asg_desired 1 900
    wait_for_ready_nodes 1 900
    kubectl rollout status deployment/exp001-app -n optimization-evidence --timeout=5m
    sleep 120
    [[ "$(ready_node_count)" -eq 1 ]]
    [[ "$(asg_desired_capacity "$(nodegroup_asg)")" == "1" ]]
    collect_evidence "arm-b-capacity-realized"
    ;;

  snapshot)
    collect_evidence "manual-snapshot"
    ;;
esac
