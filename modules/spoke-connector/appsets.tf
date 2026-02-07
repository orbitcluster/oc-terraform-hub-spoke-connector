################################################################################
# ApplicationSet Resources
# Creates ApplicationSets for GitOps deployments
# Flow: policy update → cluster registration → appsets (via depends_on)
################################################################################

# SCM Provider ApplicationSet - discovers repos with topic
resource "kubectl_manifest" "appset_scm_provider" {
  count = var.enable_scm_appset ? 1 : 0

  yaml_body = templatefile("${path.module}/yamls/appset-scm-provider.yaml", {
    github_org       = var.github_org
    github_app_topic = var.github_app_topic
    argocd_namespace = local.argocd_namespace
  })

  depends_on = [
    kubernetes_secret_v1.github_token,
    kubernetes_secret_v1.spoke_cluster,
    aws_iam_policy.argocd_assume_spoke_updated  # Policy before appsets
  ]
}

# Environment-specific ApplicationSets (dev, staging, prod)
resource "kubectl_manifest" "appset_environment" {
  for_each = var.enable_environment_appsets ? toset(["dev", "staging", "prod"]) : toset([])

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
    kubernetes_secret_v1.spoke_cluster,
    aws_iam_policy.argocd_assume_spoke_updated  # Policy before appsets
  ]
}

# PR Preview ApplicationSet - for all repos with topic
resource "kubectl_manifest" "appset_pr_preview" {
  count = var.enable_pr_preview_appset ? 1 : 0

  yaml_body = templatefile("${path.module}/yamls/appset-pr-preview.yaml", {
    github_org       = var.github_org
    github_app_topic = var.github_app_topic
    argocd_namespace = local.argocd_namespace
  })

  depends_on = [
    kubernetes_secret_v1.github_token,
    kubernetes_secret_v1.spoke_cluster,
    aws_iam_policy.argocd_assume_spoke_updated  # Policy before appsets
  ]
}

################################################################################
# Custom ApplicationSets
# User-provided ApplicationSet YAML configurations
################################################################################

resource "kubectl_manifest" "custom_appset" {
  for_each = var.custom_appsets

  yaml_body = each.value.yaml_content

  depends_on = [
    kubernetes_secret_v1.github_token,
    kubernetes_secret_v1.spoke_cluster,
    aws_iam_policy.argocd_assume_spoke_updated  # Policy before appsets
  ]
}
