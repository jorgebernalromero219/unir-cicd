.PHONY: all $(MAKECMDGOALS)

build:
	sudo docker build -t calculator-app .
	sudo docker build -t calc-web ./web

server:
	sudo docker run --rm --name apiserver --network-alias apiserver --env PYTHONPATH=/opt/calc --env FLASK_APP=app/api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0

test-unit:
	sudo docker run --name unit-tests --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest pytest --cov --cov-report=xml:results/coverage.xml --cov-report=html:results/coverage --junit-xml=results/unit_result.xml -m unit || true
	sudo docker cp unit-tests:/opt/calc/results ./
	sudo docker rm unit-tests || true

test-api:
	sudo docker network create calc-test-api || true
	sudo docker run -d --network calc-test-api --env PYTHONPATH=/opt/calc --name apiserver --env FLASK_APP=app/api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0
	sudo docker run --network calc-test-api --name api-tests --env PYTHONPATH=/opt/calc --env BASE_URL=http://apiserver:5000/ -w /opt/calc calculator-app:latest pytest --junit-xml=results/api_result.xml -m api || true
	sudo docker cp api-tests:/opt/calc/results ./
	sudo docker stop apiserver || true
	sudo docker rm --force apiserver || true
	sudo docker stop api-tests || true
	sudo docker rm --force api-tests || true
	sudo docker network rm calc-test-api || true

test-e2e:
	sudo docker network create calc-test-e2e || true
	sudo docker stop apiserver || true
	sudo docker rm --force apiserver || true
	sudo docker stop calc-web || true
	sudo docker rm --force calc-web || true
	sudo docker stop e2e-tests || true
	sudo docker rm --force e2e-tests || true
	sudo docker run -d --network calc-test-e2e --env PYTHONPATH=/opt/calc --name apiserver --env FLASK_APP=app/api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0
	sudo docker run -d --network calc-test-e2e --name calc-web -p 80:80 calc-web

	sudo docker create --network calc-test-e2e --name e2e-tests \
           --workdir / \
           cypress/included:12.17.4 --browser chrome || true

	sudo docker exec e2e-tests mkdir -p /results || true
	sudo docker exec e2e-tests chmod -R 777 /results || true

	sudo docker cp ./test/e2e/cypress.json e2e-tests:/cypress.json
	sudo docker cp ./test/e2e/cypress e2e-tests:/cypress

	sudo docker start -a e2e-tests || true

	sudo docker cp e2e-tests:/results/cypress_result.xml ./results/e2e_result.xml || true

	sudo docker rm --force apiserver  || true
	sudo docker rm --force calc-web || true
	sudo docker stop e2e-tests || true
	sudo docker rm --force e2e-tests || true
	sudo docker network rm calc-test-e2e || true

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
	sudo docker run -d --rm --name apiserver --network-alias apiserver --env PYTHONPATH=/opt/calc --env FLASK_APP=app/api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0
	sudo docker run -d --rm --name calc-web -p 80:80 calc-web
