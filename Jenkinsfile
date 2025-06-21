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
                sh 'sudo make build'
            }
        }

        stage('Unit Tests') {
            steps {
                echo 'Ejecutando pruebas unitarias!'
                sh 'sudo make test-unit'
                archiveArtifacts artifacts: 'results/unit_result.xml'
            }
        }

        stage('API Tests') {
            steps {
                echo 'Ejecutando pruebas de API!'
                sh '''
                    set -ex
                    echo "Limpiando contenedores y redes Docker antiguos antes de las pruebas de API..."
                    sudo docker stop apiserver-api || true
                    sudo docker rm --force apiserver-api || true
                    sudo docker stop api-tests || true
                    sudo docker rm --force api-tests || true
                    sudo docker network rm calc-test-api || true
                    sleep 1
                    sudo docker network create calc-test-api || true
                    sleep 1

                    API_CONTAINER_ID_API=$(sudo docker run -d --network calc-test-api --env PYTHONPATH=/opt/calc --name apiserver-api --env FLASK_APP=app.api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0)
                    
                    sudo docker run --network calc-test-api --name api-tests --env PYTHONPATH=/opt/calc --env BASE_URL=http://apiserver-api:5000/ -w /opt/calc calculator-app:latest pytest --junit-xml=results/api_result.xml -m api || true

                    sudo docker cp api-tests:/opt/calc/results ./

                    sudo docker stop "$API_CONTAINER_ID_API" || true
                    sudo docker rm --force "$API_CONTAINER_ID_API" || true
                    sudo docker stop api-tests || true
                    sudo docker rm --force api-tests || true
                    sudo docker network rm calc-test-api || true
                '''
                archiveArtifacts artifacts: 'results/api_result.xml'
            }
        }

        stage('E2E Tests') {
            steps {
                echo 'Ejecutando pruebas E2E!'
                sh '''
                    set -ex
                    echo "Limpiando contenedores y redes Docker antiguos antes de las pruebas E2E..."
                    sudo docker stop apiserver-e2e || true
                    sudo docker rm --force apiserver-e2e || true
                    sudo docker stop calc-web-e2e || true
                    sudo docker rm --force calc-web-e2e || true
                    sudo docker stop e2e-tests-runner || true
                    sudo docker rm --force e2e-tests-runner || true
                    sudo docker network rm calc-test-e2e || true
                    sleep 1

                    echo "Creando red y lanzando servicios API y Web para E2E..."
                    sudo docker network create calc-test-e2e || true
                    sleep 2

                    API_CONTAINER_ID=$(sudo docker run -d --network calc-test-e2e --env PYTHONPATH=/opt/calc --name apiserver-e2e --env FLASK_APP=app.api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0)
                    WEB_CONTAINER_ID=$(sudo docker run -d --network calc-test-e2e --name calc-web-e2e -p 80:80 calc-web)
                    echo "API Server ID: $API_CONTAINER_ID"
                    echo "Web Server ID: $WEB_CONTAINER_ID"
                    sleep 5

                    echo "Navegando a test/e2e e instalando/ejecutando Cypress..."
                    cd test/e2e
                    npm cache clean --force || true
                    npm install cypress@12.17.4 || true
                    ./node_modules/.bin/cypress install || true
                    
                    mkdir -p results || true
                    chmod -R 777 results || true

                    echo "Ejecutando Cypress..."
                    ./node_modules/.bin/cypress run --browser chrome --reporter junit --reporter-options 'mochaFile=results/cypress_result.xml,toConsole=true'

                    CYPRESS_EXIT_CODE=$?

                    echo "Cypress tests completed with exit code: $CYPRESS_EXIT_CODE."

                    echo "Copiando resultados E2E..."
                    cp results/cypress_result.xml ../../results/e2e_result.xml || true

                    echo "Limpieza final de contenedores y red E2E..."
                    docker stop "$API_CONTAINER_ID" || true
                    docker rm --force "$API_CONTAINER_ID" || true
                    docker stop "$WEB_CONTAINER_ID" || true
                    docker rm --force "$WEB_CONTAINER_ID" || true
                    docker network rm calc-test-e2e || true

                    exit $CYPRESS_EXIT_CODE
                '''
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
