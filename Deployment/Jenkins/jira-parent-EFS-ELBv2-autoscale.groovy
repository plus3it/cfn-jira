pipeline {

    agent any

    options {
        buildDiscarder(
            logRotator(
                numToKeepStr: '5',
                daysToKeepStr: '30',
                artifactDaysToKeepStr: '30',
                artifactNumToKeepStr: '3'
            )
        )
        disableConcurrentBuilds()
        timeout(time: 60, unit: 'MINUTES')
    }

    environment {
        AWS_DEFAULT_REGION = "${AwsRegion}"
        AWS_CA_BUNDLE = '/etc/pki/tls/certs/ca-bundle.crt'
        REQUESTS_CA_BUNDLE = '/etc/pki/tls/certs/ca-bundle.crt'
    }

    parameters {
        string(name: 'AwsRegion', defaultValue: 'us-east-1', description: 'Amazon region to deploy resources into')
        string(name: 'AwsCred', description: 'Jenkins-stored AWS credential with which to execute cloud-layer commands')
        string(name: 'GitCred', description: 'Jenkins-stored Git credential with which to execute git commands')
        string(name: 'GitProjUrl', description: 'SSH URL from which to download the Jenkins git project')
        string(name: 'GitProjBranch', description: 'Project-branch to use from the Jenkins git project')
        string(name: 'CfnStackRoot', description: 'Unique token to prepend to all stack-element names')
        string(name: 'TemplateUrl', description: 'S3-hosted URL for the EC2 template file')
        string(name: 'AdminPubkeyURL', description: 'URL to the administrator pub keys')
        string(name: 'AmiId', description: 'ID of the AMI to launch')
        string(name: 'AsgTemplateUri', description: 'URI for the template that creates the Jira-hosting EC2 instance.')
        string(name: 'BackupVolumeDevice', defaultValue: 'false', description: 'Whether to mount an extra EBS volume. Leave as default (\"false\") to launch without an extra application volume')
        string(name: 'BackupVolumeMountPath', defaultValue: '/var/backups', description: 'Filesystem path to mount the extra app volume. Ignored if \"AppVolumeDevice\" is blank')
        string(name: 'BackupVolumeSize', defaultValue: '10', description: 'Size in GB of the EBS volume to create. Ignored if \"AppVolumeDevice\" is blank')
        string(name: 'BackupVolumeType', defaultValue: 'gp2', description: 'Type of EBS volume to create. Ignored if \"AppVolumeDevice\" is blank')
        string(name: 'DbAdminName', description: 'Name of the Jira master database-user.')
        string(name: 'DbAdminPass', description: 'Password of the Jira master database-user.')
        string(name: 'DbDataSize', defaultValue: '5', description: 'Size in GiB of the RDS table-space to create. Must be between 5GB and 16384GB.')
        string(name: 'DbInstanceName', description: 'Instance-name of the Jira database.')
        string(name: 'DbInstanceType', defaultValue: 'db.t2.small', description: 'Amazon RDS instance type')
        string(name: 'DbNodeName', description: 'NodeName of the Jira database.')
        string(name: 'Ec2Domain', description: 'Suffix for Jira hostname and DNS record')
        string(name: 'Ec2Hostname', description: 'Node-name for Jira hostname and DNS record')
        string(name: 'Ec2ProvKey', description: 'Public/private key pairs allowing the provisioning-user to securely connect to the instance after it launches.')
        string(name: 'EfsTemplateUri', description: 'Link to EFS template')
        string(name: 'ElbTemplateUri', description: 'Link to ELB template')
        string(name: 'EpelRepo', defaultValue: 'epel', description: 'An alphanumeric string that represents the EPEL yum repo s label')
        string(name: 'HaSubnets', description: 'Subnets to deploy service-elements to: select as many private-subnets as are available in VPC - selecting one from each Availability Zone')
        string(name: 'IamTemplateUri', description: 'URI for the template that creates Jira IAM role(s).')
        string(name: 'InstanceType', defaultValue: 't2.large', description: 'Amazon EC2 instance type')
        string(name: 'JiraAppPrepUrl', defaultValue: '', description: 'URL to the Jira Datacenter EC2 application installer/configuration script.')
        string(name: 'JiraBinaryInstallerUrl', defaultValue: '', description: 'URL to the Jira Datacenter binary-installer file.')
        string(name: 'JiraHomeSharePath', defaultValue: '', description: 'Share-path of shared Jira-home.')
        string(name: 'JiraHomeShareType', description: 'Type of network share hosting persisted Jira-home content.')
        string(name: 'JiraListenPort', defaultValue: '443', description: 'TCP Port number on which the Jenkins ELB listens for requests')
        string(name: 'JiraListenerCert', defaultValue: '', description: 'Name/ID of the ACM-managed SSL Certificate securing the public listener')
        string(name: 'JiraOsPrepUrl', defaultValue: '', description: 'URL to the Jira Datacenter EC2 OS-preparationscript.')
        string(name: 'JiraPluginUrl', defaultValue: '', description: 'URL to the Jira Datacenter Plugin installation script.')
        string(name: 'JiraProxyFqdn', description: 'FQDN of the front-end proxy host/service for Jira.')
        string(name: 'JiraServicePort', defaultValue: '80', description: 'TCP Port number that the Jira host listens to')
        string(name: 'PgsqlVersion', defaultValue: '9.5.10', description: 'The X.Y.Z version of the PostGreSQL database to deploy.')
        string(name: 'PipIndexFips', defaultValue: 'https://pypi.org/simple/', description: 'URL of pip index  that is compatible with FIPS 140-2 requirements.')
        string(name: 'PipRpm', defaultValue: 'python2-pip', description: 'Name of preferred pip RPM.')
        string(name: 'ProvisionUser', defaultValue: 'jirabuild', description: 'Default login user account name.')
        string(name: 'ProxyPrettyName', description: 'A short human friendly label to assign to the ELB (no capital letters)')
        string(name: 'PubElbSubnets', description: 'Select three subnets - each from different, user-facing Availability Zones.')
        string(name: 'PyStache', defaultValue: 'pystache', description: 'Name of preferred pystache RPM')
        string(name: 'RdsTemplateUri', description: 'URI for the template that creates Jira RDS database.')
        string(name: 'S3TemplateUri', description: 'URI for the template that creates Jira S3 buckets.')
        string(name: 'RolePrefix', description: '(Optional) Prefix to apply to IAM role')
        string(name: 'ServiceTld', defaultValue: 'amazonaws.com', description: 'TLD of the IAMable service-name')
        string(name: 'SgTemplateUri', description: 'URI for the template that creates Jira SGs.')
        string(name: 'TargetVPC', description: 'ID of the VPC to deploy cluster nodes into.')
        string(name: 'WatchmakerConfig', defaultValue: '', description: '(Optional) URL to a Watchmaker config file')
        string(name: 'WatchmakerEnvironment', defaultValue: '', description: 'Environment in which the instance is being deployed')
        string(name: 'WatchmakerS3Source', defaultValue: 'false', description: 'Flag that tells watchmaker to use its instance role to retrieve watchmaker content from S3')
    }

    stages {
        stage ('Prepare Agent Environment') {
            steps {
                deleteDir()
                git branch: "${GitProjBranch}",
                    credentialsId: "${GitCred}",
                    url: "${GitProjUrl}"
                writeFile file: 'parent.instance.parms.json',
                    text: /
                    [
                      {
                        "ParameterKey": "AdminPubkeyURL",
                        "ParameterValue": "${env.AdminPubkeyURL}"
                      },
                      {
                        "ParameterKey": "AmiId",
                        "ParameterValue": "${env.AmiId}"
                      },
                      {
                        "ParameterKey": "AsgTemplateUri",
                        "ParameterValue": "${env.AsgTemplateUri}"
                      },
                      {
                        "ParameterKey": "BackupVolumeDevice",
                        "ParameterValue": "${env.BackupVolumeDevice}"
                      },
                      {
                        "ParameterKey": "BackupVolumeMountPath",
                        "ParameterValue": "${env.BackupVolumeMountPath}"
                      },
                      {
                        "ParameterKey": "BackupVolumeSize",
                        "ParameterValue": "${env.BackupVolumeSize}"
                      },
                      {
                        "ParameterKey": "BackupVolumeType",
                        "ParameterValue": "${env.BackupVolumeType}"
                      },
                      {
                        "ParameterKey": "DbAdminName",
                        "ParameterValue": "${env.DbAdminName}"
                      },
                      {
                        "ParameterKey": "DbAdminPass",
                        "ParameterValue": "${env.DbAdminPass}"
                      },
                      {
                        "ParameterKey": "DbDataSize",
                        "ParameterValue": "${env.DbDataSize}"
                      },
                      {
                        "ParameterKey": "DbInstanceName",
                        "ParameterValue": "${env.DbInstanceName}"
                      },
                      {
                        "ParameterKey": "DbInstanceType",
                        "ParameterValue": "${env.DbInstanceType}"
                      },
                      {
                        "ParameterKey": "DbNodeName",
                        "ParameterValue": "${env.DbNodeName}"
                      },
                      {
                        "ParameterKey": "Ec2Domain",
                        "ParameterValue": "${env.Ec2Domain}"
                      },
                      {
                        "ParameterKey": "Ec2Hostname",
                        "ParameterValue": "${env.Ec2Hostname}"
                      },
                      {
                        "ParameterKey": "Ec2ProvKey",
                        "ParameterValue": "${env.Ec2ProvKey}"
                      },
                      {
                        "ParameterKey": "EfsTemplateUri",
                        "ParameterValue": "${env.EfsTemplateUri}"
                      },
                      {
                        "ParameterKey": "ElbTemplateUri",
                        "ParameterValue": "${env.ElbTemplateUri}"
                      },
                      {
                        "ParameterKey": "EpelRepo",
                        "ParameterValue": "${env.EpelRepo}"
                      },
                      {
                        "ParameterKey": "HaSubnets",
                        "ParameterValue": "${env.HaSubnets}"
                      },
                      {
                        "ParameterKey": "IamTemplateUri",
                        "ParameterValue": "${env.IamTemplateUri}"
                      },
                      {
                        "ParameterKey": "InstanceType",
                        "ParameterValue": "${env.InstanceType}"
                      },
                      {
                        "ParameterKey": "JiraAppPrepUrl",
                        "ParameterValue": "${env.JiraAppPrepUrl}"
                      },
                      {
                        "ParameterKey": "JiraBinaryInstallerUrl",
                        "ParameterValue": "${env.JiraBinaryInstallerUrl}"
                      },
                      {
                        "ParameterKey": "JiraHomeSharePath",
                        "ParameterValue": "${env.JiraHomeSharePath}"
                      },
                      {
                        "ParameterKey": "JiraHomeShareType",
                        "ParameterValue": "${env.JiraHomeShareType}"
                      },
                      {
                        "ParameterKey": "JiraListenerCert",
                        "ParameterValue": "${env.JiraListenerCert}"
                      },
                      {
                        "ParameterKey": "JiraListenPort",
                        "ParameterValue": "${env.JiraListenPort}"
                      },
                      {
                        "ParameterKey": "JiraOsPrepUrl",
                        "ParameterValue": "${env.JiraOsPrepUrl}"
                      },
                      {
                        "ParameterKey": "JiraPluginUrl",
                        "ParameterValue": "${env.JiraPluginUrl}"
                      },
                      {
                        "ParameterKey": "JiraProxyFqdn",
                        "ParameterValue": "${env.JiraProxyFqdn}"
                      },
                      {
                        "ParameterKey": "JiraServicePort",
                        "ParameterValue": "${env.JiraServicePort}"
                      },
                      {
                        "ParameterKey": "PgsqlVersion",
                        "ParameterValue": "${env.PgsqlVersion}"
                      },
                      {
                        "ParameterKey": "PipIndexFips",
                        "ParameterValue": "${env.PipIndexFips}"
                      },
                      {
                        "ParameterKey": "PipRpm",
                        "ParameterValue": "${env.PipRpm}"
                      },
                      {
                        "ParameterKey": "ProvisionUser",
                        "ParameterValue": "${env.ProvisionUser}"
                      },
                      {
                        "ParameterKey": "ProxyPrettyName",
                        "ParameterValue": "${env.ProxyPrettyName}"
                      },
                      {
                        "ParameterKey": "PubElbSubnets",
                        "ParameterValue": "${env.PubElbSubnets}"
                      },
                      {
                        "ParameterKey": "PyStache",
                        "ParameterValue": "${env.PyStache}"
                      },
                      {
                        "ParameterKey": "RdsTemplateUri",
                        "ParameterValue": "${env.RdsTemplateUri}"
                      },
                      {
                        "ParameterKey": "RolePrefix",
                        "ParameterValue": "${env.RolePrefix}"
                      },
                      {
                        "ParameterKey": "S3TemplateUri",
                        "ParameterValue": "${env.S3TemplateUri}"
                      },
                      {
                        "ParameterKey": "ServiceTld",
                        "ParameterValue": "${env.ServiceTld}"
                      },
                      {
                        "ParameterKey": "SgTemplateUri",
                        "ParameterValue": "${env.SgTemplateUri}"
                      },
                      {
                        "ParameterKey": "TargetVPC",
                        "ParameterValue": "${env.TargetVPC}"
                      }
                    ]
                   /
                }
            }
        stage ('Prepare AWS Environment') {
            options {
                timeout(time: 1, unit: 'HOURS')
            }
            steps {
                withCredentials(
                    [
                        [$class: 'AmazonWebServicesCredentialsBinding', accessKeyVariable: 'AWS_ACCESS_KEY_ID', credentialsId: "${AwsCred}", secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'],
                        sshUserPrivateKey(credentialsId: "${GitCred}", keyFileVariable: 'SSH_KEY_FILE', passphraseVariable: 'SSH_KEY_PASS', usernameVariable: 'SSH_KEY_USER')
                    ]
                ) {
                    sh '''#!/bin/bash
                        echo "Attempting to delete any active ${CfnStackRoot}-ParAuto-${BUILD_NUMBER} stacks... "
                        aws --region "${AwsRegion}" cloudformation delete-stack --stack-name "${CfnStackRoot}-ParAuto-${BUILD_NUMBER}"

                        aws cloudformation wait stack-delete-complete --stack-name ${CfnStackRoot}-ParAuto-${BUILD_NUMBER} --region ${AwsRegion}
                    '''
                }
            }
        }
        stage ('Launch Jenkins Master Parent Instance Stack') {
            options {
                timeout(time: 1, unit: 'HOURS')
            }
            steps {
                withCredentials(
                    [
                        [$class: 'AmazonWebServicesCredentialsBinding', accessKeyVariable: 'AWS_ACCESS_KEY_ID', credentialsId: "${AwsCred}", secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'],
                        sshUserPrivateKey(credentialsId: "${GitCred}", keyFileVariable: 'SSH_KEY_FILE', passphraseVariable: 'SSH_KEY_PASS', usernameVariable: 'SSH_KEY_USER')
                    ]
                ) {
                    sh '''#!/bin/bash
                        echo "Attempting to create stack ${CfnStackRoot}-ParAuto-${BUILD_NUMBER}..."
                        aws --region "${AwsRegion}" cloudformation create-stack --stack-name "${CfnStackRoot}-ParAuto-${BUILD_NUMBER}" \
                          --disable-rollback --capabilities CAPABILITY_NAMED_IAM \
                          --template-url "${TemplateUrl}" \
                          --parameters file://parent.instance.parms.json

                        aws cloudformation wait stack-create-complete --stack-name ${CfnStackRoot}-ParAuto-${BUILD_NUMBER} --region ${AwsRegion}
                    '''
                }
            }
        }
    }
}
