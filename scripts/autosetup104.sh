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
   mkdir -p ~/hyperledger/org1/peer2/assets/ca/
   # Copy the root cert of org1's CA to local. Org1 CA runs in 101.
   scp user1@192.168.176.101:/home/hyperledger/org1/ca/crypto/ca-cert.pem ~/hyperledger/org1/peer2/assets/ca/org1-ca-cert.pem
   export FABRIC_CA_CLIENT_HOME=~/hyperledger/org1/peer2
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org1/peer2/assets/ca/org1-ca-cert.pem

   sudo -E /home/user1/gopath/bin/fabric-ca-client enroll -d -u https://peer2-org1:peer2o1PW@rca-org1.inuit.local:7054

}

getTLScert() {
   sudo chown -R $(whoami) ~/hyperledger
   mkdir -p ~/hyperledger/org1/peer1/assets/tls-ca/
   # Copy the root cert of TLS CA to local.
   scp user1@192.168.176.101:/home/hyperledger/tls/ca/crypto/ca-cert.pem ~/hyperledger/org1/peer2/assets/tls-ca/tls-ca-cert.pem
   export FABRIC_CA_CLIENT_HOME=~/hyperledger/org1/peer2
   export FABRIC_CA_CLIENT_MSPDIR=tls-msp
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org1/peer2/assets/tls-ca/tls-ca-cert.pem

   sudo -E /home/user1/gopath/bin/fabric-ca-client enroll -d -u https://peer2-org1:peer2o1PW@ca-tls.inuit.local:7052 --enrollment.profile tls --csr.hosts peer2-org1.inuit.local
   for entry in ~/hyperledger/org1/peer2/tls-msp/keystore/*
   do 
      mv "$entry" key.pem
   done

}

launcho1p2() {
   sudo chown -R $(whoami) ~/hyperledger
   mkdir -p ~/hyperledger/org1/peer2/msp/admincerts
   # Copy org1's admin certificate to peer2's MSP
   scp user1@192.168.176.103:/home/hyperledger/org1/peer1/msp/admincerts/org1-admin-cert.pem /home/hyperledger/org1/peer2/msp/admincerts/org1-admin-cert.pem 
   docker-compose -f $1 up -d
   sleep 5
   docker ps -a
   docker logs peer2-org1.inuit.local | grep -q Started peer with ID=[name:
   # if [ $? -eq ]
   
}

enrollP2o2() {
   sudo chown -R $(whoami) ~/hyperledger
   mkdir -p ~/hyperledger/org2/peer2/assets/ca/
   # Copy org2 root ca cert to ~/hyperledger/org2/peer2/assets/ca
   scp user1@192.168.176.105:/home/hyperledger/org2/ca/crypto/ca-cert.pem ~/hyperledger/org2/peer2/assets/ca/org2-ca-cert.pem
   export FABRIC_CA_CLIENT_HOME=~/hyperledger/org2/peer2
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org2/peer2/assets/ca/org2-ca-cert.pem
   sudo -E /home/user1/gopath/bin/fabric-ca-client enroll -d -u https://peer2-org2:peer2o2PW@rca-org2.inuit.local:7055

}

getTLScertp2o2() {
   sudo chown -R $(whoami) ~/hyperledger
   mkdir -p ~/hyperledger/org2/peer2/assets/tls-ca/
   scp user1@192.168.176.101:/home/hyperledger/tls/ca/crypto/ca-cert.pem ~/hyperledger/org2/peer2/assets/tls-ca/tls-ca-cert.pem
   export FABRIC_CA_CLIENT_HOME=~/hyperledger/org2/peer2
   export FABRIC_CA_CLIENT_MSPDIR=tls-msp
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org2/peer2/assets/tls-ca/tls-ca-cert.pem
   
   sudo -E /home/user1/gopath/bin/fabric-ca-client enroll -d -u https://peer2-org2:peer2o2PW@ca-tls.inuit.local:7052 --enrollment.profile tls --csr.hosts peer2-org2.inuit.local
   
}

launchO2peer() {
   docker-compose -f $1 up -d
   sleep 5
   docker ps -a
   docker logs peer2-org2.inuit.local | grep -q Started peer with ID=[name:
   # if [ $? -eq ]
   
}

if [ $1 = peer ]; then
do
   getFabCA
   enrollPeer
   getTLScert
   launcho1p2 ../peer2-o1-docker-compose.yaml
done

launchO2peer ../peer2-o2-docker-compose.yaml

enrollOrd() {
   sudo chown -R $(whoami) ~/hyperledger
   export FABRIC_CA_CLIENT_HOME=~/hyperledger/org1/ord2
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org1/peer2/assets/ca/org1-ca-cert.pem

   sudo -E /home/user1/gopath/bin/fabric-ca-client enroll -d -u https://ord2-org1:ord1o2pw@rca-org1.inuit.local:7054

   export FABRIC_CA_CLIENT_MSPDIR=tls-msp
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org1/peer2/assets/tls-ca/tls-ca-cert.pem
   sudo -E /home/user1/gopath/bin/fabric-ca-client enroll -d -u https://ord2-org1:ord2o1PW@ca-tls.inuit.local:7052 --enrollment.profile tls --csr.hosts ord2-org1.inuit.local
   for key in ~/hyperledger/org1/ord2/tls-msp/keystore/*
   do 
      mv "$key" key.pem
   done
 
}
