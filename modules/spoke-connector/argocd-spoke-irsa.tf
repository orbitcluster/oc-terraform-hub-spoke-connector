################################################################################
# ArgoCD Spoke Access IRSA
# Self-contained IAM role, policy, and service account for spoke cluster access
# This approach creates everything needed without modifying existing ArgoCD setup
################################################################################

# Get current AWS caller identity
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Local for constructing OIDC provider
locals {
  # Extract OIDC provider from the OIDC issuer URL
  oidc_provider = replace(var.cluster_oidc_issuer_url, "https://", "")

  # Spoke cluster role ARNs
  spoke_role_arns = [for k, v in var.spoke_clusters : v.argocd_role_arn]

  # Service account name
  spoke_sa_name = "argocd-spoke-controller"
}

################################################################################
# IAM Role for ArgoCD Spoke Access (IRSA)
################################################################################

resource "aws_iam_role" "argocd_spoke_access" {
  count = length(local.spoke_role_arns) > 0 ? 1 : 0

  name = "${var.hub_cluster_name}-argocd-spoke-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_provider}"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider}:sub" = "system:serviceaccount:${local.argocd_namespace}:${local.spoke_sa_name}"
          "${local.oidc_provider}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    Name      = "${var.hub_cluster_name}-argocd-spoke-access"
    Purpose   = "ArgoCD spoke cluster access via IRSA"
    ManagedBy = "terraform-hub-spoke-connector"
  }
}

################################################################################
# IAM Policy - Assume Spoke Cluster Roles
################################################################################

resource "aws_iam_policy" "argocd_assume_spokes" {
  count = length(local.spoke_role_arns) > 0 ? 1 : 0

  name        = "${var.hub_cluster_name}-argocd-assume-spokes"
  description = "Allows ArgoCD to assume IAM roles in spoke clusters"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AssumeSpokeClusters"
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = local.spoke_role_arns
    }]
  })

  tags = {
    Name      = "${var.hub_cluster_name}-argocd-assume-spokes"
    ManagedBy = "terraform-hub-spoke-connector"
  }
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "argocd_assume_spokes" {
  count = length(local.spoke_role_arns) > 0 ? 1 : 0

  role       = aws_iam_role.argocd_spoke_access[0].name
  policy_arn = aws_iam_policy.argocd_assume_spokes[0].arn
}

################################################################################
# IAM Policy - EKS Describe (needed for AWS auth)
################################################################################

resource "aws_iam_policy" "argocd_eks_describe" {
  count = length(local.spoke_role_arns) > 0 ? 1 : 0

  name        = "${var.hub_cluster_name}-argocd-eks-describe"
  description = "Allows ArgoCD to describe EKS clusters"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid = "DescribeEKS"
      # checkov:skip=CKV_AWS_355:Temporarily ignoring wildcards for EKS describe
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster"]
      Resource = "*"
    }]
  })

  tags = {
    Name      = "${var.hub_cluster_name}-argocd-eks-describe"
    ManagedBy = "terraform-hub-spoke-connector"
  }
}

resource "aws_iam_role_policy_attachment" "argocd_eks_describe" {
  count = length(local.spoke_role_arns) > 0 ? 1 : 0

  role       = aws_iam_role.argocd_spoke_access[0].name
  policy_arn = aws_iam_policy.argocd_eks_describe[0].arn
}

################################################################################
# Kubernetes Service Account with IRSA Annotation
################################################################################

resource "kubernetes_service_account_v1" "argocd_spoke_controller" {
  count = length(local.spoke_role_arns) > 0 ? 1 : 0

  metadata {
    name      = local.spoke_sa_name
    namespace = local.argocd_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.argocd_spoke_access[0].arn
    }
    labels = {
      "app.kubernetes.io/part-of"    = "argocd"
      "app.kubernetes.io/component"  = "spoke-controller"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

################################################################################
# Patch ArgoCD Application Controller to use new Service Account
################################################################################

resource "kubectl_manifest" "patch_argocd_controller" {
  count = length(local.spoke_role_arns) > 0 ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name      = "argocd-application-controller"
      namespace = local.argocd_namespace
    }
    spec = {
      template = {
        spec = {
          serviceAccountName = local.spoke_sa_name
        }
      }
    }
  })

  force_conflicts   = true
  server_side_apply = true

  depends_on = [kubernetes_service_account_v1.argocd_spoke_controller]
}
