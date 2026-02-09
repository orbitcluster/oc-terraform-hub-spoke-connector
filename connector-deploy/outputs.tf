################################################################################
# Outputs
################################################################################

output "registered_clusters" {
  description = "List of cluster names registered with ArgoCD"
  value       = module.spoke_connector.registered_clusters
}

output "cluster_secrets" {
  description = "Map of cluster secret names"
  value       = module.spoke_connector.cluster_secrets
}
