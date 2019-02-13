# dbp-deployment

# Deploy to Docker for Desktop - Windows

## Deployment

### Install Docker for Desktop

Check recommended version [here](https://github.com/Alfresco/alfresco-dbp-deployment/blob/master/README-prerequisite.md#docker-desktop).

### Enable Kubernetes

In the 'Kubernetes' tab of the Docker settings,  click the 'Enable Kubernetes' checkbox.

### Increase Memory and CPUs

In the Advanced tab of the Docker preferences, set 'CPUs' to 4.

While Alfresco Digital Business Platform installs and runs with only 8 GiB allocated to Docker, 
for better performance we recommend that 'Memory' value be set slightly higher, to at least 10 - 12 GiB
(depending on the size of RAM in your workstation). 

### Restart docker  
Docker can be buggy on its first start. So once windows is running, it is always safer to restart it before proceeding. 
```bash
restart docker
```

### Docker Registry Pull Secrets
??? mention all of this https://github.com/Alfresco/alfresco-anaxes-shipyard/blob/master/SECRETS.md


Do the following command then copy the string output.
```bash
certutil -encode "%USERPROFILE%\.docker\config.json" tmp.b64 && findstr /v /c:- tmp.b64
```

### Create the file secrets.yaml. And insert the following into the file
```bash
apiVersion: v1
kind: Secret
metadata:
  name: quay-registry-secret
type: kubernetes.io/dockerconfigjson
data: # add the string here
```
Note that when you paste the string output in the data section, it may be pasted with new lines in it. So make sure to take out the new lines. 

### Attach the secrets.yaml file to your namespace
```bash
kubectl create -f secrets.yaml --namespace <yourNamespace>
```

### Add the alfresco-incubator chart repository
helm repo add alfresco-incubator https://kubernetes-charts.alfresco.com/incubator






log in
    docker login quay.io
    give username and password if prompted
try docker pull for the tika image just to test
    docker pull alfresco/alfresco-base-java:11
if it all works, see if the token exits in auth ie, is there a string there, in config.json in C:\Users\Ayman Harake\.docker?
if so do the following

%%%
 --set alfresco-content-services.pdfrenderer.resources.requests.memory="500Mi" ^

ipconfig
then copy the ip address (piv4 not 6)
then you pasted that at the end off C:\Windows\System32\drivers\etc\hosts
make sure you press enter to leave one new line at the end

paste the following block all as one
----------------------------------------------------------------------------------------------------------

helm install alfresco-incubator/alfresco-dbp ^
--set alfresco-content-services.externalHost="localhost-k8s" ^
--set alfresco-content-services.networkpolicysetting.enabled=false ^
--set alfresco-content-services.repository.environment.IDENTITY_SERVICE_URI="http://localhost-k8s/auth" ^
--set alfresco-content-services.repository.replicaCount=1 ^
--set alfresco-content-services.repository.livenessProbe.initialDelaySeconds=420 ^
--set alfresco-content-services.pdfrenderer.livenessProbe.initialDelaySeconds=300 ^
--set alfresco-content-services.libreoffice.livenessProbe.initialDelaySeconds=300 ^
--set alfresco-content-services.imagemagick.livenessProbe.initialDelaySeconds=300 ^
--set alfresco-content-services.share.livenessProbe.initialDelaySeconds=420 ^
--set alfresco-content-services.repository.resources.requests.memory="2000Mi" ^
--set alfresco-content-services.pdfrenderer.resources.requests.memory="500Mi" ^
--set alfresco-content-services.imagemagick.resources.requests.memory="500Mi" ^
--set alfresco-content-services.libreoffice.resources.requests.memory="500Mi" ^
--set alfresco-content-services.share.resources.requests.memory="1000Mi" ^
--set alfresco-content-services.postgresql.resources.requests.memory="500Mi" ^
--set alfresco-process-services.processEngine.environment.IDENTITY_SERVICE_AUTH="http://localhost-k8s/auth" ^
--set alfresco-process-services.processEngine.resources.requests.memory="1000Mi" ^
--set alfresco-process-services.adminApp.resources.requests.memory="250Mi" ^
--namespace ayman

--------------------------------------------------------------------------------------
kubectl get pods --namespace ayman
-make note of the ways to display errors on a particular pod


in that bamboo build folder on desktop, look for scripts/activiti.lic
you should find the license in here to use at http://localhost-k8s/activiti-app/#/





-------------------------------------------------



helm list

helm delete --purge elevated-marmot incendiary-platypus

docker pull alfresco/alfresco-base-java:11
