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
	sudo docker network create calc-test-api || true
	sudo docker run -d --network calc-test-api --env PYTHONPATH=/opt/calc --name apiserver --env FLASK_APP=app.api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0
	sudo docker run --network calc-test-api --name api-tests --env PYTHONPATH=/opt/calc --env BASE_URL=http://apiserver:5000/ -w /opt/calc calculator-app:latest pytest --junit-xml=results/api_result.xml -m api || true
	sudo docker cp api-tests:/opt/calc/results ./
	sudo docker stop apiserver || true
	sudo docker rm --force apiserver || true
	sudo docker stop api-tests || true
	sudo docker rm --force api-tests || true
	sudo docker network rm calc-test-api || true

test-e2e:
	set -ex
	sudo docker network create calc-test-e2e || true
	sleep 1

	sudo docker stop apiserver || true
	sudo docker rm --force apiserver || true
	sudo docker stop calc-web || true
	sudo docker rm --force calc-web || true
	sudo docker stop e2e-tests || true
	sudo docker rm --force e2e-tests || true

	echo "Launching API and Web servers for E2E tests..."
	sudo docker run -d --network calc-test-e2e --env PYTHONPATH=/opt/calc --name apiserver --env FLASK_APP=app.api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0
	sudo docker run -d --network calc-test-e2e --name calc-web -p 80:80 calc-web

	echo "Attempting to create Cypress container..."
	sudo docker create --network calc-test-e2e --name e2e-tests \
			-v $(pwd)/test/e2e:/cypress-app \
			--workdir /cypress-app \
			my-custom-cypress:latest cypress run --browser chrome || true

	sudo docker exec e2e-tests mkdir -p /results || true
	sudo docker exec e2e-tests chmod -R 777 /results || true

	sudo docker cp ./test/e2e/cypress.json e2e-tests:/cypress.json
	sudo docker cp ./test/e2e/cypress e2e-tests:/cypress

	echo "Starting Cypress container and running tests..."
	sudo docker start -a e2e-tests || true
	echo "Cypress tests completed."

	echo "Copying E2E results..."
	sudo docker cp e2e-tests:/results/cypress_result.xml ./results/e2e_result.xml || true
	echo "E2E results copied. Starting cleanup..."

	sudo docker rm --force apiserver || true
	sudo docker rm --force calc-web || true
	sudo docker stop e2e-tests || true
	sudo docker rm --force e2e-tests || true
	sudo docker network rm calc-test-e2e || true
