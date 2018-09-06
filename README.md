# DOTC-Jira

The DOTC-Jira project is a sub-project of the overarching DevOps Tool-Chain (DOTC) project. This project — and its peer projects — is designed to handle the automated deployment of common DevOps tool-chain services onto STIG-harderend, EL7-compatible Amazon EC2 instances and related AWS resources. The first part of this automation is comprised of CloudFormation (CFn) templates. Included in this project are the following templated activities:

* [AutoScaling EC2](Templates/make_jira-dc_EC2-autoscale.tmplt.json) instance
* [Standalone EC2](Templates/make_jira-dc_EC2-node.tmplt.json) instance
* [EFS-based](Templates/make_jira-dc_EFS.tmplt.json) network-shares
* [Elastic LoadBalancer](Templates/make_jira-dc_ELBv1-pub.tmplt.json) (a.k.a., "Classic" or  "ELBv1" load-balancer)
* [Application LoadBalancer](Templates/make_jira-dc_ELBv2-pub.tmplt.json) (a.k.a, "ELBv2")
* [Instance-role](Templates/make_jira-dc_IAM-instance.tmplt.json) creation
* PostGreSQL [Amazon Relational Database Service](Templates/make_jira-dc_RDS.tmplt.json)
* [Simple Storage Service](Templates/make_jira-dc_S3-buckets.tmplt.json) (S3) backups-storage
* Network [Security Groups](Templates/make_jira-dc_SGs.tmplt.json)
* EFS + ELBv1 + Standalone EC2 [linked-stack template](Templates/make_jira-dc_parent-EFS-ELBv1.tmplt.json)
* EFS + ELBv2 + AutoScaling EC2 [linked-stack template](Templates/make_jira-dc_parent-EFS-ELBv2-autoscale.tmplt.json)
* EFS + ELBv2 + Standalone EC2 [linked-stack template](Templates/make_jira-dc_parent-EFS-ELBv2-instance.tmplt.json)

Additionally, automation-scripts are provided to automate the deployment of the Jira Server software onto the relevant EC2 instances - whether stand-alone or managed via AWS's AutoScaling service.

The above _may_ be usable to &mdash or, more likely, act as a starting-point for &mdash - automate the deployment of Jira DataCenter. No assocaited testing was done: if you borrow these templates to underpin additional capabilities, please  [contribute back](.github/contributing.md) the fruits of that effort (or notify us so we can link to your project).

## Design Assumptions

These templates are intended for use within AWS VPCs. It is further expected that the deployed-to VPCs will be configured with public and private subnets. All Jira elements other than the Elastic LoadBalancer(s) are expected to be deployed into private subnets. The Elastic LoadBalancers provide transit of Internet-originating web UI requests to the the Jira node's web-based interface.

## Notes on Templates' Usage

It is generally expected that the use of the various, individual-service templates will be run via the "parent" template(s). The "parent" template allows for a kind of "one-button" deployment method where all the user needs to worry about is populating the template's fields and ensuring that CFn can find the child templates.

In order to use the "parent" template, it is recommended that the child templates be hosted in an S3 bucket separate from the one created for backups by this stack-set. The template-hosting bucket may be public or not. The files may be set to public or not. CFn typically has sufficient privileges to read the templates from a bucket without requiring the containing bucket or files being set public. Use of S3 for hosting eliminates the need to find other hosting-locations or sort out access-particulars of those hosting locations.

The EC2-related templates — either autoscale or instance — currently require that the scripts be anonymously `curl`able. The scripts can still be hosted in a non-public S3 bucket, but the scripts' file-ACLs will need to allow `public-read`. This may change in future releases — likely via an enhancement to the IAM template.

These templates do not include Route53 functionality. It is assumed that the requisite Route53 or other DNS alias will be configured separate from the instantiation of the public-facing ELB.

* While there are templates provided for standalone EC2 instances, they are provided mostly for "completeness". It's expected most users of these templates will desire the availability-enhancements accorded by the use of the auto-scaling templates.
* The ELBv1 template is similarly provided for "completeness". It is expected that most users of these templates will either wish to use the more up-to-date AWS services ("future proofing") and/or the desire the extensible capabilities of the ALB (ELBv2).

## Jira Plugins

The capability to automate the installation of Jira plugins is provided through a supporting script.  The plugins-script takes arrays containing URLs to the plugin binaries and downloads the files into the appropriate Jira plugins-folder.  To pre-install Jira plugins, edit the plugin-script by adding plugin URLs into the appropriate plugins-array variable, and then add the URL where the plugins-script is hosted to the CFn parameters file. 

* Jira plugins fall into two types, Type 1 and Type 2, and are in installed in two different folders.  It is up to the end-user to make a pre-determination of the plugin type and placing the plugin URL in the appropriate array variable.
* The plugin-script supports standard and authenticated URLs:
  * Standard URLs to the plugin binaries must be public-readable.  S3-hosted binaries must have permissions set as `--acl=public-read`
  * Authenticated URLs are supported and must have the format `https://<USERNAME>:<PASSWORD>@<FQDN>/PATH/TO/FILE`

## Resultant Service Architecture

The templates and scripts act together to make standing up a new service is quick and (reasonably) easy. Application-level configuration - beyond JDBC configuration - are not handled by these templates and scripts.

These templates and scripts are also designed to ensure that Jira data is persisted and backed up. This ensures that the Jira service can be quickly and easily reconstituted as necessary.
* As part of this design, the Jira installation root is designed to be placed on an external, persistent network-attached storage. The supported storage option is currently limited to NFS (e.g. if using EFS). Some hooks for use with GlusterFS are included but not well-tested.
* Jira configuration data is expected to be hosted within an external PostGreSQL database (typically hosted via RDS).
* Backup cron-jobs for the Jira attachments directory and automated-exports directory are included in this automation. However, it is incumbent on the Jira-administrator to enable automated backup-exports within the Jira Application.

## Closing Notes

* Ability to destroy and recreate at will, while retaining all configuration and hosted data, has been tested. It's expected that most such actions will happen via stack-update or autoscaling actions (manual, scheduled or reactive).  In the event that a stack-update results in two instances being "live" simultaneously, it will be necessary to restart the new instance after the pre-update instance terminates. This requirement is resultant Jira's built-in data-integrity protections.
* Due to a [bug](https://bugzilla.redhat.com/show_bug.cgi?id=1312002) in the systemd/nfs-client implementation in RHEL/CentOS 7, reboots of instances have a better than 90% probability of hanging. This _should_ only effect template-users that deploy standalone Jira EC2s.
* The EC2 template runs [watchmaker](http://watchmaker.readthedocs.io/en/stable/) after the EC2 instance launches but before Jira has been installed. Watchmaker ensures that the resultant system is STIG-hardened. See the [Watchmaker document)(https://watchmaker.readthedocs.io/) for description of what Watchmaker does, how it does it and any additional, envionrment-specific fine-tuning that may be desired/needed.

![Build Status](https://travis-ci.org/plus3it/dotc-jira_dc.svg?branch=master)
