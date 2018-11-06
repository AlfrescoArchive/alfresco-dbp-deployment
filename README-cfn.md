# DBP Deployment on AWS Cloud

## Overview

This project contains the code for the AWS-based DBP product on AWS Cloud using an AWS CloudFormation template.  It's built with a main CloudFormation (CFN) template that also spins up sub-stacks for a VPC, Bastion Host, EKS Cluster and Worker Nodes (including registering them with the EKS Master) in an auto-scaling group.

**Note:** You need to clone the following repositories to deploy the DBP:
* [Alfresco DBP Deployment](https://github.com/Alfresco/alfresco-dbp-deployment)
* [ACS Deployment AWS](https://github.com/Alfresco/acs-deployment-aws)

## Limitations

Currently, this setup will only work in AWS US East (N.Virginia) and West (Oregon) regions due to current EKS support. For an overview of which regions EKS is currently available, see [Regional Product Services](https://aws.amazon.com/about-aws/global-infrastructure/regional-product-services/).


## How to deploy DBP Cluster on AWS
### Prerequisites
* You need a hosted zone e.g. example.com. See [Creating a Public Hosted Zone](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/CreatingHostedZone.html)
* An SSL certificate for the Elastic Load Balancer and the domains in the hosted zone [Creating SSL Cert](https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/ssl-server-cert.html)

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

### Preparing the S3 bucket for CFN template deployment
The master template (`aws/templates/full-deployment.yaml`) requires a few supporting files hosted in S3, like lambdas, scripts and CFN templates. To do this, create or use an S3 bucket in the same region as you intend to deploy DBP. Also, the S3 bucket needs to have a key prefix in it:
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
          |       |      +-- alfresco-lambda-empty-s3-bucket.jar
          |       |      +-- helm-helper-lambda.zip
          |       |-- scripts
          |       |      |-- deleteIngress.sh
          |       |      +-- getElb.sh
          |       |      +-- helmDeploy.sh
          |       |      +-- helmIngress.sh
          |       |      +-- helmInit.sh
          |       |-- templates
          |       |      |-- acs.yaml
          |       |      +-- full-deployment.yaml
          |       |      +-- full-master-parameters.json
          |       |      +-- bastion-and-eks-cluster.yaml
          |       |      +-- efs.yaml
          |       |      +-- rds.yaml
          |       |      +-- s3-bucket.yaml
```

## Deploying DBP EKS with AWS Console
**Note:** To use the AWS Console, make sure that you've uploaded the required files to S3 as described in [Preparing the S3 bucket for CFN template deployment](#preparing-the-s3-bucket-for-cfn-template-deployment).

* Go to the AWS Console and open CloudFormation
* Click ```Create Stack```
* In ```Upload a template to Amazon S3``` choose `/alfresco-dbp-deployment/aws/templates/full-deployment.yaml`
* Choose a stack name, like `my-dbp-eks`
* Fill out the parameters. In many cases you can use the default parameters. For some parameter sections
we will provide some additional information.

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


## Deploying DBP EKS with AWS Cli
**Note:** To use the Cli, make sure that you've uploaded the required files to S3 as described in [Preparing the S3 bucket for CFN template deployment](#preparing-the-s3-bucket-for-cfn-template-deployment).

### Prerequisites

To run the DBP deployment on AWS provided Kubernetes cluster requires:

| Component   | Getting Started Guide |
| ------------| --------------------- |
| AWS Cli     | https://github.com/aws/aws-cli#installation |


Create DBP EKS by using the [cloudformation command](https://docs.aws.amazon.com/cli/latest/reference/cloudformation/index.html). Make sure that you use the same bucket name and key prefix in the Cli command as you provided in [Prepare the S3 bucket for CFN template deployment](#prepare-the-s3-bucket-for-cfn-template-deployment).

```bash
aws cloudformation create-stack \
  --stack-name my-dbp-eks \
  --template-body file://alfresco-dbp-deployment/aws/templates/full-deployment.yaml \
  --capabilities CAPABILITY_IAM \
  --parameters file://alfresco-dbp-deployment/aws/templates/full-deployment-parameters.json \
  --parameters ParameterKey=KeyPairName,ParameterValue=<MyKey.pem> \
               ParameterKey=AvailabilityZones,ParameterValue=us-east-1a\\,us-east-1b \
               ParameterKey=EksExternalUserArn,ParameterValue=arn:aws:iam::<AccountId>:user/<IamUser>

```

### Deleting DBP EKS with AWS Cli
Open a terminal and enter:
```
aws cloudformation delete-stack --stack-name <master-dbp-eks-stack>
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

### Install the DBP on the EKS cluster

To install the DBP on the EKS cluster please follow the steps provided here: [Install DBP](https://github.com/Alfresco/alfresco-dbp-deployment/blob/master/README.md)
