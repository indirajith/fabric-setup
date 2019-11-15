Fabric Network Setup Manual
============================

This manual illustrates how to setup Fabric network with Fabric-CA 
and RAFT consensus on multiple hosts. 

.. note:: This manual is an updated/modified version of the official guide
of Fabric-CA operations guide available on: `<https://hyperledger-fabric-ca.readthedocs.io/en/latest/operations_guide.html>`_.

All identities that participate on a Hyperledger Fabric
blockchain network must be authorized. This authorization
is provided in the form of cryptographic material that is
verified against trusted authorities.

In this guide, you will see the process for setting up a
blockchain network that includes two organizations, each with two peers
and two orderers. You'll see how to generate cryptographic material for orderers,
peers, administrators, and end users so that private keys never leave
the host or container where they are generated.

Topology
---------

In this example, we will look at how to setup up an orderer, peers, and CAs
across two organizations. The topology of this deployment can be seen in the
image below:

.. image:: ./images/network_topology_v2.png

This example will simulate a deployment using docker containers. The
containers are running on different host machines. This is done so that you can see 
which assets need to be exchanged out-of-band between the parties involved in the network.
Eventhough we have org0 in our topology we are not going to use this org. It is for further
expansion of the network.

As the deployment is spread across different networks, the
example has extra hosts defined in the docker-composer file for each containers.

The documentation provides docker-compose files for per host basis. One can easily understand
the containers in each host from the docker-compose files and the topology diagram.

Components Description
^^^^^^^^^^^^^^^^^^^^^^

In the topology each column shows a host. The top box shows the IP of the host and the boxes under them
depicts the containers that particular host contains.

Certificate Authority (CA) provides the following functionalities:
   - Registration of identities
   - Issuance of enrollment certificates
   - Certificate renewal and revocation

Fabric-CA consists of both server and client. 

To make communication between several components and nodes of fabric network secure, we use TLS. It's
recommended not to use same CA for both communication and organisational enrollment. For this purpose 
we use separate CA for TLS communication. But we this manual uses same TLS CA for all the organisations.
TLS CA provides x509 certificates for all the nodes of the network. 

This manual uses separate CAs for each organisations, org1 and org2. These organisational CAs provide
enrollment certificates for the components of their respective organisations like, peers, orderers, clients,
admins, amd clients. 

Peers in the tutorial uses CouchDB as their world state database. each peer has its own CouchDB. Peers
spin up their respective couchdb database containers which are specified in the peer's docker-compose files.


Setup CAs
----------

Download fabric-ca-client binary
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

For each host that needs to acquire cryptographic material, you will need to have the
fabric-ca-client binary available on the host machine. The client will be used to
connect to the Fabric CA server container.

The 'fabric-ca-client' command is used on the host machine. So we need to have fabric-ca-client binary 
installed on the hosts from which we want to issue enrollment commands. With this way the crypto
materials don't leave the host where the containers need them. 
Please refer the following link to understand how to install fabric-ca on the hosts machines:
`<https://hyperledger-fabric-ca.readthedocs.io/en/release-1.4/users-guide.html>`_.

To install fabric-ca binaries:
Prereqs:
Go 1.10+
GOPATH environment variable set correctly
libtool and libtdhl-dev packages installed

For Ubuntu:

.. code:: bash

   sudo apt install libtool libltdl-dev

For MacOSX:

.. code:: bash

   brew install libtool

Install
The following installs both the fabric-ca-server and fabric-ca-client binaries in $GOPATH/bin.

.. code:: bash

   go get -u github.com/hyperledger/fabric-ca/cmd/...

Note: If you have already cloned the fabric-ca repository, make sure you are on the master branch 
before running the ‘go get’ command above. Otherwise, you might see an error.


This manual uses fabric-ca in docker images we don't need to install them natively on the hosts.


.. note:: If we don't provide an exact version, by default the latest tag will be used. Provide the version in the 
docker-compose image value.


Setup TLS CA
^^^^^^^^^^^^^^

A TLS CA is used to issue TLS certificates.  These certificates are required in
order to secure the communication between various processes. We use a same TLS CA for all nodes and 
components in both organisations.

In order to simplify this example, all organizations will use the same TLS CA
and TLS mutual authentication is disabled.

.. note:: In a production environment, you will probably use your organization's CA
          to get TLS certificates. You will have to transfer out-of-band your CA's
          certificate with organizations that will validate your TLS certificates.

For the Fabric CA docker-compose files use init first in the commands, to have the default 
fabric-ca-server-config.yaml file to be created. That can then be costomised with CSR options 
if needed. Then we can change the command in the docker-compose command for CA containers to start. 
which will start the containers with our specification. 

Start Server Natively
The following starts the fabric-ca-server with default settings.

.. code:: bash

  fabric-ca-server start -b admin:adminpw

Initializing the server
Initialize the Fabric CA server as follows:

.. code:: bash

   fabric-ca-server init -b admin:adminpw

The server configuration file contains a Certificate Signing Request (CSR) section that can be configured. The following is a sample CSR.

.. code:: bash

   cn: fabric-ca-server
   names:
      - C: US
        ST: "North Carolina"
        L:
        O: Hyperledger
        OU: Fabric
   hosts:
     - host1.example.com
     - localhost
   ca:
      expiry: 131400h
      pathlength: 1


We can change the CSR section according to our need. To avoid copy paste errors, it's recommanded to use the ``docker-compose.yaml``
files. The sections provided below is to get an idea of what we are discussing.

A docker service, such as the one below can be used to a launch a Fabric TLS CA
container. First init the CA server by changing the command in the following docker-compose file to ` fabric-ca-server init -b tls-ca-admin:tls-ca-adminpw`.
It creates fabric-ca-sever-config in the fabric-ca-server's home directory. Where we can configure the CSR section. Then change the command
as bellow and start the server. After starting the CA server check for server's certificate. If it does not have specified CSR values, delete
the certificate and other artifacts generated by the server except the `fabric-ca-server-config.yaml` and restart the server. Do the same for
fabric-ca-clients when enrolling identities.

.. code:: yaml

   version: '2'

   networks:
      fabric-host1:

   services:
      ca-tls:
         container_name: ca-tls.inuit.local
         image: hyperledger/fabric-ca:1.4.0
         command: sh -c 'fabric-ca-server start -d -b tls-ca-admin:tls-ca-adminpw --port 7052'
         environment:
            - FABRIC_CA_SERVER_HOME=/etc/hyperledger/fabric-tlsca/crypto
            - FABRIC_CA_SERVER_TLS_ENABLED=true
            - FABRIC_CA_SERVER_NAME=ca-tls.inuit.local
            - FABRIC_CA_SERVER_CSR_CN=ca-tls.inuit.local
            - FABRIC_CA_SERVER_CSR_HOSTS=ca-tls.inuit.local,localhost,0.0.0.0
            - FABRIC_CA_SERVER_DEBUG=true
         volumes:
            - ~/hyperledger/tls/ca:/etc/hyperledger/fabric-tlsca
         networks:
            - fabric-host1
         ports:
            - 7052:7052

