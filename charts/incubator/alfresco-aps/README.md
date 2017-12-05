# Anaxes APS deployment

This Helm chart provides deployment for Alfresco Process Services.

An Ingress is used to rewrite the paths of the service and offer externally through one common service.

This chart depends on the following charts to provide the database and ingress path rewrites:
- Postgresql - [https://github.com/kubernetes/charts/tree/master/stable/postgresql](https://github.com/kubernetes/charts/tree/master/stable/postgresql)
- Existent Ingress controller

You can deploy this chart to a minikube or AWS cluster with `helm install alfresco-aps`

Once deployed you can use the `get-aps-url.sh` script to get the publicly accessible URL for the Alfresco Process Services.