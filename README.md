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

After you have installed the prerequisites, please install the infrastructure required.  The steps to install the infrastructure can be found in the [alfresco-infrastructure-deployment](https://github.com/Alfresco/alfresco-infrastructure-deployment/blob/master/README.md) project.

After installing the infrastructure, please run the following commands:

```bash
git clone https://github.com/Alfresco/alfresco-dbp-deployment.git
cd alfresco-dbp-deployment
```
Environment variables from the infrastructure project will be used in the deployment steps below.

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

### 1. Enable or disable the components you want up from the dbp deployment.
To do this open the alfresco-dbp/values.yaml file and set to true/false the components you want enabled.

Example:
alfresco-content-services:
  enabled: true

### 2. Deploy the DBP

```bash
helm repo add alfresco-dbp https://alfresco.github.io/charts/incubator

helm dependency update alfresco-dbp

#On MINIKUBE
helm install alfresco-dbp \
--set alfresco-sync-service.activemq.broker.host="${INGRESSRELEASE}-activemq-broker" \
--set alfresco-content-services.repository.environment.ACTIVEMQ_HOST="${INGRESSRELEASE}-activemq-broker" \
--set alfresco-content-services.repository.environment.SYNC_SERVICE_URI="http://$ELBADDRESS:$INFRAPORT/syncservice" \
--namespace=$DESIREDNAMESPACE

#On AWS
helm install alfresco-dbp \
--set alfresco-sync-service.activemq.broker.host="${INGRESSRELEASE}-activemq-broker" \
--set alfresco-content-services.repository.environment.ACTIVEMQ_HOST="${INGRESSRELEASE}-activemq-broker" \
--set alfresco-content-services.repository.environment.SYNC_SERVICE_URI="http://$ELBADDRESS/syncservice" \
--namespace=$DESIREDNAMESPACE
```

### 3. Get the DBP release name from the previous command and set it as a variable:
```bash
export DBPRELEASE=littering-lizzard
```

### 4. Checkout the status of your DBP deployment:

```bash
helm status $INGRESSRELEASE
helm status $INFRARELEASE
helm status $DBPRELEASE

#On MINIKUBE: Open Alfresco Repository in Browser
open http://$ELBADDRESS:`kubectl get service $DBPRELEASE-alfresco-content-services-repository --namespace $DESIREDNAMESPACE -o jsonpath={.spec.ports[0].nodePort}`/alfresco

#On MINIKUBE: Open Alfresco Share in Browser
open http://$ELBADDRESS:`kubectl get service $DBPRELEASE-alfresco-content-services-share --namespace $DESIREDNAMESPACE -o jsonpath={.spec.ports[0].nodePort}`/share

#On MINIKUBE: Open Alfresco Process Services in Browser
open http://$ELBADDRESS:`kubectl get service $DBPRELEASE-alfresco-process-services --namespace $DESIREDNAMESPACE -o jsonpath={.spec.ports[0].nodePort}`/activiti-app

```

### 5. Teardown:

```bash
helm delete $INGRESSRELEASE
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
