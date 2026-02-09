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

module "spoke_connector" {
  source = "../modules/spoke-connector"

  # Hub cluster info (for IRSA)
  hub_cluster_name        = data.terraform_remote_state.hub_infra.outputs.cluster_name
  cluster_oidc_issuer_url = data.terraform_remote_state.hub_infra.outputs.cluster_oidc_issuer_url

  # GitHub configuration for SCM Provider
  github_pat       = var.github_pat
  github_org       = var.github_org
  github_app_topic = var.github_app_topic

  # Spoke clusters to register
  spoke_clusters = var.spoke_clusters

}
