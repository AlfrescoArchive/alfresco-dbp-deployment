# alfresco-dbp-deployment

Setup instructions:

1. helm init
2. export DESIREDNAMESPACE=svidrascu

cd charts/incubator

Create your registry secrets
kubectl create -f secrets.yaml --namespace $DESIREDNAMESPACE

deploy infrastructure
helm install alfresco-dbp-infra --namespace $DESIREDNAMESPACE

- get the nginx-ingress-controller port associated to the 80 port and export it as a variable:
example: handy-chinchilla-nginx-ingress-controller       10.0.0.8    <pending>    80:32260/TCP,443:32301/TCP
in our case 32260
export INFRAPORT=80
- get minikube ip and set it as a variable:
export ELBADDRESS=a3a1e2125d9ba11e7a6910a8fa36acdf-1722764392.us-east-1.elb.amazonaws.com
 - get the release name and set it as a variable
export INFRARELEASE=sappy-chimp

export LDAP_USERNAME=your username
export LDAP_PASSWORD=your pass
export EMAIL=your email

edit 

kubectl create secret docker-registry docker-internal-secret --docker-server=docker-internal.alfresco.com --docker-username=$LDAP_USERNAME --docker-password=$LDAP_PASSWORD --docker-email=$EMAIL --namespace=$DESIREDNAMESPACE

kubectl create secret generic ldap-credentials --from-literal=username=$LDAP_USERNAME  --from-literal=password=$LDAP_PASSWORD --namespace=$DESIREDNAMESPACE

kubectl create configmap agp --from-file=alfresco-dbp/config/alfresco-global.properties --namespace=$DESIREDNAMESPACE

kubectl create configmap share-amps --from-file=urls=alfresco-dbp/config/share-amps-to-apply.txt --namespace=$DESIREDNAMESPACE

kubectl create configmap repo-amps --from-file=urls=alfresco-dbp/config/repository-amps-to-apply.txt --namespace=$DESIREDNAMESPACE

helm install alfresco-dbp --set alfresco-activiti-cloud-gateway.keycloakURL="http://$ELBADDRESS/auth/" --set alfresco-activiti-cloud-gateway.eurekaURL="http://$ELBADDRESS/registry/" --set alfresco-activiti-cloud-gateway.rabbitmqReleaseName="$INFRARELEASE-rabbitmq" --namespace=$DESIREDNAMESPACE

helm status Your Release Name