#!/bin/bash
set -x
if [ -z "$1" ]; then
  CLUSTER="dev"
else
  CLUSTER=$1
fi

if [ -z "$2" ]; then
  ARGO_CLUSTER="argo"
else
  ARGO_CLUSTER=$2
fi
TEMP_DIR="/tmp/argocd-playground"

if ! [ -f ${TEMP_DIR}/argocd ]; then

  mkdir -p ${TEMP_DIR} &&
    cd /tmp/argocd-playground &&
    curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 &&
    mv argocd-linux-amd64 argocd && chmod +x argocd
fi

kind get kubeconfig --name "${CLUSTER}" --internal >${TEMP_DIR}/kubeconfig
argocd admin initial-password -n argocd --context "kind-${ARGO_CLUSTER}" | head -1 >${TEMP_DIR}/.admin
POD_NAME="argo-init"
kubectl delete pod ${POD_NAME} --context "kind-${ARGO_CLUSTER}" --force

cat <<EOF | kubectl --context kind-argo apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: $POD_NAME
  namespace: default
spec:  # specification of the pod’s contents
  restartPolicy: Never
  containers:
  - name: hello
    image: "alpine/k8s:1.26.9"
    command: ["/bin/sh"]
    args:
      - -c
      - >-
          kubectl get pods &&
          /argo/argocd login argocd-server.argocd.svc.cluster.local --username=admin --password $(cat ${TEMP_DIR}/.admin) &&
           kubectl config  current-context && 
          /argo/argocd cluster list && 
          /argo/argocd cluster add --label env=test kind-${CLUSTER} &&
          /argo/argocd  cluster list

    env:
    - name: ARGOCD_SERVERS
      value: "argocd-server.argocd.svc.cluster.local"
    - name: ARGOCD_OPTS
      value: "--insecure"
    - name: "KUBECONFIG"
      value: "/argo/kubeconfig"
    volumeMounts:
    - mountPath: /argo
      name: test-volume
  volumes:
  - name: test-volume
    hostPath:
      # directory location on host
      path: /tmp/argocd-playground
      # this field is optional
      type: Directory
EOF

kubectl wait --for=condition=Ready pod/${POD_NAME} --timeout=66s  --context "kind-${ARGO_CLUSTER}" -n default
kubectl logs --context "kind-${ARGO_CLUSTER}" ${POD_NAME}
