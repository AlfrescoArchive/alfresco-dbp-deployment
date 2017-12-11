# alfresco-dbp-deployment

Setup instructions:

@Prerequisites for Minikube:
Minikube machine must have 12 gigs of memory for the dbp deployment to work.   
Use this command to create it:
```bash
minikube start --memory 12000
```
@Prerequisites for AWS:
A VPC with 5 nodes. Each node should be a m4.xlarge EC2 instance.

1. helm init

2. Set your desired namespace as a variable. This will be used in further steps.
```bash
export DESIREDNAMESPACE=svidrascu
```
3. Create your registry secrets
```bash
kubectl create -f secrets.yaml --namespace $DESIREDNAMESPACE
```

4. NOTE! ONLY FOR AWS!   

Create a EFS storage on aws and make sure it is in the same VPC as your cluster is. Save the name of the server ex: 
```bash
export NFSSERVER=fs-d660549f.efs.us-east-1.amazonaws.com
```

5. Deploy infrastructure

```bash
#ON AWS
helm install alfresco-dbp-infra --set persistence.volumeEnv=aws --set persistence.nfs.server="$NFSSERVER" --namespace $DESIREDNAMESPACE

#ON MINIKUBE
helm install alfresco-dbp-infra --namespace $DESIREDNAMESPACE
```

6. Wait for the infra release to get deployed (when running helm status infrarelease, all your pods should be available 1/1).
Get the Infra release name from the previous command and set it as a variable

  ```bash
export INFRARELEASE=enervated-deer
  ```

7. NOTE! ONLY FOR MINIKUBE   

On AWS you must not add a port to the the command ran at point 11!    

Get the nginx-ingress-controller port associated to the 80 port and export it as a variable:   
example: handy-chinchilla-nginx-ingress-controller       10.0.0.8    <pending>    80:32260/TCP,443:32301/TCP   
in our case 32260   
You will find this port when deploying the infra, in the result message from helm.

```bash
export INFRAPORT=31923
```

8. get minikube or elb ip and set it as a variable, will be used in step 11:

```Bash
#for minikube
export ELBADDRESS=$(minikube ip)

#for AWS
export ELBADDRESS=$(kubectl get services $INFRARELEASE-nginx-ingress-controller --namespace=$DESIREDNAMESPACE -o jsonpath={.status.loadBalancer.ingress[0].hostname})
```

9. Set your auth credentials, will be used for downloading amps and setting registries for acs

  ```bash
  export LDAP_USERNAME=your username 
  export LDAP_PASSWORD=your pass
  export EMAIL=your email
  ```
  
10. Create Secrets and Config Maps for ACS

  ```bash
  kubectl create secret docker-registry docker-internal-secret --docker-server=docker-internal.alfresco.com --docker-username=$LDAP_USERNAME --docker-password=$LDAP_PASSWORD --docker-email=$EMAIL --namespace=$DESIREDNAMESPACE
  kubectl create secret generic ldap-credentials --from-literal=username=$LDAP_USERNAME  --from-literal=password=$LDAP_PASSWORD --namespace=$DESIREDNAMESPACE
  kubectl create configmap agp --from-file=alfresco-dbp/config/alfresco-global.properties --namespace=$DESIREDNAMESPACE
  kubectl create configmap share-amps --from-file=urls=alfresco-dbp/config/share-amps-to-apply.txt --namespace=$DESIREDNAMESPACE
  kubectl create configmap repo-amps --from-file=urls=alfresco-dbp/config/repository-amps-to-apply.txt --namespace=$DESIREDNAMESPACE
  ```

11. Deploy the dbp

  ```bash
#On MINIKUBE
helm install alfresco-dbp --set alfresco-activiti-cloud-gateway.keycloakURL="http://$ELBADDRESS:$INFRAPORT/auth/" --set alfresco-activiti-cloud-gateway.eurekaURL="http://$ELBADDRESS:$INFRAPORT/registry/" --set alfresco-activiti-cloud-gateway.rabbitmqReleaseName="$INFRARELEASE-rabbitmq" --namespace=$DESIREDNAMESPACE

#On AWS
helm install alfresco-dbp --set alfresco-activiti-cloud-gateway.keycloakURL="http://$ELBADDRESS/auth/" --set alfresco-activiti-cloud-gateway.eurekaURL="http://$ELBADDRESS/registry/" --set alfresco-activiti-cloud-gateway.rabbitmqReleaseName="$INFRARELEASE-rabbitmq" --namespace=$DESIREDNAMESPACE
  ```

12. Checkout the status of your deployment:

helm status Your Release Name
