# alfresco-dbp-deployment

## Setup instructions:

### **Prerequisites**

  Have a k8s cluster ready, you can checkout how to create one using this [guide](https://github.com/Alfresco/alfresco-anaxes-shipyard/blob/master/docs/running-a-cluster.md), but keep the in mind the following restrictions: 

  **Minikube cluster**:
  Minikube machine must have 12 gigs of memory for the dbp deployment to work.   
  Use this command to create it:
  ```bash
  minikube start --memory 12000
  ```
  **AWS cluster**:
  A VPC with 5 nodes. Each node should be a **m4.xlarge** EC2 instance.



### 1. Install the Tiller pod in your k8s cluster:

```bash
helm init
```

### 2. Create and Set your desired namespace as a variable. This will be used in further steps.
```bash
kubectl create namespace svidrascu
export DESIREDNAMESPACE=svidrascu
```

### 3. Create your registry secrets:

    a. Login with Docker to Quay.io with your credentials:
    ```
    docker login quay.io
    ```
    b. Generate a base64 value for your dockercfg, this will allow Kubernetes to access quay.io
    ```
    cat ~/.docker/config.json | base64
    ```
    c. Create the file secrets.yaml. Insert the following into the file
    ```
    apiVersion: v1
    kind: Secret
    metadata:
      name: quay-registry-secret
    type: kubernetes.io/dockerconfigjson
    data:
      .dockerconfigjson:
    ```
      Add the base64 string generated in step 2 to .dockerconfigjson in secrets.yaml

    d. Create your secret in your previously defined namespace.
    ```
    kubectl create -f secrets.yaml --namespace $DESIREDNAMESPACE
    ```

More information on creating [secrets...](https://github.com/Alfresco/alfresco-anaxes-shipyard/blob/master/examples/README.md#prerequisites)

### 4. NOTE! ONLY FOR AWS!   

Create a EFS storage on aws and make sure it is in the same VPC as your cluster is. Make sure you open inbound traffic in the security group to allow NFS traffic. Save the name of the server ex: 
```bash
export NFSSERVER=fs-d660549f.efs.us-east-1.amazonaws.com
```

### 5. Deploy infrastructure
```bash
cd charts/incubator

#ON AWS
helm install alfresco-dbp-infrastructure --set persistence.volumeEnv=aws --set persistence.nfs.server="$NFSSERVER" --namespace $DESIREDNAMESPACE

#ON MINIKUBE
helm install alfresco-dbp-infrastructure --namespace $DESIREDNAMESPACE
```

### 6. Wait for the infrastructure release to get deployed

To check if the infrastructure is up and ready you can run:
  ```bash
  kubectl get pods --namespace $DESIREDNAMESPACE
  # all your pods should be available 1/1
  ```

Get the Infrastructure release name from the previous command and set it as a variable

  ```bash
export INFRARELEASE=enervated-deer
  ```

### 7. NOTE! ONLY FOR MINIKUBE   

Get the nginx-ingress-controller port for the infrastructure:   

```bash
export INFRAPORT=$(kubectl get service $INFRARELEASE-nginx-ingress-controller --namespace=$DESIREDNAMESPACE -o jsonpath={.spec.ports[0].nodePort})
```

### 8. get minikube or elb ip and set it as a variable, will be used in step 11:

```Bash
#for minikube
export ELBADDRESS=$(minikube ip)

#for AWS
export ELBADDRESS=$(kubectl get services $INFRARELEASE-nginx-ingress-controller --namespace=$DESIREDNAMESPACE -o jsonpath={.status.loadBalancer.ingress[0].hostname})
```

### 9. Set your auth credentials, will be used for downloading amps and setting registries for acs

  ```bash
  export LDAP_USERNAME=your username 
  export LDAP_PASSWORD=your pass
  export EMAIL=your email
  ```
  
### 10. Create Secrets and Config Maps for ACS

  ```bash
  kubectl create secret docker-registry docker-internal-secret --docker-server=docker-internal.alfresco.com --docker-username=$LDAP_USERNAME --docker-password=$LDAP_PASSWORD --docker-email=$EMAIL --namespace=$DESIREDNAMESPACE
  kubectl create secret generic ldap-credentials --from-literal=username=$LDAP_USERNAME  --from-literal=password=$LDAP_PASSWORD --namespace=$DESIREDNAMESPACE
  kubectl create configmap agp --from-file=alfresco-dbp/config/alfresco-global.properties --namespace=$DESIREDNAMESPACE
  kubectl create configmap share-amps --from-file=urls=alfresco-dbp/config/share-amps-to-apply.txt --namespace=$DESIREDNAMESPACE
  kubectl create configmap repo-amps --from-file=urls=alfresco-dbp/config/repository-amps-to-apply.txt --namespace=$DESIREDNAMESPACE
  ```

### 11. Deploy the dbp

  ```bash
#On MINIKUBE
helm install alfresco-dbp --set alfresco-activiti-cloud-gateway.keycloakURL="http://$ELBADDRESS:$INFRAPORT/auth/" --set alfresco-activiti-cloud-gateway.eurekaURL="http://$ELBADDRESS:$INFRAPORT/registry/" --set alfresco-activiti-cloud-gateway.rabbitmqReleaseName="$INFRARELEASE-rabbitmq" --namespace=$DESIREDNAMESPACE

#On AWS
helm install alfresco-dbp --set alfresco-activiti-cloud-gateway.keycloakURL="http://$ELBADDRESS/auth/" --set alfresco-activiti-cloud-gateway.eurekaURL="http://$ELBADDRESS/registry/" --set alfresco-activiti-cloud-gateway.rabbitmqReleaseName="$INFRARELEASE-rabbitmq" --namespace=$DESIREDNAMESPACE
  ```

Copy and export the Release name that is shown as a result of the deployment
```bash
export DBPRELEASE=enervated-monkey
```

### 12. Checkout the status of your DBP deployment:

  ```bash
helm status $INFRARELEASE
helm status $DBPRELEASE
  ```

### 13. Teardown:

  ```bash
helm delete $INFRARELEASE
helm delete $DBPRELEASE
kubectl delete namespace $DESIREDNAMESPACE
  ```
Depending on your cluster type you should be able to also delete it if you want.
For minikube you can just run 
  ```bash
  minikube delete
  ```
For more information on running and tearing down k8s environemnts, follow this [guide](https://github.com/Alfresco/alfresco-anaxes-shipyard/blob/master/docs/running-a-cluster.md).