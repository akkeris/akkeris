#!/bin/sh
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.7/deploy/manifests/00-crds.yaml
kubectl create namespace cert-manager
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install \
  --name cert-manager \
  --namespace cert-manager \
  --version v0.7.2 \
  --set=extraArgs={"--dns01-self-check-nameservers=8.8.8.8:53\,1.1.1.1:53"} \
  jetstack/cert-manager

# TODO: Install cluster issuer.