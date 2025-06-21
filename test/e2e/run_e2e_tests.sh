#!/bin/bash
set -ex

echo "Starting E2E Tests with a robust bash script (run_e2e_tests.sh)..."

sudo docker stop apiserver-e2e || true
sudo docker rm --force apiserver-e2e || true
sudo docker stop calc-web-e2e || true
sudo docker rm --force calc-web-e2e || true
sudo docker stop e2e-tests-runner || true
sudo docker rm --force e2e-tests-runner || true
sudo docker network rm calc-test-e2e || true

sleep 1

sudo docker network create calc-test-e2e || true
sleep 2

echo "Launching API and Web servers for E2E tests..."
API_CONTAINER_ID=$(sudo docker run -d --network calc-test-e2e --name apiserver-e2e --env FLASK_APP=app.api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0)
WEB_CONTAINER_ID=$(sudo docker run -d --network calc-test-e2e --name calc-web-e2e -p 80:80 calc-web)

echo "API Server ID: $API_CONTAINER_ID"
echo "Web Server ID: $WEB_CONTAINER_ID"

sleep 5

echo "Attempting to run Cypress tests..."
E2E_CONTAINER_ID=$(sudo docker run -d --user root --network calc-test-e2e --name e2e-tests-runner \
                       -v "$(pwd)":/cypress-app \
                       --workdir /cypress-app \
                       my-custom-cypress:latest bash -c " \
                         set -ex; \
                         npm cache clean --force; \
                         npm install cypress@12.17.4; \ # Instalar Cypress CLI localmente
                         ./node_modules/.bin/cypress install; \ # Asegurar instalación del binario
                         mkdir -p results; \
                         chmod -R 777 results; \
                         cypress run --browser electron --reporter junit --reporter-options 'mochaFile=results/cypress_result.xml,toConsole=true'; \
                       ")
    
echo "Cypress Container ID: $E2E_CONTAINER_ID"

echo "Waiting for Cypress tests to complete..."
CYPRESS_EXIT_CODE=$(sudo docker wait "$E2E_CONTAINER_ID") || true
echo "Cypress tests completed with exit code: $CYPRESS_EXIT_CODE."

echo "Copying E2E results..."
sudo docker cp "$E2E_CONTAINER_ID":/cypress-app/results/cypress_result.xml ./results/e2e_result.xml || true
echo "E2E results copied. Starting cleanup..."

sudo docker stop "$API_CONTAINER_ID" || true
sudo docker rm --force "$API_CONTAINER_ID" || true
sudo docker stop "$WEB_CONTAINER_ID" || true
sudo docker rm --force "$WEB_CONTAINER_ID" || true
sudo docker stop "$E2E_CONTAINER_ID" || true
sudo docker rm --force "$E2E_CONTAINER_ID" || true
sudo docker network rm calc-test-e2e || true

exit $CYPRESS_EXIT_CODE
