// Pipeline script for Jenkins environment jenkins.ojop.io

pipeline {
  // https://jenkins.io/doc/book/pipeline/jenkinsfile/
  // https://www.jfrog.com/confluence/display/RTF/Working+With+Pipeline+Jobs+in+Jenkins

  agent {
    kubernetes {
      label "${BUILD_TAG}"
      defaultContainer 'dind-command-1'
      yaml """
        apiVersion: v1
        kind: Pod
        metadata:
          name: test
          labels:
            name: docker-build
        spec:
          containers:
          - name: dind-daemon
            image: docker:18.09-dind
            securityContext:
              privileged: true
          - name: awscli
            image: mesosphere/aws-cli:latest
            command:
            - cat
            tty: true
          - name: dind-command-1
            image: docker:18.09
            command:
            - cat
            tty: true
          - name: maven
            image: maven:3.3.9-jdk-8-alpine
            command:
            - cat
            tty: true
            env:
            - name: DOCKER_HOST
              value: tcp://localhost:2375
      """
    }
  }

  options {
    disableConcurrentBuilds()
  }

  tools {
    jdk 'jdk8'
  }

  environment {
      BRANCH_NAME = "ignite-2.7"
      RELEASE_VERSION = "2.7.0"
      REPO_URL = "https://github.com/percipiomedia/ignite.git"
      ARTIFACTORY_SERVER_ID = "jobcase"
  }

  parameters {
    booleanParam(name: 'RUN_UNIT_TESTS', defaultValue: false, description: '')
    string(name: 'DOCKER_IMAGE_NAME', defaultValue: 'platform/apacheignite', description: '')
  }

  stages {
    stage ('Run Build') {
        steps {
          container('maven') {
            // Create an Artifactory server instance, as described above in this article:
            def server = Artifactory.server("${ARTIFACTORY_SERVER_ID}")

            // Create and set an Artifactory Maven Build instance:
            def rtMaven = Artifactory.newMavenBuild()
            // Don't resolve artifacts from Artifactory
            // rtMaven.resolver server: server, releaseRepo: 'libs-release', snapshotRepo: 'libs-snapshot'
            rtMaven.deployer server: server, releaseRepo: 'libs-release-local', snapshotRepo: 'libs-snapshot-local'

            // Set a Maven Tool defined in Jenkins "Manage":
            env.MAVEN_HOME="/usr/share/maven"

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
        container('maven') {
           sh "mvn -f modules/core/pom.xml test -DskipTests=false -Dtest=org.apache.ignite.testsuites.IgniteBasicTestSuite -Dmaven.test.failure.ignore=true -Drelease.version=${RELEASE_VERSION}"
         }
      }
      post {
          always {
              junit '**/target/surefire-reports/TEST*.xml'
          }
      }
    }

    stage ('Build Assembly') {
      steps {
        container('maven') {
          sh 'mvn -f pom.xml initialize -Prelease -X'
        }
      }
    }

    stage('Get ECR Login') {
      steps {
        container('awscli') {
          script
          {
            withCredentials([usernamePassword(credentialsId: 'ecr-full-base', passwordVariable: 'AWS_SECRET_ACCESS_KEY', usernameVariable: 'AWS_ACCESS_KEY_ID'), string(credentialsId: 'ecr-full-token', variable: 'AWS_SESSION_TOKEN')])
            {
              docker_login = sh (
                              script: "aws ecr --region us-east-1 get-login --no-include-email",
                              returnStdout: true
                            ).trim()
            }
          }
        }
      }
    }

    stage('Build Docker Image') {
      steps {
        container('dind-command-1') {
          script {
            sh "${docker_login}"
            docker_image = docker.build(
                              "${params.DOCKER_IMAGE_NAME}",
                              "--cache-from 669820959381.dkr.ecr.us-east-1.amazonaws.com/" +
                                  "${params.DOCKER_IMAGE_NAME}" +
                                  ":${env.BRANCH_NAME}-latest ."
                            )
          }
        }
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
        container('dind-command-1') {
          script {
            sh "${docker_login}"
            commitId = checkout(scm).GIT_COMMIT
            docker.withRegistry('https://669820959381.dkr.ecr.us-east-1.amazonaws.com') {
                docker_image.push("${commitId}")
                docker_image.push("${env.BRANCH_NAME}-${env.BUILD_NUMBER}")
                docker_image.push("${env.BRANCH_NAME}-latest")
            }

          }
        }
      }
    }


  }
}
