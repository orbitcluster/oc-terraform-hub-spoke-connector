################################################################################
# Variables
################################################################################

variable "spoke_clusters" {
  description = "Map of spoke clusters to register with ArgoCD"
  type = map(object({
    cluster_name    = string # EKS cluster name
    server          = string # API server endpoint
    ca_data         = string # Base64 encoded CA certificate
    env             = string # Environment: dev, staging, prod
    argocd_role_arn = string # IAM role ARN for ArgoCD access
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.spoke_clusters : contains(["dev", "staging", "prod"], v.env)
    ])
    error_message = "Each spoke cluster env must be one of: dev, staging, prod"
  }
}

variable "github_pat" {
  description = "GitHub Personal Access Token with repo scope for SCM Provider"
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_org" {
  description = "GitHub organization name to scan for repositories"
  type        = string
  default     = "orbitcluster"
}

variable "github_app_topic" {
  description = "GitHub topic to filter repositories for deployment"
  type        = string
  default     = "orbit-deploy"
}

variable "argocd_assume_spoke_policy_arn" {
  description = "ARN of the ArgoCD assume-spoke IAM policy (from custom-addons output)"
  type        = string
}
