# Alfresco Digital Business Platform Deployment

## Prerequisites

The Alfresco Digital Business Platform Deployment requires:

| Component        | Recommended version |
| ------------- |:-------------:|
| Docker     | 17.0.9.1 |
| Kubernetes | 1.8.0    |
| Helm       | 2.7.0    |
| Minikube   | 0.25.0   |

Any variation from these technologies and versions may affect the end result. If you do experience any issues please let us know through our [Gitter channel](https://gitter.im/Alfresco/platform-services?utm_source=share-link&utm_medium=link&utm_campaign=share-link).

*Note*: You do not need to clone this repo to deploy the dbp.

### Deploy the infrastructure components

After you have installed the prerequisites, please install the infrastructure required.  The steps to install the infrastructure can be found in the [alfresco-infrastructure-deployment](https://github.com/Alfresco/alfresco-infrastructure-deployment/blob/master/README.md) project.

Environment variables from the infrastructure project will be used in the deployment steps below.

**Note! AWS ONLY ** 
We don't advise you to use the same EFS instance for persisting the data from multiple dbp deployments.

### Docker Registry Pull Secrets

See the Anaxes Shipyard documentation on [secrets](https://github.com/Alfresco/alfresco-anaxes-shipyard/blob/master/SECRETS.md).

*Note*: You can reuse the secrets.yaml file from charts/incubator directory. 

```bash
cd charts/incubator
cat ~/.docker/config.json | base64
```

Add the base64 string generated to .dockerconfigjson in secrets.yaml. The file should look similar to this:

```bash
apiVersion: v1
kind: Secret
metadata:
  name: quay-registry-secret
type: kubernetes.io/dockerconfigjson
data:
# Docker registries config json in base64 to do this just run - cat ~/.docker/config.json | base64
  .dockerconfigjson: ew0KCSJhdXRocyI6IHsNCgkJImh0dHBzOi8vcXVheS5pbyI6IHsNCgkJCSJhdXRoIjogImRHVnpkRHAwWlhOMD0iDQoJCX0sDQoJCSJxdWF5LmlvIjogew0KCQkJImF1dGgiOiAiZEdWemREcDBaWE4w550KCQl9DQoJfSwNCgkiSHR0cEhlYWRlcnMiOiB7DQoJCSJVc2VyLUFnZW50IjogIkRvY2tlci1DbGllbnQvMTcuMTIuMC1jZS1yYzMgKGRhcndpbikiDQoJfQ0KfQ==
```

Then run this command:

```bash
kubectl create -f secrets.yaml --namespace $DESIREDNAMESPACE
```

*Note*: Make sure the $DESIREDNAMESPACE variable has been set when the infrastructure chart was deployed so that the secret gets created in the same namespace.

## Deployment

### 1. Deploy the DBP

```bash

#On MINIKUBE
helm install alfresco-incubator/alfresco-dbp \
--set alfresco-sync-service.activemq.broker.host="${INFRARELEASE}-activemq-broker" \
--set alfresco-content-services.repository.environment.ACTIVEMQ_HOST="${INFRARELEASE}-activemq-broker" \
--set alfresco-content-services.repository.environment.SYNC_SERVICE_URI="http://$ELBADDRESS:$INFRAPORT/syncservice" \
--namespace=$DESIREDNAMESPACE

#On AWS
helm install alfresco-incubator/alfresco-dbp \
--set alfresco-sync-service.activemq.broker.host="${INFRARELEASE}-activemq-broker" \
--set alfresco-content-services.repository.environment.ACTIVEMQ_HOST="${INFRARELEASE}-activemq-broker" \
--set alfresco-content-services.repository.environment.SYNC_SERVICE_URI="http://$ELBADDRESS/syncservice" \
--namespace=$DESIREDNAMESPACE
```

You can either deploy the dbp fully or choose the components you need for your specific case. 
By default the dbp chart will deploy fully.

To disable specific components you can set the following values to false when deploying:

alfresco-content-services.enabled
alfresco-process-services.enabled
alfresco-sync-service.enabled

```bash
#example: For disabling sync-service you will need to append the following subcommand to the helm install command:
 --set alfresco-sync-service.enabled=false 
```

### 2. Get the DBP release name from the previous command and set it as a variable:

```bash
export DBPRELEASE=littering-lizzard
```

### 3. Checkout the status of your DBP deployment:

```bash
helm status $INGRESSRELEASE
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

### 4. Teardown:

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

For more information on running and tearing down k8s environments, follow this [guide](https://github.com/Alfresco/alfresco-anaxes-shipyard/blob/master/docs/running-a-cluster.md).
