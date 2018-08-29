
function delete_google_kubernetes {
	kubectl config use-context $CLUSTER_NAME
	gcloud container clusters delete $CLUSTER_NAME
}

function uninstall_helm() {
	kubectl config use-context $CONTEXT_NAME
	kubectl delete serviceaccount --namespace kube-system tiller --context $CONTEXT_NAME
	kubectl delete clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller --context $CONTEXT_NAME
	helm reset --service-account tiller --kube-context $CONTEXT_NAME
	# kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
}


function uninstall_kafka() {
	helm del --purge kafkalogs --kube-context $CONTEXT_NAME
}

function uninstall_registry() {
	helm del --purge registry --kube-context $CONTEXT_NAME
}

function uninstall_vault() {
	kubectl delete vault akkeris -n default --context $CONTEXT_NAME
	helm del --purge vault --kube-context $CONTEXT_NAME
}


function uninstall_jenkins() {
	helm del --purge jenkins --kube-context $CONTEXT_NAME
}

function uuninstall_influxdb() {
 	helm del --purge metrics --kube-context $CONTEXT_NAME
 	# http://influxdb-influxdb.akkeris:8086
}

function delete_gcloud_letsencrypt_issuer {
	gcloud iam service-accounts delete letsencrypt@$PROJECT_ID.iam.gserviceaccount.com
}

function delete_ssl_site {
	# gcloud compute addresses delete $HOST --global
}


function uninstall_akkeris_sites() {
}