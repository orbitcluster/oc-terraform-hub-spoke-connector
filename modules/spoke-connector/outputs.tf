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
  value       = length(data.aws_iam_role.argocd_hub_role) > 0 ? data.aws_iam_role.argocd_hub_role[0].arn : null
}

output "argocd_spoke_service_account" {
  description = "Name of the Kubernetes service account for spoke access"
  # We now use the default ArgoCD controller service account
  value = "argocd-application-controller"
}
