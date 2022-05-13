#!/bin/bash

. ./utils.sh
. ./global.sh
. ./fabric-var.sh


function enrollRegisterarAdmin(){

mkdir -p $CA_CRYPTO_PATH/ca-admin
infoln "Enrollment URL for registerar admin https://${REGISTERAR_NAME}:${ENROLLMENT_SECRET}@${caAddress}"
set -x
fabric-ca-client enroll -u https://${REGISTERAR_NAME}:${ENROLLMENT_SECRET}@${caAddress}
set +x
if [ $? -ne 0 ]; then 
 errorln "Error while  performing admin enrollment "
 exit 1
fi 
infoln "Enrollment of registerar admin completed..."

}

function enrollRegisterarAdminTLS() {

mkdir -p $CA_CRYPTO_PATH/ca-admin/tls
set -x
fabric-ca-client enroll -u https://admin:${ENROLLMENT_SECRET}@${caAddress} --csr.hosts "admin" --enrollment.profile tls

res=$?
set +x
if [ $res -ne 0 ]; then 
   errorln " Error while Enrolling reg admin's TLS profile "
   exit 1
fi

infoln " Reg admin TLS is Enrolled successfully .......... "

}

function registerOrgAdmin(){

set -x 
fabric-ca-client register --id.name Admin --id.secret ${ENROLLMENT_SECRET} --id.type admin \
--id.attrs "hf.Registrar.Roles=*,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert" \
-u https://${caAddress}

res=$?
set +x
if [ $res -ne 0 ]; then 
   errorln " Error while registering Org Admin  "
   exit 1
fi

infoln " Org Admin is registered successfully .......... "

}


function enrollOrgAdmin() {

mkdir -p $CRYPTO_PATH/users/Admin@${orgName}/msp/{admincerts,cacerts,keystore,signcerts}
export FABRIC_CA_CLIENT_HOME=$CRYPTO_PATH/users/Admin@${orgName}
export FABRIC_CA_CLIENT_MSPDIR=$CRYPTO_PATH/users/Admin@${orgName}/msp
set -x
fabric-ca-client enroll -u https://Admin:${ENROLLMENT_SECRET}@${caAddress} 

res=$?
set +x
if [ $res -ne 0 ]; then 
   errorln " Error while Enrolling Org Admin admin.${orgName} "
   exit 1
fi

infoln " Org Admin is Enrolled .......... TLS enrollment pending "

}

function enrollOrgAdminTLS() {

mkdir -p $CRYPTO_PATH/users/Admin@${orgName}/tls/{admincerts,cacerts,keystore,signcerts}
export FABRIC_CA_CLIENT_HOME=$CRYPTO_PATH/users/Admin@${orgName}
export FABRIC_CA_CLIENT_MSPDIR=$CRYPTO_PATH/users/Admin@${orgName}/tls
set -x
fabric-ca-client enroll -u https://Admin:${ENROLLMENT_SECRET}@${caAddress} --csr.hosts "Admin" --enrollment.profile tls

res=$?
set +x
if [ $res -ne 0 ]; then 
   errorln " Error while Enrolling Org Admin admin.${orgName}'s TLS profile "
   exit 1
fi

infoln " Org Admin is Enrolled successfully .......... "

}


function registerPeerIdentity(){

local peerNum=peer$1
local peerID=${peerNum}.${orgName}.${domainName}
local caAddress=$2
set -x 
fabric-ca-client register --id.name ${peerID} --id.secret ${ENROLLMENT_SECRET} --id.type peer \
--id.affiliation org1.department1 -u https://${caAddress}

res=$?
set +x
if [ $res -ne 0 ]; then 
   errorln " Error while registering peer ${peerID} "
   exit 1
fi

infoln " peer ${peerID} is registered successfully .......... "

}

