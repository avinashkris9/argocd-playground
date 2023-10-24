all: help
default: help
CG=\033[0;32m
NC=\033[0m
APP=argocd
.PHONY: help setup cluster
NodePort:=30950
ARGO_CLUSTER:="argo"
ARG_DEPLOY_CLUSTER:="dev"


##TODO
## install kind and argocd cli jq installed

help:  ## Show help messages for make targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(firstword $(MAKEFILE_LIST)) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}'

get-argocd-password: ## Get Argocd password
	kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o name | cut -d'/' -f 2



destroy: ## Nuke Kind cluster

	kind delete clusters ${ARGO_CLUSTER} ${ARG_DEPLOY_CLUSTER}

argo: ## Get Argo
	$(eval ARGO_URL =$(shell kubectl get svc argocd-server -n argocd -o json | jq -r '.spec.ports[0].nodePort'))

	$(eval ARGO_PASSWORD =$(shell argocd admin initial-password -n argocd))
	echo "Initial admin password ${ARGO_PASSWORD}"
	echo "Argo Running on $(ARGO_URL)"

	argocd login localhost --insecure --username admin --password $(ARGO_PASSWORD) --grpc-web

install-rollouts: ## Install Rollout CRD to current cluster

	kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml


install-argo: cluster ## Install ArgoCD

	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	kubectl apply -f k8s/ingress.yaml
	kubectl patch deployment argocd-server --type json -p='[ { "op": "replace", "path":"/spec/template/spec/containers/0/command","value": ["argocd-server","--staticassets","/shared/app","--insecure"] }]' -n argocd
	kubectl wait --for=condition=available deployment -l "app.kubernetes.io/name=argocd-server" -n argocd --timeout=300s
	sleep 60

multi_cluster:
	argocd cluster add --label env=test docker-desktop
	@if ! [ $$(kind get clusters | grep ${ARG_DEPLOY_CLUSTER}) ]; then \
	kind create cluster  --name ${ARG_DEPLOY_CLUSTER} ; \
	fi
	k8s/add-cluster-argo.sh ${ARG_DEPLOY_CLUSTER} ${ARGO_CLUSTER} ; \

cluster: ## Create Kind Clusters
	 
	@if ! [ $$(kind get clusters | grep ${ARGO_CLUSTER}) ]; then \
		echo "Creating Kind Clusters ${ARGO_CLUSTER}" ; \
		kind create cluster --config ./k8s/kind.yaml --name ${ARGO_CLUSTER}; \
		kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml ;\
		kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.13.1/cert-manager.yaml; \
		sleep 120;\
		kubectl apply -f k8s/cert-issuer.yaml; \
		kubectl wait --namespace ingress-nginx  --for=condition=ready pod --selector=app.kubernetes.io/component=controller   --timeout=90s ;\
	fi
	@kubectl cluster-info --context kind-${ARGO_CLUSTER}
	@kubectl get nodes


run: ## Create Manifest Files
	## Try'in out multiple things
	@mkdir -p apps
	@mkdir -p app-resources
	@mkdir -p app-resources/$$(jsonnet params.libsonnet| jq -r '.name')
	jsonnet appset.jsonnet --tla-str  name=$$(jsonnet params.libsonnet| jq -r '.name') --tla-str    environment=$$(jsonnet params.libsonnet| jq -r '.environment') --tla-str    namespace=$$(jsonnet params.libsonnet| jq -r '.namespace') >apps/$$(jsonnet params.libsonnet| jq -r '.name').json
	jsonnet app.jsonnet  >app-resources/$$(jsonnet params.libsonnet| jq -r '.name')/app.json
	kubectl apply -f apps/$$(jsonnet params.libsonnet| jq -r '.name').json --context=kind-argo

bootstrap: ## Argo Bootstrapping
	argocd appset create cluster-bootstrap/ApplicationSet.yaml --upsert
	argocd appset list