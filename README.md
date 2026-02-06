# oc-terraform-hub-spoke-connector

Reusable Terraform module for connecting ArgoCD hub cluster with spoke EKS clusters. Manages cluster registration and ApplicationSets for GitOps deployments.

## Architecture

This module follows the same pattern as `oc-terraform-module-eks-setup`:

```
oc-terraform-hub-spoke-connector/       # Reusable module (this repo)
├── .github/
│   ├── workflows/main.yml              # Reusable workflow_call
│   └── actions/                        # Composite actions
├── modules/spoke-connector/            # Core module
│   ├── spoke-registration.tf           # ArgoCD cluster secrets
│   ├── appsets.tf                      # ApplicationSet templates
│   └── yamls/                          # YAML templates
└── connector-deploy/                   # Deploy component

oc-terraform-connector-config/          # Calling repo (create this)
├── .github/workflows/ci.yml            # Calls main.yml
└── connector.tfvars                    # Your spoke cluster config
```

## Usage

### 1. Create a config repository (e.g., `oc-terraform-connector-config`)

**`.github/workflows/ci.yml`:**
```yaml
name: "connector-ci"
on:
  workflow_dispatch:

permissions:
  contents: read
  id-token: write
  issues: write

jobs:
  connector-ci:
    uses: "orbitcluster/oc-terraform-hub-spoke-connector/.github/workflows/main.yml@v1.0.0"
    with:
      tfvar_file_path: "connector.tfvars"
      bucket_name: "oc-backend-hub"
      approvers: "dilipsamanta, mav-sk"
      master_s3_directory: "oc-eks-hub"
      module_ref: "v1.0.0"
    secrets: inherit
```

**`connector.tfvars`:**
```hcl
region              = "us-east-1"
hub_bucket_name     = "oc-backend-hub"
master_s3_directory = "oc-eks-hub"

github_org       = "orbitcluster"
github_app_topic = "orbit-deploy"

spoke_clusters = {
  "spoke-dev" = {
    cluster_name    = "BU12345-SPOKE001-eks"
    server          = "https://xxxxx.gr7.us-east-1.eks.amazonaws.com"
    ca_data         = "LS0tLS1CRUdJTi..."
    env             = "dev"
    argocd_role_arn = "arn:aws:iam::123456789:role/argocd-spoke-access"
  }
}
```

### 2. Set GitHub Secrets

| Secret | Description |
|--------|-------------|
| `OC_ROLE_TO_ASSUME` | AWS IAM role ARN for GitHub Actions |
| `GITHUB_PAT_SCM` | GitHub PAT with `repo` scope for SCM Provider |

## Features

- **Spoke Cluster Registration** - Creates ArgoCD cluster secrets
- **SCM Provider ApplicationSet** - Auto-discovers repos with topic
- **Environment Deployments** - Separate ApplicationSets for dev/staging/prod
- **PR Previews** - Ephemeral environments on dev cluster
- **Prod Approvals** - Production requires manual sync

## Application Requirements

Applications must have:
1. GitHub topic: `orbit-deploy`
2. `helm/Chart.yaml` in repository root
3. `helm/values.yaml` (base values)
4. `helm/values-{env}.yaml` (environment-specific)

## License

MIT