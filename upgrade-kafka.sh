#!/bin/sh
helm upgrade kafkalogs incubator/kafka --set=external.domain=$CLUSTER.$DOMAIN -f ./helm/kafka-values.yaml --wait --timeout 600
