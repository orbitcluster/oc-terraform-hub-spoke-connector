# PR Previews Lifecycle

This document explains how the `orbit-apps-pr-preview` ApplicationSet generates ephemeral environments for open pull requests and how it manages the lifecycle of the PR namespaces.

## Namespace Creation

When a new pull request is opened, the ApplicationSet automatically provisions a dedicated namespace for it based on the repository name and PR branch slug. This is achieved using the `CreateNamespace=true` sync option.

## Namespace Deletion

By default, ArgoCD does not automatically delete namespaces created via `CreateNamespace=true` when the corresponding Application is deleted. To address this, we use ArgoCD's resource tracking metadata so that ArgoCD explicitly owns the generated namespace.

In the `appset-dev-pr.yaml` template, we configure `managedNamespaceMetadata` with the `app.kubernetes.io/instance` label and the `argocd.argoproj.io/tracking-id` annotation:

```yaml
managedNamespaceMetadata:
  labels:
    istio-injection: enabled
    allow-hub-ecr-pull: "true"
    app.kubernetes.io/instance: "{{.repository}}-pr-{{.branch_slug}}"
  annotations:
    argocd.argoproj.io/tracking-id: "{{.repository}}-pr-{{.branch_slug}}:/Namespace:{{.repository}}-pr-{{.branch_slug}}"
```

With this configuration:

1. The `tracking-id` directly links the namespace back to the PR Application.
2. Since the Application is configured with `prune: true`, ArgoCD prunes the namespace and all its corresponding resources when the Application is removed (which happens when the PR is merged or closed).
