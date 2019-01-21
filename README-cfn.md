# DBP Deployment on AWS EKS

## Overview

This project contains the code for the AWS-based DBP product on AWS Cloud using an AWS CloudFormation template.  It's built with a main CloudFormation (CFN) template that also spins up sub-stacks for a VPC, Bastion Host, EKS Cluster and Worker Nodes (including registering them with the EKS Master) in an auto-scaling group.

**Note:** You need to clone the following repositories to deploy the DBP:
1. [Alfresco DBP Deployment](https://github.com/Alfresco/alfresco-dbp-deployment)
2. [ACS Deployment AWS](https://github.com/Alfresco/acs-deployment-aws)

#### Limitations

Within this project we rely on [ACS Deployment AWS](https://github.com/Alfresco/acs-deployment-aws) to set the EKS cluster through a set of defined cloudformation templates. Infrastructure limitations are set by the before mentioned project.

### Prerequisites
* You need to create an IAM user that has the following [permissions](#Permissions) 
* You need a hosted zone e.g. example.com. See [Creating a Public Hosted Zone](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/CreatingHostedZone.html)
* An SSL certificate for the Elastic Load Balancer and the domains in the hosted zone [Creating SSL Cert](https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/ssl-server-cert.html)
* Also consider reading [Getting Started/Amazon EKS Prerequisites](https://docs.aws.amazon.com/eks/latest/userguide/eks-ug.pdf) 

### Permissions
Ensure that the IAM role or IAM user that creates the stack allows the following permissions:

```
ec2:AssociateAddress
ec2:DescribeAddresses

eks:CreateCluster
eks:Describe

iam:PassRole

kms:Decrypt
kms:Encrypt
                  
logs:CreateLogStream
logs:GetLogEvents
logs:PutLogEvents
logs:DescribeLogGroups
logs:DescribeLogStreams
logs:PutRetentionPolicy
logs:PutMetricFilter
logs:CreateLogGroup
     
s3:GetObject
s3:GetReplicationConfiguration
s3:ListBucket
s3:GetObjectVersionForReplication
s3:GetObjectVersionAcl 
s3:PutObject
s3:ReplicateObject
                  
sts:AssumeRole
```

## Preparing the S3 bucket for CFN template deployment
The master template (`alfresco-dbp-deployment/aws/templates/full-deployment.yaml`) requires a few supporting files hosted in S3, like lambdas, scripts and CFN templates. To do this, create or use an S3 bucket in the same region as you intend to deploy DBP. Also, the S3 bucket needs to have a key prefix in it:
```s3://<bucket_name>/<key_prefix>``` (e.g. ```s3://my-s3-bucket/development```)

**Note:** With S3 in AWS Console you can create the `<key_prefix>` when creating a folder.

To simplify the upload, we created a helper script named **uploadHelper.sh**, which only works with Mac or Linux. For Windows, upload those files manually. Initiate the upload by following the instructions below:
1) Open a terminal and change directory to DBP cloned repository.
2) ```chmod +x uploadHelper.sh```
3) ```uploadHelper.sh <bucket_name> <key_prefix>```. This will upload the files to S3.
4) Check that the bucket contains the following files:

```
s3://<bucket_name> e.g. my-s3-bucket
          |-- <key_prefix> e.g. development
          |       |-- lambdas
          |       |      |-- eks-helper-lambda.zip
          |       |      +-- cluster-init-helper-lambda.zip
          |       |      +-- alfresco-lambda-empty-s3-bucket.jar
          |       |      +-- helm-helper-lambda.zip
          |       |-- scripts
          |       |      |-- deleteAcs.sh
          |       |      +-- deleteIngress.sh
          |       |      +-- getElb.sh
          |       |      +-- hardening_bootstrap.sh
          |       |      +-- helmAcs.sh
          |       |      +-- helmDeploy.sh
          |       |      +-- helmFluentd.sh
          |       |      +-- helmIngress.sh
          |       |      +-- helmInit.sh
          |       |-- templates
          |       |      |-- acs-deployment-master.yaml
          |       |      +-- acs-master-parameters.json
          |       |      +-- acs.yaml
          |       |      +-- bastion-and-eks-cluster.yaml
          |       |      +-- dbp-install.yaml
          |       |      +-- efs.yaml
          |       |      +-- full-deployment-parameters.json
          |       |      +-- full-deployment.yaml
          |       |      +-- rds.yaml
          |       |      +-- s3-bucket.yaml
```
## To create the stack and deploy the DBP you can use one of the following options
 1. [Deploy DBP using AWS Console](#deploying-dbp-eks-with-aws-console)
 2. [Deploy DBP using AWS CLI](#deploying-dbp-eks-with-aws-cli)

## Deploying DBP EKS with AWS Console
**Note:** To use the AWS Console, make sure that you've uploaded the required files to S3 as described in [Preparing the S3 bucket for CFN template deployment](#preparing-the-s3-bucket-for-cfn-template-deployment).

* Go to the AWS Console and open CloudFormation
* Click ```Create Stack```
* In ```Upload a template to Amazon S3``` choose `/alfresco-dbp-deployment/aws/templates/full-deployment.yaml`
* Choose a stack name, like `my-dbp-eks`
* Fill out the parameters. In many cases you can use the default parameters. For some parameter sections we will provide some additional information.

**S3 Cross Replication Bucket for storing DBP content store**

```Enable Cross Region Replication for This Bucket``` : Cross Region Replication replicates your data into another bucket. See [Cross-Region Replication](https://docs.aws.amazon.com/AmazonS3/latest/dev/crr.html) for more information.

**DBP Stack Configuration**

```The name of the S3 bucket that holds the templates``` : Take the bucket name from the upload step.

```The Key prefix for the templates in the S3 template bucket``` : Take the `key_prefix` from the upload step.

```The SSL Certificate arn to use with ELB``` : Take the SSL certificate arn for your domains in the hosted zone. For more information about how to create SSL certificates, see the AWS documentation on the [AWS Certificate Manager](https://docs.aws.amazon.com/acm/latest/userguide/acm-overview.html).

```The domain name``` : Choose the subdomain which will be used for the url e.g. **my-dbp-eks.example.com**. For more information about how to create a hosted zone and its subdomains visit the AWS documentation on [Creating a Subdomain](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/CreatingNewSubdomain.html).

```Private Registry Credentials. Base64 encryption of dockerconfig json``` : \
**Notice:** The credentials are needed for different DBP images that are pulled from quay.io.
1) Login to quay.io with ```docker login quay.io```.
2) Validate that you can see the credentials with ```cat ~/.docker/config.json``` for Quay.io.
3) Get the encoded credentials with ```cat ~/.docker/config.json | base64```.
4) Copy them into the textbox.

```The hosted zone to create Route53 Record for DBP``` : Enter your hosted zone e.g. **example.com.**. For more information about how to create a hosted zone, see the AWS documentation on [Creating a Public Hosted Zone](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/CreatingHostedZone.html).

After the CFN stack creation has finished, you can find the Alfresco URL in the output from the master template.

### Deleting DBP EKS with AWS Console
Go to CloudFormation and delete the master DBP EKS stack. The nested stacks will be deleted first, followed by the master stack.

## Deploying DBP EKS with AWS CLI

Check [prerequisites section](https://github.com/Alfresco/alfresco-dbp-deployment/blob/master/README-prerequisite.md) before you start.

1. Create a new keypair in EC2 using 
    ```
    aws ec2 create-key-pair --key-name $DESIRED_KEY_NAME
    ```
2. Make sure that you use the same bucket name and key prefix in the Cli command as you provided in [Prepare the S3 bucket for CFN template deployment](#preparing-the-s3-bucket-for-cfn-template-deployment).
    * you can also use the following command to create the bucket in the CLI
        ```
        aws s3api create-bucket --bucket $DESIRED_BUCKET_NAME
        ```
    * export the bucket key prefix in a variable
        ```
         export $DESIRED_KEY_PREFIX=<key_prefix>
        ```
    * after that use the uploadHelper.sh script to upload all the required resources to S3
         ```
         uploadHelper.sh $DESIRED_BUCKET_NAME $DESIRED_KEY_PREFIX
         ```
3. Set a variable with your quay registry secret to be able to pull docker images
    ```
    export REGISTRY_SECRET=$(cat ~/.docker/config.json | base64)
    ```
4. Set up the external name for the DBP using a desired deployment name and a DOMAIN
    ```
        export EXTERNAL_NAME="$DESIRED_DEPLOYMENT_NAME.$DOMAIN"
    ```
5. Get your ELB certificate ARN from Certificate Manager in AWS console and export it into ELB_CERT_ARN. This should be the one matching your created domain name.
6. Create a replication bucket into the eu-west-1 region and then export the bucket name into REPLICATION_BUCKET and the kms encryption key of it into REPLICATION_KMS_ENCRYPTION_KEY.
7. Set an RDS password
    ``` 
        export RDS_PASSWORD=$DESIRED_PASSWORD
    ```
8. Get the external user ARN and export the "Arn" value result from the below command into EXTERNAL_USER_ARN
    ```
        aws sts get-caller-identity
    ```
9. Replace placeholders in the full-deployment-parameters.json
    ```
    export CIDR="0.0.0.0/0"
    export REPLICATION_BUCKET_REGION="eu-west-1"
    export ALF_PASS="alfresco"
    export AVAILABILITY_ZONES="us-east-1a,us-east-1b"
    ```
    ```
      sed -i'.bak' "
      s#@@RemoteAccessCIDRValue@@#${CIDR}#g;
      s/@@TemplateBucketNameValue@@/${DESIRED_BUCKET_NAME}/g;
      s#@@TemplateBucketKeyPrefixValue@@#${DESIRED_KEY_PREFIX}#g;
      s/@@RDSPasswordValue@@/${RDS_PASSWORD}/g;
      s/@@RDSCreateSnapshotWhenDeleted@@/true/g;
      s/@@AlfrescoPasswordValue@@/${ALF_PASS}/g;
      s#@@UseCrossRegionReplicationValue@@#true#g;
      s#@@ReplicationBucketRegionValue@@#${REPLICATION_BUCKET_REGION}#g;
      s#@@ExternalNameValue@@#$EXTERNAL_NAME#g;
      s#@@Route53DnsZoneValue@@#${ROUTE_53_ZONE}#g;
      s#@@ElbCertArnValue@@#${ELB_CERT_ARN}#g;
      s#@@ReplicationBucketValue@@#${REPLICATION_BUCKET}#g;
      s#@@NodesMetricsEnabledValue@@#true#g;
      s#@@ReplicationBucketKMSEncryptionKeyValue@@#${REPLICATION_KMS_ENCRYPTION_KEY}#g;
      s#@@RegistryCredentialsValue@@#${REGISTRY_SECRET}#g;
      s#@@DeployInfrastructureOnlyValue@@#false#g;
      s#@@KeyPairNameValue@@#${DESIRED_KEY_NAME}#g;
      s#@@AvailabilityZonesValue@@#${AVAILABILITY_ZONES}#g;
      s#@@EksExternalUserArnValue@@#${EXTERNAL_USER_ARN}#g;
    " alfresco-dbp-deployment/aws/templates/full-deployment-parameters.json
    ```
10. Create DBP EKS by using the [cloudformation command](https://docs.aws.amazon.com/cli/latest/reference/cloudformation/index.html).
    ```
    aws cloudformation create-stack \
      --stack-name my-dbp-eks \
      --template-body file://alfresco-dbp-deployment/aws/templates/full-deployment.yaml \
      --capabilities CAPABILITY_IAM \
      --parameters file://alfresco-dbp-deployment/aws/templates/full-deployment-parameters.json \
      --region=us-east-1 \
      --disable-rollback
    
    ```
11. Verify the created stack
    ```
        aws cloudformation describe-stacks --stack-name $STACK_NAME
    ```
12. Update the kubeconfig with the new EKS cluster
    ```
        aws eks update-kubeconfig --name $CLUSTER_NAME
    ```

### Deleting DBP EKS with AWS Cli
Open a terminal and enter:
```
aws cloudformation delete-stack --stack-name $STACK_NAME
```

## Cluster bastion access
To access the cluster using the deployed bastion, follow the instructions in [How to connect bastion host remotely](https://github.com/Alfresco/acs-deployment-aws/blob/master/docs/bastion_access.md).

## Cluster remote access
### Prerequisites

To access the DBP deployment on AWS provided Kubernetes cluster requires:

| Component   | Getting Started Guide |
| ------------| --------------------- |
| Kubectl     | https://kubernetes.io/docs/tasks/tools/install-kubectl/ |
| IAM User    | https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html |

Follow the detailed instructions in [EKS cluster remote access](https://github.com/Alfresco/acs-deployment-aws/blob/master/docs/eks_cluster_remote_access.md).
