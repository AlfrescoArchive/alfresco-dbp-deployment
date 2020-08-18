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
          --repo-pods)
              REPO_PODS="$2";
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

# We get Bastion AZ and Region to get a valid right region and query for volumes
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
BASTION_AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
REGION=${BASTION_AZ%?}
# We use this tag below to find the proper EKS cluster name and figure out the unique volume
TAG_NAME="KubernetesCluster"
TAG_VALUE=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=$TAG_NAME" --region $REGION --output=text | cut -f5)
# EKSname is not unique if we have multiple ACS deployments in the same cluster
# It must be a name unique per Alfresco deployment, not per EKS cluster.
SOLR_VOLUME1_NAME_TAG="$TAG_VALUE-SolrVolume1"
SOLR_VOLUME1_ID=$(aws ec2 describe-volumes --region $REGION --filters "Name=tag:Name,Values=$SOLR_VOLUME1_NAME_TAG" --query "Volumes[?State=='available'].{Volume:VolumeId}" --output text)

ALFRESCO_PASSWORD=$(printf %s $ALFRESCO_PASSWORD | iconv -t utf16le | openssl md4| awk '{ print $2}')
echo Adding additional permissions to helm
kubectl create clusterrolebinding add-on-cluster-admin --clusterrole=cluster-admin --serviceaccount=kube-system:default
helm repo update

if [ "$INSTALL" = "true" ]; then

echo "alfresco-infrastructure:
  persistence:
    efs:
      enabled: true
      dns: \"$EFSNAME\"
  nginx-ingress:
    enabled: false
  alfresco-identity-service:
    keycloak:
      postgresql:
        persistence:
          subPath: \"$DESIREDNAMESPACE/alfresco-identity-service/database-data\"
    client:
      alfresco:
        redirectUris: \"[\\\"https://$EXTERNALNAME*\\\"]\"
alfresco-content-services:
  networkpolicysetting:
    enabled: false
  alfresco-infrastructure:
    enabled: false
  externalHost: \"$EXTERNALNAME\"
  externalProtocol: \"https\"
  externalPort: 443
  registryPullSecrets: \"quay-registry-secret\"
  postgresql:
    enabled: false
  database:
    external: true
    driver: \"org.mariadb.jdbc.Driver\"
    url: \"'jdbc:mariadb:aurora//$RDSENDPOINT:3306/alfresco?useUnicode=yes&characterEncoding=UTF-8'\"
    user: \"alfresco\"
    password: \"$DATABASEPASSWORD\"
  repository:
    image:
      repository: \"alfresco/alfresco-content-repository-aws\"
      tag: \"7.0.0-A3\"
    replicaCount: $REPO_PODS
    adminPassword: \"$ALFRESCO_PASSWORD\"
    environment:
      IDENTITY_SERVICE_URI: \"https://$EXTERNALNAME/auth/\"
    livenessProbe:
      initialDelaySeconds: 420
  persistence:
    repository:
      enabled: false
  s3connector:
    enabled: true
    config:
      bucketName: \"$S3BUCKETNAME\"
      bucketLocation: \"$S3BUCKETLOCATION\"
    secrets:
      encryption: kms
      awsKmsKeyId: \"$S3BUCKETALIAS\"
  transformrouter:
    livenessProbe:
      initialDelaySeconds: 300
  pdfrenderer:
    livenessProbe:
      initialDelaySeconds: 300
  libreoffice:
    livenessProbe:
      initialDelaySeconds: 300
  imagemagick:
    livenessProbe:
      initialDelaySeconds: 300
  share:
    livenessProbe:
      initialDelaySeconds: 420
  alfresco-search:
    resources:
      requests:
        memory: \"2500Mi\"
      limits:
        memory: \"2500Mi\"
    environment:
      SOLR_JAVA_MEM: \"-Xms2000M -Xmx2000M\"
    persistence:
      VolumeSizeRequest: \"100Gi\"
      EbsPvConfiguration:
        volumeID: \"$SOLR_VOLUME1_ID\"
    affinity: |
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
              - key: \"SolrMasterOnly\"
                operator: In
                values:
                - \"true\"
    tolerations:
    - key: \"SolrMasterOnly\"
      operator: \"Equal\"
      value: \"true\"
      effect: \"NoSchedule\"
    PvNodeAffinity:
      required:
        nodeSelectorTerms:
        - matchExpressions:
          - key: \"SolrMasterOnly\"
            operator: In
            values:
            - \"true\"
alfresco-process-services:
  postgresql:
    persistence:
      subPath: \"$DESIREDNAMESPACE/alfresco-process-services/database-data\"
      existingClaim: \"alfresco-volume-claim\"
  persistence:
    subPath: \"$DESIREDNAMESPACE/alfresco-process-services/process-data\"
  processEngine:
    environment:
      IDENTITY_SERVICE_AUTH: \"https://$EXTERNALNAME/auth/\"
postgres:
  enabled: false" > dbp_install_values.yaml

echo Running Helm Command...
helm install alfresco-incubator/alfresco-dbp --version $CHARTVERSION -f dbp_install_values.yaml --name $RELEASENAME --namespace $DESIREDNAMESPACE
else
helm upgrade $RELEASENAME alfresco-incubator/alfresco-dbp --version $CHARTVERSION --reuse-values
fi

fi