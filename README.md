# oc-terraform-hub-spoke-connector

Reusable Terraform module for connecting ArgoCD hub cluster with spoke EKS clusters. Manages cluster registration, IRSA setup, and ApplicationSets for GitOps deployments.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CALLING REPO (per org)                            │
│  oc-terraform-connector-config/                                             │
│  ├── .github/workflows/ci.yml    # Calls reusable workflow                  │
│  └── connector.tfvars            # Spoke cluster configuration              │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      THIS MODULE (reusable)                                 │
│  oc-terraform-hub-spoke-connector/                                          │
│  ├── .github/                                                               │
│  │   ├── workflows/main.yml         # Reusable workflow_call                │
│  │   └── actions/                   # Composite actions                     │
│  ├── connector-deploy/              # Deployment component                  │
│  │   ├── backend.tf                 # S3 backend (dynamic)                  │
│  │   ├── provider.tf                # AWS/K8s/kubectl providers             │
│  │   ├── connector-deploy.tf        # Module invocation                     │
│  │   └── variables.tf               # Input variables                       │
│  └── modules/spoke-connector/       # Core module                           │
│      ├── argocd-spoke-irsa.tf       # IRSA: role, policies, SA, patch       │
│      ├── spoke-registration.tf      # ArgoCD cluster secrets                │
│      ├── github-secret.tf           # GitHub PAT secret                     │
│      ├── appsets.tf                 # ApplicationSet resources              │
│      └── yamls/                     # AppSet YAML templates                 │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           HUB CLUSTER                                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ IRSA Role +  │  │   Cluster    │  │   GitHub     │  │ Application  │     │
│  │ Service Acct │  │   Secrets    │  │   Secret     │  │    Sets      │     │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────────────────────┘
          │                   │
          ▼                   ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│   Dev Spoke      │  │  Staging Spoke   │  │   Prod Spoke     │
│   Cluster        │  │    Cluster       │  │   Cluster        │
└──────────────────┘  └──────────────────┘  └──────────────────┘
```

## Execution Flow

```
1. IRSA Setup        → Create IAM role, policies, K8s SA, patch ArgoCD deployment
2. Cluster Secrets   → Create ArgoCD cluster secrets (one per spoke)
3. GitHub Secret     → Store PAT for SCM provider
4. ApplicationSets   → Deploy SCM/Environment/PR/Custom appsets
```

## Features

| Feature | Description |
|---------|-------------|
| **Self-Contained IRSA** | Creates IAM role + policies + K8s SA, patches ArgoCD controller |
| **Spoke Registration** | ArgoCD cluster secrets with AWS auth config |
| **SCM Provider AppSet** | Auto-discovers repos with GitHub topic |
| **Environment AppSets** | Separate deployments for dev/staging/prod |
| **PR Previews** | Ephemeral environments on dev cluster |
| **Prod Approvals** | Production requires manual sync (no auto-sync) |
| **Custom AppSets** | Support for user-provided ApplicationSet YAML |

## Usage

### 1. Create a config repository (e.g., `oc-terraform-connector-config`)

**`.github/workflows/ci.yml`:**
```yaml
name: "connector-ci"
on:
  workflow_dispatch:
  push:
    branches: [main]
    paths: ["**.tfvars"]

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

# GitHub Configuration
github_org       = "orbitcluster"
github_app_topic = "orbit-deploy"

# ApplicationSet toggles (all default to true)
enable_scm_appset          = true
enable_environment_appsets = true
enable_pr_preview_appset   = true

# Spoke Clusters
spoke_clusters = {
  "dev-spoke" = {
    cluster_name    = "BU12345-DEV001-eks"
    server          = "https://XXXXXXXXXX.gr7.us-east-1.eks.amazonaws.com"
    ca_data         = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t..."
    env             = "dev"
    argocd_role_arn = "arn:aws:iam::123456789012:role/argocd-spoke-access"
  }

  "staging-spoke" = {
    cluster_name    = "BU12345-STAGE001-eks"
    server          = "https://YYYYYYYYYY.gr7.us-east-1.eks.amazonaws.com"
    ca_data         = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t..."
    env             = "staging"
    argocd_role_arn = "arn:aws:iam::123456789012:role/argocd-spoke-access"
  }

  "prod-spoke" = {
    cluster_name    = "BU12345-PROD001-eks"
    server          = "https://ZZZZZZZZZZ.gr7.us-east-1.eks.amazonaws.com"
    ca_data         = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t..."
    env             = "prod"
    argocd_role_arn = "arn:aws:iam::123456789012:role/argocd-spoke-access"
  }
}

