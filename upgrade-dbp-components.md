#Upgrade DBP Components

The Digital Business Platform contains several different components, each with its own life cycle.
To update any of them you should follow this process:
1. Update the [requirements](https://github.com/Alfresco/alfresco-dbp-deployment/blob/master/helm/alfresco-dbp/requirements.yaml) file with the new version of the component.
1. If you are updating DBP 1.5, please increase the version of the DBP chart in [Chart.yaml](https://github.com/Alfresco/alfresco-dbp-deployment/blob/develop/helm/alfresco-dbp/Chart.yaml#L2).
1. Create a PR.
1. The DBP test pipeline should be run when new versions of the chart are pushed to the Helm repository.
1. You can talk to any member of the Platform Services team to review your PR.
