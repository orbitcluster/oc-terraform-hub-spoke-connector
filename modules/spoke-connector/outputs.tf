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
