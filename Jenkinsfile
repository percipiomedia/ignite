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

    // run benchmark parameters
    booleanParam(name: 'RUN_BENCHMARK_TESTS', defaultValue: false, description: '')

    booleanParam(name: 'USE_COMPUTE', defaultValue: false, description: '')
    string(name: 'JVM_HEAP_SIZE', defaultValue: '6g', description: '')
    string(name: 'JVM_METASPACE_SIZE', defaultValue: '2g', description: '')
    string(name: 'JIRA_USER_NAME', defaultValue: 'mgay@jobcase.com', description: '')
    string(name: 'JIRA_AUTH_TOKEN', defaultValue: 'hli5MJzMBhL0gmXEfsGuEED7', description: '')

    string(name: 'PARENT_CONFLUENCE_PAGE_ID', defaultValue: '477003947', description: '')
    string(name: 'CONFLUENCE_SPACE_KEY', defaultValue: '~95425488', description: '')
    string(name: 'NUM_NODES', defaultValue: '2', description: '')

    booleanParam(name: 'STOP_CONTAINERS', defaultValue: true, description: '')
    booleanParam(name: 'RUN_ALL', defaultValue: false, description: '')
    booleanParam(name: 'RUN_MLSTORE', defaultValue: false, description: '')

    booleanParam(name: 'JAVA_FLIGHT_RECORDER', defaultValue: true, description: '')

    string(name: 'THREAD_COUNT', defaultValue: '64', description: '')
    string(name: 'IGNITE_STRIPED_POOL_SIZE', defaultValue: '8', description: '')

    string(name: 'RUN_BENCHMARK_PROP_FILE', defaultValue: '', description: '')
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

            aws --region us-east-1 ecr get-login --no-include-email --registry-ids 669820959381 > /tmp/docker_login.sh

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

    stage ('Run Benchmark Tests') {
       environment {
         // make parameters available as environment settings
         USE_COMPUTE = "${params.USE_COMPUTE}"

         JVM_HEAP_SIZE = "${params.JVM_HEAP_SIZE}"

         JVM_METASPACE_SIZE = "${params.JVM_METASPACE_SIZE}"
         JIRA_USER_NAME = "${params.JIRA_USER_NAME}"
         JIRA_AUTH_TOKEN = "${params.JIRA_AUTH_TOKEN}"

         PARENT_CONFLUENCE_PAGE_ID = "${params.PARENT_CONFLUENCE_PAGE_ID}"
         CONFLUENCE_SPACE_KEY = "${params.CONFLUENCE_SPACE_KEY}"
         NUM_NODES = "${params.NUM_NODES}"

         STOP_CONTAINERS = "${params.STOP_CONTAINERS}"
         RUN_ALL = "${params.RUN_ALL}"
         RUN_MLSTORE = "${params.RUN_MLSTORE}"

         JAVA_FLIGHT_RECORDER = "${params.JAVA_FLIGHT_RECORDER}"

         THREAD_COUNT = "${params.THREAD_COUNT}"
         IGNITE_STRIPED_POOL_SIZE = "${params.IGNITE_STRIPED_POOL_SIZE}"

         RUN_BENCHMARK_PROP_FILE = "${params.RUN_BENCHMARK_PROP_FILE}"
       }
       when {
            expression {
                "${params.RUN_BENCHMARK_TESTS}" == "true"
            }
        }
        steps {
          sh '''#!/bin/bash
            source ${WORKSPACE}/dev-ops/jenkins/pipeline/run_benchmark.sh.sh
           '''
        }
    }

  }

}