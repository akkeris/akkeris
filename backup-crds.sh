#!/bin/sh
export cluster=ds3
export timestamp=$(date +%s)
export backupdir="backups-$timestamp"
mkdir $backupdir


# backup section
echo "Creating backups $backupdir for $cluster"
velero backup create $backupdir --ttl=8760h --include-resources="*" --include-cluster-resources=true --exclude-namespaces velero --kubecontext $cluster --wait
kubectl get issuer -o yaml --all-namespaces --context $cluster > $backupdir/cert-manager-backup-issuer.yaml
kubectl get clusterissuer -o yaml --all-namespaces --context $cluster > $backupdir/cert-manager-backup-clusterissuer.yaml
kubectl get certificates -o yaml --all-namespaces --context $cluster > $backupdir/cert-manager-backup-certificates.yaml
kubectl get certificaterequests -o yaml --all-namespaces --context $cluster > $backupdir/cert-manager-backup-certificaterequests.yaml
kubectl get orders -o yaml --all-namespaces --context $cluster > $backupdir/cert-manager-backup-orders.yaml
kubectl get challenges -o yaml --all-namespaces --context $cluster > $backupdir/cert-manager-backup-challenges.yaml
kubectl get secrets/letsencrypt-prod-private-key -o yaml --context $cluster -n cert-manager > $backupdir/letsencrypt-prod-private-key.yaml
kubectl get secrets/route53-svc-acct-secret -o yaml  --context $cluster -n cert-manager > $backupdir/route53-svc-acct-secret.yaml
kubectl get secrets -l certmanager.k8s.io/certificate-name --context $cluster -n istio-system -o yaml > $backupdir/istio-tls-secrets.yaml
kubectl get virtualservices --context $cluster --all-namespaces -o yaml > $backupdir/istio-virtual-services.yaml
kubectl get gateways --context $cluster --all-namespaces -o yaml > $backupdir/istio-gateways.yaml
kubectl get policies --context $cluster --all-namespaces -o yaml > $backupdir/istio-policies.yaml
kubectl get instances --context $cluster --all-namespaces -o yaml > $backupdir/istio-instances.yaml
kubectl get deployments --context $cluster -n istio-system -o yaml > $backupdir/istio-deployments.yaml
kubectl get replicasets --context $cluster -n istio-system -o yaml > $backupdir/istio-replicasets.yaml
kubectl get services --context $cluster -n istio-system -o yaml > $backupdir/istio-services.yaml
kubectl get configmaps --context $cluster -n istio-system -o yaml > $backupdir/istio-configmaps.yaml
kubectl get configmaps -n kube-system --context $cluster -o yaml > $backupdir/kube-system-configmaps.yaml
kubectl get crds -lchart=istio -o yaml --context $cluster > $backupdir/crds.yaml
kubectl get horizontalpodautoscaler.autoscaling -n istio-system --context $cluster -o yaml > hpa.yaml
kubectl get mutatingwebhookconfiguration/istio-sidecar-injector -o yaml --context $cluster > mwh.yaml

exit 1
