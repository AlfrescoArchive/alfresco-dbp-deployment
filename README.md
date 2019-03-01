# Alfresco Digital Business Platform Deployment

Check [prerequisites section](https://github.com/Alfresco/alfresco-dbp-deployment/blob/master/README-prerequisite.md) before you start.

The Alfresco Digital Business Platform can be deployed to different environments such as AWS or locally.

- [Deploy to AWS using KOPS](#aws)
- [Deploy to AWS using EKS](README-cfn.md)
- [Deploy to Docker for Desktop - Mac](#docker-for-desktop---mac)

# AWS

*Note:* You do not need to clone this repo to deploy the dbp.

### Kubernetes Cluster

For more information please check the Anaxes Shipyard documentation on [running a cluster](https://github.com/Alfresco/alfresco-anaxes-shipyard/blob/master/docs/running-a-cluster.md).

Resource requirements for AWS: 
* A VPC and cluster with 5 nodes. Each node should be a m4.xlarge EC2 instance.

### Helm Tiller

Initialize the Helm Tiller:

```bash
helm init
kubectl create clusterrolebinding tiller-clusterrole-binding --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
```

*Note:* This setup will deploy the helm server component and will give helm access to the whole cluster. For a more secure, customized setup, please read -> https://helm.sh/docs/using_helm/#role-based-access-control

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

```
helm repo add alfresco-incubator https://kubernetes-charts.alfresco.com/incubator
helm repo add alfresco-stable https://kubernetes-charts.alfresco.com/stable
```

### 3. Configure domain in your values file

Depending on the dnszone you have configured in our aws account, define an entry you would like to use for your deployment.

```bash
export DNSZONE=YourDesiredCname.YourRoute53DnsZone
```

Afterwards pull the helm values file from the current repo:

```bash
curl -O https://raw.githubusercontent.com/Alfresco/alfresco-dbp-deployment/master/charts/incubator/alfresco-dbp/values.yaml
sed -i s/REPLACEME/$DNSZONE/g values.yaml
```

Note! The name for the DNS entry you are defining here will be set in route53 later on.

### 4. Deploy the DBP

```bash
# From within the same folder as your values file
helm install alfresco-incubator/alfresco-dbp -f values.yaml \
--set alfresco-infrastructure.persistence.efs.enabled=true \
--set alfresco-infrastructure.persistence.efs.dns="$NFSSERVER" \
--namespace=$DESIREDNAMESPACE
```

You can either deploy the dbp fully or choose the components you need for your specific case. 
By default the dbp chart will deploy fully.

To disable specific components you can set the following values to false when deploying:
```
alfresco-content-services.enabled
activiti-cloud-full-example.enabled
alfresco-sync-service.enabled
alfresco-infrastructure.nginx-ingress.enabled
```

Example: For disabling sync-service you will need to append the following subcommand to the helm install command:
```bash
--set alfresco-sync-service.enabled=false 
```
If you are using `https` you should include the following setting in your helm install command:

```bash
--set alfresco-content-services.externalProtocol="https" \
```

If you want to include multiple uris for alfresco client redirect uris check this [guide](https://github.com/Alfresco/alfresco-identity-service#changing-alfresco-client-redirecturis).

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
* In the **Name** field, enter your dns name defined in step 3 prefixed by "*." , for example: "`*.YourDesiredCname.YourRoute53DnsZone`".
* In the **Alias Target**, select your ELB address ("`$ELBADDRESS`").
* Click **Create**.

You may need to wait a couple of minutes before the record set propagates around the world.

### 8. Checkout the status of your DBP deployment:

*Note:* When checking status, your pods should be ```READY x/x```

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

## Deployment

### 1. Install Docker for Desktop

Check recommended version [here](https://github.com/Alfresco/alfresco-dbp-deployment/blob/master/README-prerequisite.md#docker-desktop).

### 2. Enable Kubernetes

In the 'Kubernetes' tab of the Docker preferences,  click the 'Enable Kubernetes' checkbox.

### 3. Increase Memory and CPUs

In the Advanced tab of the Docker preferences, set 'CPUs' to 4.

While Alfresco Digital Business Platform installs and runs with only 10 GiB allocated to Docker, 
for better performance we recommend that 'Memory' value be set slightly higher, to at least 14 GiB
(depending on the size of RAM in your workstation).

### 4. Change/Verify Context

If you have previously deployed the DBP to AWS or minikube you will need to change/verify that the `docker-for-desktop` context is being used.

```bash
kubectl config current-context                 # Display the current context
kubectl config use-context docker-for-desktop  # Set the default context if needed
```

### 5. Install Helm Client

```bash
brew update; brew install kubernetes-helm
```

### 6. Initialize Helm Tiller (Server Component)

```bash
helm init
kubectl create clusterrolebinding tiller-clusterrole-binding --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
```

*Note:* This setup will deploy the helm server component and will give helm access to the whole cluster. For a more secure, customized setup, please read -> https://helm.sh/docs/using_helm/#role-based-access-control

### 7. Add the Alfresco Incubator Helm Repository

```bash
helm repo add alfresco-incubator https://kubernetes-charts.alfresco.com/incubator
helm repo add alfresco-stable https://kubernetes-charts.alfresco.com/stable
```

### 8. Add Local DNS

We will be forming a local dns with the use of nip.io. All you have to do it get your ip using the following command.

```bash
export LOCALIP=$(ipconfig getifaddr en0)
```

*Note:* Save this ip for later use.

### 9. Docker Registry Pull Secrets

See the Anaxes Shipyard documentation on [secrets](https://github.com/Alfresco/alfresco-anaxes-shipyard/blob/master/SECRETS.md).

*Note*: You can reuse the secrets.yaml file from charts/incubator directory.  

### 10. Download and modify the minimal-values.yaml file

The minimal-values.yaml file contains values for local only development and multiple components are disabled with the purpose of reducing the memory footprint of the Digital Business Platform. This should not be used as a starting point for production use.

Pull the minimal values file from the current repo:

```bash
curl -O https://raw.githubusercontent.com/Alfresco/alfresco-dbp-deployment/master/charts/incubator/alfresco-dbp/minimal-values.yaml
sed -i s/REPLACEME/$LOCALIP/g minimal-values.yaml
```

### 11. Deploy the DBP

```bash
# From within the same folder as your minimal-values file
helm install alfresco-incubator/alfresco-dbp -f minimal-values.yaml
```

### 12. Check Deployment Status of DBP

```bash
kubectl get pods
```

*Note:* When checking status, your pods should be `READY x/x` and `STATUS Running`

### 13. Check DBP Components

You can access DBP components at the following URLs:


  Alfresco Digital Workspace: http://alfresco-cs-repository.YOURIP.nip.io/digital-workspace/
  Content: http://alfresco-cs-repository.YOURIP.nip.io/alfresco
  Share: http://alfresco-cs-repository.YOURIP.nip.io/share
  Alfresco Identity Service: http://alfresco-identity-service.YOURIP.nip.io/auth
  Activiti Cloud Gateway: http://activiti-cloud-gateway.YOURIP.nip.io
  Activiti Modeling App: http://activiti-cloud-gateway.YOURIP.nip.io/activiti-cloud-modeling

  
### 14. Teardown:

```bash
helm ls
```
Use the name of the DBP release found above as DBPRELEASE
```bash 
helm delete --purge <DBPRELEASE>
```

### Notes

#### kubectl not found

In some cases, after installing Docker for Desktop and enabling Kubernetes, the `kubectl` command may not be found. 
Docker for Desktop also installs the command as `kubectl.docker`. 
We would recommend using this command over installing the kubernetes cli which may not match the version of kubernetes that Docker for Desktop is using. 

#### K8s Cluster Namespace

If you are deploying multiple projects in your Docker for Desktop Kuberenetes Cluster you may find it useful to use namespaces to segment the projects.

To create a namespace:
```bash
export DESIREDNAMESPACE=example
kubectl create namespace $DESIREDNAMESPACE
```

You can then use this environment variable `DESIREDNAMESPACE` in the deployment steps by appending `--namespace $DESIREDNAMESPACE` to the `helm` and `kubectl` commands.

You may also need to remove this namespace when you no longer need it.

```bash
kubectl delete namespace $DESIREDNAMESPACE
```

#### K8s Dashboard

You may find it helpful to see the Kubernetes resources visually which can be achieved by installing the Kubernetes Dashboard: https://github.com/kubernetes/dashboard/wiki/Installation

## Troubleshooting

**Error: Invalid parameter: redirect_uri**

After deploying the DBP, when accesing one of the applications, for example Process Services, if you receive the error message *We're sorry Invalid parameter: redirect_uri*, the `redirectUris` parameter provided for deployment is invalid. Make sure the `alfresco-infrastructure.alfresco-identity-service.client.alfresco.redirectUris` parameter has a valid value when installing the chart. For more details on how to configure it, check this [guide](https://github.com/Alfresco/alfresco-identity-service#changing-alfresco-client-redirecturis).