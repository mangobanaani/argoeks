#!/usr/bin/env bash
set -euo pipefail

# AWS Account Purge Script (AWS CLI v2 + jq)
# Destroys common billable resources across all regions.
# SAFETY: Requires NUKE_CONFIRM env var to equal the AWS account ID.
# Usage examples:
#   Preview only:   ./scripts/aws-purge-all.sh --preview
#   Limit regions:  REGIONS="us-east-1 eu-west-1" ./scripts/aws-purge-all.sh
#   Execute purge:  NUKE_CONFIRM=$(aws sts get-caller-identity --query Account --output text) ./scripts/aws-purge-all.sh

require() { command -v "$1" >/dev/null 2>&1 || { echo "FATAL: missing dependency: $1" >&2; exit 1; }; }
require aws
require jq

log() { printf "[%s] %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }

# Enforce env-only credentials (ignore shared config/credentials files)
unset AWS_PROFILE || true
export AWS_SHARED_CREDENTIALS_FILE=/dev/null
export AWS_CONFIG_FILE=/dev/null
export AWS_SDK_LOAD_CONFIG=0

# Require env credentials (e.g., provided by `set -a; source .env; set +a`)
if [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
  echo "ERROR: No AWS env credentials found. Source your .env first:" >&2
  echo "  set -a; source .env; set +a" >&2
  exit 2
fi

PREVIEW=false
if [[ "${1:-}" == "--preview" ]]; then PREVIEW=true; fi

# Verify AWS identity early
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || true)
if [[ -z "${ACCOUNT_ID}" ]]; then
  echo "ERROR: Unable to retrieve AWS caller identity. Ensure credentials are valid (token not expired)." >&2
  echo "Try: aws sso login --profile <profile>  OR  export AWS_ACCESS_KEY_ID/SECRET_KEY/SESSION_TOKEN" >&2
  exit 2
fi

if [[ "${PREVIEW}" == "false" ]]; then
  if [[ -z "${NUKE_CONFIRM:-}" || "${NUKE_CONFIRM}" != "${ACCOUNT_ID}" ]]; then
    cat >&2 <<EOF
SAFETY CHECK FAILED
-------------------
This script is DESTRUCTIVE. To proceed, set env var NUKE_CONFIRM to the current account id.

Detected account: ${ACCOUNT_ID}

Examples:
  export NUKE_CONFIRM=${ACCOUNT_ID}
  ./scripts/aws-purge-all.sh

Or run one-shot:
  NUKE_CONFIRM=${ACCOUNT_ID} ./scripts/aws-purge-all.sh

EOF
    exit 3
  fi
fi

# Region selection (avoid bash 4+ dependencies)
if [[ -n "${REGIONS:-}" ]]; then
  REGIONS_LIST="${REGIONS}"
else
  REGIONS_LIST="$(aws ec2 describe-regions --all-regions --query 'Regions[].RegionName' --output text | xargs -n1 | tr '\n' ' ')"
fi

log "Target account: ${ACCOUNT_ID}"
log "Mode: $([[ "${PREVIEW}" == true ]] && echo PREVIEW || echo PURGE)"
log "Regions: ${REGIONS_LIST}"

# Helpers
maybe_run() { if [[ "${PREVIEW}" == true ]]; then echo "PREVIEW: $*"; else eval "$*"; fi; }
count_or_preview() {
  local desc_cmd="$1" label="$2" region="$3"
  if out=$(eval "${desc_cmd}" 2>/dev/null); then
    local count
    count=$(jq -r 'paths(type=="array") as $p | if getpath($p) | type == "array" then getpath($p) | length else empty end' <<<"${out}" | sort -nr | head -n1)
    count=${count:-0}
    log "${region}: ${label} -> ${count}"
    echo "${out}"
  else
    log "${region}: ${label} -> 0 (or access error)"
    echo "{}"
  fi
}

delete_eks() {
  local region="$1"
  local clusters
  clusters=$(aws eks list-clusters --region "${region}" --query 'clusters' --output json 2>/dev/null || echo '[]')
  for name in $(jq -r '.[]' <<<"${clusters}"); do
    # Delete nodegroups
    local ngs fgs
    ngs=$(aws eks list-nodegroups --region "${region}" --cluster-name "${name}" --query 'nodegroups' --output json || echo '[]')
    for ng in $(jq -r '.[]' <<<"${ngs}"); do
      maybe_run aws eks delete-nodegroup --region "${region}" --cluster-name "${name}" --nodegroup-name "${ng}"
    done
    fgs=$(aws eks list-fargate-profiles --region "${region}" --cluster-name "${name}" --query 'fargateProfileNames' --output json || echo '[]')
    for fp in $(jq -r '.[]' <<<"${fgs}"); do
      maybe_run aws eks delete-fargate-profile --region "${region}" --cluster-name "${name}" --fargate-profile-name "${fp}"
    done
    maybe_run aws eks delete-cluster --region "${region}" --name "${name}"
  done
}

delete_ecs() {
  local region="$1"
  local clusters
  clusters=$(aws ecs list-clusters --region "${region}" --query 'clusterArns' --output json 2>/dev/null || echo '[]')
  for arn in $(jq -r '.[]' <<<"${clusters}"); do
    local services
    services=$(aws ecs list-services --region "${region}" --cluster "${arn}" --query 'serviceArns' --output json || echo '[]')
    for s in $(jq -r '.[]' <<<"${services}"); do
      maybe_run aws ecs update-service --region "${region}" --cluster "${arn}" --service "${s}" --desired-count 0 || true
      maybe_run aws ecs delete-service --region "${region}" --cluster "${arn}" --service "${s}" --force || true
    done
    maybe_run aws ecs delete-cluster --region "${region}" --cluster "${arn}" || true
  done
  # Deregister task definitions
  local tds
  tds=$(aws ecs list-task-definitions --region "${region}" --query 'taskDefinitionArns' --output json 2>/dev/null || echo '[]')
  for td in $(jq -r '.[]' <<<"${tds}"); do
    maybe_run aws ecs deregister-task-definition --region "${region}" --task-definition "${td}" || true
  done
}

delete_asg() {
  local region="$1"
  local groups
  groups=$(aws autoscaling describe-auto-scaling-groups --region "${region}" --query 'AutoScalingGroups[].AutoScalingGroupName' --output json 2>/dev/null || echo '[]')
  for g in $(jq -r '.[]' <<<"${groups}"); do
    maybe_run aws autoscaling update-auto-scaling-group --region "${region}" --auto-scaling-group-name "${g}" --min-size 0 --max-size 0 --desired-capacity 0 || true
    maybe_run aws autoscaling delete-auto-scaling-group --region "${region}" --auto-scaling-group-name "${g}" --force-delete || true
  done
  local lcs lts
  lcs=$(aws autoscaling describe-launch-configurations --region "${region}" --query 'LaunchConfigurations[].LaunchConfigurationName' --output json 2>/dev/null || echo '[]')
  for name in $(jq -r '.[]' <<<"${lcs}"); do
    maybe_run aws autoscaling delete-launch-configuration --region "${region}" --launch-configuration-name "${name}" || true
  done
  lts=$(aws ec2 describe-launch-templates --region "${region}" --query 'LaunchTemplates[].LaunchTemplateId' --output json 2>/dev/null || echo '[]')
  for id in $(jq -r '.[]' <<<"${lts}"); do
    maybe_run aws ec2 delete-launch-template --region "${region}" --launch-template-id "${id}" || true
  done
}

delete_elb() {
  local region="$1"
  # ALB/NLB
  local elbs
  elbs=$(aws elbv2 describe-load-balancers --region "${region}" --query 'LoadBalancers[].LoadBalancerArn' --output json 2>/dev/null || echo '[]')
  for arn in $(jq -r '.[]' <<<"${elbs}"); do
    maybe_run aws elbv2 delete-load-balancer --region "${region}" --load-balancer-arn "${arn}" || true
  done
  local tgs
  tgs=$(aws elbv2 describe-target-groups --region "${region}" --query 'TargetGroups[].TargetGroupArn' --output json 2>/dev/null || echo '[]')
  for t in $(jq -r '.[]' <<<"${tgs}"); do
    maybe_run aws elbv2 delete-target-group --region "${region}" --target-group-arn "${t}" || true
  done
  # Classic ELB
  local celbs
  celbs=$(aws elb describe-load-balancers --region "${region}" --query 'LoadBalancerDescriptions[].LoadBalancerName' --output json 2>/dev/null || echo '[]')
  for n in $(jq -r '.[]' <<<"${celbs}"); do
    maybe_run aws elb delete-load-balancer --region "${region}" --load-balancer-name "${n}" || true
  done
}

terminate_ec2() {
  local region="$1"
  local instances
  instances=$(aws ec2 describe-instances --region "${region}" --filters Name=instance-state-name,Values=pending,running,stopping,stopped --query 'Reservations[].Instances[].InstanceId' --output json 2>/dev/null || echo '[]')
  if [[ $(jq 'length' <<<"${instances}") -gt 0 ]]; then
    maybe_run aws ec2 terminate-instances --region "${region}" --instance-ids $(jq -r '.[]' <<<"${instances}") || true
  fi
  # EIPs
  local eips
  eips=$(aws ec2 describe-addresses --region "${region}" --query 'Addresses[].AllocationId' --output json 2>/dev/null || echo '[]')
  for a in $(jq -r '.[]' <<<"${eips}"); do
    maybe_run aws ec2 release-address --region "${region}" --allocation-id "${a}" || true
  done
  # Volumes (available)
  local vols
  vols=$(aws ec2 describe-volumes --region "${region}" --filters Name=status,Values=available --query 'Volumes[].VolumeId' --output json 2>/dev/null || echo '[]')
  for v in $(jq -r '.[]' <<<"${vols}"); do
    maybe_run aws ec2 delete-volume --region "${region}" --volume-id "${v}" || true
  done
  # AMIs
  local images
  images=$(aws ec2 describe-images --region "${region}" --owners self --query 'Images[].ImageId' --output json 2>/dev/null || echo '[]')
  for img in $(jq -r '.[]' <<<"${images}"); do
    maybe_run aws ec2 deregister-image --region "${region}" --image-id "${img}" || true
  done
  # Snapshots (self)
  local snaps
  snaps=$(aws ec2 describe-snapshots --region "${region}" --owner-ids self --query 'Snapshots[].SnapshotId' --output json 2>/dev/null || echo '[]')
  for s in $(jq -r '.[]' <<<"${snaps}"); do
    maybe_run aws ec2 delete-snapshot --region "${region}" --snapshot-id "${s}" || true
  done
}

delete_rds() {
  local region="$1"
  local dbs clusters
  dbs=$(aws rds describe-db-instances --region "${region}" --query 'DBInstances[].DBInstanceIdentifier' --output json 2>/dev/null || echo '[]')
  for db in $(jq -r '.[]' <<<"${dbs}"); do
    maybe_run aws rds delete-db-instance --region "${region}" --db-instance-identifier "${db}" --skip-final-snapshot || true
  done
  clusters=$(aws rds describe-db-clusters --region "${region}" --query 'DBClusters[].DBClusterIdentifier' --output json 2>/dev/null || echo '[]')
  for c in $(jq -r '.[]' <<<"${clusters}"); do
    maybe_run aws rds delete-db-cluster --region "${region}" --db-cluster-identifier "${c}" --skip-final-snapshot || true
  done
}

delete_dynamodb() {
  local region="$1"
  local tables
  tables=$(aws dynamodb list-tables --region "${region}" --query 'TableNames' --output json 2>/dev/null || echo '[]')
  for t in $(jq -r '.[]' <<<"${tables}"); do
    maybe_run aws dynamodb delete-table --region "${region}" --table-name "${t}" || true
  done
}

delete_ecr() {
  local region="$1"
  local repos
  repos=$(aws ecr describe-repositories --region "${region}" --query 'repositories[].repositoryName' --output json 2>/dev/null || echo '[]')
  for r in $(jq -r '.[]' <<<"${repos}"); do
    # Delete all images first
    local imageIds
    imageIds=$(aws ecr list-images --region "${region}" --repository-name "${r}" --query 'imageIds' --output json || echo '[]')
    if [[ $(jq 'length' <<<"${imageIds}") -gt 0 ]]; then
      if [[ "${PREVIEW}" == true ]]; then
        log "${region}: Would delete images in ECR repo ${r}"
      else
        aws ecr batch-delete-image --region "${region}" --repository-name "${r}" --image-ids "${imageIds}" >/dev/null || true
      fi
    fi
    maybe_run aws ecr delete-repository --region "${region}" --repository-name "${r}" --force || true
  done
}

delete_lambda() {
  local region="$1"
  local funcs layers
  funcs=$(aws lambda list-functions --region "${region}" --query 'Functions[].FunctionName' --output json 2>/dev/null || echo '[]')
  for f in $(jq -r '.[]' <<<"${funcs}"); do
    maybe_run aws lambda delete-function --region "${region}" --function-name "${f}" || true
  done
  layers=$(aws lambda list-layers --region "${region}" --query 'Layers[].LayerName' --output json 2>/dev/null || echo '[]')
  for l in $(jq -r '.[]' <<<"${layers}"); do
    # Delete latest 50 versions (best-effort)
    local vers
    vers=$(aws lambda list-layer-versions --region "${region}" --layer-name "${l}" --query 'LayerVersions[].Version' --output json || echo '[]')
    for v in $(jq -r '.[]' <<<"${vers}"); do
      maybe_run aws lambda delete-layer-version --region "${region}" --layer-name "${l}" --version-number "${v}" || true
    done
  done
}

delete_sqs_sns() {
  local region="$1"
  local qs tps
  qs=$(aws sqs list-queues --region "${region}" --query 'QueueUrls' --output json 2>/dev/null || echo '[]')
  for q in $(jq -r '.[]' <<<"${qs}"); do
    maybe_run aws sqs delete-queue --region "${region}" --queue-url "${q}" || true
  done
  tps=$(aws sns list-topics --region "${region}" --query 'Topics[].TopicArn' --output json 2>/dev/null || echo '[]')
  for t in $(jq -r '.[]' <<<"${tps}"); do
    maybe_run aws sns delete-topic --region "${region}" --topic-arn "${t}" || true
  done
}

delete_cloudwatch_logs() {
  local region="$1"
  local groups
  groups=$(aws logs describe-log-groups --region "${region}" --query 'logGroups[].logGroupName' --output json 2>/dev/null || echo '[]')
  for g in $(jq -r '.[]' <<<"${groups}"); do
    maybe_run aws logs delete-log-group --region "${region}" --log-group-name "${g}" || true
  done
}

delete_vpc_layer() {
  local region="$1"
  # NAT gateways
  for nat in $(aws ec2 describe-nat-gateways --region "${region}" --query 'NatGateways[].NatGatewayId' --output text 2>/dev/null || true); do
    [[ -n "$nat" ]] && maybe_run aws ec2 delete-nat-gateway --region "${region}" --nat-gateway-id "$nat" || true
  done
  # Wait for NAT gateways to disappear to avoid VPC dependency violations
  if [[ "${PREVIEW}" == false ]]; then
    local start now timeout states
    timeout=${NAT_DELETE_TIMEOUT:-600}
    start=$(date +%s)
    while :; do
      states=$(aws ec2 describe-nat-gateways --region "${region}" --query 'NatGateways[].State' --output text 2>/dev/null || true)
      if [[ -z "$states" ]] || ! grep -Eq 'pending|available|deleting' <<<"$states"; then
        log "${region}: NAT gateways removed (states: ${states:-none})."
        break
      fi
      now=$(date +%s)
      if (( now - start > timeout )); then
        log "${region}: NAT deletion wait timed out after ${timeout}s; continuing."
        break
      fi
      log "${region}: Waiting for NAT gateways to delete... (states: $states)"
      sleep 15
    done
  fi
  # VPC endpoints
  vpc_endpoints=$(aws ec2 describe-vpc-endpoints --region "${region}" --query 'VpcEndpoints[].VpcEndpointId' --output text 2>/dev/null || true)
  if [[ -n "${vpc_endpoints}" ]]; then
    maybe_run aws ec2 delete-vpc-endpoints --region "${region}" --vpc-endpoint-ids ${vpc_endpoints} || true
  fi
  # Load balancers already handled
  # Network interfaces (detached only)
  for eni in $(aws ec2 describe-network-interfaces --region "${region}" --query 'NetworkInterfaces[?Status==`available`].NetworkInterfaceId' --output text 2>/dev/null || true); do
    [[ -n "$eni" ]] && maybe_run aws ec2 delete-network-interface --region "${region}" --network-interface-id "$eni" || true
  done

  # VPCs teardown
  for vpc in $(aws ec2 describe-vpcs --region "${region}" --query 'Vpcs[].VpcId' --output text 2>/dev/null || true); do
    [[ -z "$vpc" ]] && continue
    # Skip default VPC by default
    local is_default
    is_default=$(aws ec2 describe-vpcs --region "${region}" --vpc-ids "$vpc" --query 'Vpcs[0].IsDefault' --output text)
    if [[ "$is_default" == "true" ]]; then continue; fi

    # Detach and delete IGWs (after NAT/EIP dependencies cleared)
    for igw in $(aws ec2 describe-internet-gateways --region "${region}" --filters Name=attachment.vpc-id,Values=$vpc --query 'InternetGateways[].InternetGatewayId' --output text); do
      maybe_run aws ec2 detach-internet-gateway --region "${region}" --internet-gateway-id "$igw" --vpc-id "$vpc" || true
      maybe_run aws ec2 delete-internet-gateway --region "${region}" --internet-gateway-id "$igw" || true
    done

    # Route tables (non-main)
    for rtb in $(aws ec2 describe-route-tables --region "${region}" --filters Name=vpc-id,Values=$vpc --query 'RouteTables[].{Id:RouteTableId,Assoc:Associations}' --output json | jq -r '.[] | select(.Assoc|map(select(.Main==true))|length==0) | .Id'); do
      # Disassociate any associations first
      for assoc in $(aws ec2 describe-route-tables --region "${region}" --route-table-ids "$rtb" --query 'RouteTables[0].Associations[].RouteTableAssociationId' --output text); do
        maybe_run aws ec2 disassociate-route-table --region "${region}" --association-id "$assoc" || true
      done
      maybe_run aws ec2 delete-route-table --region "${region}" --route-table-id "$rtb" || true
    done

    # NACLs (non-default)
    for acl in $(aws ec2 describe-network-acls --region "${region}" --filters Name=vpc-id,Values=$vpc --query 'NetworkAcls[?IsDefault==`false`].NetworkAclId' --output text); do
      maybe_run aws ec2 delete-network-acl --region "${region}" --network-acl-id "$acl" || true
    done

    # Security groups (non-default): revoke rules then delete to avoid dependencies
    for sg in $(aws ec2 describe-security-groups --region "${region}" --filters Name=vpc-id,Values=$vpc --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text); do
      # Revoke ingress (write JSON to temp file to avoid shell quoting issues)
      inperm=$(aws ec2 describe-security-groups --region "${region}" --group-ids "$sg" --query 'SecurityGroups[0].IpPermissions' --output json 2>/dev/null || echo '[]')
      if [[ $(jq 'length' <<<"${inperm}") -gt 0 ]]; then
        if [[ "${PREVIEW}" == true ]]; then
          log "${region}: Would revoke ingress rules for SG ${sg}"
        else
          tmp_in=$(mktemp)
          echo "${inperm}" > "$tmp_in"
          aws ec2 revoke-security-group-ingress --region "${region}" --group-id "$sg" --ip-permissions file://"$tmp_in" || true
          rm -f "$tmp_in"
        fi
      fi
      # Revoke egress
      outperm=$(aws ec2 describe-security-groups --region "${region}" --group-ids "$sg" --query 'SecurityGroups[0].IpPermissionsEgress' --output json 2>/dev/null || echo '[]')
      if [[ $(jq 'length' <<<"${outperm}") -gt 0 ]]; then
        if [[ "${PREVIEW}" == true ]]; then
          log "${region}: Would revoke egress rules for SG ${sg}"
        else
          tmp_out=$(mktemp)
          echo "${outperm}" > "$tmp_out"
          aws ec2 revoke-security-group-egress --region "${region}" --group-id "$sg" --ip-permissions file://"$tmp_out" || true
          rm -f "$tmp_out"
        fi
      fi
      maybe_run aws ec2 delete-security-group --region "${region}" --group-id "$sg" || true
    done

    # Subnets
    for subnet in $(aws ec2 describe-subnets --region "${region}" --filters Name=vpc-id,Values=$vpc --query 'Subnets[].SubnetId' --output text); do
      maybe_run aws ec2 delete-subnet --region "${region}" --subnet-id "$subnet" || true
    done

    # Finally VPC
    maybe_run aws ec2 delete-vpc --region "${region}" --vpc-id "$vpc" || true
  done
}

delete_api_gateway() {
  local region="$1"
  local rest ids
  rest=$(aws apigateway get-rest-apis --region "${region}" --query 'items[].id' --output json 2>/dev/null || echo '[]')
  for id in $(jq -r '.[]' <<<"${rest}"); do
    maybe_run aws apigateway delete-rest-api --region "${region}" --rest-api-id "$id" || true
  done
  ids=$(aws apigatewayv2 get-apis --region "${region}" --query 'Items[].ApiId' --output json 2>/dev/null || echo '[]')
  for id in $(jq -r '.[]' <<<"${ids}"); do
    maybe_run aws apigatewayv2 delete-api --region "${region}" --api-id "$id" || true
  done
}

delete_secrets() {
  local region="$1"
  local secrets
  secrets=$(aws secretsmanager list-secrets --region "${region}" --query 'SecretList[].ARN' --output json 2>/dev/null || echo '[]')
  for arn in $(jq -r '.[]' <<<"${secrets}"); do
    maybe_run aws secretsmanager delete-secret --region "${region}" --secret-id "$arn" --force-delete-without-recovery || true
  done
}

delete_s3_global() {
  # Buckets are global but reside in a region; optionally honor REGIONS filter
  local buckets
  buckets=$(aws s3api list-buckets --query 'Buckets[].Name' --output json 2>/dev/null || echo '[]')
  for b in $(jq -r '.[]' <<<"${buckets}"); do
    # Detect bucket region
    local loc region
    loc=$(aws s3api get-bucket-location --bucket "$b" --query 'LocationConstraint' --output text 2>/dev/null || echo 'us-east-1')
    region=${loc:-us-east-1}
    [[ "${region}" == "None" ]] && region="us-east-1"
    if [[ -n "${REGIONS:-}" ]]; then
      # Skip if bucket region not in filter
      if ! grep -qw "${region}" <<<"${REGIONS}"; then continue; fi
    fi
    if [[ "${PREVIEW}" == true ]]; then
      log "S3: Would empty and delete bucket ${b} (region ${region})"
      continue
    fi
    # Try to empty current versions first
    aws s3 rm "s3://${b}" --region "${region}" --recursive || true
    # If versioned, delete all versions and delete markers
    if ver=$(aws s3api get-bucket-versioning --bucket "$b" --query 'Status' --output text 2>/dev/null); then
      if [[ "$ver" == "Enabled" || "$ver" == "Suspended" ]]; then
        while :; do
          page=$(aws s3api list-object-versions --bucket "$b" --max-items 1000 2>/dev/null || echo '{}')
          versions=$(jq -c '{Objects: ((.Versions//[]) + (.DeleteMarkers//[])) | .[]? | {Key:.Key, VersionId:.VersionId}} | {Objects:[inputs]}' <<<"${page}" 2>/dev/null || echo '{}')
          # Build delete batch if any
          keys=$(echo "$page" | jq -r '[(.Versions//[])[], (.DeleteMarkers//[])[]] | length')
          if [[ "${keys}" == "0" || -z "${keys}" ]]; then break; fi
          aws s3api delete-objects --bucket "$b" --delete "$(echo "$page" | jq '{Objects: ((.Versions//[]) + (.DeleteMarkers//[]) | map({Key:.Key,VersionId:.VersionId}))}')" >/dev/null || true
        done
      fi
    fi
    # Finally remove bucket
    aws s3api delete-bucket --bucket "$b" --region "${region}" || true
  done
}

summary_preview_region() {
  local region="$1"
  log "---- Preview in ${region} ----"
  aws eks list-clusters --region "${region}" --query 'clusters' --output json 2>/dev/null | jq -r '"EKS clusters: \(.|length)"' || true
  aws ecs list-clusters --region "${region}" --query 'clusterArns' --output json 2>/dev/null | jq -r '"ECS clusters: \(.|length)"' || true
  aws elbv2 describe-load-balancers --region "${region}" --query 'LoadBalancers' --output json 2>/dev/null | jq -r '"ELBv2: \(.|length)"' || true
  aws elb describe-load-balancers --region "${region}" --query 'LoadBalancerDescriptions' --output json 2>/dev/null | jq -r '"Classic ELB: \(.|length)"' || true
  aws ec2 describe-instances --region "${region}" --filters Name=instance-state-name,Values=pending,running,stopping,stopped --query 'Reservations[].Instances' --output json 2>/dev/null | jq -r 'flatten | "EC2 instances: \(.|length)"' || true
  aws ec2 describe-nat-gateways --region "${region}" --query 'NatGateways[?State!=`deleted`]' --output json 2>/dev/null | jq -r '"NAT gateways: \(.|length)"' || true
  aws rds describe-db-instances --region "${region}" --query 'DBInstances' --output json 2>/dev/null | jq -r '"RDS instances: \(.|length)"' || true
  aws rds describe-db-clusters --region "${region}" --query 'DBClusters' --output json 2>/dev/null | jq -r '"RDS clusters: \(.|length)"' || true
  aws dynamodb list-tables --region "${region}" --query 'TableNames' --output json 2>/dev/null | jq -r '"DynamoDB tables: \(.|length)"' || true
  aws ecr describe-repositories --region "${region}" --query 'repositories' --output json 2>/dev/null | jq -r '"ECR repos: \(.|length)"' || true
  aws lambda list-functions --region "${region}" --query 'Functions' --output json 2>/dev/null | jq -r '"Lambda functions: \(.|length)"' || true
  aws logs describe-log-groups --region "${region}" --query 'logGroups' --output json 2>/dev/null | jq -r '"Log groups: \(.|length)"' || true
  aws sqs list-queues --region "${region}" --query 'QueueUrls' --output json 2>/dev/null | jq -r '"SQS queues: \(.|length)"' || true
  aws sns list-topics --region "${region}" --query 'Topics' --output json 2>/dev/null | jq -r '"SNS topics: \(.|length)"' || true
}

# MAIN
if [[ "${PREVIEW}" == true ]]; then
  log "Previewing resources slated for deletion in account ${ACCOUNT_ID}"
  for r in ${REGIONS_LIST}; do
    summary_preview_region "$r"
  done
  # S3 preview
  log "S3 buckets (global):"
  aws s3api list-buckets --query 'Buckets[].Name' --output json 2>/dev/null | jq -r '. | length as $n | "Buckets: "+($n|tostring)'
  exit 0
fi

log "Starting purge in account ${ACCOUNT_ID}"
for r in ${REGIONS_LIST}; do
  log "--- Region ${r} ---"
  delete_eks "$r"
  delete_ecs "$r"
  delete_asg "$r"
  delete_elb "$r"
  terminate_ec2 "$r"
  delete_rds "$r"
  delete_dynamodb "$r"
  delete_ecr "$r"
  delete_lambda "$r"
  delete_api_gateway "$r"
  delete_sqs_sns "$r"
  delete_cloudwatch_logs "$r"
  delete_secrets "$r"
  delete_vpc_layer "$r"
done

delete_s3_global

log "Purge submitted. Some deletions are asynchronous and may take minutes to complete. Re-run with --preview to confirm zero resources remain."
