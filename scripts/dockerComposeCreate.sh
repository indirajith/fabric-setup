#!/bin/bash


set -ev
createCA() 
{
   echo "Please enter the number of required CAs"
   read numCA
   #declare -a CAS;
   [ -z "$numCA" ] && \
      echo "Please enter the number of CAs" || \
      for num in $(seq 1 $numCA)
      do
         echo "Enter the name of CA $num"
         read FABRIC_CA_SERVER_NAME
         echo "Enter Common Name (cn) of CA $num"
         read FABRIC_CA_SERVER_CSR_CN
         echo "Enter the CSR hosts of CA $num"
         read FABRIC_CA_SERVER_CSR_HOSTS
         echo "Enter the home path of CA $num"
         read FABRIC_CA_SERVER_HOME
         #writeDockerCA() $FABRIC_CA_SERVER_NAME $FABRIC_CA_SERVER_CSR_CN $FABRIC_CA_SERVER_CSR_HOSTS $FABRIC_CA_SERVER_HOME
         set -x
         docker-compose -f docker/docker-compose-ca.yml -d up
         set +x
         writeDockerCA

         # CAS[$num]="ca_org${num}"
      done
      # echo ${CAS[*]}
}

writeDockerCA()
{
   cat <<end-of-ca
      ${carole}ca${num}-${ORG}:
         image: hyperledger/${IMAGETAG}
         container_name: ${FABRIC_CA_SERVER_NAME}
         command: sh -c 'fabric-ca-server start -d -b tls-ca-admin:tls-ca-adminpw --port 7052'
         environment:
           - FABRIC_CA_SERVER_HOME=${FABRIC_CA_SERVER_HOME}
           - FABRIC_CA_SERVER_TLS_ENABLED=true
           - FABRIC_CA_SERVER_NAME=${FABRIC_CA_SERVER_NAME}
           - FABRIC_CA_SERVER_CSR_CN=${FABRIC_CA_SERVER_CSR_CN}
           - FABRIC_CA_SERVER_CSR_HOSTS=${FABRIC_CA_SERVER_CSR_HOSTS}
           - FABRIC_CA_SERVER_DEBUG=${DEBUGSTATUS}
         volumes:
           - ${ca_server_local_valume}/${ORG}/${carole}:${FABRIC_CA_SERVER_HOME}
         networks:
           - fabric
         ports:
           - ${PORT}:${PORT}
end-of-ca
}

createCA

# createPeer() 
# {
# 
# }
# 
# createOrderer() 
# {
# 
# }
# 
# createCLI() 
# {
# 
# }