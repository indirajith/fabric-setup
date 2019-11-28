#!/bin/bash

set -ex
getFabCA() {
   if ! type fabric-ca-server >/dev/null
   then
      sudo apt -y install libtool libltdl-dev
      go get -u github.com/hyperledger/fabric-ca/cmd/...
      if [ $? -ne 0 ]; then
         echo "Error! getting fabric-ca binaries."
         exit 1
      fi
   fi
}

clearContainers() {
   CONTAINER_IDS=$(docker ps -aq)
   if [ -z "$CONTAINER_IDS" -o "$CONTAINER_IDS" == " " ]; then
      echo "---- No containers available for stop and deletion ----"
   else
      docker stop $CONTAINER_IDS
      docker rm -f $CONTAINER_IDS
   fi
}

initCA() {
   echo $1, $2
   sed -i 's/start/init/' $1
   docker-compose -f $1 up
   sudo chown -R $(whoami) ~/hyperledger
   if grep -q tls $1; then
      sed -i -e 's/cn: .*/cn: ca-tls\.inuit\.local/' -e 's/C: .*/C: IT/' -e 's/ST: .*/ST: "Lazio"/' -e 's/\bL:.*/L: RM/' -e 's/\bO: .*/O: Inuit/' -e 's/OU: .*/OU: fabric/' $2
   elif grep -q org1 $1; then
      sed -i -e 's/cn: .*/cn: rca-org1\.inuit\.local/' -e 's/C: .*/C: IT/' -e 's/ST: .*/ST: "Lazio"/' -e 's/\bL:.*/L: RM/' -e 's/\bO: .*/O: Inuit/' -e 's/OU: .*/OU: fabric/' $2
   else
      echo "Error in docker-compose file names!"
      exit 1
   fi
   sed -i 's/init/start/' $1
   pushd $(dirname $2)
   bn=$(basename $2)
   GLOBIGNORE=$bn
   rm -rf *
   unset GLOBIGNORE
   popd
}

startCA() {
   docker-compose -f $1 up -d
   # sleep 5
   docker ps -a
   # docker logs xyz | grep -q Listening on https://0.0.0.0:
   # if [ $? -ne 0 ]; then
   #    echo "ERROR!!! Bringing up TLS CA."
   #    exit 1
   # fi

}

enrollCAAdmint() {
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/tls/ca/crypto/ca-cert.pem
   export FABRIC_CA_CLIENT_HOME=~/hyperledger/tls/ca/admin
   sudo chown -R $(whoami) ~/hyperledger
   mkdir -p ~/hyperledger/tls/ca/admin
   sleep 5

   set +e
   sudo -E $GOPATH/bin/fabric-ca-client enroll -d -u https://tls-ca-admin:tls-ca-adminpw@0.0.0.0:7052
   sudo -E $GOPATH/bin/fabric-ca-client register -d --id.name peer1-org1 --id.secret peer1o1PW --id.type peer -u https://localhost:7052
   sudo -E $GOPATH/bin/fabric-ca-client register -d --id.name peer2-org1 --id.secret peer2o1PW --id.type peer -u https://localhost:7052
   sudo -E $GOPATH/bin/fabric-ca-client register -d --id.name peer1-org2 --id.secret peer1o2PW --id.type peer -u https://localhost:7052
   sudo -E $GOPATH/bin/fabric-ca-client register -d --id.name peer2-org2 --id.secret peer2o2PW --id.type peer -u https://localhost:7052
   sudo -E $GOPATH/bin/fabric-ca-client register -d --id.name ord1-org1 --id.secret ord1o1PW --id.type orderer -u https://localhost:7052
   sudo -E $GOPATH/bin/fabric-ca-client register -d --id.name ord2-org1 --id.secret ord2o1PW --id.type orderer -u https://localhost:7052
   sudo -E $GOPATH/bin/fabric-ca-client register -d --id.name ord1-org2 --id.secret ord1o2PW --id.type orderer -u https://localhost:7052
   sudo -E $GOPATH/bin/fabric-ca-client register -d --id.name ord2-org2 --id.secret ord2o2PW --id.type orderer -u https://localhost:7052
   set -e
}

enrollCAAdmin1() {
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org1/ca/crypto/ca-cert.pem
   export FABRIC_CA_CLIENT_HOME=~/hyperledger/org1/ca/admin
   sudo chown -R $(whoami) ~/hyperledger
   mkdir -p ~/hyperledger/org1/ca/admin
   sleep 5

   set +e
   sudo -E $GOPATH/bin/fabric-ca-client enroll -d -u https://rca-org1-admin:rca-org1-adminpw@0.0.0.0:7054
   sudo -E $GOPATH/bin/fabric-ca-client register -d --id.name peer1-org1 --id.secret peer1o1PW --id.type peer -u https://0.0.0.0:7054
   sudo -E $GOPATH/bin/fabric-ca-client register -d --id.name peer2-org1 --id.secret peer2o1PW --id.type peer -u https://0.0.0.0:7054
   sudo -E $GOPATH/bin/fabric-ca-client register -d --id.name admin-org1 --id.secret org1AdminPW --id.type admin --id.attrs "hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert" -u https://0.0.0.0:7054
   sudo -E $GOPATH/bin/fabric-ca-client register -d --id.name user-org1 --id.secret org1UserPW --id.type user -u https://0.0.0.0:7054
   sudo -E $GOPATH/bin/fabric-ca-client register -d --id.name ord1-org1 --id.secret ord1o1pw --id.type orderer -u https://0.0.0.0:7054
   sudo -E $GOPATH/bin/fabric-ca-client register -d --id.name ord2-org1 --id.secret ord1o2pw --id.type orderer -u https://0.0.0.0:7054
   set -e
}

if [[ $1 == ca ]]; then
   getFabCA
   clearContainers
   initCA ../ca-tls-docker-compose.yaml ~/hyperledger/tls/ca/crypto/fabric-ca-server-config.yaml
   startCA ../ca-tls-docker-compose.yaml
   enrollCAAdmint
   initCA ../rca-org1-docker-compose.yaml ~/hyperledger/org1/ca/crypto/fabric-ca-server-config.yaml
   startCA ../rca-org1-docker-compose.yaml
   enrollCAAdmin1
else 
   echo "Please enter 'ca' to setup TLS CA and org1 CA"
   exit 1
fi