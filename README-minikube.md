# Alfresco Digital Business Platform Deployment on Minikube

### Disclaimer: Minikube deployments aren't officially supported

Although we have conducted some limited testing of Alfresco Digital Business Platform
deployments on Minikube and believe the information below is accurate,
we can neither guarantee its performance nor suitability for purpose.
Please refer to the main [Alfresco Digital Business Platform](README.md)
document for details about supported platforms.

## Prerequisites

The Alfresco Digital Business Platform Deployment requires:

| Component   | Recommended version | Getting Started Guide |
| ------------|:-----------: | ---------------------- |
| Docker      | 17.0.9.1     | https://docs.docker.com/ |
| Kubernetes  | 1.8.4        | https://kubernetes.io/docs/tutorials/kubernetes-basics/ |
| Kubectl     | 1.8.4        | https://kubernetes.io/docs/tasks/tools/install-kubectl/ |
| Helm        | 2.8.2        | https://docs.helm.sh/using_helm/#quickstart-guide |
| Kops        | 1.8.1        | https://github.com/kubernetes/kops/blob/master/docs/aws.md |
| Minikube    | 0.25.0       | https://kubernetes.io/docs/getting-started-guides/minikube/ |

Any variation from these technologies and versions may affect the end result. If you do experience any issues please let us know through our [Gitter channel](https://gitter.im/Alfresco/platform-services?utm_source=share-link&utm_medium=link&utm_campaign=share-link).

*Note*: You do not need to clone this repo to deploy the dbp.

### Kubernetes Cluster

Please check the Anaxes Shipyard documentation on [running a cluster](https://github.com/Alfresco/alfresco-anaxes-shipyard/blob/master/docs/running-a-cluster.md).

Note the resource requirements:
* Minikube: At least 12 Gb of memory, i.e.:
```bash
minikube start --memory 12000
```

### Helm Tiller

Initialize the Helm Tiller:
```bash
helm init
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

### 1. Install the nginx-ingress-controller

Install the nginx-ingress-controller into your cluster
```bash
helm repo update

cat <<EOF > ingressvalues.yaml
controller:
  config:
    ssl-redirect: "false"
  scope:
    enabled: true
    namespace: $DESIREDNAMESPACE
EOF

helm install stable/nginx-ingress --version=0.12.3 -f ingressvalues.yaml \
--namespace $DESIREDNAMESPACE
```


** !Optional **

If you want your own certificate set here you should create a secret from your cert files:

```bash
kubectl create secret tls certsecret --key /tmp/tls.key --cert /tmp/tls.crt --namespace $DESIREDNAMESPACE
```

Then deploy the ingress with following settings
```bash
cat <<EOF > ingressvalues.yaml
controller:
  config:
    ssl-redirect: "false"
  scope:
    enabled: true
    namespace: $DESIREDNAMESPACE
  publishService:
    enabled: true
  extraArgs:
    default-ssl-certificate: $DESIREDNAMESPACE/certsecret
EOF

helm install stable/nginx-ingress --version=0.12.3 -f ingressvalues.yaml \
--namespace $DESIREDNAMESPACE
```


### 2. Get the nginx-ingress-controller release name from the previous command and set it as a varible:
```bash
export INGRESSRELEASE=knobby-wolf
```

### 3. Wait for the nginx-ingress-controller release to get deployed:
```bash
helm status $INGRESSRELEASE
```

*Note:* When checking status, your pods should be ```READY 1/1```

### 4. Get the nginx-ingress-controller port for the infrastructure :
```bash
export INFRAPORT=$(kubectl get service $INGRESSRELEASE-nginx-ingress-controller --namespace $DESIREDNAMESPACE -o jsonpath={.spec.ports[0].nodePort})
```

### 5. Get Minikube or ELB IP and set it as a variable for future use:

```bash
export ELBADDRESS=$(minikube ip)
```

### 6. Add the Alfresco Helm repository to helm

```helm repo add alfresco-incubator https://kubernetes-charts.alfresco.com/incubator```

### 7. Deploy the DBP

```bash
helm install alfresco-incubator/alfresco-dbp \
--set alfresco-infrastructure.alfresco-identity-service.ingressHostName="$ELBADDRESS:$INFRAPORT" \
--set alfresco-content-services.repository.environment.IDENTITY_SERVICE_URI="http://$ELBADDRESS:$INFRAPORT/auth" \
--set alfresco-process-services.processEngine.environment.IDENTITY_SERVICE_AUTH="http://$ELBADDRESS:$INFRAPORT/auth" \
--namespace=$DESIREDNAMESPACE
```

You can either deploy the dbp fully or choose the components you need for your specific case. 
By default the dbp chart will deploy fully.

To disable specific components you can set the following values to false when deploying:
```
alfresco-content-services.enabled
alfresco-process-services.enabled
alfresco-sync-service.enabled
```

Example: For disabling sync-service you will need to append the following subcommand to the helm install command:
```bash
 --set alfresco-sync-service.enabled=false 
```

### 8. Get the DBP release name from the previous command and set it as a variable:

```bash
export DBPRELEASE=littering-lizzard
```

### 9. Checkout the status of your DBP deployment:

```bash
helm status $INGRESSRELEASE
helm status $DBPRELEASE

# Open Alfresco Repository in Browser
open http://$ELBADDRESS:`kubectl get service $DBPRELEASE-alfresco-content-services-repository -o jsonpath={.spec.ports[0].nodePort} --namespace $DESIREDNAMESPACE `/alfresco

# Open Alfresco Share in Browser
open http://$ELBADDRESS:`kubectl get service $DBPRELEASE-alfresco-content-services-share -o jsonpath={.spec.ports[0].nodePort} --namespace $DESIREDNAMESPACE `/share

# Open Alfresco Process Services in Browser
open http://$ELBADDRESS:`kubectl get service $DBPRELEASE-alfresco-process-services -o jsonpath={.spec.ports[0].nodePort} --namespace $DESIREDNAMESPACE `/activiti-app
```

If you want to see the full list of values that have been applied to the deployment you can run:

```bash
helm get values -a $DBPRELEASE
```

### 10. Teardown:

```bash
helm delete --purge $INGRESSRELEASE
helm delete --purge $DBPRELEASE
kubectl delete namespace $DESIREDNAMESPACE
```
You can also just simply delete the whole minikube vm.
```bash
minikube delete
```

For more information on running and tearing down k8s environments, follow this [guide](https://github.com/Alfresco/alfresco-anaxes-shipyard/blob/master/docs/running-a-cluster.md).

***Notes***

Because some of our modules pass headers bigger than 4k we had to increase the default value of the proxy buffer size for nginx.
We also enable the CORS header for the applications that need it through the Ingress Rule.
