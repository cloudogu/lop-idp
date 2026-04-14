#!groovy
@Library('github.com/cloudogu/ces-build-lib@5.1.0')
import com.cloudogu.ces.cesbuildlib.*

git = new Git(this, "cesmarvin")
git.committerName = 'cesmarvin'
git.committerEmail = 'cesmarvin@cloudogu.com'
gitflow = new GitFlow(this, git)
github = new GitHub(this, git)
changelog = new Changelog(this)

repositoryName = "lop-idp"
productionReleaseBranch = "main"

registryNamespace = "k8s"
registryUrl = "registry.cloudogu.com"
authRegistrationCrdChartVersion = "1.0.0"

goVersion = "1.26.0"
helmTargetDir = "target/k8s"
helmChartDir = "${helmTargetDir}/helm"

node('docker') {
    timestamps {
        properties([
                disableConcurrentBuilds(),
        ])

        catchError {
            timeout(activity: false, time: 60, unit: 'MINUTES') {
                stage('Checkout') {
                    checkout scm
                    make 'clean'
                }

                new Docker(this)
                        .image("golang:${goVersion}")
                        .mountJenkinsUser()
                        .inside("--volume ${WORKSPACE}:/${repositoryName} -w /${repositoryName}")
                                {
                                    stage('Generate k8s Resources') {
                                        make 'helm-update-dependencies'
                                        make 'helm-generate'
                                        archiveArtifacts "${helmTargetDir}/**/*"
                                    }

                                    stage("Lint helm") {
                                        make 'helm-lint'
                                    }
                                }

                K3d k3d = new K3d(this, "${WORKSPACE}", "${WORKSPACE}/k3d", env.PATH)

                try {
                    stage('Set up k3d cluster') {
                        k3d.startK3d()
                    }

                    stage('Prepare k3d prerequisites') {
                        sh("openssl req -x509 -nodes -newkey rsa:2048 -keyout global-config.key -out global-config.crt -days 1 -subj '/CN=ces.test'")
                        String serverCertificate = readFile("global-config.crt").trim()
                        String indentedServerCertificate = serverCertificate.readLines().collect { "    ${it}" }.join("\n")

                        writeFile file: "global-config.yaml", text: """domain: "ces.test"
fqdn: "ces.test"
admin_group: "cesAdmin"
certificate:
  server.crt: |
${indentedServerCertificate}
"""

                        k3d.kubectl("create configmap global-config --from-file=config.yaml=global-config.yaml")
                    }

                    stage('Install k3d prerequisites') {
                        withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'harborhelmchartpush', usernameVariable: 'HARBOR_USERNAME', passwordVariable: 'HARBOR_PASSWORD']]) {
                            try {
                                k3d.helm("registry login ${registryUrl} --username '${HARBOR_USERNAME}' --password '${HARBOR_PASSWORD}'")
                                k3d.helm("upgrade --install k8s-auth-registration-crd oci://${registryUrl}/${registryNamespace}/k8s-auth-registration-crd --version ${authRegistrationCrdChartVersion} --namespace default")
                            } finally {
                                k3d.helm("registry logout ${registryUrl}")
                            }
                        }
                    }

                    stage('Deploy lop-idp') {
                        k3d.helm("upgrade --install ${repositoryName} ${helmChartDir} --namespace default --wait --timeout 10m")
                    }

                    stage('Test lop-idp') {
                        k3d.kubectl("rollout status statefulset/lop-idp-ldap --timeout=300s")
                        k3d.kubectl("rollout status deployment/lop-idp-cas --timeout=300s")
                        k3d.kubectl("rollout status deployment/lop-idp-usermgt --timeout=300s")
                        k3d.kubectl("rollout status deployment/lop-idp-ldap-mapper --timeout=300s")
                        k3d.kubectl("rollout status deployment/lop-idp-k8s-auth-registration-operator --timeout=300s")
                        k3d.kubectl("wait --for=condition=ready pod -l app.kubernetes.io/instance=${repositoryName} --timeout=300s")
                    }
                } catch(Exception e) {
                    k3d.collectAndArchiveLogs()
                    throw e as java.lang.Throwable
                } finally {
                    stage('Remove k3d cluster') {
                        k3d.deleteK3d()
                    }
                }
            }
        }

        stageAutomaticRelease()
    }
}

void stageAutomaticRelease() {
    if (gitflow.isReleaseBranch()) {
        Makefile makefile = new Makefile(this)
        String releaseVersion = makefile.getVersion()
        String changelogVersion = git.getSimpleBranchName()

        stage('Push Helm chart to Harbor') {
            new Docker(this)
                    .image("golang:${goVersion}")
                    .mountJenkinsUser()
                    .inside("--volume ${WORKSPACE}:/${repositoryName} -w /${repositoryName}")
                            {
                                make 'helm-package'
                                archiveArtifacts "${helmTargetDir}/**/*"

                                withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'harborhelmchartpush', usernameVariable: 'HARBOR_USERNAME', passwordVariable: 'HARBOR_PASSWORD']]) {
                                    sh ".bin/helm registry login ${registryUrl} --username '${HARBOR_USERNAME}' --password '${HARBOR_PASSWORD}'"
                                    sh ".bin/helm push ${helmChartDir}/${repositoryName}-${releaseVersion}.tgz oci://${registryUrl}/${registryNamespace}"
                                }
                            }
        }

        stage('Finish Release') {
            gitflow.finishRelease(changelogVersion, productionReleaseBranch)
        }

        stage('Add Github-Release') {
            releaseId = github.createReleaseWithChangelog(changelogVersion, changelog, productionReleaseBranch)
        }
    }
}

void make(String makeArgs) {
    sh "make ${makeArgs}"
}
