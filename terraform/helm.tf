provider "helm" {
    kubernetes {
        host     = "${google_container_cluster.akkeris.}"
        username = "${var.clusterUsername}"
        password = "${var.clusterPassword}"
        service_account = "tiller"

        client_certificate     = "${google_container_cluster.primary.master_auth.0.client_certificate}"
        client_key             = "${google_container_cluster.primary.master_auth.0.client_key}"
        cluster_ca_certificate = "${google_container_cluster.primary.master_auth.0.cluster_ca_certificate}"
    }
}

resource "helm_release" "vault" {
    name       = "vault-operator"
    namespaces = "akkeris"
    chart      = "stable/vault-operator"

    set {
        name  = "etcd-operator.enabled"
        value = true
    }
}

resource "helm_release" "registry" {
    name      = "registry"
    namespace = "akkeris"
    chart     = "stable/docker-registry"
}

resource "helm_release" "jenkins" {
    name      = "jenkins"
    namespace = "akkeris"
    chart     = "stable/jenkins"

    set {
        name  = "Master.AdminPassword"
        value = "${var.jenkinsPass}"
    }
}

resource "helm_release" "influxdb" {
    name      = "influxdb"
    namespace = "akkris"
    chart     = "stable/influxdb"
}

resource "helm_repository" "incubator" {
    name = "incubator"
    url  = "https://kubernetes-charts-incubator.storage.googleapis.com"
}

resource "helm_release" "kafka" {
    name      = "kafkalogs"
    namespace = "akkeris"
    chart     = "incubator/kafka"
}