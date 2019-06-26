# Akkeris

Akkeris, a kubernetes based PaaS, is a powerful platform for managing applications and their resources.

## TL;DR;

```console
$ helm install ./helm/akkeris
```

## Introduction

## Prerequisites

## Installing the Chart

## Uninstalling the Chart

## Configuration

Parameter | Description | Default
--------- | ----------- | -------
`regionApi.name` | region-api container name | `region-api`
`regionApi.image.repository` | region-api container image repository | `akkeris/region-api`
`regionApi.image.tag` | region-api container image tag | `release-38`
`regionApi.image.pullPolicy` | region-api container image pull policy | `IfNotPresent`
`regoinApi.ingress.enables` | If true, region-api Ingress will be created | `false`
`databaseBroker.enabled` | If true, create postgres broker | `true`

Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`. For example,

```console
$ helm install stable/akkeris --name my-release \
    --set server.terminationGracePeriodSeconds=360
```

Alternatively, a YAML file that specifies the values for the above parameters can be provided while installing the chart. For example,

```console
$ helm install stable/akkeris --name my-release -f values.yaml
```

> **Tip**: You can use the default [values.yaml](values.yaml)

## RBAC Configuration

## ConfigmMap Files

## Istio Configuration
