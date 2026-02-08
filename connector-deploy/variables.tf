################################################################################
# Variables for Connector Deployment
################################################################################

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "hub_bucket_name" {
  description = "S3 bucket name for hub cluster state"
  type        = string
}

variable "master_s3_directory" {
  description = "Master S3 directory for hub cluster state"
  type        = string
  default     = "oc-eks-hub"
}

variable "module_version" {
  description = "Version/ref of spoke-connector module to use"
  type        = string
  default     = "main"
}

variable "github_pat" {
  description = "GitHub Personal Access Token with repo scope"
  type        = string
  sensitive   = true
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = "orbitcluster"
}

variable "github_app_topic" {
  description = "GitHub topic for app discovery"
  type        = string
  default     = "orbit-deploy"
}

variable "spoke_clusters" {
  description = "Map of spoke clusters to register"
  type = map(object({
    cluster_name    = string
    server          = string
    ca_data         = string
    env             = string
    argocd_role_arn = string
  }))
  default = {}
}

################################################################################
# ApplicationSet Configuration
################################################################################


variable "custom_appsets" {
  description = "Map of custom ApplicationSet YAML configurations to deploy"
  type = map(object({
    yaml_content = string
  }))
  default = {}
}

variable "enable_folder_structure_appsets" {
  description = "Enable folder-based (env/dev, env/qa) ApplicationSets"
  type        = bool
  default     = true
}