This container can be started using the following docker command.

.. code:: bash

    docker-compose up ca-tls 
    docker-compose up -d ca-tls # -d for detached mode. ca-tls : Service name defined in docker-compose file.

On a successful launch of the container, you will see the following line in
the CA container's log.

.. code:: bash

   [INFO] Listening on https://0.0.0.0:7052

At this point the TLA CA server is on a listening on a secure socket, and can start
issuing TLS certificates.

.. note:: Everytime when fabric-ca-server start command is issued, it generates new pair of private, public
   key pairs. The certificates generated would have the latest key pair. At this point we can not use previously
   generated keys and certificate with this CA server. So, remove any previously generated crypto materials
   and start afresh. 

Enroll TLS CA's Admin
~~~~~~~~~~~~~~~~~~~~~~~

Before you can start using the CA client, you must acquire the signing
certificate for the CA's TLS certificate. This is a required step before you
can connect using TLS.

In our example, you would need to acquire the file located at ``~/hyperledger/tls/ca/crypto/ca-cert.pem``
on the machine running the TLS CA server and copy this file over to all hosts where
you will be running the CA client binary. This certificate, also known as the TLS
CA's signing certificate is going to be used to validate the TLS certificate of
the CA. Once the certificate has been copied over to the CA client's host
machine, you can start issuing commands using the CA.

The TLS CA's signing certificate will need to be available on each host that will run
commands against the TLS CA.

The TLS CA server was started with a bootstrap identity which has full admin
privileges for the server. One of the key abilities of the admin
is the ability to register new identities. The administrator for this CA will
use the Fabric CA client to register the following new identities with the CA.

Total indentities: 2 peers for each 2 orgs (org1, org2) : 4 peers.
                   2 orderer for each 2 orgs: 4 orderers.


These identities will be used to get TLS
certificates for peers and orderers.

You will issue the commands below to enroll the TLS CA admin and then register
identities. We assume the trusted root certificate for the TLS CA has been copied
to ``~/hyperledger/tls/ca/crypto/ca-cert.pem`` on all host machines that
will communicate with this CA via the fabric-ca-client. This directory is mapped to
``/etc/hyperledger/tls/ca/crypto/ca-cert.pem`` in the container.

TLS-CA admin can directly enrolled without registration as it is the bootstrap identity.

When issueing the following commands if you encounter file creation permission errors, run 'fabric-ca-client' command with sudo. For this to work, the 'fabric-ca-client' executable must be in sudo PATH variable or we must provide the absolute path to this executable. Also the environmental variables must be persisted to sudo as well.
For example issue the following command with absolute path of `fabric-ca-client` binary instead, after exporting environmental variables.

.. code:: bash 

   sudo -E /home/user1/gopath/bin/fabric-ca-client  enroll -d -u https://tls-ca-admin:tls-ca-adminpw@0.0.0.0:7052

The above method has to be followed for all the fabric-ca-client commands provided bellow.

.. code:: bash

   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/tls/ca/crypto/ca-cert.pem
   export FABRIC_CA_CLIENT_HOME=~/hyperledger/tls/ca/admin


   fabric-ca-client enroll -d -u https://tls-ca-admin:tls-ca-adminpw@0.0.0.0:7052
   fabric-ca-client register -d --id.name peer1-org1 --id.secret peer1o1PW --id.type peer -u https://localhost:7052
   fabric-ca-client register -d --id.name peer2-org1 --id.secret peer2o1PW --id.type peer -u https://localhost:7052
   fabric-ca-client register -d --id.name peer1-org2 --id.secret peer1o2PW --id.type peer -u https://localhost:7052
   fabric-ca-client register -d --id.name peer2-org2 --id.secret peer2o2PW --id.type peer -u https://localhost:7052
   
   fabric-ca-client register -d --id.name ord1-org1 --id.secret ord1o1PW --id.type orderer -u https://localhost:7052
   fabric-ca-client register -d --id.name ord2-org1 --id.secret ord2o1PW --id.type orderer -u https://localhost:7052
   fabric-ca-client register -d --id.name ord1-org2 --id.secret ord1o2PW --id.type orderer -u https://localhost:7052
   fabric-ca-client register -d --id.name ord2-org2 --id.secret ord2o2PW --id.type orderer -u https://localhost:7052

.. note:: If the path of the environment variable FABRIC_CA_CLIENT_TLS_CERTFILES is not
          an absolute path, it will be parsed as relative to the client's home directory.

With the identities registered on the TLS CA, we can move forward to setting up the
each organization's network. Anytime we need to get TLS certificates for a node in an
organization, we will refer to this CA.


Setup Org1's CA
~~~~~~~~~~~~~~~~~

Each organization must have it's own Certificate Authority (CA) for
issuing enrollment certificates. The CA will issue the certificates
for each of the peers and clients in the organization.

Your CA creates the identities that belong to your organization and issue
each identity a public and private key. These keys are what allow all of your
nodes and applications to sign and verify their actions. Any identity signed
by your CA will be understood by other members of the network to identify the
components that belong to your organization.


An administrator for Org1 will launch a Fabric CA docker container, which
will be used by Org1 to issue cryptographic material for identities in Org1.

A docker service, such as the one below can be used to a launch a Fabric CA
container.

.. code:: yaml

   rca-org1:
      container_name: rca-org1.inuit.local
      image: hyperledger/fabric-ca
      command: sh -c 'fabric-ca-server start -d -b rca-org1-admin:rca-org1-adminpw --port 7054'
      environment:
         - FABRIC_CA_SERVER_HOME=/etc/hyperledger/fabric-org1-rca/crypto
         - FABRIC_CA_SERVER_TLS_ENABLED=true
         - FABRIC_CA_SERVER_NAME=rca-org1.inuit.local
         - FABRIC_CA_SERVER_CSR_CA=rca-org1.inuit.local
         - FABRIC_CA_SERVER_CSR_HOSTS=rca-org1.inuit.local,localhost,0.0.0.0
         - FABRIC_CA_SERVER_DEBUG=true
      volumes:
         - ~/hyperledger/org1/ca:/etc/hyperledger/fabric-org1-rca
      networks:
         - fabric-host1
      ports:
         - 7054:7054


Just append the docker-compose file on the host 1 with the above service definition.

On a successful launch of the container, you will see the following line in
the CA container's log.

.. code:: bash

   [INFO] Listening on https://0.0.0.0:7054

At this point the CA server is listening on a secure socket, and can start
issuing cryptographic material.

Enroll Org1's CA Admin
^^^^^^^^^^^^^^^^^^^^^^^

You will issue the commands below to enroll the CA admin and then register
both of Org1's identities.

The following identies are being registered:
   - Peer 1 (peer1-org1)
   - Peer 2 (peer2-org1)
   - Admin (admin-org1)
   - End user (user-org1)
   - Orderer 1 (ord1-org1)
   - Orderer 2 (ord2-org1)

