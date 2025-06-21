SHELL := /bin/bash

.PHONY: all $(MAKECMDGOALS)

build:
	sudo docker build -t calculator-app .
	sudo docker build -t calc-web ./web

server:
	sudo docker run --rm --name apiserver --network-alias apiserver --env PYTHONPATH=/opt/calc --env FLASK_APP=app.api.py -p 5001:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0

test-unit:
	sudo docker run --name unit-tests --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest pytest --cov --cov-report=xml:results/coverage.xml --cov-report=html:results/coverage --junit-xml=results/unit_result.xml -m unit || true
	sudo docker cp unit-tests:/opt/calc/results ./
	sudo docker rm unit-tests || true

test-api:
	set -ex
	sudo docker stop apiserver-api || true
	sudo docker rm --force apiserver-api || true
	sudo docker stop api-tests || true
	sudo docker rm --force api-tests || true
	sudo docker network rm calc-test-api || true
	sleep 5
	sudo docker network create calc-test-api || true
	sleep 1

	API_CONTAINER_ID_API=$(sudo docker run -d --network calc-test-api --env PYTHONPATH=/opt/calc --name apiserver-api --env FLASK_APP=app.api.py -p 5001:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0)

	sudo docker run --network calc-test-api --name api-tests --env PYTHONPATH=/opt/calc --env BASE_URL=http://apiserver-api:5000/ -w /opt/calc calculator-app:latest pytest --junit-xml=results/api_result.xml -m api || true

	sudo docker cp api-tests:/opt/calc/results ./

	sudo docker stop "$API_CONTAINER_ID_API" || true
	sudo docker rm --force "$API_CONTAINER_ID_API" || true
	sudo docker stop api-tests || true
	sudo docker rm --force api-tests || true
	sudo docker network rm calc-test-api || true

test-e2e:
	set -ex
	sudo docker stop apiserver-e2e-test || true
	sudo docker rm --force apiserver-e2e-test || true
	sudo docker stop calc-web-e2e-test || true
	sudo docker rm --force calc-web-e2e-test || true
	sudo docker stop e2e-tests-runner || true
	sudo docker rm --force e2e-tests-runner || true
	sudo docker network rm calc-test-e2e || true
	sleep 5

	echo "Creando red y lanzando servicios API y Web para E2E..."
	sudo docker network create calc-test-e2e || true
	sleep 2

	API_CONTAINER_ID=$(sudo docker run -d --network calc-test-e2e --env PYTHONPATH=/opt/calc --name apiserver-e2e-test -p 5001:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0)
	WEB_CONTAINER_ID=$(sudo docker run -d --network calc-test-e2e --name calc-web-e2e-test -p 80:80 calc-web)

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
	sudo docker stop "$API_CONTAINER_ID" || true
	sudo docker rm --force "$API_CONTAINER_ID" || true
	sudo docker stop "$WEB_CONTAINER_ID" || true
	sudo docker rm --force "$WEB_CONTAINER_ID" || true
	sudo docker network rm calc-test-e2e || true

	exit "$CYPRESS_EXIT_CODE"

run-web:
	sudo docker run --rm --volume `pwd`/web:/usr/share/nginx/html  --volume `pwd`/web/constants.local.js:/usr/share/nginx/html/constants.js --name calc-web -p 5001:80 nginx

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
