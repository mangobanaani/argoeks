# Karpenter Autoscaling

What is installed
- Karpenter controller via Helm in `karpenter` namespace with IRSA.
- Node IAM role + instance profile (EKS worker, CNI, ECR RO, SSM).
- Default `EC2NodeClass` + `NodePool` with spot/on‑demand, amd64/arm64, consolidation.

Discovery
- VPC subnets and cluster security group are tagged `karpenter.sh/discovery=<cluster>` by Terraform.

Customize
- Add/modify NodePools via GitOps (CRDs). Common examples:
  - Dedicated GPU pool: add `requirements` for `nvidia.com/gpu` and instance types.
  - Arm‑preferred savings: set `kubernetes.io/arch=arm64` and `capacity-type=spot`.
- To pin AMI family or add EBS defaults, edit the `EC2NodeClass` or add new ones.

Tips
- Keep a tiny managed node group for system workloads; Karpenter handles the rest.
- Use taints/affinity on critical add‑ons to control placement.