In the commands below, we will assume the trusted root certificate for the CA's
TLS certificate has been copied to
``~/home/hyperledger/org1/ca/crypto/ca-cert.pem``
on the host machine where the fabric-ca-client binary is present. (mapped to /etc/hyperledger/<respective_directory>)
If the client's binary is located on a different host, you will need to get the
signing certificate through an out-of-band process.

.. code:: bash

   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org1/ca/crypto/ca-cert.pem
   export FABRIC_CA_CLIENT_HOME=~/hyperledger/org1/ca/admin

   fabric-ca-client enroll -d -u https://rca-org1-admin:rca-org1-adminpw@0.0.0.0:7054

   fabric-ca-client register -d --id.name peer1-org1 --id.secret peer1o1PW --id.type peer -u https://0.0.0.0:7054
   fabric-ca-client register -d --id.name peer2-org1 --id.secret peer2o1PW --id.type peer -u https://0.0.0.0:7054
   fabric-ca-client register -d --id.name admin-org1 --id.secret org1AdminPW --id.type admin --id.attrs "hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert" -u https://0.0.0.0:7054
   fabric-ca-client register -d --id.name user-org1 --id.secret org1UserPW --id.type user -u https://0.0.0.0:7054

   fabric-ca-client register -d --id.name ord1-org1 --id.secret ord1o1pw --id.type orderer -u https://0.0.0.0:7054
   fabric-ca-client register -d --id.name ord2-org1 --id.secret ord1o2pw --id.type orderer -u https://0.0.0.0:7054export FABRIC_CA_CLIENT_TLS_CERTFILES=/tmp/hyperledger/org1/ca/crypto/ca-cert.pem
   

Setup Org2's CA
~~~~~~~~~~~~~~~~~

The same set of steps that you followed for Org1 apply to Org2. So we will quickly
go through the set of steps that the administrator for Org2 will perform.

A docker service, such as the one below can be used to a launch a Fabric CA for
Org2. According to our topology the root CA for the org2 is on host 105. So make a
docker-compose file with the following content on host 105. Host specific docker-files
are available in the project directory.

.. code:: yaml

version: '2'

networks:
   fabric-host5:

services:
   rca-org2:
      container_name: rca-org2.inuit.local
      image: hyperledger/fabric-ca
      command: sh -c 'fabric-ca-server start -d -b rca-org2-admin:rca-org2-adminpw --port 7055'
      environment:
         - FABRIC_CA_SERVER_HOME=/etc/hyperledger/fabric-org2-rca/crypto
         - FABRIC_CA_SERVER_NAME=rca-org2.inuit.local
         - FABRIC_CA_SERVER_TLS_ENABLED=true
         - FABRIC_CA_SERVER_CSR_CN=rca-org2.inuit.local
         - FABRIC_CA_SERVER_CSR_HOSTS=rca-org2.inuit.local,localhost,0.0.0.0
         - FABRIC_CA_SERVER_DEBUG=true
      volumes:
         - ~/hyperledger/org2/ca:/etc/hyperledger/fabric-org2-rca
      networks:
         - fabric-host5
      ports:
         - 7055:7055

On a successful launch of the container, you will see the following line in
the CA container's log.

.. code:: bash

   [INFO] Listening on https://0.0.0.0:7055

At this point the CA server is listening on a secure socket, and can start
issuing cryptographic material.

Enrolling Org2's CA Admin
^^^^^^^^^^^^^^^^^^^^^^^^^^

You will issue the commands below to get the CA admin enrolled and all peer
related identities registered. In the commands below, we will assume the trusted
root certificate of CA's TLS certificate has been copied to
``~/hyperledger/org2/ca/crypto/ca-cert.pem``.

.. code:: bash

   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org2/ca/crypto/ca-cert.pem
   export FABRIC_CA_CLIENT_HOME=~/hyperledger/org2/ca/admin
   
   fabric-ca-client enroll -d -u https://rca-org2-admin:rca-org2-adminpw@0.0.0.0:7055
   fabric-ca-client register -d --id.name peer1-org2 --id.secret peer1o2PW --id.type peer -u https://0.0.0.0:7055
   fabric-ca-client register -d --id.name peer2-org2 --id.secret peer2o2PW --id.type peer -u https://0.0.0.0:7055
   fabric-ca-client register -d --id.name admin-org2 --id.secret org2AdminPW --id.type admin --id.attrs "hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert" -u https://0.0.0.0:7055
   fabric-ca-client register -d --id.name user-org2 --id.secret org2UserPW --id.type user -u https://0.0.0.0:7055
   
   fabric-ca-client register -d --id.name ord1-org2 --id.secret ord1o2pw --id.type orderer -u https://0.0.0.0:7055
   fabric-ca-client register -d --id.name ord2-org2 --id.secret ord2o2pw --id.type orderer -u https://0.0.0.0:7055

Setup Peers
-----------------

Once the CAs are up and running, we can start enrolling peers.

Setup Org1's Peers
^^^^^^^^^^^^^^^^^^^

An administrator for Org1 will enroll the peers with it's CA and then launch the
peer docker containers. Before you can start up a peer, you will need to enroll
the peer identities with the CA to get the MSP that the peer will use.
This is known as the local peer MSP.

Enroll Peer1
~~~~~~~~~~~~~

If the host machine running Peer1 does not have the fabric-ca-client binary,
refer to the instructions above on to download the binary.

In the command below, we will assume the trusted root certificate of Org1 has
been copied to ``/etc/hyperledger/org1/peer1/assets/ca/org1-ca-cert.pem``
on Peer1's host machine. Acquiring of the signing certificate is an out of
band process.

.. code:: bash

   export FABRIC_CA_CLIENT_HOME=~/hyperledger/org1/peer1
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org1/peer1/assets/ca/org1-ca-cert.pem
   # sudo chown -R <user> /etc/hyperledger
   fabric-ca-client enroll -d -u https://peer1-org1:peer1o1PW@rca-org1.inuit.local:7054

Next step is to get the TLS cryptographic material for the peer. This requires another enrollment,
but this time you will enroll against the ``tls`` profile on the TLS CA. You will
also need to provide the address of the Peer1's host machine in the enrollment
request as the input to the ``csr.hosts`` flag. In the command below, we will
assume the certificate of the TLS CA has been copied to
``~/hyperledger/org1/peer1/assets/tls-ca/tls-ca-cert.pem``
on Peer1's host machine.

.. code:: bash

   export FABRIC_CA_CLIENT_MSPDIR=tls-msp          
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org1/peer1/assets/tls-ca/tls-ca-cert.pem
   fabric-ca-client enroll -d -u https://peer1-org1:peer1o1PW@ca-tls.inuit.local:7052 --enrollment.profile tls --csr.hosts peer1-org1.inuit.local

Go to path ``~/hyperledger/org1/peer1/tls-msp/keystore`` and change the name of
the key to ``key.pem``. This will make it easy to be able to refer to in
later steps.

