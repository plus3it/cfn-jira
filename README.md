This project is designed to make a deployment of Jira Data Center a bit more automated. The templates and scripts act together to ensure that Jira data is persisted so that it can be quickly and easily reconstituted as necessary. The Jira installation root is designed to be placed on persistent storage options - the currently supported storage options are NFS (e.g. if using EFS) and GlusterFS. Jira configuration data is expected to be hosted within an external PostGreSQL database (typically hosted via RDS).

Note: The EC2 template runs [watchmaker](http://watchmaker.readthedocs.io/en/stable/) after Jira has provisioned so that the resultant system is hardened. See the previously (linked-to) documents for information on what watchmaker does.

![Build Status](https://travis-ci.org/plus3it/dotc-jira_dc.svg?branch=master)
