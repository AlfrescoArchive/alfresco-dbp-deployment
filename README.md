# Alfresco Digital Business Platform Deployment

The Alfresco Digital Business Platform can be deployed to different environments such as AWS or locally.

- [Deploy to AWS](#AWS)
- [Deploy to Docker for Desktop - Mac](#docker-for-desktop---mac)

# AWS

## Prerequisites

The Alfresco Digital Business Platform Deployment requires:

| Component   | Recommended version | Getting Started Guide |
| ------------|:-----------: | ---------------------- |
| Docker      | 17.0.9.1     | https://docs.docker.com/ |
| Kubernetes  | 1.8.4        | https://kubernetes.io/docs/tutorials/kubernetes-basics/ |
| Kubectl     | 1.8.4        | https://kubernetes.io/docs/tasks/tools/install-kubectl/ |
| Helm        | 2.8.2        | https://docs.helm.sh/using_helm/#quickstart-guide |
| Kops        | 1.8.1        | https://github.com/kubernetes/kops/blob/master/docs/aws.md |

Any variation from these technologies and versions may affect the end result. If you do experience any issues please let us know through our [Gitter channel](https://gitter.im/Alfresco/platform-services?utm_source=share-link&utm_medium=link&utm_campaign=share-link).

*Note:* You do not need to clone this repo to deploy the dbp.

### Kubernetes Cluster

For more information please check the Anaxes Shipyard documentation on [running a cluster](https://github.com/Alfresco/alfresco-anaxes-shipyard/blob/master/docs/running-a-cluster.md).

Resource requirements for AWS: 
* A VPC and cluster with 5 nodes. Each node should be a m4.xlarge EC2 instance.

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

### Ingress Customization

For routing the components of the DBP deployment outside the k8s cluster we use [nginx-ingress](https://github.com/kubernetes/charts/tree/master/stable/nginx-ingress). For your deployment to function properly you must have a route53 DNSZone and you will need to create a route53 record set in the following steps.

For more options on configuring the ingress controller that is deployed through the alfresco-infrastructure chart, please check the [Alfresco Infrastructure](https://github.com/Alfresco/alfresco-infrastructure-deployment) chart Readme.

## Deployment

### 1. EFS Storage

Create an [EFS storage](https://docs.aws.amazon.com/efs/latest/ug/creating-using-create-fs.html) on AWS and make sure 
it is in the same VPC as your cluster. Make sure you [open inbound traffic](https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_SecurityGroups.html) 
in the security group to allow NFS traffic. 

Save the name of the server ex:
```bash
export NFSSERVER=fs-d660549f.efs.us-east-1.amazonaws.com
```

***Note!***
The Persistent volume created to store the data on the created EFS has the ReclaimPolicy set to Recycle.
This means that by default, when you delete the release the saved data is deleted automatically.

To change this behaviour and keep the data you can set the alfresco-infrastructure.persistence.reclaimPolicy value to Retain.
For more Information on Reclaim Policies checkout the official K8S documentation here -> https://kubernetes.io/docs/concepts/storage/persistent-volumes/#reclaim-policy

We don't advise you to use the same EFS instance for persisting the data from multiple dbp deployments.

### 2. Add the Alfresco Helm repository to helm

```helm repo add alfresco-incubator https://kubernetes-charts.alfresco.com/incubator```

### 3. Define a variable for your Route53 entry that you will use for the deployment

```bash
export ELB_CNAME="YourDesiredCname.YourRoute53DnsZone"
#example export ELB_CNAME="alfresco.example.com"
```

### 4. Deploy the DBP

```bash
# Remember to use https here if you have a trusted certificate set on the ingress
helm install alfresco-incubator/alfresco-dbp \
--set alfresco-infrastructure.alfresco-api-gateway.keycloakURL="http://$ELB_CNAME/auth/" \
--set alfresco-infrastructure.persistence.efs.enabled=true \
--set alfresco-infrastructure.persistence.efs.dns="$NFSSERVER" \
--set alfresco-content-services.externalHost="$ELB_CNAME" \
--set alfresco-content-services.networkpolicysetting.enabled=false \
--set alfresco-content-services.repository.environment.IDENTITY_SERVICE_URI="http://$ELB_CNAME/auth" \
--set alfresco-process-services.processEngine.environment.IDENTITY_SERVICE_AUTH="http://$ELB_CNAME/auth" \
--namespace=$DESIREDNAMESPACE
```

You can either deploy the dbp fully or choose the components you need for your specific case. 
By default the dbp chart will deploy fully.

To disable specific components you can set the following values to false when deploying:
```
alfresco-content-services.enabled
alfresco-process-services.enabled
alfresco-sync-service.enabled
alfresco-infrastructure.nginx-ingress.enabled
```

Example: For disabling sync-service you will need to append the following subcommand to the helm install command:
```bash
--set alfresco-sync-service.enabled=false 
```

### 5. Get the DBP release name from the previous command and set it as a variable:

```bash
export DBPRELEASE=littering-lizzard
```

### 6. Get ELB IP and copy it for linking the ELB in AWS Route53:

```bash
export ELBADDRESS=$(kubectl get services $DBPRELEASE-nginx-ingress-controller --namespace=$DESIREDNAMESPACE -o jsonpath={.status.loadBalancer.ingress[0].hostname})
echo $ELBADDRESS
```

### 7. Create a Route 53 Record Set in your Hosted Zone

* Go to **AWS Management Console** and open the **Route 53** console.
* Click **Hosted Zones** in the left navigation panel, then **Create Record Set**.
* In the **Name** field, enter your "`$ELB_CNAME`" defined in step 4.
* In the **Alias Target**, select your ELB address ("`$ELBADDRESS`").
* Click **Create**.

You may need to wait a couple of minutes before the record set propagates around the world.

### 8. Checkout the status of your DBP deployment:

*Note:* When checking status, your pods should be ```READY 1/1```

```bash
helm status $DBPRELEASE
```

If you want to see the full list of values that have been applied to the deployment you can run:

```bash
helm get values -a $DBPRELEASE
```

### 9. Teardown:

```bash
helm delete --purge $DBPRELEASE
kubectl delete namespace $DESIREDNAMESPACE
```
Depending on your cluster type you should be able to also delete it if you want.

For more information on running and tearing down k8s environments, follow this [guide](https://github.com/Alfresco/alfresco-anaxes-shipyard/blob/master/docs/running-a-cluster.md).

***Notes***

Because some of our modules pass headers bigger than 4k we had to increase the default value of the proxy buffer size for nginx.
We also enable the CORS header for the applications that need it through the Ingress Rule.

# Docker for Desktop - Mac

## Prerequisites

| Component   | Recommended version | Getting Started Guide |
| ------------|:-----------: | ----------------------   |
| Docker for Desktop | 18.06.1-ce   | https://www.docker.com/products/docker-desktop |
| Homebrew           | 1.7.6        | https://brew.sh/         |
| Helm               | 2.8.2        | https://docs.helm.sh/using_helm/#quickstart-guide |

## Setup

After installing Docker for Desktop you must enable Kubernetes and we recommend that you increase the memory and cores used by Docker for Desktop.

- Memory mimimum: 8 GB
- Core minimum: 4 cores

We also recommend that you use Homebrew to install the Helm prerequisite. The homebrew package name is kubernetes-helm.

If you have previously deployed the DBP to AWS you will need to change/verify the `docker-for-desktop` context is being used.

```bash
kubectl config current-context                 # Display the current context
kubectl config use-context docker-for-desktop  # Set the default context
```

### Helm Tiller

Initialize the Helm Tiller:
```bash
helm init
```

## Deployment

### 1. Add the Alfresco Helm repository to helm

```bash
helm repo add alfresco-incubator https://kubernetes-charts.alfresco.com/incubator
```

### 2. Add local DNS

Add Local DNS Entry for Host Machine (needed for JWT issuer matching). Be sure to specify an active network interface.  It is not always `en0` as illustrated.  You can use the command `ipconfig -a` to find an active interface.

```bash
sudo sh -c 'echo "`ipconfig getifaddr en0`       localhost-k8s" >> /etc/hosts'; cat /etc/hosts
```

*Note:* If your IP address changes you will need to update the `/etc/hosts` entry for localhost-k8s.

### 3. Deploy the DBP

The extended install command configures the hostnames, URLs and memory requirements needed to run in Docker for Desktop.  It also configures the time for initiating the kubernetes probes to test if a serivce is available.

```bash
helm install alfresco-incubator/alfresco-dbp \
--set alfresco-infrastructure.alfresco-api-gateway.keycloakURL="http://localhost-k8s/auth/" \
--set alfresco-infrastructure.rabbitmq-ha.enabled=false \
--set alfresco-infrastructure.alfresco-activiti-cloud-registry.enabled=false \
--set alfresco-infrastructure.alfresco-api-gateway.enabled=false \
--set alfresco-content-services.externalHost="localhost-k8s" \
--set alfresco-content-services.networkpolicysetting.enabled=false \
--set alfresco-content-services.repository.environment.IDENTITY_SERVICE_URI="http://localhost-k8s/auth" \
--set alfresco-content-services.repository.replicaCount=1 \
--set alfresco-content-services.repository.livenessProbe.initialDelaySeconds=420 \
--set alfresco-content-services.pdfrenderer.livenessProbe.initialDelaySeconds=300 \
--set alfresco-content-services.libreoffice.livenessProbe.initialDelaySeconds=300 \
--set alfresco-content-services.imagemagick.livenessProbe.initialDelaySeconds=300 \
--set alfresco-content-services.share.livenessProbe.initialDelaySeconds=420 \
--set alfresco-content-services.repository.resources.requests.memory="2000Mi" \
--set alfresco-content-services.pdfrenderer.resources.requests.memory="500Mi" \
--set alfresco-content-services.imagemagick.resources.requests.memory="500Mi" \
--set alfresco-content-services.libreoffice.resources.requests.memory="500Mi" \
--set alfresco-content-services.share.resources.requests.memory="1000Mi" \
--set alfresco-content-services.postgresql.resources.requests.memory="500Mi" \
--set alfresco-process-services.processEngine.environment.IDENTITY_SERVICE_AUTH="http://localhost-k8s/auth" \
--set alfresco-process-services.processEngine.environment.IDENTITY_SERVICE_ENABLED=true \
--set alfresco-process-services.processEngine.resources.requests.memory="1000Mi" \
--set alfresco-process-services.adminApp.resources.requests.memory="250Mi"
```

### 4. Check deployment status of DBP

```bash
kubectl get pods
```

*Note:* When checking status, your pods should be `READY 1/1` and `STATUS Running`

### 5. Check DBP Components

You can access DBP components at the following address
- http://localhost-k8s/alfresco
- http://localhost-k8s/share
- http://localhost-k8s/content-app
- http://localhost-k8s/activiti-app
- http://localhost-k8s/activiti-admin
- http://localhost-k8s/auth/

*Notes:*

- As deployed, the activiti-app starts in read-only mode.  
  - Apply a license by uploading an Activiti license file after deployment.

- As deployed, the activiti-admin app does not work because it is not configured with the correct server endpoint. 
  - To fix that, click 'Edit endpoint configuration' and then in the form enter http://localhost-k8s for the server address.
  - Save the form and  click 'Check Process Services REST endpoint' to see if it is valid.

- The http://localhost-k8s/activiti-admin/solr endpoint is disabled by default.   
  - See https://github.com/Alfresco/acs-deployment/blob/master/docs/examples/search-external-access.md for more information.

### 6. Teardown:

```bash
helm ls
```
Use the name of the DBP release found above as DBPRELEASE
```bash 
helm delete --purge <DBPRELEASE>
```

### Notes

#### K8s Cluster Namespace

If you are deploying multiple projects in your Docker for Desktop Kuberenetes Cluster you may find it useful to use namespaces to segment the projects.

To create a namespace
```bash
export DESIREDNAMESPACE=example
kubectl create namespace $DESIREDNAMESPACE
```

You can then use this environment variable `DESIREDNAMESPACE` in the deployment steps by appending `--namespace $DESIREDNAMESPACE` to the `helm` and `kubectl` commands.

You may also need to remove this namespace when you no longer need it.

```bash
kubectl delete namespace $DESIREDNAMESPACE
```