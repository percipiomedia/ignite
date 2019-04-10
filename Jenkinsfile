pipeline {
  // https://jenkins.io/doc/book/pipeline/jenkinsfile/
  // https://www.jfrog.com/confluence/display/RTF/Working+With+Pipeline+Jobs+in+Jenkins

  agent {
    label 'docker'
  }

  options {
    disableConcurrentBuilds()
  }

  tools {
    jdk 'JDK8u181'
    maven 'Maven 3.3.9'
  }

  environment {
      BRANCH_NAME = "ignite-2.7"
      RELEASE_VERSION = "2.7.0"
      REPO_URL = "https://github.com/percipiomedia/ignite.git"
      ARTIFACTORY_SERVER_ID = "jobcase"
      MAVEN_TOOL = "Maven 3.3.9"
      ECR_HOST = "669820959381.dkr.ecr.us-east-1.amazonaws.com"
  }

  parameters {
    booleanParam(name: 'RUN_UNIT_TESTS', defaultValue: false, description: '')
    string(name: 'DOCKER_IMAGE_NAME', defaultValue: 'platform/apacheignite', description: '')
  }

  stages {
    stage ('Run Build') {
        steps {
          script {
            // Create an Artifactory server instance, as described above in this article:
            def server = Artifactory.server("${ARTIFACTORY_SERVER_ID}")

            // Create and set an Artifactory Maven Build instance:
            def rtMaven = Artifactory.newMavenBuild()
            // Don't resolve artifacts from Artifactory
            // rtMaven.resolver server: server, releaseRepo: 'libs-release', snapshotRepo: 'libs-snapshot'
            rtMaven.deployer server: server, releaseRepo: 'libs-release-local', snapshotRepo: 'libs-snapshot-local'

            // Set a Maven Tool defined in Jenkins "Manage":
            rtMaven.tool = "${MAVEN_TOOL}"

            // Run Maven:
            def mvn_goals = "clean install -Pall-java,all-scala,licenses -DskipTests=true -Drelease.version=${RELEASE_VERSION}"
            def buildInfo = rtMaven.run pom: 'pom.xml', goals: mvn_goals.toString()

            // Publish the build-info to Artifactory:
            server.publishBuildInfo buildInfo
          }
        }
    }

    stage ('Run Core Basic Unit tests') {
       environment {
         MAVEN_OPTS = "-Xms2g -Xmx2g"
       }
       when {
            expression {
                "${params.RUN_UNIT_TESTS}" == "true"
            }
        }
        steps {
          sh "mvn -f modules/core/pom.xml test -DskipTests=false -Dtest=org.apache.ignite.testsuites.IgniteBasicTestSuite -Dmaven.test.failure.ignore=true -Drelease.version=${RELEASE_VERSION}"
        }
        post {
              always {
                  junit '**/target/surefire-reports/TEST*.xml'
              }
        }
    }

    stage ('Build Assembly') {
        steps {
          sh 'mvn -f pom.xml initialize -Prelease -X'
        }
    }

    stage ('Build Docker Image') {
        steps {
          sh '''#!/bin/bash
            id

            mvn -f docker/apache-ignite-jobcase/prod/pom.xml dependency:copy-dependencies

            cd ${WORKSPACE}/docker/apache-ignite-jobcase/prod

            rm -rf ./apache-ignite-*

            # copy maven build result into docker build path
            cp ${WORKSPACE}/target/bin/apache-ignite-*-bin.zip .
            unzip apache-ignite-*-bin.zip

            docker build -t apacheignite/jobcase:${RELEASE_VERSION} .
           '''
        }
    }

    stage ('Validate Docker Container') {
        steps {
          sh '''#!/bin/bash
            source ${WORKSPACE}/dev-ops/jenkins/pipeline/validate_docker_image.sh
           '''
        }
    }

    stage ('Push Docker Image') {
        steps {
          sh """#!/bin/bash

            login_cmd=$(aws --region us-east-1 ecr get-login --no-include-email --registry-ids 669820959381)

            echo "${login_cmd}" > /tmp/docker_login.sh

            chmod +x /tmp/docker_login.sh

            /tmp/docker_login.sh

            rm /tmp/docker_login.sh

            docker tag apacheignite/jobcase:${RELEASE_VERSION} ${ECR_HOST}/${params.DOCKER_IMAGE_NAME}:${RELEASE_VERSION}-build${BUILD_NUMBER}
            docker tag apacheignite/jobcase:${RELEASE_VERSION} ${ECR_HOST}/${params.DOCKER_IMAGE_NAME}:LATEST2.7

            docker push ${ECR_HOST}/${params.DOCKER_IMAGE_NAME}:${RELEASE_VERSION}-build${BUILD_NUMBER}
            docker push ${ECR_HOST}/${params.DOCKER_IMAGE_NAME}:LATEST2.7
          """
        }
    }
  }
}