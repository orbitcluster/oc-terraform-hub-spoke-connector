################################################################################
# ESO Hub ECR Role update - Trust Policy
# Update the Trust Policy of the existing ESO ECR Hub Role to include the spoke roles
################################################################################

locals {
  # The role name in the spoke clusters is standard
  spoke_eso_role_name = "eso-spoke-ecr-role"

  # Construct the spoke Role ARNs by extracting the AWS Account ID from the provided argocd_role_arn
  # ARN format: arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME
  spoke_eso_role_arns = [
    for k, v in var.spoke_clusters : "arn:${data.aws_partition.current.partition}:iam::${split(":", v.argocd_role_arn)[4]}:role/${local.spoke_eso_role_name}"
  ]

  # The role name in the hub cluster
  hub_eso_role_name = "ecr-hub-role"
}

data "aws_partition" "current" {}
data "aws_region" "current" {}

# 1. Fetch the existing role
data "aws_iam_role" "hub_eso_ecr_role" {
  count = length(local.spoke_eso_role_arns) > 0 ? 1 : 0
  name  = local.hub_eso_role_name
}

# 2. Build the new trust policy document including the spoke roles
data "aws_iam_policy_document" "hub_eso_trust_policy" {
  count = length(local.spoke_eso_role_arns) > 0 ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = local.spoke_eso_role_arns
    }
  }
}

# 3. Update the assume role policy using local-exec (since the role is managed by another repo/module)
resource "null_resource" "update_hub_eso_trust_policy" {
  count = length(local.spoke_eso_role_arns) > 0 ? 1 : 0

  triggers = {
    # Re-run if the spoke roles change
    policy_hash = md5(data.aws_iam_policy_document.hub_eso_trust_policy[0].json)
  }

  provisioner "local-exec" {
    command = <<EOT
      aws iam update-assume-role-policy \
        --role-name ${local.hub_eso_role_name} \
        --policy-document '${data.aws_iam_policy_document.hub_eso_trust_policy[0].json}' \
        --region ${data.aws_region.current.name} \
        --no-cli-pager
    EOT
  }
}
