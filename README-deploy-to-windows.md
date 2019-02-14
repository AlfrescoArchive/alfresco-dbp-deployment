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
Docker can be faulty on its first start. So it is always safer to restart it before proceeding. So right click on the docker icon in the system tray, then left click "restart...". 


### Pull secrets
Log in to quay.io
```bash
docker login quay.io
```
Give username and password if prompted.

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



### Test to make sure that the token exists
```bash
docker pull alfresco/alfresco-base-java:11
```
Check the config.json file in C:\Users\<YourUserName>\.docker has a string after the word "auth".

log in
    docker login quay.io
    give username and password if prompted
try docker pull for the tika image just to test
    docker pull alfresco/alfresco-base-java:11
if it all works, see if the token exits in auth ie, is there a string there, in config.json in C:\Users\Ayman Harake\.docker?
if so do the following

%%%
### ???
```bash
 --set alfresco-content-services.pdfrenderer.resources.requests.memory="500Mi" ^
```
### Do the following command to find your ipv4 address and copy it to your clipboard. ???
```bash
ipconfig
```
note: if there are many ipv4 addresses, make sure to use the one that looks most similar to this:
```bash
Wireless LAN adapter Wi-Fi 2:

   Connection-specific DNS Suffix  . : internal.alfresco.com
   Link-local IPv6 Address . . . . . : fe80::c4e7:80c8:7609:42ae%13
   IPv4 Address. . . . . . . . . . . : 10.244.50.193
   Subnet Mask . . . . . . . . . . . : 255.255.254.0
   Default Gateway . . . . . . . . . : 10.244.50.1
```

### Paste the ipv4 address at the end of the hosts file in C:\Windows\System32\drivers\etc, then add localhost-k8s to the line so that it looks like the following example. ???
```bash
10.244.50.193 localhost-k8s
```
note: Make sure to leave a new line at the end before saving it. 

### Install alfresco-dbp

Copy and paste the following block into your command line, making sure to change <yournamespace> to the namespace that you are using. 
  
```bash
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
--namespace <yourNameSpace>
```
repeatadly run the following command until you can see that all the pods are successfuly installed. This can take up to one hour. 

```bash
kubectl get pods --namespace ayman
```

Note: If any pods are failing, you can use each of the three following commands to see more about their errors:
```bash
kubectl logs <the part of the pod name that all the pods have in common> --namespace <your namespace name>
kubectl describe pod <the part of the pod name that all the pods have in common> --namespace <your namespace name>
helm status <name that all the pods have in common>
```

Clone the following file to your desired location. in the following example, it is cloned to the desktop.
open your git command line, here we used bash.
```bash
cd "C:\Users\<your user name>\Desktop"
git clone https://git.alfresco.com/platform-services/bamboo-build-dbp.git
```

Once all the pods are ready, go to http://localhost-k8s/activiti-app/#/ and you will see that all works well but that your license is in valid. Click on "upload license". Then browse to the folder that you cloned and locate scripts/activiti.lic inside it. 

### That's it! :) 

note: After restarting your computer, there will be some errors in the pods. You will have to run the following command then install the pods again, while making sure that your IP address hasn't changed. If it has then do the IP section again:
```bash
helm delete --purge <name that all the pods have in common>
```
