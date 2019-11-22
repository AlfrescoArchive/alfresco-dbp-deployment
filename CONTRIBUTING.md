# Contributing to Alfresco Digital Business Platform

Ways to contribute would be by submitting pull requests, reporting issues and creating suggestions. In the case of a defect please provide steps to reproduce the issue, as well as the expected result and the actual one. If you'd like a hand at trying to implement features yourself, please validate your changes by running the tests. Also pull requests should contain tests whenever possible. 

#### How to upgrade DBP Components

The Digital Business Platform contains several different components, each with its own life cycle, where any increment of the minor segment of the appVersion of a component must increment the minor segment of the appVersion (and version) of the DBP chart. Additionally, any increment of any appVersion or chart version segment must always increment the chart version of a released DBP chart.

To upgrade a component you should follow this process:
1. Update the [requirements](https://github.com/Alfresco/alfresco-dbp-deployment/blob/master/helm/alfresco-dbp/requirements.yaml) file with the new chart version of the component.
1. If you are updating DBP 1.5, please increase the version of the DBP chart in [Chart.yaml](https://github.com/Alfresco/alfresco-dbp-deployment/blob/master/helm/alfresco-dbp/Chart.yaml#L2).
1. Create a PR referencing a JIRA issue.
1. The DBP test pipeline should be run when new versions of the chart are pushed to the Helm repository.

#### Contributor Agreement

As a contributor you must sign a [contribution agreement](https://cla-assistant.io/Alfresco/alfresco-identity-service). Please review the guidelines for [submitting contributions](https://community.alfresco.com/docs/DOC-6269-submitting-contributions). After reviewing the guidelines, if you have any questions about making a contribution you can contact us on the [Platform Services](https://gitter.im/Alfresco/platform-services) gitter channel.