At this point, you will have two MSP directories. One MSP contains peer's enrollment
certificate and the other has the peer's TLS certificate. However, there needs to be
an additional folder added in the enrollment MSP directory, and this is the ``admincerts``
folder. This folder will contain certificate(s) for the administrator of Org1.
We will talk more about this when we enroll Org1's admin a little further down.

Enroll Peer2 Org1
~~~~~~~~~~~~~~~~~

You will perform similar commands for Peer2. In the commands below, we will
assume the trusted root certificate of Org1 has been copied to
``~/hyperledger/org1/peer2/assets/ca/org1-ca-cert.pem`` on Peer2's host
machine.

.. code:: bash

   export FABRIC_CA_CLIENT_HOME=~/hyperledger/org1/peer2/
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org1/peer2/assets/ca/org1-ca-cert.pem
   fabric-ca-client enroll -d -u https://peer2-org1:peer2o1PW@rca-org1.inuit.local:7054

Next step is to get the TLS cryptographic material for the peer. This requires another enrollment,
but this time you will enroll against the ``tls`` profile on the TLS CA. You will
also need to provide the address of the Peer2's host machine in the enrollment
request as the input to the ``csr.hosts`` flag. In the command below, we will
assume the certificate of the TLS CA has been copied to
``~/hyperledger/org1/peer2/assets/tls-ca/tls-ca-cert.pem``
on Peer2's host machine.

.. code:: bash

   export FABRIC_CA_CLIENT_HOME=~/hyperledger/org1/peer2/
   export FABRIC_CA_CLIENT_MSPDIR=tls-msp
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org1/peer2/assets/tls-ca/tls-ca-cert.pem
   fabric-ca-client enroll -d -u https://peer2-org1:peer2o1PW@ca-tls.inuit.local:7052 --enrollment.profile tls --csr.hosts peer2-org1.inuit.local

Go to path ``~/hyperledger/org1/peer2/tls-msp/keystore`` and change the name of
the key to ``key.pem``. This will make it easy to be able to refer to in
later steps.

At this point, you will have two MSP directories. One MSP contains peer's enrollment
certificate and the other has the peer's TLS certificate. You will add the
``admincerts`` folder to the enrollment MSP once the admin has been enrolled.

Enroll Org1's Admin
~~~~~~~~~~~~~~~~~~~~

At this point, both peers have been enrolled. Now, you will enroll
Org1's admin identity. The admin identity is responsible for activities such as
installing and instantiating chaincode. The steps below will enroll the admin.
The commands below assumes that this is being executed on Peer1's host machine.

.. code:: bash

   export FABRIC_CA_CLIENT_HOME=~/hyperledger/org1/admin
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org1/peer1/assets/ca/org1-ca-cert.pem
   export FABRIC_CA_CLIENT_MSPDIR=msp
   fabric-ca-client enroll -d -u https://admin-org1:org1AdminPW@rca-org1.inuit.local:7054

After enrollment, you should have an admin MSP. You will copy the
certificate from this MSP and move it to the Peer1's MSP in the ``admincerts``
folder. You will need to disseminate this admin certificate to other peers in the
org, and it will need to go in to the ``admincerts`` folder of each peers' MSP.

The command below is only for Peer1, the exchange of the admin certificate to Peer2 will
happen out-of-band.

.. code:: bash

    mkdir ~/hyperledger/org1/peer1/msp/admincerts
    cp ~/hyperledger/org1/admin/msp/signcerts/cert.pem ~/hyperledger/org1/peer1/msp/admincerts/org1-admin-cert.pem

If the ``admincerts`` folder is missing from the peer's local MSP, the peer will
fail to start up.

Launch Org1's Peers
~~~~~~~~~~~~~~~~~~~~

Once we have enrolled all the peers and org admin, we have the necessary MSPs to
start the peers.

A docker service, such as the one below can be used to a launch a container for
Peer1. Copy the docker-compose.yaml files on all the hosts in its entirety to avoid 
copy paste errors. The approproate sections are given below for reference and better understanding.

.. code:: yaml

  peer1-org1:
      container_name: peer1-org1.inuit.local
      image: hyperledger/fabric-peer
      environment:
         - CORE_PEER_ID=peer1-org1.inuit.local
         - CORE_PEER_ADDRESS=peer1-org1.inuit.local:7051
         - CORE_PEER_LOCALMSPID=org1MSP
         - CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/org1/peer1/msp
         - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
         - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=fabric-proj_fabric-host2 # Starts chaincode containers on the same bridge network as peer
         - CORE_LEDGER_STATE_STATEDATABASE=CouchDB
         - CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=couchdbp1o1:5984
         - CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=peer1-org1
         - CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=p1o1cdbpw
         - FABRIC_LOGGING_SPEC=debug
         - CORE_PEER_TLS_ENABLED=true
         - CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/org1/peer1/tls-msp/signcerts/cert.pem
         - CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/org1/peer1/tls-msp/keystore/p1o1-tls-key.pem
         - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/org1/peer1/tls-msp/tlscacerts/tls-ca-tls-inuit-local-7052.pem
         - OORE_PEER_GOSSIP_USELEADERELECTION=true
         - CORE_PEER_GOSSIP_ORGLEADER=false
         - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer1-org1.inuit.local:7051
         - CORE_PEER_GOSSIP_SKIPHANDSHAKE=true
         - GODEBUG=netdns=go
      working_dir: /opt/gopath/src/github.com/hyperledger/fabric/org1/peer1
      volumes:
         - /var/run:/host/var/run
         - ~/hyperledger/org1/peer1:/etc/hyperledger/org1/peer1
         - ~/hyperledger/misc:/etc/hyperledger/misc
      depends_on:
         - couchdbp1o1
      extra_hosts:
         - "ca-tls.inuit.local:192.168.176.101"
         - "rca-org0.inuit.local:192.168.176.101"
         - "rca-org1.inuit.local:192.168.176.101"
         - "peer2-org1.inuit.local:192.168.176.104"
         - "peer2-org2.inuit.local:192.168.176.104"
         - "ord2-org1.inuit.local:192.168.176.104"
         - "cli-org0.inuit.local:192.168.176.104"
         - "peer1-org2.inuit.local:192.168.176.105"
         - "rca-org2.inuit.local:192.168.176.105"
         - "ord1-org2.inuit.local:192.168.176.105"
         - "cli-org2.inuit.local:192.168.176.105"
      networks:
         - fabric-host2
      ports:
         - 7051:7051
         - 7053:7053

   couchdbp1o1:
      container_name: couchdbp1o1
      image: hyperledger/fabric-couchdb
      environment:
         - COUCHDB_USER=peer1-org1
         - COUCHDB_PASSWORD=p1o1cdbpw
      ports:
         - "5984:5984"
      networks:
         - fabric-host2

Launching the peer service will bring up a peer container, and in the logs you will
see the following line:

.. code:: bash

   serve -> INFO 020 Started peer with ID=[name:"peer1-org1.inuit.local" ], network ID=[dev], address=[peer1-org1.inuit.local:7051]

A docker service, such as the one below can be used to a launch a container for
Peer2. Peer1 is on host 103 and peer2 is on host 104. Copy them accordingly.

