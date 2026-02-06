################################################################################
# Spoke Policy Update
# Dynamically adds spoke cluster role ARNs to the hub's ArgoCD assume-spoke policy
# This allows ArgoCD to assume the spoke cluster roles
################################################################################

# Get the current policy document
data "aws_iam_policy" "argocd_assume_spoke" {
  arn = var.argocd_assume_spoke_policy_arn
}

# Parse the current policy to get existing resources
locals {
  current_policy = jsondecode(data.aws_iam_policy.argocd_assume_spoke.policy)
  
  # Get existing spoke ARNs from the policy (handle empty/null)
  existing_spoke_arns = try(
    local.current_policy.Statement[0].Resource != "*" ? 
      (can(tolist(local.current_policy.Statement[0].Resource)) ? 
        tolist(local.current_policy.Statement[0].Resource) : 
        [local.current_policy.Statement[0].Resource]) : 
      [],
    []
  )
  
  # New spoke ARNs from registered clusters
  new_spoke_arns = [for k, v in var.spoke_clusters : v.argocd_role_arn]
  
  # Merge existing and new, remove duplicates
  merged_spoke_arns = distinct(concat(local.existing_spoke_arns, local.new_spoke_arns))
}

# Create a new version of the policy with updated spoke ARNs
resource "aws_iam_policy" "argocd_assume_spoke_updated" {
  count = length(local.new_spoke_arns) > 0 ? 1 : 0

  name        = data.aws_iam_policy.argocd_assume_spoke.name
  description = "Allows ArgoCD to assume IAM roles in spoke clusters"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AssumeSpokeClusters"
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = local.merged_spoke_arns
    }]
  })

  lifecycle {
    create_before_destroy = true
  }
}
