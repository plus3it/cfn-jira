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
        string(name: 'SourceBucket', description: 'Bucket to copy contents from')
        string(name: 'DestinationBucket', description: 'Bucket to copy contents to')
        string(name: 'RootFolder', description: 'Which bucket-folder to synchronize (if any)')
    }

    stages {
        stage ('Copy Bucket') {
            steps {
                input 'Have you turned of cron on the source node'
                withCredentials(
                    [
                        [$class: 'AmazonWebServicesCredentialsBinding', accessKeyVariable: 'AWS_ACCESS_KEY_ID', credentialsId: "${AwsCred}", secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']
                    ]
                ) {
                    sh '''#!/bin/bash
                        cat bucket_census.txt
                        printf "Syncing from s3://${SourceBucket}/${RootFolder} "
                        printf "to s3://${DestinationBucket}/${RootFolder} "
                        echo "[BE PATIENT]"
                        aws s3 sync --delete "s3://${SourceBucket}/${RootFolder}" "s3://${DestinationBucket}/${RootFolder}"

                        SYNCSTATUS="$?"

                        case ${SYNCSTATUS} in
                           0) echo "No errors recorded"
                              ;;
                           1) echo "Some files were omitted"
                              exit 0
                              ;;
                           2) echo "Error messages were emitted"
                              ;;
                        esac

                        exit "${SYNCSTATUS}"
                    '''
                }
            }
        }
        stage ('Diff Buckets') {
            steps {
                parallel (
                    source: {
                        withCredentials(
                            [
                                [$class: 'AmazonWebServicesCredentialsBinding', accessKeyVariable: 'AWS_ACCESS_KEY_ID', credentialsId: "${AwsCred}", secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']
                            ]
                        ) {
                            sh '''#!/bin/bash
                                if [[ -z ${RootFolder} ]]
                                then
                                   echo "Censusing entirety of s3://${SourceBucket}"
                                else
                                   LIMITSCOPE="--prefix ${RootFolder}"
                                   echo "Censusing s3://${SourceBucket}/${RootFolder}"
                                fi

                                BUCKETCOUNTS=($( aws s3api list-objects --bucket ${SourceBucket} \${LIMITSCOPE} --output json --query "[sum(Contents[].Size), length(Contents[])]" | awk 'NR!=2 {print \$0;next} NR==2 {print \$0 / 1024 / 1024 / 1024}' ))

                                # For the console readers...
                                printf "\tBucket Size: %sGiB\n" "${BUCKETCOUNTS[1]}"
                                printf "\tBucket objects: %s\n" "${BUCKETCOUNTS[2]}"
                            '''
                        }
                    },
                    destination: {
                        withCredentials(
                            [
                                [$class: 'AmazonWebServicesCredentialsBinding', accessKeyVariable: 'AWS_ACCESS_KEY_ID', credentialsId: "${AwsCred}", secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']
                            ]
                        ) {
                            sh '''#!/bin/bash
                                if [[ -z ${RootFolder} ]]
                                then
                                   echo "Censusing entirety of s3://${DestinationBucket}"
                                else
                                   LIMITSCOPE="--prefix ${RootFolder}"
                                   echo "Censusing s3://${DestinationBucket}/${RootFolder}"
                                fi

                                BUCKETCOUNTS=($( aws s3api list-objects --bucket ${DestinationBucket} \${LIMITSCOPE} --output json --query "[sum(Contents[].Size), length(Contents[])]" | awk 'NR!=2 {print \$0;next} NR==2 {print \$0 / 1024 / 1024 / 1024}' ))

                                # For the console readers...
                                printf "\tBucket Size: %sGiB\n" "${BUCKETCOUNTS[1]}"
                                printf "\tBucket objects: %s\n" "${BUCKETCOUNTS[2]}"
                            '''
                        }
                    }
                )
            }
        }
    }
}