.. code:: yaml

  peer2-org1:
      container_name: peer2-org1.inuit.local
      image: hyperledger/fabric-peer
      environment:
         - CORE_PEER_ID=peer2-org1.inuit.local
         - CORE_PEER_ADDRESS=peer2-org1.inuit.local:7051
         - CORE_PEER_LOCALMSPID=org1MSP
         - CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/org1/peer2/msp
         - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
         - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=fabric-proj_fabric-host4
         - CORE_LEDGER_STATE_STATEDATABASE=CouchDB
         - CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=couchdbp2o1:5984
         - CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=peer2-org1
         - CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=p2o1cdbpw
         - FABRIC_LOGGING_SPEC=grpc=debug
         - CORE_PEER_TLS_ENABLED=true
         - CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/org1/peer2/tls-msp/signcerts/cert.pem
         - CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/org1/peer2/tls-msp/keystore/key.pem
         - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/org1/peer2/tls-msp/tlscacerts/tls-ca-tls-inuit-local-7052.pem
         - CORE_PEER_GOSSIP_USELEADERELECTION=true
         - CORE_PEER_GOSSIP_ORGLEADER=false
         - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer2-org1.inuit.local:7051
         - CORE_PEER_GOSSIP_SKIPHANDSHAKE=true
         - CORE_PEER_GOSSIP_BOOTSTRAP=peer1-org1.inuit.local:7051
         - GODEBUG=netdns=go
      working_dir: /opt/gopath/src/github.com/hyperledger/fabric/org1/peer2
      volumes:
         - /var/run:/host/var/run
         - ~/hyperledger/org1/peer2:/etc/hyperledger/org1/peer2
         - ~/hyperledger/misc:/etc/hyperledger/misc
      extra_hosts:
         - "peer1-org1.inuit.local:192.168.176.103"
         - "ord1-org1.inuit.local:192.168.176.103"
         - "ord2-org2.inuit.local:192.168.176.103"
         - "cli-org1.inuit.local:192.168.176.103"
         - "peer1-org2.inuit.local:192.168.176.105"
         - "cli-org2.inuit.local:192.168.176.105"
         - "rca-org2.inuit.local:192.168.176.105"
         - "ord1-org2.inuit.local:192.168.176.105"
         - "rca-org1.inuit.local:192.168.176.101"
         - "rca-org0.inuit.local:192.168.176.101"
         - "ca-tls.inuit.local:192.168.176.101"
      depends_on:
         - couchdbp2o1
      networks:
         - fabric-host4
      ports:
         - 8051:7051
         - 8053:7053

   couchdbp2o1:
      container_name: couchdbp2o1
      image: hyperledger/fabric-couchdb
      environment:
         - COUCHDB_USER=peer2-org1
         - COUCHDB_PASSWORD=p2o1cdbpw
      ports:
         - "5984:5984"
      networks:
         - fabric-host4

   peer2-org2:
      container_name: peer2-org2.inuit.local
      image: hyperledger/fabric-peer
      environment:
         - CORE_PEER_ID=peer2-org2.inuit.local
         - CORE_PEER_ADDRESS=peer2-org2.inuit.local:7051
         - CORE_PEER_LOCALMSPID=org2MSP
         - CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/org2/peer2/msp
         - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
         - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=fabric-proj_fabric-host4
         - CORE_LEDGER_STATE_STATEDATABASE=CouchDB
         - CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=couchdbp2o2:5984
         - CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=peer2-org2
         - CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=p2o2cdbpw
         - FABRIC_LOGGING_SPEC=debug
         - CORE_PEER_TLS_ENABLED=true
         - CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/org2/peer2/tls-msp/signcerts/cert.pem
         - CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/org2/peer2/tls-msp/keystore/key.pem
         - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/org2/peer2/tls-msp/tlscacerts/tls-ca-tls-inuit-local-7052.pem
         - CORE_PEER_GOSSIP_USELEADERELECTION=true
         - CORE_PEER_GOSSIP_ORGLEADER=false
         - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer2-org2.inuit.local:7051
         - CORE_PEER_GOSSIP_SKIPHANDSHAKE=true
         - CORE_PEER_GOSSIP_BOOTSTRAP=peer1-org2.inuit.local:10051
         - GODEBUG=netdns=go
      working_dir: /opt/gopath/src/github.com/hyperledger/fabric/org2/peer2
      extra_hosts:
         - "peer1-org1.inuit.local:192.168.176.103"
         - "ord1-org1.inuit.local:192.168.176.103"
         - "ord2-org2.inuit.local:192.168.176.103"
         - "cli-org1.inuit.local:192.168.176.103"
         - "peer1-org2.inuit.local:192.168.176.105"
         - "cli-org2.inuit.local:192.168.176.105"
         - "rca-org2.inuit.local:192.168.176.105"
         - "ord1-org2.inuit.local:192.168.176.105"
         - "rca-org1.inuit.local:192.168.176.101"
         - "rca-org0.inuit.local:192.168.176.101"
         - "ca-tls.inuit.local:192.168.176.101"
      depends_on:
         - couchdbp2o2
      volumes:
         - /var/run:/host/var/run
         - ~/hyperledger/org2/peer2:/etc/hyperledger/org2/peer2
      networks:
         - fabric-host4
      ports:
         - 9051:7051
         - 9053:7053

   couchdbp2o2:
      container_name: couchdbp2o2
      image: hyperledger/fabric-couchdb
      environment:
         - COUCHDB_USER=peer2-org2
         - COUCHDB_PASSWORD=p2o2cdbpw
      ports:
         - "6984:5984"
      networks:
         - fabric-host4

Launching the peer service will bring up a peer container, and in the logs you
will see the following line:

.. code:: bash

    serve -> INFO 020 Started peer with ID=[name:"peer2-org1.inuit.local" ], network ID=[dev], address=[peer2-org1.inuit.local:7051] #8051

Setup Org2's Peers
^^^^^^^^^^^^^^^^^^^^

An administrator for Org2 will use the CA's bootstrap identity to enroll the peers
with the CA and then launch the peer docker containers.

Enroll Peer1
~~~~~~~~~~~~

You will issue the commands below to enroll Peer1. In the commands below,
we will assume the trusted root certificate of Org2 is available at
``~/hyperledger/org2/peer1/assets/ca/org2-ca-cert.pem`` on Peer1's host machine.

.. code:: bash

   export FABRIC_CA_CLIENT_HOME=~/hyperledger/org2/peer1
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org2/peer1/assets/ca/org2-ca-cert.pem
   fabric-ca-client enroll -d -u https://peer1-org2:peer1o2PW@rca-org2.inuit.local:7055

Next, you will get the TLS certificate. In the command below, we will assume the
certificate of the TLS CA has been copied to ``~/hyperledger/org2/peer1/assets/tls-ca/tls-ca-cert.pem``
on Peer1's host machine.

