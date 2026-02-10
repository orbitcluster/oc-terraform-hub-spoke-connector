################################################################################
# ArgoCD Spoke Access Configuration
# Configures the existing Hub Role (from custom-addons) with spoke-specific policies
################################################################################

locals {
  # Spoke cluster role ARNs to be added to the policy
  spoke_role_arns = [for k, v in var.spoke_clusters : v.argocd_role_arn]

  # Name of the role created by custom-addons
  hub_role_name = "${var.hub_cluster_name}-argocd-spoke-access"
}

# 1. Lookup Existing Role
data "aws_iam_role" "argocd_hub_role" {
  count = length(local.spoke_role_arns) > 0 ? 1 : 0
  name  = local.hub_role_name
}

# 2. Scoped Policy (Assume Spoke Roles)
# Even though the role has a wildcard policy (from custom-addons),
# this policy explicitly lists the managed spoke ARNs for documentation/audit.
resource "aws_iam_policy" "argocd_assume_spokes" {
  count = length(local.spoke_role_arns) > 0 ? 1 : 0

  name        = "${var.hub_cluster_name}-argocd-assume-spokes"
  description = "Allows ArgoCD to assume IAM roles in spoke clusters (Explicit List)"

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

# 3. Attach Scoped Policy to Existing Role
resource "aws_iam_role_policy_attachment" "argocd_assume_spokes" {
  count = length(local.spoke_role_arns) > 0 ? 1 : 0

  role       = data.aws_iam_role.argocd_hub_role[0].name
  policy_arn = aws_iam_policy.argocd_assume_spokes[0].arn
}

# Note: Service Account and IRSA mapping are now handled by custom-addons + ArgoCD chart.
# This module assumes the role uses the default 'argocd-application-controller' SA.
