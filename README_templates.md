Please note that use of the `make_jira-dc_parent-EFS.tmplt.json` Template assumes:
- All template files will be made available by way of an S3 bucket readable by the CloudFormation service as it operates under the IAM user or role executing the template-stack
- The executing IAM user/role has sufficient permission to view, create and modify all object-types (IAM roles, network Security-Gropus, EFS shares, RDS databases, S3 buckets and EC2 instances) in the linked-stack
- Deployment of the associated linked-stack will be into a region that has the EFS service available
- Deployment of the linked-stack will be into a VPC provisioned with private subnets (and the subnets will have a valid NAT to Internet-hosted resources)
- The target VPC will have at least three private subnets available to deploy resources into
- Deployment of the EC2, RDS and EFS resources will be into the available private subnets
