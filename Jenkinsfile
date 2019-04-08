pipeline {
  // https://jenkins.io/doc/book/pipeline/jenkinsfile/
  // https://www.jfrog.com/confluence/display/RTF/Working+With+Pipeline+Jobs+in+Jenkins

  agent any

  tools {
    jdk 'JDK8u181'
  }

  environment {
      BRANCH_NAME = "ignite-2.7"
      RELEASE_VERSION = "2.7.0"
      REPO_URL = "https://github.com/percipiomedia/ignite.git"
      ARTIFACTORY_SERVER_ID = "jobcase"
  }

  parameters {
    string(name: 'Greeting', defaultValue: 'Hello', description: 'How should I greet the world?')
  }

  stages {
      stage ('Run Build') {
          steps {
            script {
              // Create an Artifactory server instance, as described above in this article:
              def server = Artifactory.server("${ARTIFACTORY_SERVER_ID}")

              // Create and set an Artifactory Maven Build instance:
              def rtMaven = Artifactory.newMavenBuild()
              rtMaven.resolver server: server, releaseRepo: 'libs-release', snapshotRepo: 'libs-snapshot'
              rtMaven.deployer server: server, releaseRepo: 'libs-release-local', snapshotRepo: 'libs-snapshot-local'

              // Set a Maven Tool defined in Jenkins "Manage":
              rtMaven.tool = MAVEN_TOOL

              // Run Maven:
              def buildInfo = rtMaven.run pom: 'pom.xml', goals: "clean install -Pall-java,all-scala,licenses -DskipTests -Drelease.version=${RELEASE_VERSION}"

              // Publish the build-info to Artifactory:
              server.publishBuildInfo buildInfo
            }
          }
      }
  }
}