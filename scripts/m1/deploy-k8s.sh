#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "Error: kubectl is not installed."
  exit 1
fi

INSTALL_INGRESS="${INSTALL_INGRESS:-false}"
if [[ "${1:-}" == "--install-ingress-controller" ]]; then
  INSTALL_INGRESS=true
fi

if [[ "$INSTALL_INGRESS" == "true" ]]; then
  echo "Installing ingress-nginx controller..."
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
  echo "ingress-nginx controller install command applied."
fi

echo "Applying namespaces..."
kubectl apply -f k8s/namespace.yaml

echo "Deploying PostgreSQL secrets and storage..."
kubectl apply -f k8s/postgres/postgres-secret.yaml
kubectl apply -f k8s/postgres/postgres-pvc.yaml
kubectl apply -f k8s/postgres/postgres-deployment.yaml

echo "Waiting for PostgreSQL pod to be ready..."
if ! kubectl wait --for=condition=ready pod -l app=postgres -n data --timeout=300s; then
  echo "PostgreSQL pod did not become ready in time."
  kubectl get pods -n data -l app=postgres -o wide
  exit 1
fi

echo "Applying app config and secrets..."
kubectl apply -f k8s/app/configmap.yaml
kubectl apply -f k8s/app/app-secret.yaml

echo "Applying services..."
kubectl apply -f k8s/services/

echo "Deploying app services..."
kubectl apply -f k8s/app/

echo "Applying ingress..."
kubectl apply -f k8s/ingress.yaml

echo "Deployment summary:"
kubectl get pods -n data
kubectl get pods -n app
kubectl get svc -n app
kubectl get ingress -n app
