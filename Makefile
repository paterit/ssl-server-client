.PHONY : all server client verify1 verify2 clean rmi push ls copy-certs copy-client copy-server help

# defualt path where cerets will be genterated
CERT_DIR ?= /tmp/paterit/certs

SERVER_CERT_DIR ?= /home/dmt/certs
SERVER_SSH_USER ?= dmt
CLIENT_CERT_DIR ?= /home/wsemik/workspace/dmt/django-microservice-template/cicd/worker/certs

RED=\033[0;31m
NC=\033[0m

FILE_CNT_1 = 13
FILE_CNT_2 = 6

# local active net interface IP as a default value, run make all -e SSL_IP=you.host.ip to use your SSL_IP value
LOCAL_HOST_ACTIVE_IP := $(shell ip route get 1 | head -n 1 | cut -d " " -f 7)
# set SSL_IP only if it is not already set
SSL_IP ?= $(LOCAL_HOST_ACTIVE_IP)
SSL_SUBJECT = $(SSL_IP).xip.io
SSL_DNS = $(SSL_IP).xip.io
SSL_SIZE=4096

## Standard run on client machine `make -e SSL_IP=your.docker.host.ip -e CERT_DIR=/path/for/created/certs`
all:
	mkdir -p $(CERT_DIR)
	docker build -t paterit/ssl-server-client .
	@echo "Creating certs for $(SSL_IP) ..."
	make server
	@echo "Creating certs for client ..."
	make client
	make verify1
	make clean
	make verify2


server:
	docker run --rm \
		-v $(CERT_DIR):/certs \
		-e SSL_SUBJECT=$(SSL_SUBJECT) \
		-e SSL_IP=$(SSL_IP)\
		-e SSL_SIZE=$(SSL_SIZE) \
		-e SILENT=True \
		-e SSL_KEY=server-key.pem \
		-e SSL_CERT=server-cert.pem \
		-e SSL_CSR=server-key.csr \
		-e SSL_CONFIG=server-openssl.cnf \
		-e K8S_YAML_FILE=server-secret.yaml \
		paterit/ssl-server-client

client:
	docker run --rm \
		-v $(CERT_DIR):/certs \
		-e SSL_SUBJECT="client" \
		-e SSL_SIZE=$(SSL_SIZE) \
		-e SILENT=True \
		-e SSL_KEY=key.pem \
		-e SSL_CERT=cert.pem \
		-e SSL_CSR=client-key.csr \
		-e SSL_CONFIG=client-openssl.cnf \
		-e K8S_YAML_FILE=client-secret.yaml \
		paterit/ssl-server-client

clean:
	sudo chown $$USER:$$USER $(CERT_DIR)/*
	cd $(CERT_DIR); \
		rm *.cnf *.yaml *.csr *.srl

verify1:
	@ls -1 $(CERT_DIR) | wc -l | grep -q $(FILE_CNT_1) || \
		{ echo "${RED}ERROR!${NC} Expected number of files is $(FILE_CNT_1)"; exit 1; }

verify2:
	@ls -1 $(CERT_DIR) | wc -l | grep -q $(FILE_CNT_2) || \
		{ echo "${RED}ERROR!${NC} Expected number of files is $(FILE_CNT_2)"; exit 1; }

## Remove generated certs from $CERT_DIR and remove docker image used to generate certs
rmi:
	sudo rm -rf $(CERT_DIR)
	docker rmi paterit/ssl-server-client

push:
	docker push paterit/ssl-server-client:latest

## List files in $CERT_DIR
ls:
	ls -all $(CERT_DIR)

## Copy CA and client certs to $CLIENT_CERT_DIR. Rsync CA and server certs over ssh to $SERVER_SSH_USER@$SSL_IP:SERVER_CERT_DIR
copy-certs:
	make copy-client
	make copy-server

copy-client:
	cd $(CERT_DIR); \
		rsync -avc ca.pem key.pem cert.pem $(CLIENT_CERT_DIR)

copy-server:
	cd $(CERT_DIR); \
		rsync -avz -e "ssh" ca.pem server-key.pem server-cert.pem $(SERVER_SSH_USER)@$(SSL_IP):$(SERVER_CERT_DIR)


# Printing nice help when make help is called

# COLORS
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
WHITE  := $(shell tput -Txterm setaf 7)
RESET  := $(shell tput -Txterm sgr0)


TARGET_MAX_CHAR_NUM=20
## Show help
help:
	@echo ''
	@echo 'Usage:'
	@echo '  ${YELLOW}make${RESET} ${GREEN}<target>${RESET}'
	@echo ''
	@echo 'Targets:'
	@awk '/^[a-zA-Z\-\_0-9]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			printf "  ${YELLOW}%-$(TARGET_MAX_CHAR_NUM)s${RESET} ${GREEN}%s${RESET}\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)
