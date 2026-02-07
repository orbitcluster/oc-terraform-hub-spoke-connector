################################################################################
# Outputs
################################################################################

output "registered_clusters" {
  description = "Names of clusters registered with ArgoCD"
  value       = keys(var.spoke_clusters)
}

output "cluster_secrets" {
  description = "Map of cluster secret names created in ArgoCD namespace"
  value = {
    for k, v in kubernetes_secret_v1.spoke_cluster : k => v.metadata[0].name
  }
}

output "github_token_secret_name" {
  description = "Name of the GitHub token secret"
  value       = var.github_pat != "" ? kubernetes_secret_v1.github_token[0].metadata[0].name : null
}

################################################################################
# IRSA Outputs
################################################################################

output "argocd_spoke_role_arn" {
  description = "ARN of the IAM role for ArgoCD spoke cluster access"
  value       = length(aws_iam_role.argocd_spoke_access) > 0 ? aws_iam_role.argocd_spoke_access[0].arn : null
}

output "argocd_spoke_service_account" {
  description = "Name of the Kubernetes service account for spoke access"
  value       = length(kubernetes_service_account_v1.argocd_spoke_controller) > 0 ? kubernetes_service_account_v1.argocd_spoke_controller[0].metadata[0].name : null
}
