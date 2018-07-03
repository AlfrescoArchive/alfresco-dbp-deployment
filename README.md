# Alfresco Digital Business Platform Deployment

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

For mode information please check the Anaxes Shipyard documentation on [running a cluster](https://github.com/Alfresco/alfresco-anaxes-shipyard/blob/master/docs/running-a-cluster.md).

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

For more options on configuring the ingress controller that is deployed trough the alfresco-infrastructure chart please check the [Alfresco Infrastructure](https://github.com/Alfresco/alfresco-infrastructure-deployment/tree/DEPLOY-456#nginx-ingress-custom-configuration) chart Readme.

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

```helm repo add alfresco-incubator http://kubernetes-charts.alfresco.com/incubator```

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
--set alfresco-infrastructure.persistence.efs.dns="$ELB_CNAME" \
--set alfresco-content-services.externalHost="$ELB_CNAME" \
--set alfresco-content-services.networkpolicysetting.enabled=false \
--set alfresco-content-services.repository.environment.IDENTITY_SERVICE_URI="http://$ELB_CNAME/auth" \
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