.. code:: bash

   export FABRIC_CA_CLIENT_MSPDIR=tls-msp
   export FABRIC_CA_CLIENT_TLS_CERTFILES=/etc/hyperledger/org2/peer1/assets/tls-ca/tls-ca-cert.pem
   fabric-ca-client enroll -d -u https://peer1-org2:peer1o2PW@ca-tls.inuit.local:7052 --enrollment.profile tls --csr.hosts peer1-org2.inuit.local

Go to path ``~/hyperledger/org2/peer1/tls-msp/keystore`` and change the name of the
key to ``key.pem``.

Enroll Peer2
~~~~~~~~~~~~

You will issue the commands below to get Peer2 enrolled. In the commands below,
we will assume the trusted root certificate of Org2 is available at
``~/hyperledger/org2/peer2/assets/ca/org2-ca-cert.pem`` on Peer2's host machine.

.. code:: bash

   export FABRIC_CA_CLIENT_HOME=~/hyperledger/org2/peer2
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org2/peer2/assets/ca/org2-ca-cert.pem
   fabric-ca-client enroll -d -u https://peer2-org2:peer2o2PW@rca-org2.inuit.local:7055

Next, you will get the TLS certificate. In the command below, we will assume the
certificate of the TLS CA has been copied to ``~/hyperledger/org2/peer2/assets/tls-ca/tls-ca-cert.pem``
on Peer2's host machine.

.. code:: bash

   export FABRIC_CA_CLIENT_MSPDIR=tls-msp
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org2/peer2/assets/tls-ca/tls-ca-cert.pem
   fabric-ca-client enroll -d -u https://peer2-org2:peer2o2PW@ca-tls.inuit.local:7052 --enrollment.profile tls --csr.hosts peer2-org2.inuit.local

Go to path ``~/hyperledger/org2/peer2/tls-msp/keystore`` and change the name
of the key to ``key.pem``.

Enroll Org2's Admin
~~~~~~~~~~~~~~~~~~~~~

At this point, you will have two MSP directories. One MSP contains your enrollment
certificate and the other has your TLS certificate. However, there needs be one
additional folder added in the enrollment MSP directory, and this is the ``admincerts``
folder. This folder will contain certificates for the administrator of org2.
You will enroll the org2 admin's identity by issuing the commands below.

.. code:: bash

   export FABRIC_CA_CLIENT_HOME=~/hyperledger/org2/admin
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org2/peer1/assets/ca/org2-ca-cert.pem
   export FABRIC_CA_CLIENT_MSPDIR=msp
   fabric-ca-client enroll -d -u https://admin-org2:org2AdminPW@0.0.0.0:7055

After enrollment, you should have an admin MSP. You will copy the certifcate from
this MSP and move it to the peer MSP under the ``admincerts`` folder. The commands
below are only for Peer1, the exchange of admin cert to peer2 will happen out-of-band.

.. code:: bash

    mkdir ~/hyperledger/org2/peer1/msp/admincerts
    cp ~/hyperledger/org2/admin/msp/signcerts/cert.pem ~/hyperledger/org2/peer1/msp/admincerts/org2-admin-cert.pem

If the ``admincerts`` folder is missing from the peer's local MSP, the peer will
fail to start up.

Launch Org2's Peers
~~~~~~~~~~~~~~~~~~~~

Once we have enrolled all the peers and admin, we have the necessary MSPs to
start the peers.

peer1-org2 is on host 105 and peer2-org2 is on host 104.
A docker service, such as the one below can be used to a launch a container for
the peer1.

.. code:: yaml

  peer1-org2:
    ... // ...
Copy the peer1 of org2's docker-compose file here and launch the container with couchdb.
Launching the peer service will bring up a peer container, and in the logs you
will see the following line:

.. code:: bash

   serve -> INFO 020 Started peer with ID=[name:"peer1-org2.inuit.local" ], network ID=[dev], address=[peer1-org2.inuit.local:7051] #10051

A docker service, such as the one below can be used to a launch a container for
the peer2.

.. code:: yaml

  peer2-org2:
    
Copy the peer2 of org2's docker-compose file here and launch the container with couchdb.
Launching the peer service will bring up a peer container, and in the logs you
will see the following line:

.. code:: bash

    serve -> INFO 020 Started peer with ID=[name:"peer2-org2.inuit.local" ], network ID=[dev], address=[peer2-org2.inuit.local:7052] #9051

Setup Orderer
---------------

The last thing we need to setup is the orderer. We need to take a couple
of actions before we can start up the orderer.

Enroll Orderer
^^^^^^^^^^^^^^^

Before starting the orderer, you will need to enroll the orderer's identity with a
CA to get the MSP that the orderer will use. This is known as the local orderer
MSP.

If the host machine does not have the fabric-ca-client binary, please refer to
the instructions above on to download the binary.

You will issue the commands below to get the orderer enrolled. In the commands
below, we will assume the trusted root certificates for Org1 is available in
``~/hyperledger/org1/peer1/assets/ca/org1-ca-cert.pem``, and Org2 is available in
``~/hyperledger/org2/peer1/assets/ca/org2-ca-cert.pem`` on the orderer's respective 
host machines. Please refer the topology.

Enroll Ord1 Org1

.. code:: bash

   export FABRIC_CA_CLIENT_HOME=~/hyperledger/org1/ord1
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org1/peer1/assets/ca/org1-ca-cert.pem
   fabric-ca-client enroll -d -u https://ord1-org1:ord1o1pw@rca-org1.inuit.local:7054

Next, you will get the TLS certificate. In the command below, we will assume the
certificate of the TLS CA has been copied to ``~/hyperledger/org1/peer1/assets/tls-ca/tls-ca-cert.pem``
on Orderer's host machine.
TLS for Ord1 Org1

.. code:: bash 

   export FABRIC_CA_CLIENT_MSPDIR=tls-msp
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org1/peer1/assets/tls-ca/tls-ca-cert.pem
   fabric-ca-client enroll -d -u https://ord1-org1:ord1o1PW@ca-tls.inuit.local:7052 --enrollment.profile tls --csr.hosts ord1-org1.inuit.local

Enroll and TLS for Ord2 Org1

..code:: bash

   export FABRIC_CA_CLIENT_HOME=~/hyperledger/org1/ord2
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org1/peer2/assets/ca/org1-ca-cert.pem
   fabric-ca-client enroll -d -u https://ord2-org1:ord1o2pw@rca-org1.inuit.local:7054

   export FABRIC_CA_CLIENT_MSPDIR=tls-msp
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org1/peer2/assets/tls-ca/tls-ca-cert.pem
   fabric-ca-client enroll -d -u https://ord2-org1:ord2o1PW@ca-tls.inuit.local:7052 --enrollment.profile tls --csr.hosts ord2-org1.inuit.local


Go to path ``~/hyperledger/org1/<respective_orderers>/tls-msp/keystore`` and change the name
of the key to ``key.pem``.

At this point, you will have two MSP directories. One MSP contains your enrollment
certificate and the other has your TLS certificate. However, there needs be one
additional folder added in the enrollment MSP directory, this is the ``admincerts``
folder. This folder will contain certificates for the administrator of peer 1.
Now, you will enroll the Org0's admin identity by issuing the commands below.

