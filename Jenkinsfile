// SPDX-FileCopyrightText: 2023 Zextras <https://www.zextras.com>
//
// SPDX-License-Identifier: AGPL-3.0-only

pipeline {
  parameters {
    booleanParam defaultValue: false,
    description: 'Whether to upload the packages in playground repository',
    name: 'PLAYGROUND'
  }
  options {
    skipDefaultCheckout()
    buildDiscarder(logRotator(numToKeepStr: '5'))
    timeout(time: 1, unit: 'HOURS')
  }
  agent {
    node {
      label 'base'
    }
  }
  environment {
    FAILURE_EMAIL_RECIPIENTS='smokybeans@zextras.com'
  }
  stages {
    stage('Checkout & Stash') {
      steps {
        checkout scm
        script {
          env.GIT_COMMIT = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
        }
        stash includes: '**', name: 'project'
      }
    }
    stage('Building packages') {
      parallel {
        stage('Ubuntu 22') {
          agent {
            node {
              label 'yap-ubuntu-22-v1'
            }
          }
          steps {
            container('yap') {
              unstash 'project'
              withCredentials([usernamePassword(credentialsId: 'artifactory-jenkins-gradle-properties-splitted',
                passwordVariable: 'SECRET',
                usernameVariable: 'USERNAME')]) {
                  sh 'echo "machine zextras.jfrog.io" >> auth.conf'
                  sh 'echo "login $USERNAME" >> auth.conf'
                  sh 'echo "password $SECRET" >> auth.conf'
                  sh 'sudo mv auth.conf /etc/apt'
              }
              sh '''
              sudo echo "deb [trusted=yes] https://zextras.jfrog.io/artifactory/ubuntu-rc jammy main" > zextras.list
              sudo mv zextras.list /etc/apt/sources.list.d/
              '''
              script {
                if (BRANCH_NAME == 'devel') {
                  def timestamp = new Date().format('yyyyMMddHHmmss')
                  sh "sudo yap build ubuntu-jammy videoserver -r ${timestamp}"
                } else {
                  sh 'sudo yap build ubuntu-jammy videoserver'
                }
              }
              stash includes: 'artifacts/*jammy*.deb', name: 'artifacts-ubuntu-jammy'
            }
          }
          post {
            failure {
              script {
                if ("main".equals(BRANCH_NAME) || "devel".equals(BRANCH_NAME)) {
                  sendFailureEmail(STAGE_NAME)
                }
              }
            }
            always {
              archiveArtifacts artifacts: 'artifacts/*jammy*.deb', fingerprint: true
            }
          }
        }
      }
    }
  }
}

void sendFailureEmail(String step) {
  def commitInfo =sh(
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
