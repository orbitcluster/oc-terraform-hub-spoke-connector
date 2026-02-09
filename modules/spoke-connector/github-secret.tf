################################################################################
# GitHub PAT Secret
# Used by SCM Provider ApplicationSet to access GitHub API
################################################################################

resource "kubernetes_secret_v1" "github_token" {
  count = var.github_pat != "" ? 1 : 0

  metadata {
    name      = "github-token"
    namespace = local.argocd_namespace
    labels = {
      "app.kubernetes.io/part-of" = "argocd"
    }
  }

  data = {
    token = var.github_pat
  }

  type = "Opaque"
}
