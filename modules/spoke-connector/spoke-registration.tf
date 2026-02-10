################################################################################
# Spoke Cluster Registration
# Creates ArgoCD cluster secrets for each spoke cluster
# ArgoCD watches for secrets with label: argocd.argoproj.io/secret-type=cluster
# Flow: IRSA setup → cluster registration → appsets
################################################################################

resource "kubernetes_secret_v1" "spoke_cluster" {
  for_each = var.spoke_clusters

  metadata {
    name      = "cluster-${each.key}"
    namespace = local.argocd_namespace
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
      "environment"                     = each.value.env
      "cluster-name"                    = each.key
    }
  }

  data = {
    name   = each.key
    server = each.value.server
    config = jsonencode({
      awsAuthConfig = {
        clusterName = each.value.cluster_name
        roleARN     = each.value.argocd_role_arn
      }
      tlsClientConfig = {
        insecure = false
        caData   = each.value.ca_data
      }
    })
  }

  type = "Opaque"

  # Ensure IRSA is set up before registering clusters
  depends_on = [
    aws_iam_role_policy_attachment.argocd_assume_spokes
  ]
}
