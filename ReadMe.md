https://github.com/ukayani/cloud-init-example
https://help.ubuntu.com/community/CloudInit 
https://cloudinit.readthedocs.io/en/latest/topics/format.html

terraform plan -var-file=ssl.tfvars

https://docs.sonarqube.org/latest/user-guide/user-token/

docker run --rm \
  -e SONAR_HOST_URL="http://20.127.17.121" \
  -e SONAR_LOGIN="" \
  -v "$(pwd):/usr/src" \
  sonarsource/sonar-scanner-cli

docker run --rm \
  -e SONAR_HOST_URL="https://sonarqube.acqio.com.br" \
  -e SONAR_LOGIN="" \
  -v "$(pwd):/usr/src" \
  sonarsource/sonar-scanner-cli

docker run --rm \
  -e SONAR_HOST_URL="" \
  -e SONAR_LOGIN="" \
  -v "$(pwd):/usr/src" \
  sonarsource/sonar-scanner-cli
