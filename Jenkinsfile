pipeline {
  // https://jenkins.io/doc/book/pipeline/jenkinsfile/
  // https://www.jfrog.com/confluence/display/RTF/Working+With+Pipeline+Jobs+in+Jenkins

  agent any

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
      stage ('Artifactory configuration') {
          steps {
              // rtMavenResolver closure, which defines the dependencies resolution details
              rtMavenResolver (
                  id: "MAVEN_RESOLVER",
                  serverId: "${ARTIFACTORY_SERVER_ID}",
                  releaseRepo: "libs-release",
                  snapshotRepo: "libs-snapshot"
              )

              // rtMavenDeployer closure, which defines the artifacts deployment details
              rtMavenDeployer (
                  id: "MAVEN_DEPLOYER",
                  serverId: "${ARTIFACTORY_SERVER_ID}",
                  releaseRepo: "libs-release-local",
                  snapshotRepo: "libs-snapshot-local"
              )

          }
      }

      stage ('Run Build') {
          steps {
              rtMavenRun (
                  tool: MAVEN_TOOL, // Tool name from Jenkins configuration
                  pom: 'pom.xml',
                  goals: "clean install -Pall-java,all-scala,licenses -DskipTests -Drelease.version=${RELEASE_VERSION}",
                  deployerId: "MAVEN_DEPLOYER",
                  resolverId: "MAVEN_RESOLVER"
              )
          }
      }

      stage ('Publish build info') {
          steps {
              rtPublishBuildInfo (
                  serverId: "${ARTIFACTORY_SERVER_ID}"
              )
          }
      }
  }
}
