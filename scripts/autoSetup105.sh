#!/bin/sh

set -ex
getFabCA() {
   sudo apt -y install libtool libltdl-dev
   go get -u github.com/hyperledger/fabric-ca/cmd/...
   if [ $? -ne 0 ]; then
      echo "Error! getting fabric-ca binaries."
      exit 1
   fi
}

clearContainers() {
   CONTAINER_IDS=$(docker ps -a | awk '($2 ~ /dev-peer.*/) {print $1}')
   if [ -z "$CONTAINER_IDS" -o "$CONTAINER_IDS" == " " ]; then
      echo "---- No containers available for deletion ----"
   else
      docker rm -f $CONTAINER_IDS
   fi
}

initCA() {
   echo $1, $2
   sed -i 's/start/init/' $1
   docker-compose -f $1 up
   sudo chown -R $(whoami) ~/hyperledger
   sed -i -e 's/cn: .*/cn: rca-org2\.inuit\.local/' -e 's/C: .*/C: IT/' -e 's/ST: .*/ST: "Lazio"/' -e 's/\bL:.*/L: RM/' -e 's/\bO: .*/O: Inuit/' -e 's/OU: .*/OU: fabric/' $2
   sed -i 's/init/start/' $1
}

startCA() {
   set -ev
   docker-compose -f $1 up -d
   sleep 5
   docker ps -a
   docker logs ca-tls.inuit.local | grep -q Listening on https://0.0.0.0:
   # if [ $? -eq ]
}

enrollCAAdmin2() {
   sudo chown -R $(whoami) ~/hyperledger
   mkdir -p ~/hyperledger/org2/ca/admin

   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org2/ca/crypto/ca-cert.pem
   export FABRIC_CA_CLIENT_HOME=~/hyperledger/org2/ca/admin

   sudo -E /home/user1/gopath/bin/fabric-ca-client enroll -d -u https://rca-org2-admin:rca-org2-adminpw@0.0.0.0:7055
   sudo -E /home/user1/gopath/bin/fabric-ca-client register -d --id.name peer1-org2 --id.secret peer1o2PW --id.type peer -u https://0.0.0.0:7055
   sudo -E /home/user1/gopath/bin/fabric-ca-client register -d --id.name peer2-org2 --id.secret peer2o2PW --id.type peer -u https://0.0.0.0:7055
   sudo -E /home/user1/gopath/bin/fabric-ca-client register -d --id.name admin-org2 --id.secret org2AdminPW --id.type admin --id.attrs "hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert" -u https://0.0.0.0:7055
   sudo -E /home/user1/gopath/bin/fabric-ca-client register -d --id.name user-org2 --id.secret org2UserPW --id.type user -u https://0.0.0.0:7055
   sudo -E /home/user1/gopath/bin/fabric-ca-client register -d --id.name ord1-org2 --id.secret ord1o2pw --id.type orderer -u https://0.0.0.0:7055
   sudo -E /home/user1/gopath/bin/fabric-ca-client register -d --id.name ord2-org2 --id.secret ord2o2pw --id.type orderer -u https://0.0.0.0:7055

}

if [ $1 = ca ]; then
   getFabCA
   clearContainers
   initCA ../rca-org2-docker-compose.yaml ~/hyperledger/org2/ca/crypto/fabric-ca-server-config.yaml
   startCA ../rca-org2-docker-compose.yaml
   enrollCAAdmin2
fi

