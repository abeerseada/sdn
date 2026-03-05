pipeline {
    agent any

    triggers {
        githubPush()
    }

    environment {
        REPO_DIR  = '/opt/sdn'
        SSH_CREDS = 'ec2-ssh-key'
        SSH_USER  = 'ubuntu'
        HOST      = '18.185.116.60'
    }

    stages {

        stage('Clone / Update Repo') {
            steps {
                sshagent(credentials: [env.SSH_CREDS]) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ${SSH_USER}@${HOST} '
                            set -e
                            if [ -d "${REPO_DIR}/.git" ]; then
                                cd ${REPO_DIR} && git pull
                            else
                                sudo git clone https://github.com/abeerseada/sdn ${REPO_DIR}
                                sudo chown -R \$USER:\$USER ${REPO_DIR}
                            fi
                        '
                    """
                }
            }
        }

        stage('Reset Previous Deployment') {
            steps {
                sshagent(credentials: [env.SSH_CREDS]) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ${SSH_USER}@${HOST} '
                            set -e
                            cd ${REPO_DIR}
                            sudo clab destroy -t sdn-dcn.clab.yml --cleanup 2>/dev/null || true
                            bash reset-dc.sh 2>/dev/null || true
                        '
                    """
                }
            }
        }

        stage('Deploy ContainerLab Topology') {
            steps {
                sshagent(credentials: [env.SSH_CREDS]) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ${SSH_USER}@${HOST} '
                            set -e
                            cd ${REPO_DIR}
                            sudo clab deploy -t sdn-dcn.clab.yml
                        '
                    """
                }
            }
        }

        stage('Configure OVS Switches') {
            steps {
                sshagent(credentials: [env.SSH_CREDS]) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ${SSH_USER}@${HOST} '
                            set -e
                            cd ${REPO_DIR}
                            sudo bash setup-dc.sh
                            sudo bash num-ports.sh
                        '
                    """
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                sshagent(credentials: [env.SSH_CREDS]) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ${SSH_USER}@${HOST} '
                            echo "=== ContainerLab nodes ==="
                            sudo clab inspect -t ${REPO_DIR}/sdn-dcn.clab.yml
                            echo ""
                            echo "=== OVS bridges ==="
                            sudo ovs-vsctl show
                        '
                    """
                }
            }
        }
    }

    post {
        success {
            echo "SDN topology deployed successfully on ${HOST}"
            echo "Ryu FlowManager UI: http://${HOST}:8080"
        }
        failure {
            echo "Deployment failed."
        }
    }
}
