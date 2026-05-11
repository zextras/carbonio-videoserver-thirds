// SPDX-FileCopyrightText: 2023 Zextras <https://www.zextras.com>
//
// SPDX-License-Identifier: AGPL-3.0-only

library(
    identifier: 'jenkins-lib-common@1.7.5',
    retriever: modernSCM([
        $class: 'GitSCMSource',
        credentialsId: 'jenkins-integration-with-github-account',
        remote: 'git@github.com:zextras/jenkins-lib-common.git',
    ])
)

properties(defaultPipelineProperties())

pipeline {
  agent {
    node {
      label 'base'
    }
  }

  environment {
    FAILURE_EMAIL_RECIPIENTS='smokybeans@zextras.com'
  }

  options {
    buildDiscarder(logRotator(numToKeepStr: '5'))
    skipDefaultCheckout()
    timeout(time: 1, unit: 'HOURS')
  }

  stages {
    stage('Setup') {
      steps {
        checkout scm
        script {
          gitMetadata()
        }
      }
    }

    stage('Build deb/rpm') {
      steps {
        echo 'Building deb/rpm packages'
        buildStage(
          addCarbonioRepos: true,
          prepare: true,
        )
      }
      post {
        failure {
          script {
            if ("main".equals(BRANCH_NAME) || "devel".equals(BRANCH_NAME)) {
              sendFailureEmail(STAGE_NAME)
            }
          }
        }
      }
    }

    stage('Upload artifacts')
    {
      tools {
        jfrog 'jfrog-cli'
      }
      steps {
        uploadStage([
          packages: yapHelper.getPackageNames()
        ])
      }
      post {
        failure {
          script {
            if ("main".equals(BRANCH_NAME) || "devel".equals(BRANCH_NAME)) {
              sendFailureEmail(STAGE_NAME)
            }
          }
        }
      }
    }
  }
}

void sendFailureEmail(String step) {
  String commitInfo = sh(
     script: 'git log -1 --pretty=tformat:\'<ul><li>Revision: %H</li><li>Title: %s</li><li>Author: %ae</li></ul>\'',
     returnStdout: true
  )

  emailext body: """\
    <b>${step.capitalize()}</b> step has failed on trunk.<br /><br />
    Last commit info: <br />
    ${commitInfo}<br /><br />
    Check the failing build at the <a href=\"${BUILD_URL}\">following link</a><br />
  """,
  subject: "[VIDEOSERVER TRUNK FAILURE] Trunk ${step} step failure",
  to: FAILURE_EMAIL_RECIPIENTS
}
