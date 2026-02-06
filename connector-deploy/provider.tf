################################################################################
# Provider Configuration
# Connects to Hub cluster using remote state
################################################################################

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14"
    }
  }
}

provider "aws" {
  region = var.region
}

# Configure Kubernetes provider for Hub cluster
provider "kubernetes" {
  host                   = data.terraform_remote_state.hub_infra.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.hub_infra.outputs.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.hub_infra.outputs.cluster_name]
  }
}

# Configure kubectl provider for Hub cluster
provider "kubectl" {
  host                   = data.terraform_remote_state.hub_infra.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.hub_infra.outputs.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.hub_infra.outputs.cluster_name]
  }
}