function enrollPeer(){

local peerNum=peer$1
local peerID=${peerNum}.${orgName}.${domainName}
local caAddress=$2

mkdir -p $CRYPTO_PATH/peers/${peerID}/msp/{admincerts,cacerts,keystore,signcerts}
export FABRIC_CA_CLIENT_HOME=$CRYPTO_PATH/peers/${peerID}
export FABRIC_CA_CLIENT_MSPDIR=$CRYPTO_PATH/peers/${peerID}/msp
set -x
fabric-ca-client enroll -u https://${peerID}:${ENROLLMENT_SECRET}@${caAddress} 

res=$?
set +x
if [ $res -ne 0 ]; then 
   errorln " Error while Enrolling peer identity ${peerID} "
   exit 1
fi
cp $CRYPTO_PATH/users/Admin@${orgName}/msp/signcerts/*  $CRYPTO_PATH/peers/${peerID}/msp/admincerts/

infoln " Peer identity ${peerID} is Enrolled .......... TLS enrollment pending "

}


function enrollPeerTLS(){

local peerNum=peer$1
local peerID=${peerNum}.${orgName}.${domainName}
local caAddress=$2

mkdir -p $CRYPTO_PATH/peers/${peerID}/tls/{admincerts,cacerts,keystore,signcerts}
export FABRIC_CA_CLIENT_HOME=$CRYPTO_PATH/peers/${peerID}
export FABRIC_CA_CLIENT_MSPDIR=$CRYPTO_PATH/peers/${peerID}/tls
set -x
fabric-ca-client enroll -u https://${peerID}:${ENROLLMENT_SECRET}@${caAddress} --csr.hosts "peer.${orgName},${peerID}" --enrollment.profile tls

res=$?
set +x
if [ $res -ne 0 ]; then 
   errorln " Error while Enrolling peer identity ${peerID} "
   exit 1
fi
mkdir -p $CRYPTO_PATH/peers/${peerID}/tls/server
cp $CRYPTO_PATH/peers/${peerID}/tls/signcerts/* $CRYPTO_PATH/peers/${peerID}/tls/server/cert.pem
cp $CRYPTO_PATH/peers/${peerID}/tls/keystore/*  $CRYPTO_PATH/peers/${peerID}/tls/server/key.pem
cp $CRYPTO_PATH/peers/${peerID}/tls/tlscacerts/*   $CRYPTO_PATH/peers/${peerID}/tls/server/ca.pem

infoln " Peer identity ${peerID} is Enrolled ..........  "

}

function registerOrdererIdentity(){

local ordererNum=orderer$1
local ordererID=${ordererNum}.${orgName}.${domainName}
local caAddress=$2
set -x 
fabric-ca-client register --id.name ${ordererID} --id.secret ${ENROLLMENT_SECRET} --id.type orderer \
--id.affiliation org1.department1 -u https://${caAddress}

res=$?
set +x
if [ $res -ne 0 ]; then 
   errorln " Error while registering orderer ${ordererID} "
   exit 1
fi

infoln " orderer ${ordererID} is registered successfully with TLS profile.......... "

}

function enrollOrderer(){

local ordererNum=orderer$1
local ordererID=${ordererNum}.${orgName}.${domainName}
local caAddress=$2

mkdir -p $CRYPTO_PATH/orderers/${ordererID}/msp/{admincerts,cacerts,keystore,signcerts}
export FABRIC_CA_CLIENT_HOME=$CRYPTO_PATH/orderers/${ordererID}
export FABRIC_CA_CLIENT_MSPDIR=$CRYPTO_PATH/orderers/${ordererID}/msp
set -x
fabric-ca-client enroll -u https://${ordererID}:${ENROLLMENT_SECRET}@${caAddress} 

res=$?
set +x
if [ $res -ne 0 ]; then 
   errorln " Error while Enrolling orderer identity ${ordererID} "
   exit 1
fi

cp $CRYPTO_PATH/users/Admin@${orgName}/msp/signcerts/*  $CRYPTO_PATH/orderers/${ordererID}/msp/admincerts/

infoln " Orderer identity ${ordererID} is Enrolled .......... TLS enrollment pending "

}

function enrollOrdererTLS(){

local ordererNum=orderer$1
local ordererID=${ordererNum}.${orgName}.${domainName}
local caAddress=$2

mkdir -p $CRYPTO_PATH/orderers/${ordererID}/tls/{admincerts,cacerts,keystore,signcerts}
export FABRIC_CA_CLIENT_HOME=$CRYPTO_PATH/orderers/${ordererID}
export FABRIC_CA_CLIENT_MSPDIR=$CRYPTO_PATH/orderers/${ordererID}/tls
set -x
fabric-ca-client enroll -u https://${ordererID}:${ENROLLMENT_SECRET}@${caAddress} --csr.hosts "orderer.${orgName},${ordererID}" --enrollment.profile tls

res=$?
set +x
if [ $res -ne 0 ]; then 
   errorln " Error while Enrolling orderer identity ${ordererID} "
   exit 1
fi

infoln " Orderer identity ${ordererID} is Enrolled with TLS profile..........  "

}


caAddress=${FABRIC_CA_ADDRESS}

export FABRIC_CA_CLIENT_HOME=$CA_CRYPTO_PATH/ca-admin
export FABRIC_CA_CLIENT_MSPDIR=$CA_CRYPTO_PATH/ca-admin/msp
export FABRIC_CA_CLIENT_TLS_CERTFILES=${fabricCACert}
sleep 2
enrollRegisterarAdmin
export FABRIC_CA_CLIENT_MSPDIR=$CA_CRYPTO_PATH/ca-admin/tls
sleep 5
enrollRegisterarAdminTLS
export FABRIC_CA_CLIENT_MSPDIR=$CA_CRYPTO_PATH/ca-admin/msp
sleep 15
registerOrgAdmin

#Register all peer nodes
for ((i=0;i<${peerCount};i++));
do
registerPeerIdentity $i $caAddress
sleep 2

done

#Register all orderer nodes
for ((i=0;i<${ordererCount};i++));
do
registerOrdererIdentity $i $caAddress
sleep 2

done

enrollOrgAdmin
sleep 2

enrollOrgAdminTLS

#Enroll all peer nodes
for ((i=0;i<${peerCount};i++));
do
sleep 2
enrollPeer $i $caAddress
done

#Enroll all peer nodes TLS
for ((i=0;i<${peerCount};i++));
do
sleep 2
enrollPeerTLS $i $caAddress
done

#Enroll all orderer nodes
for ((i=0;i<${ordererCount};i++));
do
enrollOrderer $i $caAddress
done

# Enroll all orderer nodes TLS
for ((i=0;i<${ordererCount};i++));
do
enrollOrdererTLS $i $caAddress
done


createOrgMSPDirForConfigTX
createOrgAdminSDKDir