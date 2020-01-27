#!/bin/sh

echo "Installing Certificate Manager..."
kubectl apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.12/deploy/manifests/00-crds.yaml
kubectl create namespace cert-manager
# kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true
# kubectl label namespace kube-system certmanager.k8s.io/disable-validation=true
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install \
  --name cert-manager \
  --namespace cert-manager \
  --version v0.12.0 \
  --set=extraArgs={"--dns01-self-check-nameservers=8.8.8.8:53\,1.1.1.1:53"} \
  --wait --timeout 600 \
  jetstack/cert-manager

echo "Installing Certificate Manager... Done"