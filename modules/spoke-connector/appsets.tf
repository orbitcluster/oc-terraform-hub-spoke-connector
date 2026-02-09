################################################################################
# ApplicationSet Resources
# Creates ApplicationSets for GitOps deployments
# Flow: IRSA setup → cluster registration → appsets (via depends_on)
################################################################################




################################################################################
# Folder Structure ApplicationSets
# Implements env/dev, env/qa, env/prod workflow
################################################################################

# Dev PRs (Dynamic)
resource "kubectl_manifest" "appset_folder_dev_pr" {

  yaml_body = templatefile("${path.module}/yamls/appset-dev-pr.yaml", {
    github_org       = var.github_org
    github_app_topic = var.github_app_topic
    argocd_namespace = local.argocd_namespace
  })

  depends_on = [
    kubernetes_secret_v1.github_token
  ]
}

# Dev Main (Continuous)
resource "kubectl_manifest" "appset_folder_dev_main" {

  yaml_body = templatefile("${path.module}/yamls/appset-dev-main.yaml", {
    github_org       = var.github_org
    github_app_topic = var.github_app_topic
    argocd_namespace = local.argocd_namespace
  })

  depends_on = [
    kubernetes_secret_v1.github_token
  ]
}

# Promoter (QA/Prod)
resource "kubectl_manifest" "appset_folder_promoter" {

  yaml_body = templatefile("${path.module}/yamls/appset-promoter.yaml", {
    github_org       = var.github_org
    github_app_topic = var.github_app_topic
    argocd_namespace = local.argocd_namespace
  })

  depends_on = [
    kubernetes_secret_v1.github_token
  ]
}