# Optional: Custom ApplicationSets
# custom_appsets = {
#   "my-custom-appset" = {
#     yaml_content = file("custom-appsets/my-appset.yaml")
#   }
# }
```

### 2. Set GitHub Secrets

| Secret | Description |
|--------|-------------|
| `OC_ROLE_TO_ASSUME` | AWS IAM role ARN for GitHub Actions |
| `OC_PAT_SCM` | GitHub PAT with `repo` scope for SCM Provider |

## Variables Reference

### Required (from calling repo)

| Variable | Description |
|----------|-------------|
| `hub_bucket_name` | S3 bucket for hub cluster Terraform state |
| `master_s3_directory` | S3 prefix for hub state files |
| `github_pat` | GitHub PAT for SCM Provider (via secret) |
| `spoke_clusters` | Map of spoke cluster configurations |

### Spoke Cluster Object

```hcl
{
  cluster_name    = string  # EKS cluster name
  server          = string  # API server endpoint
  ca_data         = string  # Base64 encoded CA certificate
  env             = string  # Environment: "dev", "staging", or "prod"
  argocd_role_arn = string  # IAM role ARN that ArgoCD will assume
}
```

### Optional

| Variable | Default | Description |
|----------|---------|-------------|
| `github_org` | `orbitcluster` | GitHub organization |
| `github_app_topic` | `orbit-deploy` | Topic to filter repos |
| `enable_scm_appset` | `true` | Enable discovery AppSet |
| `enable_environment_appsets` | `true` | Enable env-specific AppSets |
| `enable_pr_preview_appset` | `true` | Enable PR preview AppSet |
| `custom_appsets` | `{}` | Map of custom AppSet YAML |

## Outputs

| Output | Description |
|--------|-------------|
| `registered_clusters` | List of registered cluster names |
| `cluster_secrets` | Map of cluster → secret name |
| `github_token_secret_name` | GitHub token secret name |
| `argocd_spoke_role_arn` | IRSA role ARN created for spoke access |
| `argocd_spoke_service_account` | K8s ServiceAccount name |

## ApplicationSets Created

| AppSet Name | Generator | Sync Policy | Target |
|-------------|-----------|-------------|--------|
| `orbit-apps-discovery` | SCM Provider | Manual | Hub cluster |
| `orbit-apps-dev` | Matrix (clusters × repos) | Auto | dev clusters |
| `orbit-apps-staging` | Matrix (clusters × repos) | Auto | staging clusters |
| `orbit-apps-prod` | Matrix (clusters × repos) | **Manual** | prod clusters |
| `orbit-apps-pr-preview` | Matrix + SCM | Auto | dev clusters |

## Application Requirements

Applications discovered by the SCM Provider must have:

1. **GitHub topic**: `orbit-deploy` (or your custom topic)
2. **Helm chart**: `helm/Chart.yaml` in repository root
3. **Values files**:
   - `helm/values.yaml` (base values)
   - `helm/values-dev.yaml` (dev environment)
   - `helm/values-staging.yaml` (staging environment)
   - `helm/values-prod.yaml` (production environment)

## Spoke Cluster Requirements

Each spoke cluster needs an IAM role that allows the hub's ArgoCD to assume it. This role is **automatically created** when deploying spoke clusters with `oc-terraform-module-custom-addons` (when `is_hub = false`).

### Automatic Setup (Recommended)

When deploying a spoke cluster, set the following in your tfvars:

```hcl
is_hub           = false
hub_cluster_name = "allhub-BU12345-APP67890-eks"  # Your hub cluster name
hub_account_id   = ""                              # Optional: defaults to current account
```

The module creates:
- **IAM Role**: `${cluster_name}-argocd-hub-assumable`
- **Trust Policy**: Allows `${hub_cluster_name}-argocd-spoke-access` to assume
- **Permissions**: `eks:DescribeCluster` for K8s authentication

**Output**: Use `argocd_spoke_role_arn` output as the `argocd_role_arn` in connector config.

### Manual Setup (Alternative)

If not using the custom-addons module, create a role with this trust policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "AWS": "arn:aws:iam::HUB_ACCOUNT:role/HUB_CLUSTER-argocd-spoke-access"
    },
    "Action": "sts:AssumeRole"
  }]
}
```


## License

MIT
<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

No providers.

## Modules

No modules.

## Resources

No resources.

## Inputs

No inputs.

## Outputs

No outputs.
<!-- END_TF_DOCS -->
