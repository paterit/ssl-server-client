TMP_DIR = /tmp/paterit/certs
RED=\033[0;31m
NC=\033[0m

FILE_CNT_1 = 13
FILE_CNT_2 = 6

SSL_SUBJECT = 192.168.100.214.xip.io
SSL_DNS = 192.168.100.214.xip.io
SSL_IP = 192.168.100.214
SSL_SIZE=4096

all:
	mkdir -p $(TMP_DIR)
	docker build -t paterit/ssl-server-client .
	make generate
	make verify1
	make clean
	make verify2

generate:
	docker run --rm \
		-v $(TMP_DIR):/certs \
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

	docker run --rm \
		-v $(TMP_DIR):/certs \
		-e SSL_SUBJECT="/CN=client" \
		-e SSL_SIZE=$(SSL_SIZE) \
		-e SILENT=True \
		-e SSL_KEY=client-key.pem \
		-e SSL_CERT=client-cert.pem \
		-e SSL_CSR=client-key.csr \
		-e SSL_CONFIG=client-openssl.cnf \
		-e K8S_YAML_FILE=client-secret.yaml \
		paterit/ssl-server-client

clean:
	sudo chown $$USER:$$USER $(TMP_DIR)/*
	cd $(TMP_DIR); \
		rm *.cnf *.yaml *.csr *.srl

verify1:
	@ls -1 $(TMP_DIR) | wc -l | grep -q $(FILE_CNT_1) || \
		{ echo "${RED}ERROR!${NC} Expected number of files is $(FILE_CNT_1)"; exit 1; }

verify2:
	@ls -1 $(TMP_DIR) | wc -l | grep -q $(FILE_CNT_2) || \
		{ echo "${RED}ERROR!${NC} Expected number of files is $(FILE_CNT_2)"; exit 1; }

rmi:
	sudo rm -rf $(TMP_DIR)
	docker rmi paterit/ssl-server-client

push:
	docker push paterit/ssl-server-client:latest

ls:
	ls -all $(TMP_DIR)
