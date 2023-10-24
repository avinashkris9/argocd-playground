# argocd-playground

Repo meant for learning ArgoCD stuffs

## Prerequisites

- kind
- jq

## How to ?

1. Create a new cluster and setup Argo. The below command will create a new K8s kind cluster named `kind-argo` and install argo CRDs
   `make install-argo`
2. Login to Argo via `http://localhost`
3. Connect to argocli

```sh
make argo
```

4. Add additional cluster named `dev` and add it to ArgoCD cluster list

```sh
make multi_cluster
```

## Application Deployment

Application Deployment are using ArgoCD ApplicationSet pattern with `Cluster Generators`. The Jsonnet template `appset.jsonnet` generate `ApplicationSet` with cluster label `env=test`. To deploy new app

- Update the Application Details in `params.libsonnet` file.
- The below command will parse the jsonnet template and create a `Deployment`, `Service`, `ApplicationSet`

`make run`

Unfortunately ArgoCD doesn't display `ApplicationSet` in UI. See https://github.com/argoproj/argo-cd/issues/7352

## Cluster Bootstrapping

This helps to setup infra leve components to cluster.

1. Add your cluster to argocd

```sh
 argocd cluster add --label env=test  docker-desktop
```

1. Update the server in `cluster-bootstrap/ApplicationSet.yaml`

```yaml
destination:
  server: https://kubernetes.docker.internal:6443
```

2. Create an Argo `Applicationset for bootstrapping`

```sh
argocd appset create cluster-bootstrap/ApplicationSet.yaml --upsert
```
