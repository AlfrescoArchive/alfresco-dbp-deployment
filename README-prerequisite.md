# Alfresco Digital Business Platform Prerequisites

The Alfresco Digital Business Platform Deployment requires:

| Component   | Recommended version | Getting Started Guide |
| ------------|:-----------: | ---------------------- |
| Docker      | 18.09.0      | https://docs.docker.com/ |
| Kubernetes  | 1.10.3       | https://kubernetes.io/docs/tutorials/kubernetes-basics/ |
| Kubectl     | 1.10.3       | https://kubernetes.io/docs/tasks/tools/install-kubectl/ |
| Helm        | 2.9.1        | https://docs.helm.sh/using_helm/#quickstart-guide |

In addition, since it can be deployed to different environments, check the requirements for:
- [KOPS deployment](#KOPS)
- [EKS deployment](#EKS)
- [Docker for Desktop deployment](#Docker-for-desktop---mac)

# KOPS
For KOPS deployment you will also need:

| Component   | Recommended version | Getting Started Guide |
| ------------|:-----------: | ---------------------- |
| Kops        | 1.8.1        | https://github.com/kubernetes/kops/blob/master/docs/aws.md |

# EKS
For EKS deployment you will also need:

| Component   | Recommended version | Getting Started Guide |
| ------------|:-----------: | ---------------------- |
| AWS Cli     | 1.16.33      | https://github.com/aws/aws-cli#installation |

# Docker for desktop - mac
For Docker for desktop on mac deployment you will also need:

| Component          | Recommended version | Getting Started Guide |
| -------------------| :--------------: | ----------------------   |
| Homebrew           |  1.7.7           | https://brew.sh/         |
| Docker for Desktop |  2.0.0.0         | https://docs.docker.com/ |

Any variation from these technologies and versions may affect the end result. If you do experience any issues please let us know through our [Gitter channel](https://gitter.im/Alfresco/platform-services?utm_source=share-link&utm_medium=link&utm_campaign=share-link).