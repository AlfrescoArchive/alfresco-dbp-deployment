# Alfresco Digital Business Platform Deployment

Check [prerequisites section](https://github.com/Alfresco/alfresco-dbp-deployment/blob/master/README-prerequisite.md) before you start.

The Alfresco Digital Business Platform can be deployed to different environments such as AWS or locally.

- [Deploy to AWS using KOPS](#aws)
- [Deploy to AWS using EKS](README-cfn.md)
- [Deploy to Docker for Desktop - Mac](#docker-for-desktop---mac)
- [Deploy to Docker for Desktop - Windows](#docker-for-desktop---windows)

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
--set alfresco-infrastructure.persistence.efs.enabled=true \
--set alfresco-infrastructure.persistence.efs.dns="$NFSSERVER" \
--set alfresco-infrastructure.alfresco-identity-service.client.alfresco.redirectUris=['\"'http://$ELB_CNAME*'"\'] \
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

## Deployment

### 1. Install Docker for Desktop

Check recommended version [here](https://github.com/Alfresco/alfresco-dbp-deployment/blob/master/README-prerequisite.md#docker-desktop).

### 2. Enable Kubernetes

In the 'Kubernetes' tab of the Docker preferences,  click the 'Enable Kubernetes' checkbox.

### 3. Increase Memory and CPUs

In the Advanced tab of the Docker preferences, set 'CPUs' to 4.

While Alfresco Digital Business Platform installs and runs with only 8 GiB allocated to Docker, 
for better performance we recommend that 'Memory' value be set slightly higher, to at least 10 - 12 GiB
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
```

### 7. Add the Alfresco Incubator Helm Repository

```bash
helm repo add alfresco-incubator https://kubernetes-charts.alfresco.com/incubator
```

### 8. Add Local DNS

Add Local DNS Entry for Host Machine (needed for JWT issuer matching). Be sure to specify an active network interface.  It is not always `en0` as illustrated.  You can use the command `ifconfig -a` to find an active interface.

```bash
sudo sh -c 'echo "`ipconfig getifaddr en0`       localhost-k8s" >> /etc/hosts'; cat /etc/hosts
```

*Note:* If your IP address changes you will need to update the `/etc/hosts` entry for localhost-k8s.

### 9. Docker Registry Pull Secrets

See the Anaxes Shipyard documentation on [secrets](https://github.com/Alfresco/alfresco-anaxes-shipyard/blob/master/SECRETS.md).

*Note*: You can reuse the secrets.yaml file from charts/incubator directory.  

### 10. Apply Alfresco Process Services license

If you have a valid Alfresco Process Services license, you can apply it at deployment time 
by creating a secret called `licenseaps` from your license file:
```bash
kubectl create secret generic licenseaps --from-file=./activiti.lic --namespace=$DESIREDNAMESPACE
```

This step is optional. If you choose not to deploy the license this way,
Alfresco Process Services will start up in read-only mode and you will need to apply it manually (see [Notes](#12-check-dbp-components) below).

### 11. Deploy the DBP

The extended install command configures the hostnames, URLs and memory requirements needed to run in Docker for Desktop.  It also configures the time for initiating the kubernetes probes to test if a service is available.

```bash
helm install alfresco-incubator/alfresco-dbp \
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
--set alfresco-process-services.processEngine.resources.requests.memory="1000Mi" \
--set alfresco-process-services.adminApp.resources.requests.memory="250Mi"
```

### 11. Check Deployment Status of DBP

```bash
kubectl get pods
```

*Note:* When checking status, your pods should be `READY 1/1` and `STATUS Running`

### 12. Check DBP Components

You can access DBP components at the following URLs:
- http://localhost-k8s/alfresco
- http://localhost-k8s/share
- http://localhost-k8s/digital-workspace/
- http://localhost-k8s/activiti-app
- http://localhost-k8s/activiti-admin
- http://localhost-k8s/auth/

*Notes:*

- As deployed, the activiti-app starts in read-only mode.  
  - Apply a license by uploading an Activiti license file after deployment.

- As deployed, the activiti-admin app does not work because it is not configured with the correct server endpoint. 
  - To fix that, click 'Edit Process Services REST Endpoint' and then in the form enter http://localhost-k8s for the server address.
  - Save the form and  click 'Check Process Services REST endpoint' to see if it is valid.

- The http://localhost-k8s/activiti-admin/solr endpoint is disabled by default.   
  - See https://github.com/Alfresco/acs-deployment/blob/master/docs/examples/search-external-access.md for more information.

### 13. Teardown:

```bash
helm ls
```
Use the name of the DBP release found above as DBPRELEASE
```bash 
helm delete --purge <DBPRELEASE>
```

### Notes

#### kubectl not found

In some cases, after installing Docker for Desktop and enabling Kubernetes, the `kubectl` command may not be found. Docker for Desktop also installs the command as `kubectl.docker`. We would recommend using this command over installing the kubernetes cli which may not match the version of kubernetes that Docker for Desktop is using. 

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

#### K8s Dashboard

You may find it helpful to see the Kubernetes resources visually which can be achieved by installing the Kubernetes Dashboard: https://github.com/kubernetes/dashboard/wiki/Installation

## Troubleshooting

**Error: Invalid parameter: redirect_uri**

After deploying the DBP, when accesing one of the applications, for example Process Services, if you receive the error message *We're sorry Invalid parameter: redirect_uri*, the `redirectUris` parameter provided for deployment is invalid. Make sure the `alfresco-infrastructure.alfresco-identity-service.client.alfresco.redirectUris` parameter has a valid value when installing the chart. For more details on how to configure it, check this [guide](https://github.com/Alfresco/alfresco-identity-service#changing-alfresco-client-redirecturis).


# Docker for Desktop - Windows

Note: All of the following commands will be using PowerShell. 

### 1. Install Docker for Desktop

Check recommended version [here](https://github.com/Alfresco/alfresco-dbp-deployment/blob/master/README-prerequisite.md#docker-desktop).

### 2. Enable Kubernetes

In the 'Kubernetes' tab of the Docker settings, click the 'Enable Kubernetes' checkbox.

Run Command Prompt as an administrator.

Enter the following commands to delete the storageClass hostpath and set up the hostpath provisioner: 

```bash
kubectl delete storageclass hostpath
kubectl create -f https://raw.githubusercontent.com/MaZderMind/hostpath-provisioner/master/manifests/rbac.yaml
kubectl create -f https://raw.githubusercontent.com/MaZderMind/hostpath-provisioner/master/manifests/deployment.yaml
kubectl create -f https://raw.githubusercontent.com/MaZderMind/hostpath-provisioner/master/manifests/storageclass.yaml
```

### 3. Increase Memory and CPUs

In the Advanced tab of the Docker preferences, set 'CPUs' to 4.

While Alfresco Digital Business Platform installs and runs with only 8 GiB allocated to Docker, 
for better performance we recommend that 'Memory' value be set slightly higher, to at least 10 - 12 GiB
(depending on the size of RAM in your workstation). 

### 4. Change/Verify Context

If you have previously deployed the DBP to AWS or minikube you will need to change/verify that the `docker-for-desktop` context is being used.

```bash
kubectl config current-context                 # Display the current context
kubectl config use-context docker-for-desktop  # Set the default context if needed
```

### 5. Restart Docker  

Docker can be faulty on its first start. So, it is always safer to restart it before proceeding. Right click on the Docker icon in the system tray, then left click "restart...". 

### 6. Install Helm

Enable running scripts (If not there will be an error when running the next script).

```bash
Set-ExecutionPolicy RemoteSigned
```

In this approach, we are using Chocolatey to install Helm. So Download and run Chocolatey.

```bash
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) ; $Env:Path="$Env:Path" + ';' + "$Env:Allusersprofile\chocolatey\bin"
``` 


Install Helm

```bash
choco install kubernetes-helm
```

Initialize Tiller (Server Component)

```bash
helm init
```

### 7. Create your namespace

```bash
kubectl create namespace DESIREDNAMESPACE
```

### 8. Pull secrets

Log in to quay.io.
```bash
docker login quay.io
```
Give your username and password if prompted.

Create a variable that stores an encoded version of your docker-config file. 


```bash
$dockerConfigFile = GET-CONTENT -Path "$env:USERPROFILE\.docker\config.json"
$QUAY_SECRET =[Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($dockerConfigFile))
```

Create a secret.yaml file using the $QUAY_SECRET variable.

```bash
echo "apiVersion: v1
kind: Secret
metadata:
  name: quay-registry-secret
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: $QUAY_SECRET" > secrets.yaml
``` 
 

Create the secret in your namespace. 

```bash
kubectl create -f secrets.yaml --namespace DESIREDNAMESPACE
```

### 9. Add remote chart repository to Helm configuration.

```bash
helm repo add alfresco-incubator https://kubernetes-charts.alfresco.com/incubator
```

### 10. Authorize connections

Go to the config.json file in "C:\Users\yourUserProfile\.docker", and check that there is a string after "auth", such as in the following example.

```bash
"auth": "klsdjfsdkifdsiEWRFJDOFfslakfdjsidjfdslfjds"
```

Do the following command to find your ipv4 address and copy it to your clipboard.

```bash
ipconfig
```

Note: If there are many ipv4 addresses, use the ipv4 address of the connection that you are currently using.


Paste the ipv4 address at the end of the hosts file in C:\Windows\System32\drivers\etc, followed by "localhost-k8s" as in the following example. 

```bash
# Copyright (c) 1993-2009 Microsoft Corp.
#
# This is a sample HOSTS file used by Microsoft TCP/IP for Windows.
#
# This file contains the mappings of IP addresses to host names. Each
# entry should be kept on an individual line. The IP address should
# be placed in the first column followed by the corresponding host name.
# The IP address and the host name should be separated by at least one
# space.
#
# Additionally, comments (such as these) may be inserted on individual
# lines or following the machine name denoted by a '#' symbol.
#
# For example:
#
#      102.54.94.97     rhino.acme.com          # source server
#       38.25.63.10     x.acme.com              # x client host

# localhost name resolution is handled within DNS itself.
#	127.0.0.1       localhost
#	::1             localhost

# Added by Docker for Windows
10.244.50.193 host.docker.internal
10.244.50.193 gateway.docker.internal
# End of section

<Your ipv4 address> localhost-k8s

```

Note: Make sure to leave a new line at the end before saving it. 

### 11. Install alfresco-dbp

Copy and paste the following block into your command line.
  
```bash
helm install alfresco-incubator/alfresco-dbp `
--set alfresco-content-services.externalHost="localhost-k8s" `
--set alfresco-content-services.networkpolicysetting.enabled=false `
--set alfresco-content-services.repository.environment.IDENTITY_SERVICE_URI="http://localhost-k8s/auth" `
--set alfresco-content-services.repository.replicaCount=1 `
--set alfresco-content-services.repository.livenessProbe.initialDelaySeconds=420 `
--set alfresco-content-services.pdfrenderer.livenessProbe.initialDelaySeconds=300 `
--set alfresco-content-services.libreoffice.livenessProbe.initialDelaySeconds=300 `
--set alfresco-content-services.imagemagick.livenessProbe.initialDelaySeconds=300 `
--set alfresco-content-services.share.livenessProbe.initialDelaySeconds=420 `
--set alfresco-content-services.repository.resources.requests.memory="2000Mi" `
--set alfresco-content-services.pdfrenderer.resources.requests.memory="500Mi" `
--set alfresco-content-services.imagemagick.resources.requests.memory="500Mi" `
--set alfresco-content-services.libreoffice.resources.requests.memory="500Mi" `
--set alfresco-content-services.share.resources.requests.memory="1000Mi" `
--set alfresco-content-services.postgresql.resources.requests.memory="500Mi" `
--set alfresco-process-services.processEngine.environment.IDENTITY_SERVICE_AUTH="http://localhost-k8s/auth" `
--set alfresco-process-services.processEngine.resources.requests.memory="1000Mi" `
--set alfresco-process-services.adminApp.resources.requests.memory="250Mi" `
--namespace $DESIREDNAMESPACE
```

Repeatedly run the following command until you can see that all the pods are successfully installed. This can take up to one hour. 

```bash
kubectl get pods --namespace $DESIREDNAMESPACE
```

If any pods are failing, you can use each of the following commands to see more about their errors:

```bash
kubectl logs <podName> --namespace $DESIREDNAMESPACE
kubectl describe pod <podName> --namespace $DESIREDNAMESPACE
```



### 12. Teardown:

Use the following command to find the release name.

```bash
helm ls
```

Delete that release with the following command, replacing 'DBRELEASE' with the release name that you just retrieved in the previous command. 

```bash 
helm delete --purge <DBPRELEASE>
```
