
id = $(shell echo $RANDOM | md5sum | head -c 6; echo;)
.PHONY = docker.build docker.publish version
db:
	docker-compose up -d  --quiet-pull   --remove-orphans db
	docker-compose logs -f --tail=100 db
start:
	docker-compose build --no-rm  --parallel    -q
	docker-compose up -d  --quiet-pull   --remove-orphans
	docker-compose logs -f --tail=100
tail:
	docker-compose logs -f --tail=100

stop:
	docker-compose down


iex.req:
	docker-compose exec req bash -c "iex --remsh requestor --sname req${id}  --cookie dev" 
iex.pro:
	docker-compose exec pro bash -c "iex --remsh processor --sname pro${id}  --cookie dev" 


docker.build:
	docker build . -t ziinc/crawldis:latest -t ziinc/crawldis:$$(make version)

docker.publish: docker.build
	docker push ziinc/crawldis:$$(make version)
	docker push ziinc/crawldis:latest

version:
	@cat mix.exs | grep version | sed -e 's/.*version: "\(.*\)",/\1/'