We will do the same for the second organisation, org2 as follows.

Ord1 Org2

..code:: bash

   export FABRIC_CA_CLIENT_HOME=~/hyperledger/org2/ord1
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org2/peer1/assets/ca/org2-ca-cert.pem
   fabric-ca-client enroll -d -u https://ord1-org2:ord1o2pw@rca-org2.inuit.local:7055

   export FABRIC_CA_CLIENT_MSPDIR=tls-msp
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org2/peer1/assets/tls-ca/tls-ca-cert.pem
   fabric-ca-client enroll -d -u https://ord1-org2:ord1o2PW@ca-tls.inuit.local:7052 --enrollment.profile tls --csr.hosts ord1-org2.inuit.local

Ord2 Org2 
   export FABRIC_CA_CLIENT_HOME=~/hyperledger/org2/ord2
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org2/ord2/assets/ca/org2-ca-cert.pem
   fabric-ca-client enroll -d -u https://ord2-org2:ord2o2pw@rca-org2.inuit.local:7055
   
   export FABRIC_CA_CLIENT_MSPDIR=tls-msp
   export FABRIC_CA_CLIENT_TLS_CERTFILES=~/hyperledger/org1/peer1/assets/tls-ca/tls-ca-cert.pem
   fabric-ca-client enroll -d -u https://ord2-org2:ord2o2PW@ca-tls.inuit.local:7052 --enrollment.profile tls --csr.hosts ord2-org2.inuit.local


Create Genesis Block and Channel Transaction
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The orderer requires a genesis block that it uses to bootstrap itself.
You can find more information in the `Hyperledger Fabric documentation <https://hyperledger-fabric.readthedocs.io/en/release-1.4/configtx.html?channel-configuration-configtx>`_

In documentation below, you'll find a snippet of ``configtx.yaml``. Please copy ``configtx.yaml``, as a whole 
document not in parts.

On the orderer's host machine, we need to collect the MSPs for all the
organizations. The ``organization`` section in the ``configtx.yaml`` looks like:

.. code:: yaml

   Organizations:

   - &Org1
        # DefaultOrg defines the organization which is used in the sampleconfig
        # of the fabric.git development environment
      Name: org1MSP

        # ID to load the MSP definition as
      ID: org1MSP

      MSPDir: /etc/hyperledger/org1/msp

        # Policies defines the set of policies at this level of the config tree
        # For organization policies, their canonical path is usually
        #   /Channel/<Application|Orderer>/<OrgName>/<PolicyName>
      Policies:
         Readers:
            Type: Signature
            Rule: "OR('org1MSP.member', 'org1MSP.admin', 'org1MSP.peer', 'org1MSP.client')"
         Writers:
            Type: Signature
            Rule: "OR('org1MSP.member', 'org1MSP.admin', 'org1MSP.client')"
         Admins:
            Type: Signature
            Rule: "OR('org1MSP.admin')"

        # leave this flag set to true.
      AnchorPeers:
            # AnchorPeers defines the location of peers which can be used
            # for cross org gossip communication.  Note, this value is only
            # encoded in the genesis block in the Application section context
         - Host: peer1-org1.inuit.local
           Port: 7051

   - &Org2
        # DefaultOrg defines the organization which is used in the sampleconfig
        # of the fabric.git development environment
      Name: org2MSP

        # ID to load the MSP definition as
      ID: org2MSP

      MSPDir: /etc/hyperledger/org2/msp

        # Policies defines the set of policies at this level of the config tree
        # For organization policies, their canonical path is usually
        #   /Channel/<Application|Orderer>/<OrgName>/<PolicyName>
      Policies:
         Readers:
            Type: Signature
            Rule: "OR('org2MSP.member', 'org2MSP.admin', 'org2MSP.peer', 'org2MSP.client')"
         Writers:
            Type: Signature
            Rule: "OR('org2MSP.member', 'org2MSP.admin', 'org2MSP.client')"
         Admins:
            Type: Signature
            Rule: "OR('org2MSP.admin')"

      AnchorPeers:
            # AnchorPeers defines the location of peers which can be used
            # for cross org gossip communication.  Note, this value is only
            # encoded in the genesis block in the Application section context
         - Host: peer1-org2.inuit.local
           Port: 10051


The MSP for Org1 will contain the trusted root certificate of Org1,
the certificate of the Org1's admin identity, and the trusted root certificate of
the TLS CA. The MSP folder structure can be seen below. This structure is in containers.

.. code:: text

   /etc/hyperledger/org1/msp
   ├── admincerts
   │   └── admin-org1-cert.pem
   ├── cacerts
   │   └── org1-ca-cert.pem
   ├── tlscacerts
   │   └── tls-ca-cert.pem
   ├── users
   |
   └── config.yaml

The pattern is the same for all organization. The MSP folder structure for
Org2 would like:

.. code:: text

   /etc/hyperledger/org2/msp
   ├── admincerts
   │   └── admin-org2-cert.pem
   ├── cacerts
   │   └── org2-ca-cert.pem
   ├── tlscacerts
   │   └── tls-ca-cert.pem
   ├── users
   |
   └── config.yaml


Once all these MSPs are present on the orderer's host machine you will execute the
following commands from the directory in which ``configtx.yaml`` is present:

.. code:: bash

   ./configtxgen -profile SampleMultiNodeEtcdRaft -channelID orderersyschannel -outputBlock genesis.block
   ./configtxgen -profile TwoOrgsChannel -outputCreateChannelTx twoorgschannel.tx -channelID twoorgschannel

This will generate two artifacts, ``genesis.block`` and ``twoorgschannel.tx``, which will
be used in later steps.

# Commands for gathering certificates
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 
# The Fabric CA client has a couple commands that are useful in acquiring the certificates
# for the orderer genesis and peer MSP setup.
# 
# The first command is the `fabric-ca-client certificate` command. This command can be used
# to get certificates for the admincers folder. For more information on how to use this command
# , please refer to: `listing certificate information <https://hyperledger-fabric-ca.readthedocs.io/en/latest/users-guide.html#listing-certificate-information>`__
# 
# The second command is the `fabric-ca-client getcainfo` command. This command can be used to gather
# certificates for the `cacerts` and `tlscacerts` folders. The `getcainfo` command returns back the
# certificate of the CA.
# 
# Mutual TLS
# ^^^^^^^^^^^^
# 
# Endpoints can be secured using Mutual TLS as well. If the CA, Peer, or Orderer are using mutual
# TLS then the client must also present a TLS certificate that will be verified by the server.
# 
# Mutual TLS requires the client to acquire a TLS certificate that it will present to the server.
# Acquiring a TLS certificate can be done via a TLS certificate authority that does have mutual TLS enabled.
# Once the client has aquired a TLS certificate, then it can start communication with mutual TLS enabled servers aslong as the trusted TLS authority on the server is the same as issuing authority for the client's TLS certificate.

Launch Orderer
^^^^^^^^^^^^^^^

Once you have created the genesis block and the channel transaction, you can
define an orderer service that points to the genesis.block created above.

