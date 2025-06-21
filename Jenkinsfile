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
                echo 'El entorno del agente está pre-construido con Docker CLI, Git, y Make (desde my-jenkins-agent:latest).'
                sh 'docker --version'
                sh 'make --version'
                sh 'git --version'
                sh 'node --version'
                sh 'npm --version'
                sh 'chromium-browser --version || true'
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
                echo 'Construyendo la etapa de Build!'
                sh 'make build'
            }
        }

        stage('Unit Tests') {
            steps {
                echo 'Ejecutando pruebas unitarias!'
                sh 'make test-unit'
                archiveArtifacts artifacts: 'results/unit_result.xml'
            }
        }

        stage('API Tests') {
            steps {
                echo 'Ejecutando pruebas de API!'
                sh '''
                    set -ex
                    echo "Limpiando contenedores y redes Docker antiguos antes de las pruebas de API..."
                    docker stop apiserver-api || true
                    docker rm --force apiserver-api || true
                    docker stop api-tests || true
                    docker rm --force api-tests || true
                    docker network rm calc-test-api || true
                    sleep 1
                    docker network create calc-test-api || true
                    sleep 1

                    API_CONTAINER_ID_API=$(docker run -d --network calc-test-api --env PYTHONPATH=/opt/calc --name apiserver-api --env FLASK_APP=app.api.py -p 5001:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0)
                    
                    docker run --network calc-test-api --name api-tests --env PYTHONPATH=/opt/calc --env BASE_URL=http://apiserver-api:5000/ -w /opt/calc calculator-app:latest pytest --junit-xml=results/api_result.xml -m api || true

                    docker cp api-tests:/opt/calc/results ./

                    docker stop "$API_CONTAINER_ID_API" || true
                    docker rm --force "$API_CONTAINER_ID_API" || true
                    docker stop api-tests || true
                    docker rm --force api-tests || true
                    docker network rm calc-test-api || true
                '''
                archiveArtifacts artifacts: 'results/api_result.xml'
            }
        }

        stage('E2E Tests') {
            steps {
                echo 'Ejecutando pruebas E2E!'
                sh 'make test-e2e'
                archiveArtifacts artifacts: 'results/e2e_result.xml'
            }
        }
    }

    post {
        always {
            echo 'Las acciones post-construcción siempre se ejecutan.'
            junit 'results/*_result.xml'
            cleanWs()
        }
        failure {
            echo "¡El pipeline ha fallado! Enviando correo electrónico."
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
