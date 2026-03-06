pipeline {
    agent any

    triggers {
        githubPush()
    }

    environment {
        REPO_DIR  = '/opt/sdn'
        SSH_CREDS = 'ec2-ssh-key'
        SSH_USER  = 'ubuntu'
        HOST      = '63.180.217.182'
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
                            sudo clab destroy --all --cleanup 2>/dev/null || true
                            bash reset-dc.sh 2>/dev/null || true
                            sudo ip -o link show | awk -F': ' '{print $2}' | awk '{print $1}' | grep -E '^(c[1-4]|a[0-3][1-2]|e[0-3][1-2]|h[0-3][1-2][1-2])' | xargs -I{} sudo ip link delete {} 2>/dev/null || true
                        '
                    """
                }
            }
        }

        stage('Create OVS Bridges') {
            steps {
                sshagent(credentials: [env.SSH_CREDS]) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ${SSH_USER}@${HOST} '
                            set -e
                            cd ${REPO_DIR}
                            sudo bash setup-dc.sh
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
            echo "Ryu FlowManager UI: http://${HOST}:8081"
        }
        failure {
            echo "Deployment failed."
        }
    }
}
