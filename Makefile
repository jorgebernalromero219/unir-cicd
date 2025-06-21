SHELL := /bin/bash

.PHONY: all $(MAKECMDGOALS)

build:
	sudo docker build -t calculator-app .
	sudo docker build -t calc-web ./web

server:
	sudo docker run --rm --name apiserver --network-alias apiserver --env PYTHONPATH=/opt/calc --env FLASK_APP=app.api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0

test-unit:
	sudo docker run --name unit-tests --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest pytest --cov --cov-report=xml:results/coverage.xml --cov-report=html:results/coverage --junit-xml=results/unit_result.xml -m unit || true
	sudo docker cp unit-tests:/opt/calc/results ./
	sudo docker rm unit-tests || true

test-api:
	set -ex

	sudo docker stop apiserver || true
	sudo docker rm --force apiserver || true
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

test-e2e:
	set -ex

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
	API_CONTAINER_ID=$(sudo docker run -d --network calc-test-e2e --env PYTHONPATH=/opt/calc --name apiserver-e2e --env FLASK_APP=app.api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0)
	WEB_CONTAINER_ID=$(sudo docker run -d --network calc-test-e2e --name calc-web-e2e -p 80:80 calc-web)

	echo "API Server ID: $API_CONTAINER_ID"
	echo "Web Server ID: $WEB_CONTAINER_ID"

	sleep 5

	echo "Attempting to run Cypress tests..."
	E2E_CONTAINER_ID=$(sudo docker run -d --user root --network calc-test-e2e --name e2e-tests-runner \
                           -v $(pwd)/test/e2e:/cypress-app \
                           --workdir /cypress-app \
                           my-custom-cypress:latest bash -c " \
                             set -ex; \
                             npm cache clean --force; \
                             npm install cypress@12.17.4; \
                             ./node_modules/.bin/cypress install; \
                             mkdir -p results; \
                             chmod -R 777 results; \
                             ./node_modules/.bin/cypress run --browser chrome --reporter junit --reporter-options 'mochaFile=results/cypress_result.xml,toConsole=true'; \
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

	exit "$CYPRESS_EXIT_CODE"

run-web:
	sudo docker run --rm --volume `pwd`/web:/usr/share/nginx/html  --volume `pwd`/web/constants.local.js:/usr/share/nginx/html/constants.js --name calc-web -p 80:80 nginx

stop-web:
	sudo docker stop calc-web

start-sonar-server:
	sudo docker network create calc-sonar || true
	sudo docker run -d --rm --stop-timeout 60 --network calc-sonar --name sonarqube-server -p 9000:9000 --volume `pwd`/sonar/data:/opt/sonarqube/data --volume `pwd`/sonar/logs:/opt/sonarqube/logs sonarqube:8.3.1-community

stop-sonar-server:
	sudo docker stop sonarqube-server
	sudo docker network rm calc-sonar || true

start-sonar-scanner:
	sudo docker run --rm --network calc-sonar -v `pwd`:/usr/src sonarsource/sonar-scanner-cli

pylint:
	sudo docker run --rm --volume `pwd`/opt/calc --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest pylint app/ | tee results/pylint_result.txt

deploy-stage:
	sudo docker stop apiserver || true
	sudo docker stop calc-web || true
	sudo docker run -d --rm --name apiserver --network-alias apiserver --env PYTHONPATH=/opt/calc --env FLASK_APP=app.api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0
	sudo docker run -d --rm --name calc-web -p 80:80 calc-web
