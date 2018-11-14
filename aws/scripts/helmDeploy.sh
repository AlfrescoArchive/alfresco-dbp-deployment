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

if [ $# -lt 13 ]; then
  usage
else
  # extract options and their arguments into variables.
  while true; do
      case "$1" in
          -h | --help)
              usage
              exit 1
              ;;
          --release-name)
              RELEASENAME="$2";
              shift 2
              ;;
          --efsname)
              EFSNAME="$2";
              shift 2
              ;;
          --rds-endpoint)
              RDSENDPOINT="$2";
              shift 2
              ;;
          --database-password)
              DATABASEPASSWORD="$2";
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
          --external-name)
              EXTERNALNAME="$2";
              shift 2
              ;;
          --s3bucket-name)
              S3BUCKETNAME="$2";
              shift 2
              ;;
          --s3bucket-location)
              S3BUCKETLOCATION="$2";
              shift 2
              ;;
          --s3bucket-alias)
              S3BUCKETALIAS="$2";
              shift 2
              ;;
          --chart-version)
              CHARTVERSION="$2";
              shift 2
              ;;
          --install)
              INSTALL="true";
              shift
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
  .dockerconfigjson: $REGISTRYCREDENTIALS" > secret.yaml
kubectl create -f secret.yaml

echo "kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: gp2
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp2
reclaimPolicy: Retain
mountOptions:
  - debug" > storage.yaml
kubectl create -f storage.yaml
kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

ALFRESCO_PASSWORD=$(printf %s $ALFRESCO_PASSWORD | iconv -t utf16le | openssl md4| awk '{ print $2}')
echo Adding additional permissions to helm
kubectl create clusterrolebinding add-on-cluster-admin --clusterrole=cluster-admin --serviceaccount=kube-system:default
helm repo update

if [ "$INSTALL" = "true" ]; then
echo Running Helm Command...
helm install alfresco-incubator/alfresco-dbp --version $CHARTVERSION \
--name $RELEASENAME \
--namespace $DESIREDNAMESPACE \
--set postgresql.enabled=false \
--set alfresco-process-services.postgresql.persistence.subPath="$DESIREDNAMESPACE/alfresco-process-services/database-data" \
--set alfresco-process-services.postgresql.persistence.existingClaim="alfresco-volume-claim" \
--set alfresco-process-services.persistence.subPath="$DESIREDNAMESPACE/alfresco-process-services/process-data" \
--set alfresco-process-services.processEngine.environment.IDENTITY_SERVICE_AUTH="https://$EXTERNALNAME/auth/" \
--set alfresco-content-services.repository.environment.IDENTITY_SERVICE_URI="https://$EXTERNALNAME/auth/" \
--set alfresco-content-services.alfresco-search.persistence.search.data.subPath="$DESIREDNAMESPACE/alfresco-content-services/solr-data" \
--set alfresco-content-services.networkpolicysetting.enabled=false \
--set alfresco-content-services.alfresco-infrastructure.enabled=false \
--set alfresco-content-services.externalHost="$EXTERNALNAME" \
--set alfresco-content-services.externalProtocol="https" \
--set alfresco-content-services.externalPort="443" \
--set alfresco-content-services.registryPullSecrets="quay-registry-secret" \
--set alfresco-content-services.repository.adminPassword="$ALFRESCO_PASSWORD" \
--set alfresco-content-services.alfresco-search.environment.SOLR_JAVA_MEM="-Xms2000M -Xmx2000M" \
--set alfresco-content-services.alfresco-search.resources.requests.memory="2500Mi" \
--set alfresco-content-services.alfresco-search.resources.limits.memory="2500Mi" \
--set alfresco-content-services.postgresql.enabled=false \
--set alfresco-content-services.database.external=true \
--set alfresco-content-services.database.driver="org.mariadb.jdbc.Driver" \
--set alfresco-content-services.database.url="'jdbc:mariadb:aurora//$RDSENDPOINT:3306/alfresco?useUnicode=yes&characterEncoding=UTF-8'" \
--set alfresco-content-services.database.user="alfresco" \
--set alfresco-content-services.database.password="$DATABASEPASSWORD" \
--set alfresco-content-services.persistence.repository.enabled=false \
--set alfresco-content-services.s3connector.enabled=true \
--set alfresco-content-services.s3connector.config.bucketName="$S3BUCKETNAME" \
--set alfresco-content-services.s3connector.config.bucketLocation="$S3BUCKETLOCATION" \
--set alfresco-content-services.s3connector.secrets.encryption=kms \
--set alfresco-content-services.s3connector.secrets.awsKmsKeyId="$S3BUCKETALIAS" \
--set alfresco-content-services.repository.image.repository="alfresco/alfresco-content-repository-aws" \
--set alfresco-content-services.repository.image.tag="6.1.0-EA3" \
--set alfresco-content-services.repository.replicaCount=1 \
--set alfresco-content-services.repository.livenessProbe.initialDelaySeconds=420 \
--set alfresco-content-services.pdfrenderer.livenessProbe.initialDelaySeconds=300 \
--set alfresco-content-services.libreoffice.livenessProbe.initialDelaySeconds=300 \
--set alfresco-content-services.imagemagick.livenessProbe.initialDelaySeconds=300 \
--set alfresco-content-services.share.livenessProbe.initialDelaySeconds=420 \
--set alfresco-infrastructure.persistence.efs.enabled=true \
--set alfresco-infrastructure.persistence.efs.dns="$EFSNAME" \
--set alfresco-infrastructure.nginx-ingress.enabled=false \
--set alfresco-infrastructure.alfresco-identity-service.keycloak.postgresql.persistence.subPath="$DESIREDNAMESPACE/alfresco-identity-service/database-data" \
--set alfresco-infrastructure.alfresco-identity-service.client.alfresco.redirectUris="[\"https://$EXTERNALNAME*\"]"
else
helm upgrade $RELEASENAME alfresco-incubator/alfresco-dbp --version $CHARTVERSION --reuse-values
fi

fi