enrollPeers() {
   sudo chown -R $(whoami) ~/hyperledger
   mkdir -p ~/hyperledger/org2/peer1/assets/ca/
   cp ~/hyperledger/org2/ca/crypto/ca-cert ~/hyperledger/org2/peer1/assets/ca/org2-ca-cert.pem
   export FABRIC_CA_CLIENT_HOME=~/hyperledger/org2/peer1
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org2/peer1/assets/ca/org2-ca-cert.pem

   sudo -E /home/user1/gopath/bin/fabric-ca-client enroll -d -u https://peer1-org2:peer1o2PW@rca-org2.inuit.local:7055
   mkdir -p ~/hyperledger/org2/peer1/assets/tls-ca/
   scp user1@192.168.176.101://home/hyperledger/tls/ca/crypto/ca-cert.pem ~/hyperledger/org2/peer1/assets/tls-ca/tls-ca-cert.pem
   export FABRIC_CA_CLIENT_MSPDIR=tls-msp
   export FABRIC_CA_CLIENT_TLS_CERTFILES=/etc/hyperledger/org2/peer1/assets/tls-ca/tls-ca-cert.pem
   
   sudo -E /home/user1/gopath/bin/fabric-ca-client enroll -d -u https://peer1-org2:peer1o2PW@ca-tls.inuit.local:7052 --enrollment.profile tls --csr.hosts peer1-org2.inuit.local
   for key in ~/hyperledger/org2/peer1/tls-msp/keystore/*
   do 
      mv "$key" key.pem
   done


}

enrollO2admin() {
   sudo chown -R $(whoami) ~/hyperledger
   export FABRIC_CA_CLIENT_HOME=~/hyperledger/org2/admin
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org2/peer1/assets/ca/org2-ca-cert.pem
   export FABRIC_CA_CLIENT_MSPDIR=msp

   sudo -E /home/user1/gopath/bin/fabric-ca-client enroll -d -u https://admin-org2:org2AdminPW@0.0.0.0:7055
   mkdir -p ~/hyperledger/org2/peer1/msp/admincerts
   cp ~/hyperledger/org2/admin/msp/signcerts/cert.pem ~/hyperledger/org2/peer1/msp/admincerts/org2-admin-cert.pem
}

launchO2peer() {
   docker-compose -f $1 up -d
   sleep 5
   docker ps -a
   docker logs peer1-org2.inuit.local | grep -q Started peer with ID=[name:
   # if [ $? -eq ]
   
}

enrollOrd() {
   sudo chown -R $(whoami) ~/hyperledger
   export FABRIC_CA_CLIENT_HOME=~/hyperledger/org2/ord1
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org2/peer1/assets/ca/org1-ca-cert.pem

   sudo -E /home/user1/gopath/bin/fabric-ca-client enroll -d -u https://ord1-org2:ord1o2pw@rca-org2.inuit.local:7055

   export FABRIC_CA_CLIENT_MSPDIR=tls-msp
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org2/peer1/assets/tls-ca/tls-ca-cert.pem

   sudo -E /home/user1/gopath/bin/fabric-ca-client enroll -d -u https://ord1-org2:ord1o2PW@ca-tls.inuit.local:7052 --enrollment.profile tls --csr.hosts ord1-org2.inuit.local
   for key in ~/hyperledger/org1/ord1/tls-msp/keystore/*
   do 
      mv "$key" key.pem
   done
}

launchOrd() {
   # Docker-compose file , docker-compose up
}

createCLI() {

}

createJoinChannel() {
   export CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/org2/admin/msp
   export CORE_PEER_ADDRESS=peer1-org2.inuit.local:7051 # cli and this peer on same host local host network
   # so 7051 not 10051
   peer channel join -b /etc/hyperledger/org2/peer1/assets/twoorgschannel.block

   export CORE_PEER_ADDRESS=peer2-org2.inuit.local:9051
   peer channel join -b /etc/hyperledger/org2/peer1/assets/twoorgschannel.block
}

installInstanChaincode() {
   export CORE_PEER_ADDRESS=peer1-org2.inuit.local:7051
   export CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/org2/admin/msp
   peer chaincode install -n mycc -v 1.0 -p github.com/hyperledger/fabric-samples/chaincode/abac/go

   export CORE_PEER_ADDRESS=peer2-org2.inuit.local:9051
   export CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/org2/admin/msp
   peer chaincode install -n mycc -v 1.0 -p github.com/hyperledger/fabric-samples/chaincode/abac/go

   peer chaincode instantiate -C twoorgschannel -n mycc -v 1.0 -c '{"Args":["init","a","100","b","200"]}' -o ord1-org1.inuit.local:7050 --tls --cafile /etc/hyperledger/org1/peer1/tls-msp/tlscacerts/tls-ca-tls-inuit-local-7052.pem
}

launchO2peer ../peer2-o2-docker-compose.yaml