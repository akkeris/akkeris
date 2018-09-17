# Akkeris

This is the home for resources to install Akkeris. For information on contributing see the [contributing](https://github.com/akkeris/contributing) repo and wiki.

## Installing Akkeris

**Important**: THIS A PROTOTYPE - We recommend you run these scripts in an isolated account and/or project with a domain that is not in use. This is a highly volitile setup and tear down process that could accidently (or incidently) affect other resources. Run with caution.  

This is very work in progress, but in this repo there's scripts that help outline how to install kubernetes on various platforms.

### Pre-reqs

1. Clone out this repo
2. Have a domain setup for a cloud provider below, it should be managed (its NS records) the cloud providers DNS systems.
3. Setup a new project and enable your account to acccess/provision redis, memcached, postgres SQL systems.

### Google Cloud

Note, removing `TEST_MODE=true` will use production letsencrypt systems, only remove it if you intend to use the cluster.  Without it (if you provision and deprovision too many times) your domain could be banned (rate limited rather) on lets encrypts systems for one week.

**Installing**

```
TEST_MODE=true PROVIDER=gcloud EMAIL=youremailongcloud@example.com PROJECT_ID=project-ongcloud-172320 CLUSTER_NAME=kobayashi ISSUER=letsencrypt DOMAIN=example.com REGION=us-west1 ZONE=us-west1-a ./gcloud_provision.sh
```

**Uninstalling**

```
TEST_MODE=true PROVIDER=gcloud EMAIL=youremailongcloud@example.com PROJECT_ID=project-ongcloud-172320 CLUSTER_NAME=kobayashi ISSUER=letsencrypt DOMAIN=example.com REGION=us-west1 ZONE=us-west1-a ./gcloud_deprovision.sh
```


### AWS

TBD, but most likely similar to the provision scripts above.

### Azure

TBD, but most likely similar to the provision scripts above.

### Bare Metal (or VMs) via Rancher

TBD, but most likely similar to the provision scripts above.
