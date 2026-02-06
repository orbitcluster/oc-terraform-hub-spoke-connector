################################################################################
# ApplicationSet Resources
# Creates ApplicationSets for GitOps deployments
################################################################################

# SCM Provider ApplicationSet - discovers repos with topic
resource "kubectl_manifest" "appset_scm_provider" {
  yaml_body = templatefile("${path.module}/yamls/appset-scm-provider.yaml", {
    github_org       = var.github_org
    github_app_topic = var.github_app_topic
    argocd_namespace = local.argocd_namespace
  })

  depends_on = [kubernetes_secret_v1.github_token]
}

# Environment-specific ApplicationSets (dev, staging, prod)
resource "kubectl_manifest" "appset_environment" {
  for_each = toset(["dev", "staging", "prod"])

  yaml_body = templatefile("${path.module}/yamls/appset-environment.yaml", {
    environment      = each.key
    github_org       = var.github_org
    github_app_topic = var.github_app_topic
    argocd_namespace = local.argocd_namespace
    # Prod requires manual approval - no auto-sync
    auto_sync = each.key != "prod"
  })

  depends_on = [
    kubernetes_secret_v1.github_token,
    kubernetes_secret_v1.spoke_cluster
  ]
}

# PR Preview ApplicationSet - for all repos with topic
resource "kubectl_manifest" "appset_pr_preview" {
  yaml_body = templatefile("${path.module}/yamls/appset-pr-preview.yaml", {
    github_org       = var.github_org
    github_app_topic = var.github_app_topic
    argocd_namespace = local.argocd_namespace
  })

  depends_on = [
    kubernetes_secret_v1.github_token,
    kubernetes_secret_v1.spoke_cluster
  ]
}
