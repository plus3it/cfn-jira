### "Classic" Elastic LoadBalancer

All of the Jira EC2 instances launched by this project should be deployed into a VPC's private subnets. The Elastic LoadBalancer &mdash; created by the [make_jira-dc_ELBv2-pub.tmplt.json](/Templates/make_jira-dc_ELBv2-pub.tmplt.json) template &mdash; provides the public-facing ingress-/egress-point to the Jira service-deployment. This ELB provides the bare-minimum transit services required for the Jira web service to be usable from client requests arriving via the public Internet.
