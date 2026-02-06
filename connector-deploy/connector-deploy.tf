################################################################################
# Spoke Connector Deployment Configuration
# This is deployed to the Hub cluster after ArgoCD is installed
################################################################################

# Get Hub cluster info from EKS infra remote state
data "terraform_remote_state" "hub_infra" {
  backend = "s3"
  config = {
    bucket = var.hub_bucket_name
    key    = "${var.master_s3_directory}/eks_infra/terraform.tfstate"
    region = var.region
  }
}

# Get custom addons state for ArgoCD policy ARN
data "terraform_remote_state" "hub_custom_addons" {
  backend = "s3"
  config = {
    bucket = var.hub_bucket_name
    key    = "${var.master_s3_directory}/eks_custom_addons/terraform.tfstate"
    region = var.region
  }
}

module "spoke_connector" {
  source = "../modules/spoke-connector"

  # GitHub configuration for SCM Provider
  github_pat       = var.github_pat
  github_org       = var.github_org
  github_app_topic = var.github_app_topic

  # ArgoCD policy for dynamic spoke ARN updates
  argocd_assume_spoke_policy_arn = data.terraform_remote_state.hub_custom_addons.outputs.argocd_assume_spoke_policy_arn

  # Spoke clusters to register
  spoke_clusters = var.spoke_clusters
}
