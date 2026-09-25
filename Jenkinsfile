// SPDX-FileCopyrightText: 2023 Zextras <https://www.zextras.com>
//
// SPDX-License-Identifier: AGPL-3.0-only

library(
    identifier: 'jenkins-lib-common@v4.13.0',
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

  options {
    buildDiscarder(logRotator(numToKeepStr: '5'))
    disableConcurrentBuilds()
    skipDefaultCheckout()
    timeout(time: 1, unit: 'HOURS')
  }

  stages {
    stage('Setup') {
      steps {
        checkout scm
        gitMetadata()
      }
    }

    stage('Skip CI') {
      steps {
        script { semanticRelease.guard() }
      }
    }

    stage('Security Scan') {
      steps { gitleaksStage() }
    }

    stage('Build deb/rpm') {
      steps {
        echo 'Building deb/rpm packages'
        buildStage(
          addCarbonioRepos: true,
          prepare: true,
        )
        buildStage(
          addCarbonioRepos: true,
          architecture: 'aarch64',
          distros: ['ubuntu-jammy'],
          prepare: true,
        )
      }
    }

    stage('Upload artifacts')
    {
      tools {
        jfrog 'jfrog-cli'
      }
      steps {
        uploadStage()
        uploadStage([
          architecture: 'aarch64',
          distros: ['ubuntu-jammy'],
        ])
      }
    }

    stage('Semantic Release') {
      steps {
        semanticRelease()
      }
    }
  }
}
