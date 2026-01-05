# ArgoEKS Documentation

Comprehensive documentation for the ArgoEKS platform.

## Quick Navigation

### Getting Started
- [Quick Start Guide](getting-started/quickstart.md) - Get up and running in 15 minutes
- [Architecture Overview](architecture.md) - System architecture and design principles
- [Configuration Reference](config-reference.md) - Platform configuration options

### Architecture
- [System Architecture](architecture.md) - High-level architecture
- [MLOps Stack Design](architecture/mlops-gap-analysis.md) - MLOps capabilities and gaps
- [Implementation Roadmap](architecture/roadmap.md) - Development roadmap
- [Agent System](architecture/agents.md) - CI/CD agents and automation

### Infrastructure
- [Cilium CNI Benefits](cilium-benefits.md) - Why full Cilium CNI
- [Karpenter Node Provisioning](karpenter.md) - Just-in-time compute
- [Compute Options & CNI Compatibility](compute-cni-compatibility.md)
- [Multi-Region Deployment](multi-region.md) - Multi-region HA setup

### Platform Components

#### GitOps
- [GitOps Overview](gitops.md) - ArgoCD and Flux integration
- [Feature Flags](features-flags.md) - Environment feature toggles

#### Observability
- [Observability Stack](observability.md) - Prometheus, Grafana, Alertmanager
- [Alarms and Alerting](alarms.md) - Alert configuration and management

#### Security
- [Security Overview](security.md) - Security features and controls
- [PCI-DSS Compliance](pci-dss-mapping.md) - Compliance mapping

#### CI/CD
- [Pipeline Overview](readme-pipelines.md) - GitHub Actions & GitLab CI
- [CI/CD Pipelines](ci-cd-pipelines.md) - Complete pipeline reference
- [Deployment Guide](.github/deployment-guide.md) - Deployment procedures
- [Pipeline Architecture](.github/pipeline-architecture.md) - Design patterns
- [Implementation Checklist](implementation-checklist.md) - Setup steps

### MLOps
- [MLOps Implementation Guide](mlops-implementation-guide.md) - Complete MLOps stack deployment
- [Optional Modules Guide](optional-modules-guide.md) - Optional platform components

### Operations
- [Operations Runbook](operations-runbook.md) - Day-2 operations guide
- [Disaster Recovery Runbook](disaster-recovery-runbook.md) - DR procedures and recovery
- [Multi-Account Setup](runbooks/multi-account.md) - Cross-account deployment

### Cost Management
- [Cost Allocation Tags](cost-allocation-tags.md) - AWS cost tracking and optimization

### Advanced Topics
- [Serverless and Edge](serverless-edge.md) - Lambda and CloudFront integration
- [Kubernetes Improvements](kubernetes-improvements.md)
- [Stack Optimization](stack-optimization.md)
- [Cloud Architecture Review](cloud-architecture-review.md)

### Reference
- [Terraform Versions](terraform-versions.md) - Terraform and provider versions
- [Karpenter Compatibility](karpenter-compatibility.md)
- [Implementation Summary](implementation-summary.md)
- [Implementation Status](implementation-status.md)

## Documentation Structure

```
docs/
├── README.md                    # This file
├── getting-started/            # Quick start guides
│   └── quickstart.md
├── architecture/               # Architecture docs
│   ├── mlops-gap-analysis.md
│   ├── roadmap.md
│   └── agents.md
└── runbooks/                   # Operational procedures
    └── multi-account.md
```

## Contributing to Documentation

### Standards
- Use Markdown format
- Include Mermaid diagrams where helpful
- Keep code examples up-to-date
- Link to related docs

### File Naming
- Use lowercase with hyphens: `my-document.md`
- Use descriptive names

### Content Guidelines
- Start with overview/purpose
- Include examples
- Provide troubleshooting sections
- Keep it concise

## External Resources

### Cilium
- [Cilium Documentation](https://docs.cilium.io/)
- [Cilium AWS ENI Mode](https://docs.cilium.io/en/stable/network/concepts/ipam/eni/)

### Karpenter
- [Karpenter Documentation](https://karpenter.sh/)
- [Karpenter Best Practices](https://aws.github.io/aws-eks-best-practices/karpenter/)

### ArgoCD
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ApplicationSet Controller](https://argocd-applicationset.readthedocs.io/)

### Flux
- [Flux Documentation](https://fluxcd.io/docs/)
- [Flux Kustomize Guide](https://fluxcd.io/docs/components/kustomize/)

### AWS EKS
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
