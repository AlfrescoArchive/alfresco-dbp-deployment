# Alfresco Digital Business Platform Deployment

## Prerequisites

The Alfresco Digital Business Platform Deployment requires:

| Component        | Recommended version |
| ------------- |:-------------:|
| Docker     | 17.0.9.1 |
| Kubernetes | 1.8.0    |
| Helm       | 2.7.0    |
| Minikube   | 0.24.1   |

Any variation from these technologies and versions may affect the end result. If you do experience any issues please let us know through our [Gitter channel](https://gitter.im/Alfresco/platform-services?utm_source=share-link&utm_medium=link&utm_campaign=share-link).

!Note: You dont need to clone this repo to deploy the dbp.

### Kubernetes Cluster

You can choose to deploy the DBP to a local kubernetes cluster (illustrated using minikube) or you can choose to deploy to the cloud (illustrated using AWS).
Please check the Anaxes Shipyard documentation on [running a cluster](https://github.com/Alfresco/alfresco-anaxes-shipyard/blob/master/SECRETS.md).

Note the DBP resource requirements:
* Minikube: At least 12 gigs of memory, i.e.:
```bash
minikube start --memory 12000
```
* AWS: A VPC and cluster with 5 nodes. Each node should be a m4.xlarge EC2 instance.

### Helm Tiller

Initialize the Helm Tiller:
```bash
helm init
```

### Helm Registry Plugin


#### Install the helm registry plugin to be able to install the dbp chart from quay.io registry

```bash
helm plugin install https://github.com/app-registry/appr-helm-plugin.git
```

#### Login to the quay.io helm registry

```bash
helm registry login quay.io
```

You will be prompted to enter your quay.io username and password.

The end result should look similar to the following:

```bash
helm registry login quay.io
Registry plugin assets do not exist, download them now !
downloading https://github.com/app-registry/appr/releases/download/v0.7.4/appr-osx-x64 ...
Username: sergiuv
Password:
 >>> Login succeeded
```

### K8s Cluster Namespace

As mentioned as part of the Anaxes Shipyard guidelines, you should deploy into a separate namespace in the cluster to avoid conflicts (create the namespace only if it does not already exist):

```bash
export DESIREDNAMESPACE=example
kubectl create namespace $DESIREDNAMESPACE
```

This environment variable will be used in the deployment steps.

### Docker Registry Pull Secrets

See the Anaxes Shipyard documentation on [secrets](https://github.com/Alfresco/alfresco-anaxes-shipyard/blob/master/SECRETS.md).

Be sure to use the same namespace as above.

*Note*: You can reuse the secrets.yaml file from charts/incubator directory. 

```bash
cd charts/incubator
cat ~/.docker/config.json | base64
```

Add the base64 string generated to .dockerconfigjson in secrets.yaml. The file should look like this:

```bash
apiVersion: v1
kind: Secret
metadata:
  name: quay-registry-secret
type: kubernetes.io/dockerconfigjson
data:
# Docker registries config json in base64 to do this just run - cat ~/.docker/config.json | base64
  .dockerconfigjson: ew0KCSJhdXRocyI6IHsNCgkJImh0dHBzOi8vcXVheS5pbyI6IHsNCgkJCSJhdXRoIjogImRHVnpkRHAwWlhOMD0iDQoJCX0sDQoJCSJxdWF5LmlvIjogew0KCQkJImF1dGgiOiAiZEdWemREcDBaWE4wIg0KCQl9DQoJfSwNCgkiSHR0cEhlYWRlcnMiOiB7DQoJCSJVc2VyLUFnZW50IjogIkRvY2tlci1DbGllbnQvMTcuMTIuMC1jZS1yYzMgKGRhcndpbikiDQoJfQ0KfQ==
```

Then run this command:

```bash
kubectl create -f secrets.yaml --namespace $DESIREDNAMESPACE
```

## Deployment

### 1. EFS Storage (**NOTE! ONLY FOR AWS!**)

Create a EFS storage on AWS and make sure it is in the same VPC as your cluster. Make sure you open inbound traffic in the security group to allow NFS traffic. Save the name of the server ex:

```bash
export NFSSERVER=fs-d660549f.efs.us-east-1.amazonaws.com
```

### 2. Deploy the infrastructure charts:
```bash

helm repo add alfresco-incubator https://alfresco.github.io/charts/incubator
helm repo add alfresco-stable https://alfresco.github.io/charts/stable

#ON MINIKUBE
helm install alfresco-test/alfresco-dbp-infrastructure --namespace $DESIREDNAMESPACE

#ON AWS
helm install alfresco-test/alfresco-dbp-infrastructure \
--set persistence.volumeEnv=aws \
--set persistence.nfs.server="$NFSSERVER" \
--namespace $DESIREDNAMESPACE
```

### 3. Get the infrastructure release name from the previous command and set it as a variable:
```bash
export INFRARELEASE=enervated-deer
```

### 4. Wait for the infrastructure release to get deployed.  When checking status all your pods should be READY 1/1):
```bash
helm status $INFRARELEASE
```

### 5. Get the nginx-ingress-controller port for the infrastructure (**NOTE! ONLY FOR MINIKUBE**):
```bash
export INFRAPORT=$(kubectl get service $INFRARELEASE-nginx-ingress-controller -o jsonpath={.spec.ports[0].nodePort} --namespace $DESIREDNAMESPACE )
```

### 6. Get Minikube or ELB IP and set it as a variable for future use:

```bash
#ON MINIKUBE
export ELBADDRESS=$(minikube ip)

#ON AWS
export ELBADDRESS=$(kubectl get services $INFRARELEASE-nginx-ingress-controller -o jsonpath={.status.loadBalancer.ingress[0].hostname} --namespace=$DESIREDNAMESPACE )
```

### 7. Deploy the DBP

```bash

#On MINIKUBE
helm registry install quay.io/alfresco/alfresco-dbp:incubator \
--set alfresco-sync-service.activemq.broker.host="${INFRARELEASE}-activemq-broker" \
--set alfresco-content-services.repository.environment.ACTIVEMQ_HOST="${INFRARELEASE}-activemq-broker" \
--set alfresco-content-services.repository.environment.SYNC_SERVICE_URI="http://$ELBADDRESS:$INFRAPORT/syncservice" \
--set alfresco-api-gateway.keycloakURL="http://$ELBADDRESS:$INFRAPORT/auth/" \
--set alfresco-api-gateway.rabbitmqReleaseName="$INFRARELEASE-rabbitmq-ha" \
--namespace=$DESIREDNAMESPACE

#On AWS
helm registry install quay.io/alfresco/alfresco-dbp:incubator \
--set alfresco-sync-service.activemq.broker.host="${INFRARELEASE}-activemq-broker" \
--set alfresco-content-services.repository.environment.ACTIVEMQ_HOST="${INFRARELEASE}-activemq-broker" \
--set alfresco-content-services.repository.environment.SYNC_SERVICE_URI="http://$ELBADDRESS/syncservice" \
--set alfresco-api-gateway.keycloakURL="http://$ELBADDRESS/auth/" \
--set alfresco-api-gateway.rabbitmqReleaseName="$INFRARELEASE-rabbitmq-ha" \
--namespace=$DESIREDNAMESPACE
```

You can either deploy the dbp fully or choose the components you need for your specific case. 
By default the dbp chart will deploy fully.

To disable specific components you can set the following values to false when deploying:

alfresco-activiti-cloud-registry.enabled
alfresco-api-gateway.enabled
alfresco-content-services.enabled
alfresco-keycloak.enabled
alfresco-process-services.enabled
alfresco-sync-service.enabled

```bash
#example: For disabling sync-service you will need to append the following subcommand to the helm install command:
 --set alfresco-sync-service.enabled=false 
```

### 8. Get the DBP release name from the previous command and set it as a variable:

```bash
export DBPRELEASE=littering-lizzard
```

### 9. Checkout the status of your DBP deployment:

```bash
helm status $INFRARELEASE
helm status $DBPRELEASE

#On MINIKUBE: Open Alfresco Repository in Browser
open http://$ELBADDRESS:`kubectl get service $DBPRELEASE-alfresco-content-services-repository -o jsonpath={.spec.ports[0].nodePort} --namespace $DESIREDNAMESPACE `/alfresco

#On MINIKUBE: Open Alfresco Share in Browser
open http://$ELBADDRESS:`kubectl get service $DBPRELEASE-alfresco-content-services-share -o jsonpath={.spec.ports[0].nodePort} --namespace $DESIREDNAMESPACE `/share

#On MINIKUBE: Open Alfresco Process Services in Browser
open http://$ELBADDRESS:`kubectl get service $DBPRELEASE-alfresco-process-services -o jsonpath={.spec.ports[0].nodePort} --namespace $DESIREDNAMESPACE `/activiti-app

```

If you want to see the full list of values that have been applied to the deployment you can run:

```bash
helm get values -a $DBPRELEASE
```

### 10. Teardown:

```bash
helm delete $INFRARELEASE
helm delete $DBPRELEASE
kubectl delete namespace $DESIREDNAMESPACE
```
Depending on your cluster type you should be able to also delete it if you want.
For minikube you can just run
```bash
minikube delete
```
For more information on running and tearing down k8s environemnts, follow this [guide](https://github.com/Alfresco/alfresco-anaxes-shipyard/blob/master/docs/running-a-cluster.md).