Please launch the orderers on appropriate hosts from the docker-compose files.
  

Launching the orderer service will bring up an orderer container, and in the logs
you will see the following line:

.. code:: bash

   UTC [orderer/common/server] Start -> INFO 0b8 Beginning to serve requests

Create CLI Containers
----------------------

Communication with peers requires a CLI container, the container contains the appropriate
binaries that will allow you to issue peer related commands. You will create
a CLI container for each org. In this example, we launch a CLI container
in the same host machine as Peer1 for each org.

Launch Org1's CLI
^^^^^^^^^^^^^^^^^^

Launch the CLI containers on the hosts as described in the topology. Docker-compose files are available.

Launch Org2's CLI
^^^^^^^^^^^^^^^^^^

Do the same as CLI for org1.

Create and Join Channel
------------------------

Org1
^^^^^

With the CLI containers up and running, you can now issue commands to create and
join a channel. We are going to use Peer1 to create the channel. In the
host machine of Peer1, you will execute:

.. code:: bash

   docker exec -it cli-org1.inuit.local sh # or bash

This command will bring you inside the CLI container and open up a terminal. From
here, you will execute the following commands using the admin MSP:

.. code:: bash

   export CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/org1/admin/msp
   peer channel create -c twoorgschannel -f /etc/hyperledger/org1/peer1/assets/twoorgschannel.tx -o ord1-org1.inuit.local:7050 --outputBlock /etc/hyperledger/org1/peer1/assets/twoorgschannel.block --tls --cafile /etc/hyperledger/org1/peer1/tls-msp/tlscacerts/tls-ca-tls-inuit-local-7052.pem

The ``twoorgschannel.tx`` is an artifact that was generated by running the
``configtxgen`` command on the orderer. This artifact needs to be transferred
to Peer1's host machine out-of-band from the orderer. The command above will generate
``twoorgschannel.block`` on Peer1 at the specified output path ``/etc/hyperledger/org1/peer1/assets/twoorgschannel.block``,
which will be used by all peers in the network that wish
to join the channel. This ``twoorgschannel.block`` will be need to transferred to all peers
in both Org1 and Org2 out-of-band.

The next commands you are going to run is to have Peer1 and Peer2 in join
the channel.

.. code:: bash

   export CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/org1/admin/msp
   export CORE_PEER_ADDRESS=peer1-org1.inuit.local:7051
   peer channel join -b /etc/hyperledger/org1/peer1/assets/twoorgschannel.block

   export CORE_PEER_ADDRESS=peer2-org1.inuit.local:8051
   peer channel join -b /etc/hyperledger/org1/peer1/assets/twoorgschannel.block

Org2
^^^^^

Run the following command to enter the CLI docker container.

.. code:: bash

   docker exec -it cli-org2.inuit.local bash

In Org2, you only need to have the peers join the channel. Peers in Org2 do not
need to create the channel, this was already done by Org1. From inside the Org2
CLI container, you will execute the following commands using the admin MSP:

.. code:: bash

   export CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/org2/admin/msp
   export CORE_PEER_ADDRESS=peer1-org2.inuit.local:7051 # cli and this peer on same host local host network
   # so 7051 not 10051
   peer channel join -b /etc/hyperledger/org2/peer1/assets/twoorgschannel.block

   export CORE_PEER_ADDRESS=peer2-org2.inuit.local:9051
   peer channel join -b /etc/hyperledger/org2/peer1/assets/twoorgschannel.block


Install and Instantiate Chaincode
----------------------------------

Download this `chaincode <https://github.com/hyperledger/fabric-samples/tree/master/chaincode/abac/go>`_
from Github to the local file system on Peer1 in both orgs.

Org1
^^^^^

On Peer1, you are going to install chaincode. The command assumes that the
chaincode that needs to be installed is available inside the GOPATH. In this
example we will assume the chaincode is located at
``/opt/gopath/src/github.com/hyperledger/fabric-samples/chaincode/abac/go`` with the
GOPATH being ``/opt/gopath``. From Org1's CLI container, you will
execute the following command:

.. code:: bash

   export CORE_PEER_ADDRESS=peer1-org1.inuit.local:7051
   export CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/org1/admin/msp
   peer chaincode install -n mycc -v 1.0 -p github.com/hyperledger/fabric-samples/chaincode/abac/go

The same set of steps will be followed for peer2.

.. code:: bash

   export CORE_PEER_ADDRESS=peer2-org1.inuit.local:8051
   export CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/org1/admin/msp
   peer chaincode install -n mycc -v 1.0 -p github.com/hyperledger/fabric-samples/chaincode/abac/go

Org2
^^^^^

On Peer1, you are going to perform the same steps as Org1. The command
assumes that the chaincode that needs to be installed is available at
``/opt/gopath/src/github.com/hyperledger/org2/peer1/assets/chaincode/abac/go``.
From Org2's CLI container, you will execute the following command:

.. code:: bash

   export CORE_PEER_ADDRESS=peer1-org2.inuit.local:7051
   export CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/org2/admin/msp
   peer chaincode install -n mycc -v 1.0 -p github.com/hyperledger/fabric-samples/chaincode/abac/go

The same set of steps will be followed for peer2.

.. code:: bash

   export CORE_PEER_ADDRESS=peer2-org2.inuit.local:9051
   export CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/org2/admin/msp
   peer chaincode install -n mycc -v 1.0 -p github.com/hyperledger/fabric-samples/chaincode/abac/go

The next step is going to be to instantiate the chaincode. This is done once per channel.
This done by executing:

.. code:: bash

   peer chaincode instantiate -C twoorgschannel -n mycc -v 1.0 -c '{"Args":["init","a","100","b","200"]}' -o ord1-org1.inuit.local:7050 --tls --cafile /etc/hyperledger/org1/peer1/tls-msp/tlscacerts/tls-ca-tls-inuit-local-7052.pem

Invoke and Query Chaincode
----------------------------------

From Org1's CLI container, execute:

.. code:: bash

   export CORE_PEER_ADDRESS=peer1-org1.inuit.local:7051
   export CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/org1/admin/msp
   peer chaincode query -C twoorgschannel -n mycc -c '{"Args":["query","a"]}'

This should return a value of ``100``.

From Org2's CLI container, execute:

.. code:: bash

   export CORE_PEER_ADDRESS=peer1-org2.inuit.local:7051
   export CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/org2/admin/msp
   peer chaincode invoke -C twoorgschannel -n mycc -c '{"Args":["invoke","a","b","10"]}' --tls --cafile /etc/hyperledger/org2/peer1/tls-msp/tlscacerts/tls-ca-tls-inuit-local-7052.pem


This is going to subtract 10 from value of ``a`` and move it to ``b``. Now, if
you query by running:

.. code:: bash

   peer chaincode query -C mychannel -n mycc -c '{"Args":["query","a"]}'

This should return a value of ``90``.

This concludes the Setup and Operations Guide for Fabric network including Fabric CA with RAFT and couchdb on multi hosts.
