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

After you have installed the prerequisites please run the following commands:

```bash
git clone https://github.com/Alfresco/alfresco-dbp-deployment.git
cd alfresco-dbp-deployment
```

### Kubernetes Cluster

See the Anaxes Shipyard documentation on [running a cluster](https://github.com/Alfresco/alfresco-anaxes-shipyard/blob/master/SECRETS.md).

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

### K8s Cluster Namespace

As mentioned as part of the Anaxes Shipyard guidelines, you should deploy into a separate namespace in the cluster to avoid conflicts:
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

Add the base64 string generated to .dockerconfigjson in secrets.yaml and then run this command:

```bash
kubectl create -f secrets.yaml --namespace example
```

## Deployment

### 1. EFS Storage (**NOTE! ONLY FOR AWS!**)

Create a EFS storage on AWS and make sure it is in the same VPC as your cluster. Make sure you open inbound traffic in the security group to allow NFS traffic. Save the name of the server ex:
```bash
export NFSSERVER=fs-d660549f.efs.us-east-1.amazonaws.com
```

### 2. Deploy the infrastructure charts:
```bash
cd charts/incubator

helm dependency update alfresco-dbp-infrastructure

#ON MINIKUBE
helm install alfresco-dbp-infrastructure --namespace $DESIREDNAMESPACE

#ON AWS
helm install alfresco-dbp-infrastructure --namespace $DESIREDNAMESPACE --set persistence.volumeEnv=aws --set persistence.nfs.server="$NFSSERVER"
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
export INFRAPORT=$(kubectl get service $INFRARELEASE-nginx-ingress-controller --namespace $DESIREDNAMESPACE -o jsonpath={.spec.ports[0].nodePort})
```

### 6. Get Minikube or ELB IP and set it as a variable for future use:

```bash
#ON MINIKUBE
export ELBADDRESS=$(minikube ip)

#ON AWS
export ELBADDRESS=$(kubectl get services $INFRARELEASE-nginx-ingress-controller --namespace=$DESIREDNAMESPACE -o jsonpath={.status.loadBalancer.ingress[0].hostname})
```

### 7. Enable or disable the components you want up from the dbp deployment.
To do this open the alfresco-dbp/values.yaml file and set to true/false the components you want enabled.

Example:
alfresco-content-services:
  enabled: true

### 8. Deploy the DBP

```bash

helm dependency update alfresco-dbp

#On MINIKUBE
helm install alfresco-dbp \
--set alfresco-sync-service.activemq.broker.host="${INFRARELEASE}-alfresco-dbp-infrastructure-activemq" \
--set alfresco-sync-service.activemq.monitor.host="${INFRARELEASE}-alfresco-dbp-infrastructure-activemq-admin" \
--set alfresco-content-services.repository.environment.ACTIVEMQ_HOST="${INFRARELEASE}-alfresco-dbp-infrastructure-activemq" \
--set alfresco-content-services.repository.environment.SYNC_SERVICE_URI="http://$ELBADDRESS:$INFRAPORT/syncservice" \
--set alfresco-activiti-cloud-gateway.keycloakURL="http://$ELBADDRESS:$INFRAPORT/auth/" \
--set alfresco-activiti-cloud-gateway.eurekaURL="http://$ELBADDRESS:$INFRAPORT/registry/" \
--set alfresco-activiti-cloud-gateway.rabbitmqReleaseName="$INFRARELEASE-rabbitmq" \
--namespace=$DESIREDNAMESPACE

#On AWS
helm install alfresco-dbp \
--set alfresco-sync-service.activemq.host="${INFRARELEASE}-alfresco-dbp-infrastructure-activemq" \
--set alfresco-sync-service.activemq.monitor.host="${INFRARELEASE}-alfresco-dbp-infrastructure-activemq-admin" \
--set alfresco-content-services.repository.environment.ACTIVEMQ_HOST="${INFRARELEASE}-alfresco-dbp-infrastructure-activemq" \
--set alfresco-content-services.repository.environment.SYNC_SERVICE_URI="http://$ELBADDRESS/syncservice" \
--set alfresco-activiti-cloud-gateway.keycloakURL="http://$ELBADDRESS/auth/" \
--set alfresco-activiti-cloud-gateway.eurekaURL="http://$ELBADDRESS/registry/" \
--set alfresco-activiti-cloud-gateway.rabbitmqReleaseName="$INFRARELEASE-rabbitmq" \
--namespace=$DESIREDNAMESPACE
```

### 9. Get the DBP release name from the previous command and set it as a variable:
```bash
export DBPRELEASE=littering-lizzard
```

### 10. Checkout the status of your DBP deployment:

```bash
helm status $INFRARELEASE
helm status $DBPRELEASE

#On MINIKUBE: Open Alfresco Repository in Browser
open http://$ELBADDRESS:`kubectl get service $DBPRELEASE-alfresco-content-services-repository --namespace $DESIREDNAMESPACE -o jsonpath={.spec.ports[0].nodePort}`/alfresco

#On MINIKUBE: Open Alfresco Share in Browser
open http://$ELBADDRESS:`kubectl get service $DBPRELEASE-alfresco-content-services-share --namespace $DESIREDNAMESPACE -o jsonpath={.spec.ports[0].nodePort}`/share

#On MINIKUBE: Open Alfresco Process Services in Browser
open http://$ELBADDRESS:`kubectl get service $DBPRELEASE-alfresco-process-services --namespace $DESIREDNAMESPACE -o jsonpath={.spec.ports[0].nodePort}`/activiti-app

```

### 11. Teardown:

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
