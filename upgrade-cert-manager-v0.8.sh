#!/bin/sh

export cluster=maru
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
exit 1


# removal section
kubectl delete issuer --all --all-namespaces --context $cluster
kubectl delete clusterissuer --all --all-namespaces --context $cluster
kubectl delete certificates --all --all-namespaces --context $cluster
kubectl delete certificaterequests --all --all-namespaces --context $cluster
kubectl delete orders --all --all-namespaces --context $cluster
kubectl delete challenges --all --all-namespaces --context $cluster
kubectl delete -f https://github.com/jetstack/cert-manager/releases/download/v0.8.1/cert-manager.yaml --context $cluster
kubectl delete deployments --namespace cert-manager --context $cluster \
    cert-manager \
    cert-manager-cainjector \
    cert-manager-webhook

kubectl delete --context $cluster -n cert-manager issuer cert-manager-webhook-ca cert-manager-webhook-selfsign
kubectl delete --context $cluster -n cert-manager certificate cert-manager-webhook-ca cert-manager-webhook-webhook-tls
kubectl delete --context $cluster apiservice v1beta1.admission.certmanager.k8s.io

helm delete cert-manager --purge --kube-context $cluster
kubectl delete apiservice v1beta1.webhook.cert-manager.io --context $cluster
kubectl delete namespace cert-manager --context $cluster
kubectl delete -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.8/deploy/manifests/00-crds.yaml --context $cluster
exit 1


# validation section
echo "=== Check if anything else is left:"
kubectl get crd --context $cluster | grep certmanager.k8s.io
exit 1


# upgrade section
kubectl apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.12/deploy/manifests/00-crds.yaml --context $cluster
kubectl create namespace cert-manager --context $cluster
./install-cert-manager-translate-v1alpha1-to-v1alpha2.js $backupdir/cert-manager-backup-clusterissuer.yaml
./install-cert-manager-translate-v1alpha1-to-v1alpha2.js $backupdir/cert-manager-backup-certificates.yaml
./install-cert-manager-translate-v1alpha1-to-v1alpha2.js $backupdir/cert-manager-backup-orders.yaml
kubectl apply -f ./$backupdir/letsencrypt-prod-private-key.yaml -n cert-manager --context $cluster
kubectl apply -f ./$backupdir/route53-svc-acct-secret.yaml -n cert-manager --context $cluster
kubectl apply -f ./$backupdir/cert-manager-backup-clusterissuer.yaml-v1alpha2 --context $cluster
kubectl apply -f ./$backupdir/cert-manager-backup-certificates.yaml-v1alpha2 --context $cluster
kubectl apply -f ./$backupdir/cert-manager-backup-orders.yaml-v1alpha2 --context $cluster
helm repo add jetstack https://charts.jetstack.io --kube-context $cluster
helm repo update --kube-context $cluster
helm install \
      --name cert-manager \
      --namespace cert-manager \
      --version v0.12.0 \
      --set=extraArgs={"--dns01-self-check-nameservers=8.8.8.8:53\,1.1.1.1:53"} \
      --wait \
      --timeout 600 \
      --kube-context $cluster \
  jetstack/cert-manager
exit 1


#   --- wait for backup to complete ---
#   velero restore create --from-backup $backupdir --include-resources="*" --include-cluster-resources=true --kubecontext $cluster --wait
#   ^- you probably will need to run this twice. transient objects such as orders or challenges may not restore properly. then run:
#      -- scale down cert manager, disable webhook --
#      kubectl apply -f ./$backupdir/cert-manager-backup-clusterissuer.yaml --context $cluster --force
#      kubectl apply -f ./$backupdir/cert-manager-backup-certificates.yaml --context $cluster --force
#      kubectl apply -f ./$backupdir/cert-manager-backup-orders.yaml --context $cluster --force
#      -- scale up cert manager, re-enable webhook --
#      if you receive a warning, remove the order or challenge and try again.