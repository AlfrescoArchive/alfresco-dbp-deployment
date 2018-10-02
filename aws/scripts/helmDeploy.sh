#!/bin/bash

# Alfresco Enterprise Deployment AWS
# Copyright (C) 2005 - 2018 Alfresco Software Limited
# License rights for this program may be obtained from Alfresco Software, Ltd.
# pursuant to a written agreement and any use of this program without such an
# agreement is prohibited.

export PATH=$PATH:/usr/local/bin
export HOME=/root
export KUBECONFIG=/home/ec2-user/.kube/config

usage() {
  echo "$0 <usage>"
  echo " "
  echo "options:"
  echo -e "--help \t Show options for this script"
  echo -e "--helm-command \t helm command"
  echo -e "--alfresco-password \t Alfresco admin password"
  echo -e "--namespace \t Namespace to run helm command in"
  echo -e "--registry-secret \t Base64 dockerconfig.json string to private registry"
}

if [ $# -lt 12 ]; then
  usage
else
  # extract options and their arguments into variables.
  while true; do
      case "$1" in
          -h | --help)
              usage
              exit 1
              ;;
          --helm-release)
              HELM_RELEASE="$2";
              shift 2
              ;;
          --helm-command)
              HELM_COMMAND="$2";
              shift 2
              ;;
          --alfresco-password)
              ALFRESCO_PASSWORD="$2";
              shift 2
              ;;
          --namespace)
              DESIREDNAMESPACE="$2";
              shift 2
              ;;
          --registry-secret)
              REGISTRYCREDENTIALS="$2";
              shift 2
              ;;
          --)
              break
              ;;
          *)
              break
              ;;
      esac
  done

echo "apiVersion: v1
kind: Secret
metadata:
  name: quay-registry-secret
  namespace: $DESIREDNAMESPACE
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: $REGISTRYCREDENTIALS" >> secret.yaml
kubectl create -f secret.yaml

ALFRESCO_PASSWORD=$(printf %s $ALFRESCO_PASSWORD | iconv -t utf16le | openssl md4| awk '{ print $2}')

echo Running Helm Command...
$HELM_COMMAND \
--set registryPullSecrets=quay-registry-secret \
--set alfresco-content-services.repository.adminPassword="$ALFRESCO_PASSWORD"

fi