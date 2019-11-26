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

enrollPeer() {
   sudo chown -R $(whoami) ~/hyperledger
   mkdir -p ~/hyperledger/org1/peer1/assets/ca/
   # Copy the root cert of org1's CA to local. Org1 CA runs in 101.
   scp user1@192.168.176.101:/home/hyperledger/org1/ca/crypto/ca-cert.pem ~/hyperledger/org1/peer1/assets/ca/org1-ca-cert.pem
   export FABRIC_CA_CLIENT_HOME=~/hyperledger/org1/peer1
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org1/peer1/assets/ca/org1-ca-cert.pem

   sudo -E /home/user1/gopath/bin/fabric-ca-client enroll -d -u https://peer1-org1:peer1o1PW@rca-org1.inuit.local:7054

}

getTLScert() {
   sudo chown -R $(whoami) ~/hyperledger
   mkdir -p ~/hyperledger/org1/peer1/assets/tls-ca/
   # Copy the root cert of TLS CA to local.
   scp user1@192.168.176.101:/home/hyperledger/tls/ca/crypto/ca-cert.pem ~/hyperledger/org1/peer1/assets/tls-ca/tls-ca-cert.pem
   export FABRIC_CA_CLIENT_HOME=~/hyperledger/org1/peer1
   export FABRIC_CA_CLIENT_MSPDIR=tls-msp
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org1/peer1/assets/tls-ca/tls-ca-cert.pem

   sudo -E /home/user1/gopath/bin/fabric-ca-client enroll -d -u https://peer1-org1:peer1o1PW@ca-tls.inuit.local:7052 --enrollment.profile tls --csr.hosts peer1-org1.inuit.local
   for key in ~/hyperledger/org1/peer1/tls-msp/keystore/*
   do 
      mv "$key" p1o1-tls-key.pem
   done

}

enrollo1admin() {
   sudo chown -R $(whoami) ~/hyperledger
   mkdir -p ~/hyperledger/org1/admin
   export FABRIC_CA_CLIENT_HOME=~/hyperledger/org1/admin
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org1/peer1/assets/ca/org1-ca-cert.pem
   export FABRIC_CA_CLIENT_MSPDIR=msp

   sudo -E /home/user1/gopath/bin/fabric-ca-client enroll -d -u https://admin-org1:org1AdminPW@rca-org1.inuit.local:7054
   sudo chown -R $(whoami) ~/hyperledger
   mkdir -p ~/hyperledger/org1/peer1/msp/admincerts
   cp ~/hyperledger/org1/admin/msp/signcerts/cert.pem ~/hyperledger/org1/peer1/msp/admincerts/org1-admin-cert.pem
}

launcho1p1() {
   docker-compose -f $1 up -d
   sleep 5
   docker ps -a
   docker logs peer1-org1.inuit.local | grep -q Started peer with ID=[name:
   # if [ $? -eq ]
   
}

enrollOrd() {
   sudo chown -R $(whoami) ~/hyperledger
   export FABRIC_CA_CLIENT_HOME=~/hyperledger/org1/ord1
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org1/peer1/assets/ca/org1-ca-cert.pem

   sudo -E /home/user1/gopath/bin/fabric-ca-client enroll -d -u https://ord1-org1:ord1o1pw@rca-org1.inuit.local:7054

   export FABRIC_CA_CLIENT_MSPDIR=tls-msp
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org1/peer1/assets/tls-ca/tls-ca-cert.pem

   sudo -E /home/user1/gopath/bin/fabric-ca-client enroll -d -u https://ord1-org1:ord1o1PW@ca-tls.inuit.local:7052 --enrollment.profile tls --csr.hosts ord1-org1.inuit.local
   for key in ~/hyperledger/org1/ord1/tls-msp/keystore/*
   do 
      mv "$key" key.pem
   done
}

createGenesis() {
   sudo chown -R $(whoami) ~/hyperledger
   mkdir -p ~/hyperledger/org1/msp/{admincerts,cacerts,tlscerts,users}
   mkdir -p ~/hyperledger/org2/msp/{admincerts,cacerts,tlscerts,users}

   
}

if [ $1 = peer ]; then
do
   getFabCA
   enrollPeer
   getTLScert
   enrollo1admin
   launcho1p1 ../peer1-o1-docker-compose.yaml
done
