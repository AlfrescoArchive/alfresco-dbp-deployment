# Alfresco Digital Business Platform Deployment

## Prerequisites

The Alfresco Digital Business Platform Deployment requires:

| Component        | Recommended version |
| ------------- |:-------------:|
| Docker     | 17.0.9.1 |
| Kubernetes | 1.8.4    |
| Helm       | 2.8.2    |
| Minikube   | 0.25.0   |

Any variation from these technologies and versions may affect the end result. If you do experience any issues please let us know through our [Gitter channel](https://gitter.im/Alfresco/platform-services?utm_source=share-link&utm_medium=link&utm_campaign=share-link).

*Note*: You do not need to clone this repo to deploy the dbp.

### Kubernetes Cluster

You can choose to deploy the infrastructure to a local kubernetes cluster (illustrated using minikube) or you can choose to deploy to the cloud (illustrated using AWS).
Please check the Anaxes Shipyard documentation on [running a cluster](https://github.com/Alfresco/alfresco-anaxes-shipyard/blob/master/docs/running-a-cluster.md).

Note the resource requirements:
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

Or you can add an AWS generated certificate if you want and autogenerate a route53 entry

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
  service:
    targetPorts:
      https: 80
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-ssl-cert: #sslcert ARN -> https://github.com/kubernetes/kubernetes/blob/master/pkg/cloudprovider/providers/aws/aws.go
      service.beta.kubernetes.io/aws-load-balancer-ssl-ports: https
      # External dns will help you autogenerate an entry in route53 for your cluster. More info here -> https://github.com/kubernetes-incubator/external-dns
      external-dns.alpha.kubernetes.io/hostname: $DESIREDNAMESPACE.YourDNSZone
EOF

helm install stable/nginx-ingress --version=0.12.3 -f ingressvalues.yaml \
--namespace $DESIREDNAMESPACE

```

### 2. Get the nginx-ingress-controller release name from the previous command and set it as a varible:
```bash
export INGRESSRELEASE=knobby-wolf
```

### 3. Wait for the nginx-ingress-controller release to get deployed (When checking status your pod should be READY 1/1):
```bash
helm status $INGRESSRELEASE
```

### 4. (**NOTE! ONLY FOR MINIKUBE**) Get the nginx-ingress-controller port for the infrastructure :
```bash
export INFRAPORT=$(kubectl get service $INGRESSRELEASE-nginx-ingress-controller --namespace $DESIREDNAMESPACE -o jsonpath={.spec.ports[0].nodePort})
```

### 5. Get Minikube or ELB IP and set it as a variable for future use:

```bash
#ON MINIKUBE
export ELBADDRESS=$(minikube ip)

#ON AWS
export ELBADDRESS=$(kubectl get services $INGRESSRELEASE-nginx-ingress-controller --namespace=$DESIREDNAMESPACE -o jsonpath={.status.loadBalancer.ingress[0].hostname})
```

### 6. EFS Storage (**NOTE! ONLY FOR AWS!**)

Create a EFS storage on AWS and make sure it is in the same VPC as your cluster. Make sure you open inbound traffic in the security group to allow NFS traffic. Save the name of the server ex:
```bash
export NFSSERVER=fs-d660549f.efs.us-east-1.amazonaws.com
```

***Note!***
The Persistent volume created to store the data on the created EFS has the ReclaimPolicy set to Recycle.
This means that by default, when you delete the release the saved data is deleted automatically.

To change this behaviour and keep the data you can set the alfresco-infrastructure.persistence.reclaimPolicy value to Retain.
For more Information on Reclaim Policies checkout the official K8S documentation here -> https://kubernetes.io/docs/concepts/storage/persistent-volumes/#reclaim-policy

We don't advise you to use the same EFS instance for persisting the data from multiple dbp deployments.

### 7. Add the Alfresco Kubernetes repository to helm.

```helm repo add alfresco-incubator http://kubernetes-charts.alfresco.com/incubator```

### 8. Deploy the DBP

```bash

#On MINIKUBE
helm install alfresco-incubator/alfresco-dbp \
--set alfresco-infrastructure.alfresco-api-gateway.keycloakURL="http://$ELBADDRESS:$INFRAPORT/auth/" \
--set alfresco-infrastructure.alfresco-identity-service.ingressHostName="$ELBADDRESS:$INFRAPORT" \
--set alfresco-content-services.repository.environment.IDENTITY_SERVICE_URI="http://$ELBADDRESS:$INFRAPORT/auth" \
--namespace=$DESIREDNAMESPACE

#On AWS
# Remember to use https here if you have a trusted certificate set on the ingress
helm install alfresco-incubator/alfresco-dbp \
--set alfresco-infrastructure.alfresco-api-gateway.keycloakURL="http://$ELBADDRESS/auth/" \
--set alfresco-infrastructure.persistence.efs.enabled=true \
--set alfresco-infrastructure.persistence.efs.dns="$NFSSERVER" \
--set alfresco-infrastructure.alfresco-identity-service.ingressHostName="$ELBADDRESS" \
--set alfresco-content-services.repository.environment.IDENTITY_SERVICE_URI="http://$ELBADDRESS/auth" \
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

### 9. Get the DBP release name from the previous command and set it as a variable:

```bash
export DBPRELEASE=littering-lizzard
```

### 10. Checkout the status of your DBP deployment:

```bash
helm status $INGRESSRELEASE
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

### 11. Teardown:

```bash
helm delete --purge $INGRESSRELEASE
helm delete --purge $DBPRELEASE
kubectl delete namespace $DESIREDNAMESPACE
```
Depending on your cluster type you should be able to also delete it if you want.
For minikube you can just run to delete the whole minikube vm.
```bash
minikube delete
```

For more information on running and tearing down k8s environments, follow this [guide](https://github.com/Alfresco/alfresco-anaxes-shipyard/blob/master/docs/running-a-cluster.md).

***Notes***

Because some of our modules pass headers bigger than 4k we had to increase the default value of the proxy buffer size for nginx.
We also enable the CORS header for the applications that need it through the Ingress Rule.
