# Contributing to the DBP Deployment Chart

Ways to contribute would be by submitting pull requests, reporting issues and creating suggestions. In the case of a defect please provide steps to reproduce the issue, as well as the expected result and the actual one. If you'd like a hand at trying to implement features yourself, please validate your changes by running the tests. Also pull requests should contain tests whenever possible.

As a contributor you must sign a [contribution agreement](https://cla-assistant.io/Alfresco/alfresco-dbp-deployment). Please review the guidelines for [submitting contributions](https://community.alfresco.com/docs/DOC-6269-submitting-contributions).

## Branching

There are two primary branches in this project: `master` and `develop`.

`master` contains (mostly) fixed versions of components, incremented according to the Digital Business Platform (DBP) versioning guide.

`develop` contains the latest of all components, including incubator / 'snapshots'. The DBP deployment chart is also the basis for the DBP pipeline (our internal test pipeline) and we need to know as soon as possible when any new component might cause that pipeline to fail, hence this branch.

Any contributions should be made as a pull request to the `develop` branch.  Once it is validated internally in the DBP pipeline it can be merged, when agreed upon, to the `master` branch in prepartation for release.

## How to upgrade DBP Components

The Digital Business Platform contains several different components, each with its own life cycle, where any increment of the minor segment of the appVersion of a component must increment the minor segment of the appVersion (and version) of the DBP chart. Additionally, any increment of any appVersion or chart version segment must always increment the chart version of a released DBP chart.

To upgrade a component you should follow this process:

1. Update the [requirements](https://github.com/Alfresco/alfresco-dbp-deployment/blob/master/helm/alfresco-dbp/requirements.yaml) file with the new chart version of the component.
2. Please increase the version of the DBP chart in [Chart.yaml](https://github.com/Alfresco/alfresco-dbp-deployment/blob/master/helm/alfresco-dbp/Chart.yaml#L2).
3. Create a PR referencing a JIRA issue.
4. The DBP test pipeline should be run, internally, when new versions of the chart are pushed to the Helm repository. *Note* Access to push new chart versions to the Alfresco helm repository is restricted.
