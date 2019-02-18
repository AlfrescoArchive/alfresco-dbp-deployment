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
Docker can be faulty on its first start. So, it is always safer to restart it before proceeding. Right click on the docker icon in the system tray, then left click "restart...". 

### Install helm
Install chocolatery using command prompt (with admin rights). 

```bash
@"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" && SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
```

Now you can use chocolatery to install helm.

```bash
choco install kubernetes-helm
```

### Create your namespace
```bash
kubectl create namespace <yourNamespace>
```

### Pull secrets
Log in to quay.io
```bash
docker login quay.io
```
Give username and password if prompted.

Generate a base64 value for your dockercfg, this will allow Kubernetes to access quay.io

```bash
certutil -encode "%USERPROFILE%\.docker\config.json" tmp.b64 && findstr /v /c:- tmp.b64
```
Copy the string output.

Create the file secrets.yaml. And insert the copied string into the file where specified:

```bash
apiVersion: v1
kind: Secret
metadata:
  name: quay-registry-secret
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <replace this with the string>
```

Note that when you paste the string output in the data section, it may be pasted with new lines in it. So, make sure to take out the new lines. And leave a single space between "data:" and the string. 

Create the secret in your namespace. 
```bash
kubectl create -f secrets.yaml --namespace <yourNamespace>
```

### Download the alfresco helm chart

```bash
helm repo add alfresco-incubator https://kubernetes-charts.alfresco.com/incubator
```

### Authorize conections
Check that the config.json file in C:\Users\<YourUserName>\.docker has a string after the word "auth".

Go to the config.json file in "C:\Users\Ayman Harake\.docker", and check that there is a string after auth, such as in the following example.

```bash
"auth": "YWhhcmFrZTpQYXNjcnQxMlBhc2NydDEy"
```

Do the following command to find your ipv4 address and copy it to your clipboard.

```bash
ipconfig
```

Note: If there are many ipv4 addresses, use the one that looks the most similar to this:

```bash
Wireless LAN adapter Wi-Fi 2:

   Connection-specific DNS Suffix  . : internal.alfresco.com
   Link-local IPv6 Address . . . . . : fe80::c4e7:80c8:7609:42ae%13
   IPv4 Address. . . . . . . . . . . : 10.244.50.193
   Subnet Mask . . . . . . . . . . . : 255.255.254.0
   Default Gateway . . . . . . . . . : 10.244.50.1
```

Paste the ipv4 address at the end of the hosts file in C:\Windows\System32\drivers\etc, then add "localhost-k8s" to the line so that it looks like the following example. 

```bash
10.244.50.193 localhost-k8s
```

Note: Make sure to leave a new line at the end before saving it. 

### Install alfresco-dbp

Copy and paste the following block into your command line, making sure to replace <yourNamespace> accordingly. 
  
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
Repeatedly  run the following command until you can see that all the pods are successfully installed. This can take up to one hour. 

```bash
kubectl get pods --namespace ayman
```

If any pods are failing, you can use each of the following commands to see more about their errors:

```bash
kubectl logs <the part of the pod name that all the pods have in common> --namespace <your namespace name>
kubectl describe pod <the part of the pod name that all the pods have in common> --namespace <your namespace name>
```

If the postgres pod won't start and you are getting the following error:

```bash
2019-02-08 10:27:04.358 UTC [1] FATAL:  data directory "/var/lib/postgresql/data/pgdata" has wrong ownership
2019-02-08 10:27:04.358 UTC [1] HINT:  The server must be started by the user that owns the data directory.
```

Run the following commands to delete the storageClass hostpath and set up the hostpath provisioner: 

```bash
kubectl delete storageclass hostpath
kubectl create -f https://raw.githubusercontent.com/MaZderMind/hostpath-provisioner/master/manifests/rbac.yaml
kubectl create -f https://raw.githubusercontent.com/MaZderMind/hostpath-provisioner/master/manifests/deployment.yaml
kubectl create -f https://raw.githubusercontent.com/MaZderMind/hostpath-provisioner/master/manifests/storageclass.yaml
```

Clone the following file to your desired location. In the following example, it is cloned to the desktop. To do so, open your command line for git (we used bash), and run the following commands remembering to replace <yourUserName>.

```bash
cd "C:\Users\<yourUserName>\Desktop"
git clone https://git.alfresco.com/platform-services/bamboo-build-dbp.git
```

Once all the pods are ready, go to http://localhost-k8s/activiti-app/#/ and you will see that all works well, but that your license is invalid. Click on "upload license". Then browse to the folder that you cloned and locate scripts/activiti.lic inside it. 

### That's it! :) 
