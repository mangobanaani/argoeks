#!/usr/bin/env bash
set -euo pipefail

# AWS cost report script for ArgoEKS
# Generates cost breakdown by environment, service, and tags

START_DATE="${1:-$(date -v-1m +%Y-%m-01)}"  # First day of last month
END_DATE="${2:-$(date +%Y-%m-%d)}"          # Today
GRANULARITY="${3:-MONTHLY}"

echo "===================================="
echo "ArgoEKS Cost Report"
echo "Period: $START_DATE to $END_DATE"
echo "Granularity: $GRANULARITY"
echo "===================================="
echo

# Cost by environment tag
echo "[1/5] Cost by Environment..."
aws ce get-cost-and-usage \
  --time-period Start="$START_DATE",End="$END_DATE" \
  --granularity "$GRANULARITY" \
  --metrics UnblendedCost \
  --group-by Type=TAG,Key=Environment \
  --output table
echo

# Cost by service
echo "[2/5] Cost by Service..."
aws ce get-cost-and-usage \
  --time-period Start="$START_DATE",End="$END_DATE" \
  --granularity "$GRANULARITY" \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --output table
echo

# Cost by project tag
echo "[3/5] Cost by Project..."
aws ce get-cost-and-usage \
  --time-period Start="$START_DATE",End="$END_DATE" \
  --granularity "$GRANULARITY" \
  --metrics UnblendedCost \
  --group-by Type=TAG,Key=Project \
  --output table
echo

# EKS-specific costs
echo "[4/5] EKS-specific Costs..."
aws ce get-cost-and-usage \
  --time-period Start="$START_DATE",End="$END_DATE" \
  --granularity "$GRANULARITY" \
  --metrics UnblendedCost \
  --filter file://<(cat <<EOF
{
  "Dimensions": {
    "Key": "SERVICE",
    "Values": ["Amazon Elastic Kubernetes Service", "Amazon EC2 Container Registry", "Amazon Elastic Compute Cloud - Compute"]
  }
}
EOF
) \
  --output table
echo

# Total cost
echo "[5/5] Total Cost..."
aws ce get-cost-and-usage \
  --time-period Start="$START_DATE",End="$END_DATE" \
  --granularity "$GRANULARITY" \
  --metrics UnblendedCost \
  --query 'ResultsByTime[0].Total.UnblendedCost' \
  --output table
echo

echo "===================================="
echo "For detailed analysis, visit AWS Cost Explorer:"
echo "https://console.aws.amazon.com/cost-management/home#/cost-explorer"
echo "===================================="
