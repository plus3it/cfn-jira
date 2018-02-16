### IAM Role

The [make_jira-dc_IAM-instance.tmplt.json](/Templates/make_jira-dc_IAM-instance.tmplt.json) file sets up an IAM role. This role is attached to the Jira-hosting EC2 instances. The primary purpose of the IAM role is to grant access from the EC2 instances to an associated S3 bucket. Secondarily, the IAM role allows deployment of EC2 instances via the AutoScaling service within a least-privileges deployment-environment. Finally, the IAM role includes permissions sufficient to make use of AWS's [Systems Manager](https://aws.amazon.com/systems-manager/) service (as a logical future capability).

An example of the resultant IAM policy can be viewed [here](/docs/IAMpolicyExample.md)
