#!/bin/sh
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.8/deploy/manifests/00-crds.yaml
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm upgrade cert-manager jetstack/cert-manager --version v0.8.1 --set=extraArgs={"--dns01-self-check-nameservers=8.8.8.8:53\,1.1.1.1:53"}

