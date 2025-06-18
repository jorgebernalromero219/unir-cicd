pipeline {
    agent {
        docker {
            image 'my-jenkins-agent:latest'
            args '-v /var/run/docker.sock:/var/run/docker.sock'
        }
    }

    stages {
        stage('Verify Agent Environment') {
            steps {
                echo 'Agent environment is now pre-built with Docker CLI, Git, and Make (from my-jenkins-agent:latest).'
                sh 'docker --version'
                sh 'make --version'
                sh 'git --version'
            }
        }

        stage('Clean Workspace Explicitly') {
            steps {
                echo 'Borrando el contenido del workspace de Jenkins antes de clonar el repo...'
                sh 'rm -rf * .[!.]* || true'
                echo 'Workspace limpio.'
            }
        }

        stage('Source') {
            steps {
                git 'https://github.com/jorgebernalromero219/unir-cicd.git'
            }
        }

        stage('Build') {
            steps {
                echo 'Building stage!'
                sh 'make build'
            }
        }

        stage('Unit Tests') {
            steps {
                echo 'Running Unit Tests!'
                sh 'make test-unit'
                archiveArtifacts artifacts: 'results/unit_result.xml'
            }
        }

        stage('API Tests') {
            steps {
                echo 'Running API Tests!'
                sh '''
                    echo "Cleaning up old Docker containers and networks before API Tests..."
                    docker stop apiserver || true
                    docker rm --force apiserver || true
                    docker network rm calc-test-api || true
                '''
                sh 'make test-api'
                archiveArtifacts artifacts: 'results/api_result.xml'
            }
        }

        stage('E2E Tests') {
            steps {
                echo 'Running E2E Tests!'
                sh '''
                    echo "Cleaning up old Docker containers and networks before E2E Tests..."
                    docker stop apiserver || true
                    docker rm --force apiserver || true
                    docker stop calc-web || true
                    docker rm --force calc-web || true
                    docker network rm calc-test-e2e || true
                '''
                sh 'make test-e2e'
                archiveArtifacts artifacts: 'results/e2e_result.xml'
            }
        }
    }

    post {
        always {
            echo 'Post-build actions always executed.'
            junit 'results/*_result.xml'
            cleanWs()
        }
        failure {
            echo "Pipeline failed! Sending email."
            /*
            mail to: 'tu_correo@ejemplo.com',
                 subject: "Jenkins Pipeline FALLIDO: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                 body: "El pipeline '${env.JOB_NAME}' con el número de ejecución #${env.BUILD_NUMBER} ha fallado. Por favor, revisa Jenkins para más detalles."
            */
            echo "Asunto del correo: Jenkins Pipeline FALLIDO: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
            echo "Cuerpo del correo: El pipeline '${env.JOB_NAME}' con el número de ejecución #${env.BUILD_NUMBER} ha fallado. Por favor, revisa Jenkins para más detalles."
        }
    }
}
