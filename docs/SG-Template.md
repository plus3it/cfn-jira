### Security Groups

The [make_jira-dc_SGs.tmplt.json](/Templates/make_jira-dc_SGs.tmplt.json) file sets up the security group used to gate network-access to the Jira elements. The Jira design assumes that the entirety of the Jira-deployment exists within a security-silo. This silo contains only the Jira-service elements. The security-group created by this template is designed to foster communication between service-elements while allowing network-ingress and -egress to the silo _only_ through the Internet-facing load-balancer.
