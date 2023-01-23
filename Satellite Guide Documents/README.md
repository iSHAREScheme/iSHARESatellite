
![](Images/isharelogo.png)

APRIL 12, 2022

iSHARE FOUNDATION



iSHARE SATELLITE DEPLOYMENT GUIDE - Updated Version

VM-Docker based model

# **Table of Contents**
[***1. &nbsp; &nbsp; Pre-requisites***](#pre-req)

[***2. &nbsp; &nbsp; Hardware Requirements***](#hardware-req)

[***2.1. &nbsp; &nbsp; Minimum***](#minimum)

[***2.2. &nbsp; &nbsp;Recommendation***](#recommendation)

[***3 &nbsp; &nbsp; Network Requirements***](#network-req)

[***4. &nbsp; &nbsp; Getting Started***](#get_start)

[***4.1. &nbsp; &nbsp; Configure Passwords for the services***](#configure)

[***4.2. &nbsp; &nbsp; Installing Hyperledger Fabric Node***](#install_hyp)

[***4.3.&nbsp; &nbsp; Register your node***](#reg_node)

[***4.4. &nbsp; &nbsp; Join the network***](#join_net)

[***4.5. &nbsp; &nbsp; Deploy the UI and middleware applications***](#deploy)

[***5. &nbsp; &nbsp; Initial user setup***](#U_setup)


[***6. &nbsp; &nbsp; Configure keycloak***](#configure_keycloak)


[***7.. &nbsp; &nbsp; Set up email notifications***](#email)

[***8. &nbsp; &nbsp; Enable 2FA for users***](#2FA)

[***9. &nbsp; &nbsp; Commands for managing Docker services***](#docker_service)

[***10. &nbsp; &nbsp; Reference updates deployment procedure***](#ref_update)

<br> <br> <br>

# <a id="pre-requisites">  1. &nbsp; Pre-requisites </a>
The proposed model requires virtual machines provisioned on cloud providers and/or on-prem with prescribed operating systems and following software's installed in them. Make sure that you have then before beginning 

*Note: the scripts and components are tested in versions mentioned in the brackets, usually it should work well in higher version as well.*

1. Ubuntu Linux (20.04.4 LTS (Focal Fossa))
1. Docker (v20.10.14)
1. Docker-compose (version 1.24.0)
1. Create/Update rights to your DNS service to manage satellite URLs in DNS
1. SSL certificates of your domain for applications (applications by default use HTTPS so having certificates on hand is required. You may also use free Letsencrypt certificates, please refer to its website on how to get them)
1. JWT signing certificate – 
   1. For Production environments – Qualified Seals as defined in iSHARE specifications
   1. For Test environments – test certificates obtained from <https://ca7.isharetest.net:8442/ejbca/ra/>

(Use postpone option when requesting certificate. You will get email with link to download the certificate file, once your request is approved.)

<br><br><br>

# <a id="hardware-req"> 2. &nbsp; Hardware Requirements </a>   
# <a id="minimum"> 2.1. &nbsp; Minimum </a> 
Virtual Machine with 2 CPU’s and 8 GB Memory.
# <a id="recommendation"> 2.2 &nbsp; Recommendation </a>
Virtual Machine with 4 CPU’s and 16 GB Memory.

<br>

# <a id="network-req"> 3. &nbsp; Network Requirements </a>
Following ports are used by following applications, so make sure that you configure your firewall and network settings to allow access via these ports

- 443/TCP,80/TCP for Application middleware and UI. </span>
- 7051/TCP and 8051/TCP for HLF Peers. </span>
- 8443/TCP for keyCloak instance (user management backend) 
- Optionally, 8081/TCP for explorer instance (hyperledger explorer) – open to outside only if require access from outside your own network, maybe necessary when hosted on cloud.

<br>

# <a id="get_start"> 4. &nbsp; Getting Started </a> 

iSHARE satellite is based on Hyperledger fabric where participants registered via satellite are directly registered on the shared ledger and participant is trusted across the network. The iSHARE satellite is composed of following sub-components:

- Hyperledger fabric node,
- Application UI,
- Keycloak (user managment backend),
- Satellite Middleware (APIs and other relevant functions).

<br>
To install iSHARE satellite and configure it to run follow the steps:

1. Download and prepare your scripts/passwords,
1. Install Hyperledger fabric node,
1. Register your node,
1. Join the network,
1. Deploy the UI and middleware applications,
   1. Deploy keycloak,
   1. Deploy middleware,
   1. Deploy UI,
1. Setup and configure satellite access control – satellite admin user setup and login to UI. 

<br> <br>

 # <a id="configure"> 4.1. &nbsp; Configure Passwords for the Services </a>

Download the scripts from GitHub
```
git clone [https://github.com/iSHAREScheme/iSHARESatellite.git](https://github.com/iSHAREScheme/VM-Model-iSHARE-Satellites.git)</p><p>cd iSHARESatellite
```


If you want to change the default passwords (recommended and mandatory for production environments) please follow these steps, else skip this chapter.

Following are the services which uses username and password as credentials for authentication:

- Postgres DB for Application
- Explorer DB for Explorer
- Postgres DB for Keycloak

<br>

<h3 align="center"> Steps to configure password for changing HLF Explorer’s DB:</h3>

<br>

```
cd iSHARESatellite/templates
```

 Open explorer-docker-compose-template.yaml in the text editor. <br>
Under *services* section, change the password for explorerdb by referring below snippet under environment: <br> <br>

```
explorerdb:
    image: hyperledger/explorer-db:latest
    container\_name: explorerdb
    hostname: explorerdb
    environment:
      - DATABASE\_DATABASE=fabricexplorer <br>
      - DATABASE\_USERNAME=hppoc <br>
      - DATABASE\_PASSWORD=password
```
<br>

Same Password has be configured for explorer service under environment, refer below snippet:

<br>

```
explorer:
    image: hyperledger/explorer:latest
    container\_name: explorer 
    hostname: explorer 
    environment: 
      - DATABASE\_HOST=explorerdb
      - DATABASE\_DATABASE=fabricexplorer
      - DATABASE\_USERNAME=hppoc
      - DATABASE\_PASSWD=password
```
<br>

Open app-mw-config-template.yaml in the text editor, configure password in explorer db connection string. Check below:

<br>

```
explorerDb: postgresql://hppoc:password@explorerdb:5432/fabricexplorer?sslmode=disable
```

<br> <br>

<h3 align="center">Steps to configure password for Application middleware postgres DB</h3>

<br>

```
 cd iSHARESatellite/templates
```

<br>

Open docker-compose-mw-template.yaml in a text editor and look for below snippet : <br>

```
app-postgres:
  image: postgres:9
  restart: always
  environment:
    POSTGRES\_USER: admin 
    POSTGRES\_PASSWORD: adminpw
```

Change password for admin user under environment section and save. <br> <br> 



Open hlf-mw-config-template.yaml file in a text editor and look for the below snippet and lower end of the file:

```
ishareConfig: 
    middlewareConfig:
    postgres\_connection\_url: postgresql://admin:adminpw@app-postgres:5432/ishare?sslmode=disable
```

Change the password adminpw in connection string with password configured in docker-compose-mw.yaml. <br> <br> <br>

Open app-mw-config-template.yaml file in a text editor and look for the below snippet: <br>

```
ishareConfig:
    middlewareConfig: <br>
     postgres\_connection\_url: postgresql://admin:adminpw@app-postgres:5432/ishare?sslmode=disable
``` 

Change the password **adminpw** in connection string with password configured in docker-compose-mw.yaml. <br> <br> <br>


<h3 align="center"> Steps to configure password for Application Keycloak service </h3>

<br> 

``` 
cd iSHARESatellite/keycloak/postgres
```

<br>

Open init-db.sql in a text editor: <br>

```
CREATE USER keycloak WITH ENCRYPTED PASSWORD 'keycloak';
```

Change password from **keycloak** to desired password. Password should be under single quotes. <br> <br>

```
cd iSHARESatellite/keycloak
```

<br>

Open keycloak-docker-compose.yaml in a text editor,look for below snippet

```
keycloak:
    image: jboss/keycloak:11.0.2
    container\_name: keycloak
    ports:
      - 8443:8443
environment:
      - KEYCLOAK\_USER=admin
      - KEYCLOAK\_PASSWORD=admin
      - DB\_VENDOR=postgres
      - DB\_ADDR=keycloakpostgres
      - DB\_DATABASE=keycloak
      - DB\_USER=keycloak
      - DB\_PASSWORD=keycloak
```
Change **DB\_PASSWORD** value keycloak with desired password value.  

<br> <br>



# <a id="install_hyp"> 4.2. &nbsp; Installing Hyperledger Fabric node </a>

<br>

Hyperledger Fabric

The fabric component for each satellite will contain :

1. &nbsp; 2 Peers
1. &nbsp; Shared Orderer
1. &nbsp; 2 CouchDB
1. &nbsp; 1 Fabric CA

These components have to be pulled as images ,installed and initialized as per the directions mentioned here.

<br>

<h3 align="center"> Steps and sequence for creating HLF components: </h3>

<br>

Download the scripts from GitHub (if not done so already)

```
git clone https://github.com/iSHAREScheme/iSHARESatellite.git

cd iSHARESatellite 
```

<br>

To install and ensure all the necessary packages are available in the system, use the below script to verify (reboot the system on completion, if necessary).

<br>

```
bash prerequsites.sh
```

<br>

```
cd iSHARESatellite/scripts 
```

<br>

Configure environment variables to initialize scripts. See env variables with example below:

| Environment | Description | 
| ----------- | ----------- |
|   ORG_NAME  | Satellite which is going to be a part of HLF network. It should be a word  without special characters (only alphanumeric) and max 17 characters. ex: mysatellite. |
|  SUB_DOMAIN | Sub-domain reserved in DNS service for this satellite. No special characters. ex: uat.mydomain.com|
| ENVIRONMENT | Name of the infra environment like uat, test, prod. No special characters. |


<br>

```
export ORG\_NAME=newsatellite
export SUB\_DOMAIN=test.example.com 
export ENVIRONMENT=test
```

<br>

To generate HLF fabric ca certs, use the below command :

```
bash fabric-ca-cert.sh 
```

<br>

Creating HLF Fabric CA instance:

```
bash fabric-ca.sh
```
Wait more than a minute after running the above command. Certificates are being generated. Running the next "bash" command too early will cause an error. 

<br>

*Validation*

Navigate to *iSHARESatellite / hlf /\<Environment\>/\<orgName\>/ fabric-ca* directory. <br>
Check the presence of the docker\_data folder. <br>
To ensure all the HLF Fabric is running, use below commands and check the status.

```
docker-compose -f iSHARESatellite/hlf/\<Environment\>/\<orgName\>/fabric-ca/docker-compose-fabric-ca.yaml ps
```

<br>

Register and Enroll users and peers

```
bash registerAndEnroll.sh
```

<br> 

Create HLF Peer instances, it will spun up instances of  HLF Peers and CouchDB 

```
bash peer.sh
```

<br>

*Validation*

Navigate to *iSHARESatellite / hlf /\<Environment\>/\<orgName\>/ peers* directory.

Check the presence of the docker\_data folder. <br>
To ensure all the HLF Peer is running, use below commands to check the status. 

```
docker-compose -f iSHARESatellite/hlf/\<Environment\>/\<orgName\>/peers/docker-compose-hlf.yaml ps
```

<br>

HLF Peer instances needs to be a part of  iSHARE Foundation HLF network, for that HLF peers needs to reachable over the internet. Previous script peer.sh creates two HLF peer instance with hostname peer\<num\>.\<ORG\_NAME\>.\<SUB\_DOMAIN\> and they listen at port 7051 and 8051 TCP. Make sure that necessary firewall settings are updated to allow access to these peers over internet. Map dns entries for Peers hostname with server IP address ex:

If  **ORG\_NAME=newsatellite** and **SUB\_DOMAIN=test.example.com**, then

**peer0.\<orgname\>.\<subdomain\>  - peer0.newsatellite.test.example.com**, and 

**peer1.\<orgname\>.\<subdomain\>  - peer1.newsatellite.test.example.com**

<br>

|Full Record Name|Record Type|Value|TTL|
|----------------|-----------|-----|---|
|peer0.\<orgname\>.\<subdomain\>|A|12.9.7.6.5|1 min|
|peer1.\<orgname>.\<subdomain>|A|12.9.7.6.5|1 min|

<br>

The Hyperledger fabric node is deployed. Now follow the next chapter to register your node in the network.

<br> <br>

# 4.3. &nbsp; <a id="reg_node"> Register your node </a>  
<br> 

Share details with iSHARE foundation to register your node on iSHARE network
Now generate the organization definition file which iSHARE Foundation (HLF Channel Admin) would require inorder to onboard your new satellite. Use the below command to create an org definition.

```
bash orgDefinition.sh
```

<br>

Find the \<orgName\>.json at *hlf /\<ENVIRONMENT\>/\<ORG\_NAME\>* folder. <br>
Note: <orgName>.json file has to be shared securely, as it contains x509 certificates of the new satellite. <br>
Send this file as well as following details to iSHARE foundation.

<br><br>


# 4.4. &nbsp; <a id="join_net"> Join the network </a>

<br>

Join the network with information received from iSHARE Foundation. You should receive following information and files from iSHARE Foundation:

**Files: copy these files in the VM** 

- CA cert file of HLF ordering service (ca-ishareord.pem)
- Genesis.block file 
- Channel.tx file (isharechannel.tx)

Note: you need to copy Genesis.block and channel .tx file to the same folder which contains the iSHARESatellite folder

**Values for following variables**

- ORDERER\_ADDRESS - one of the ordering services hostname and port
- CHANNEL\_NAME - channel name in which a particular satellite is on boarded
- CHAINCODE\_NAME - chaincode (smart contract) which is defined in chaincode definition committed
- CHAINCODE\_VERSION -  chaincode version defined in chaincode definition committed
- CHAINCODE\_SEQUENCE - sequence number associated with chaincode 
- CHAINCODE\_POLICY - chaincode policy string used while commiting chaincode definition in the HLF network
- PARTY_ID - EORI identifier that iSHARE has used to register you in the network.
- PARTY_NAME - Name used by iSHARE to register you in the network.  

Once the above details is known, move the copy of the "ca-ishareord.pem" file in the VM and follow below steps. <br>
Export these environment variables:.

| Environment Variables | Description |
|-----------------------|-------------|
|ORG_NAME|Satellite which is going to be a part of HLF network. ex:mysatellite. You already set this value in chapter 4.2, make sure to use the same value here.|
|SUB_DOMAIN|Sub-domain reserved in DNS service for this satellite.ex: uat.mydomain.com. You already set this value in chapter 4.2, make sure to use the same value here.|
|PEER_COUNT|Number of HLF Peer nodes in a satellite. Default = 2.| 
|ENVIRONMENT|Name of the infra environment like uat, test, prod. You already set this value in chapter 4.2, make sure to use the same value here.|
|ORDERER_TLS_CA_CERT|Path to CA cert file (ca-ishareord.pem) of ordering service which you received from iSHARE Foundation and copied to your VM|
|ORDERER_ADDRESS|Ordering service hostname with port ex: orderer1.example.aks.io:443|
|CHANNEL_NAME|Name of the channel in which new satellite is onboarded.|
|ANCHOR_PEER_HOSTNAME|HLF peer node hostname of a new satellite. ex: peer0.example.com. The peer name from chapter 4.2|
|ANCHOR_PEER_PORT_NUMBER|HLF peer node listening port ex: 7051, corresponding port of the peer set in ANCHOR_PEER_HOSTNAME|
|CHAINCODE_NAME|Chaincode (smart contract) name defined in chaincode definition comitted|
|CHAINCODE_VERSION|Chaincode version defined in chaincode definition comitted.|
|CHAINCODE_POLICY|Chaincode policy defined in chaincode definition comitted.|
|PEER_ADMIN_MSP_DIR|Admin user msp directory of satellite ex: app/\<ENVIRONMENT>/crypto/peerOrganization/\<subdomain>/users/Admin@subdomain/msp| 




```
export ORG\_NAME=<orgname> 
export SUB\_DOMAIN=<sub-domain>
export PEER\_COUNT=2
export ORDERER\_COUNT=0 
export ENVIRONMENT=test
export ORDERER\_TLS\_CA\_CERT=<path-to-orderer-ca-cert>
export ORDERER\_ADDRESS=<orderer-hostname-with-port> 
export CHANNEL\_NAME=<channelname>
export ANCHOR\_PEER\_HOSTNAME=<hostname-of-one-the-hlf-peer> 
export ANCHOR\_PEER\_PORT\_NUMBER=\<port-number-of-one-the-hlf-peer\>
export CHAINCODE\_NAME=\<chaincode-name\>
export CHAINCODE\_SEQUENCE=\<chaincode-version\>
export CHAINCODE\_VERSION=\<chaincode-version\>
export CHAINCODE\_POLICY=\<chaincode-policy\>
export PEER\_ADMIN\_MSP\_DIR=/<path>/app/<orgname>/users/Admin/msp
```

<br>

Join the HLF channel using below script:
```
cd iSHARESatellite/scripts 
bash joinchannel.sh
```

<br>

Anchor peer for new satellite:
```
bash anchorPeer.sh
```

Install chaincode in new satellite peer
```
bash installChaincode.sh
```

<br>

Approve the chaincode for new satellite peer
```
bash approveChaincode.sh
```

<br>

Create chaincode instance
```
bash chaincode.sh
```

Create HLF explorer instance:
```
bash explorer.sh
```

Your node is now on network!

<br> <br>


# 4.5. &nbsp; <a id="deploy"> Deploy the UI and middleware applications </a>

**Note: Steps to configure Private key (of the eIDAS) certificate in production environment could differ to accommodate your organizations policies. <br> For test environments currently we configure the private keys in VM itself which is not very secure. But since we issue you test eIDAS certificates it is usually no issue. Please contact us if you wish to configure private keys differently.**

Export these environment variables to initialize scripts:

<br>

|Environment Variables|Description|
|---------------------|-----------|
|ORG_NAME|Satellite which is going to be a part of HLF network. ex:mysatellite. You already set this value in chapter 4.2, make sure to use the same value here.|
|SUB_DOMAIN|Sub-domain reserved in DNS service for this satellite.ex: uat.mydomain.com. You already set this value in chapter 4.2, make sure to use the same value here.|
|CHANNEL_NAME|Name of the channel in which new satellite is onboarded. Same value as used in previous chapter.|
|CHAINCODE_NAME|Chaincode (smart contract) name defined in chaincode definition comitted. Same value as used in previous chapter.|
|PARTY_ID|EORI identifier that iSHARE has used to register you in the network.|
|PARTY_NAME|Name used by iSHARE to register you in the network.|
|UIHostName|DNS name of Application UI. Ex: mysatellite.example.com. Base URL of your satellite application. This name should be unique.|
|MiddlewareHostName|DNS name for application middleware. Ex: mysatellite-mw.example.com. Base URL of your satellite APIs. This name should be unique.|
|KeycloakHostName|DNS name for application keycloak service. Ex: mysatellite-keycloak.example.com. Base URL of your keycloak for user administration. Internal use only. This name should be unique.|


<br> 

```
export ORG_NAME=<myorg> 
export SUB_DOMAIN=<test.example.com>
export ENVIRONMENT=<test> 
export CHANNEL_NAME=<mychannel>
export CHAINCODE_NAME=<ccname>
export PARTY_ID=<party_id>
export PARTY_NAME=<party_name>
export UIHostName=<myorg-test.example.com>
export MiddlwareHostName=<myorg-mw-test.example.com>
export KeycloakHostName=<myorg-keycloak-test.example.com>
```

<br>

*Configure HTTPS (SSL/TLS):* <br>

To configure SSL (HTTPS) you need the certificate chain file and private key file from your CA. 
<br>
Copy/move the full certificate full chain file and private key file into the "ssl" directory. The files should have the given names and format shown below: 

- The full chain certificate file should be named "tls.crt". 
    - The certificate file should only contain the three keys, and begin with ```"----BEGIN CERTIFICATE-----"``` and end with ```"----END CERTIFICATE-----"```.

<br>

- The private key file should be named "tls.key". 
  - The file should only contain the private key, and begin with "```----BEGIN PRIVATE KEY----```" and end with "```----END PRIVATE KEY----```", or begin with "```----BEGIN RSA PRIVATE KEY----```" and end with "```----END RSA PRIVATE KEY----```".

Note: SSL certs should be a wild card certificate of your domain name like \*.example.com.

<br>

*Configure Signing Certificate (e.g. your eIDAS certificate):*


**Note: For production environments you should have received your Qualified Seal digital certificate as specified in iSHARE, from your chosen Certificate Authority. When requesting you can request the certificate in p12 file format. For test environments you can request your certificates using following link:<a> https://ca7.isharetest.net:8442/ejbca/ra </a>. Use "postpone" option during request. Once your request is approved you will get a link via email to download the certificate.**

To extract the public certificate from p12 compatible with required format: <br> 
openssl pkcs12 -in <p12 file> -nokeys -passin <p12 password> | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > \<output filename\>(hint: jwtRSA256-public.pem). <br>

To extract the unencrypted private key from p12 compatible with required format:  <br> 
openssl pkcs12 -in <p12 file> -nocerts -nodes -passin <p12 password> | openssl rsa > <output filename>(hint: jwtRSA256-private.pem).

You can also use following script to automate above and extract certificate in various formats: <br> 
<https://github.com/iSHAREScheme/code-snippets/tree/master/Cert_Key_Extractor>

<br>


Copy/move RSA public cert and private key (e.g. your eIDAS certificate) in jwt-rsa folder. Jwt-rsa folder should contain following files with given names below:

- jwtRSA256-public.pem - public full chain certificate for jwt signing. 
  - The certificate file should contain three files, and begin with ```"-----BEGIN CERTIFICATE-----"``` and end with ```"-----END CERTIFICATE-----"```.

<br>

- jwtRSA256-private.pem – RSA private key (unecrypted) file for jwt signing  
  - The certificate file should begin with 
   "```-----BEGIN RSA PRIVATE KEY-----```"  and end with ```"-----END RSA PRIVATE KEY-----"```. 

<br>


  

<br> <br>

*Configure environment and deploy applications:* <br>

Copy “genesis.block” and “isharechannel.tx” files into the "middleware" folder. These files were shared by iSHARE Foundation to you earlier.

Create Keycloak Instance using below command, It listens at port 8443.

```
cd iSHARESatellite/scripts 
bash keycloak.sh
```

Create middleware instances using below command. 

```
bash middleware.sh
```

<br>

Create UI and Nginx instances:

```
bash deployUI.sh
```

<br>

*Configure DNS for your applications:* <br> 

Map dns entries for application services with server IP address for these environment variables:

**UIHostName** (ex: myorg-test.example.com, record type A, ip adress 123.0.0.23. Example.com is the domain name for the applications UI and 123.0.0.23 is the server’s public IP)

**MiddlwareHostName** (ex: myorg-mw-test.example.com A record 123.0.0.23, example.com is the domain name for the applications middleware and 123.0.0.23 is the server’s public IP)

**KeycloakHostName** (ex: myorg-keycloak-test.example.com A record 123.0.0.23, example.com is the domain name for the applications keycloak and 123.0.0.23 is the server’s public IP) 


|**Full Record Name**|**Record Type**|**Value**|**TTL**|
| :- | :- | :- | :- |
|\<UIHostName>|A|123.0.0.23|1min|
|\<MiddlwareHostName\>|A|123.0.0.23|1min|
|\<KeycloakHostName\>|A|123.0.0.23|1min|

<br> 
Now your satellite is deployed! Finish the next chapter to use the application.

<br> <br> <br>

# 5. <a id="U_setup"> Initial user setup </a>

The satellite is now installed. To access the satellite, first set up a satellite admin user for the keycloak identity provider with the procedure below.  Keycloak URL is accessible over the browser. Example:  <https://satellite.example.com:8443/auth>.

NOTE: Once you have set up an initial user, you can add your colleagues via satellite UI in a straightforward manner. Therefore, you do not need repeat the keycloak user setup for other users. Also, make sure to secure keycloak environment based on your organization policy to limit users that can log into the keycloak admin console. You can set stricter password and user policies via keycloak admin console. 

<br>

1. Click on administrator console and login with seeded admin user refer to below screenshots.

![](Images/keycloakuser1.png)

`           `![](Images/keycloakuser2.png)

Note: username and password for admin can be found in keycloak-docker-compose.yaml inside "keycloak" directory of the project folder. IMPORTANT NOTE: if you change the admin username and password in the keycloak ui, you also need to change these inside the keycloak-docker-compose.yaml file. 

2. Once logged in successfully, click on users in left menu

![](Images/keycloakuser3.png)

3. Click on Add User button on right side of it

![](Images/keycloakuser4.png)

4. Fill all the details in "Add user" form. Refer to the below image and click save.

Note : username and email should be email id.

` `![](Images/keycloakuser5.png)

5. Click on the "Attribute" tab and add the attributes shown in the table below. Then click save. 

Note: Attributes are mandatory. 

|**Attribute Name**|**Attribute Value**|
| :- | :- |
|**partyId**|ID of the participant that this user belongs. Usually, the satellite ID|
|**partyName**|Name of the participant corresponding to the partyId|

![](Images/keycloakuser6.png)

6. Click on the "Credentials tab and set the password for the user that is being created. 

![](Images/keycloakuser7.png)

7. Click on "Role Mappings" tab and find "Client Roles "dropdown. Select "frontend". 

![](Images/keycloakuser8.png)

8. Under "Available Roles", select "satelliteAdmin" and click on the "Add Selected" button.

![](Images/keycloakuser9.png)

Your user is now created, and you can proceed to use the satellite the UI with newly created user. In the UI you can start registering satellite participants.

<br> <br> <br>

# 6. <a id="email"> Set up email notifications </a>

You need an email account so that notifications can be sent to users. The steps below explain how to set up notifications with google email. Make to create an app password in the google account, as this is needed for the notification configuration. 

If you wish to use other email providers, please refer specifically to their values and settings for setup.

Steps for Email Notification under keycloak administrator login:

1. Login as administrator user 
2. Click on "Realm Settings" under the left menu bar. 

`         `![](Images/keycloakemail1.png)

3. Click on the "Email" tab and fill out the necessary details shown below. Remember to click save. Email notification will be enabled.

`         `![](Images/keycloakemail2.png)

Note: Form inputs for *From* and *username* should be valid email id's. Password should be the app password configured in the mail account.

 <br> <br> <br>

# 7. <a id="configure_keycloak"> Configure Keycloak </a>

Steps for RedirectURL configuration in keycloak

1. Login as administrator user
2. Click on "Clients" under left menu bar and select "frontend" from the "ClientID" options.

`                                                                                                                                                                             `![](Images/keycloakurl1.png)

3. In the "frontend" settings form, find *RootURL*, *valid RedirectURLs, Web Origins* and add the entries as follows:
 
 *RootURL* – the values to this input should be UI application URL. Example: <https://satelliteone-demo.example.com>

Valid Redirect URLs* – it includes multiple values as URLs.

-  UI application URL with \* as route. Example: <https://satelliteone-demo.krypc.com/>\*
- Keycloak URL with \* as route. Example: <https://satelliteone-demo.exapmle.com:8443/>\*

*Web Origins -* the values to this input should be keycloak URL with \* as route. Example: <https://satelliteone-demo.krypc.com:8443/>\*

Find below image as reference:

![](Images/keycloakurl2.png)



4. Match all the settings as below image and save it. Redirection settings has been changed successfully.

![](Images/keycloakurl3.png)

![](Images/keycloakurl4.png)

<br> <br>





 # 8.  <a id="2FA"> Enable 2FA for users </a> 

The steps below explain how to set up the 2FA for new devices (configured device lost/new device to configure with existing users). The keycloak administrator has the provision to enable this feature. 

1. Log in with the Keycloak admin credentials, and goto "Manage" in the left option bar, then click "Users". Select the user to reset 2FA.

2. Go to the "Credentials" tab and delete the "otp” type. Then click "confirm". 

![](Images/keycloak2fa1.png)

3. Go to the "Details" tab. Click on the "Required user action" dropdown bar, and select "Configure OTP". Click on save.

![](Images/keycloak2fa2.png)

![](Images/keycloak2fa3.png)

4. Inform the user to login with existing credentials and configure the 2FA on the new device.

The application will allow to use the existing credentials with new 2FA.

You are now ready with your Satellite. Login with the user you created in step 5.2 using the application link <UIHostName> setup in previous chapter.

<br> <br> <br>

# 9. <a id="docker_service"> Commands for managing Docker services </a>

To check the status of docker containers:
```
docker-compose -f <docker-compose-file> ps
```
To stop the container

```
docker-compose -f <docker-compose-file> down
```
To restart containers 
```
docker-compose -f <docker-compose-file> restart
```
To bring containers up and running
```
docker-compose -f <docker-compose-file> up -d
```
To get the logs of containers
```
docker-compose -f <docker-compose-file> logs <service-name-in-compose-file>
```


<br> <br> <br>

# 10. <a id="ref_update"> Reference updates deployment procedure </a>

Following is general procedure for updates deployment. When new updates are available to be deployed, iSHARE Foundation will inform you with additional details about the deployment.

You will find docker-compose files in following path in project directory. All the docker services will be managed using these docker-compose files. 

- iSHARESatellite/hlf/<Environment>/<orgName>/peers/ docker-compose-hlf.yaml
- iSHARESatellite/hlf/<Environment>/<orgName>/fabric-ca/ docker-compose-fabric-ca.yaml
- iSHARESatellite/middleware/docker-compose-mw.yaml
- iSHARESatellite/keycloak/keycloak-docker-compose.yaml
- iSHARESatellite/explorer/explorer-docker-compose.yaml
- iSHARESatellite/chaincode/cc-docker-compose-template.yaml
- iSHARESatellite/ui/docker-compose-ui.yaml

Find the services which are going to be updated below: 

|#|Services|Path|
| :- | :- | :- |
|1|<p>ishare\_mw (ishare middleware)</p><p>ishare\_hlf (ishare hlf middleware)</p>|iSHARESatellite/middleware/docker-compose-mw.yaml|
|2|<p>ishare\_ui (ishare UI)</p><p>nginx-proxy (Nginx reverse proxy)</p>|iSHARESatellite/ui/docker-compose-ui.yaml|
|3|ishare-cc.hlf (ishare chaincode)|iSHARESatellite/chaincode/cc-docker-compose-template.yaml|


Steps to deploy update/releases:

- Open the docker-compose file in a text editor eg: docker-compose-mw.yaml file to manage ishare middleware and ishare hlf middleware.
- Select one of the service eg: ishare\_mw (ishare middleware).
- Under service name (ishare\_mw), look for image key eg:
  ishare\_mw:

image: isharefoundation/ishare-satellite-app-mw:<tag>

- Change the tag of the image with new tag provided as an update/release eg: v1.50 and save it.
  Eg:
  ishare\_mw: 

`            `image: isharefoundation/ishare-satellite-app-mw: v1.50

- Stop the container with below command
  docker-compose –f <docker-compose-file> down
  eg: docker-compose –f docker-compose-mw.yaml down
- Start the docker services again with below
  docker-compose –f <docker-compose-file> up -d
  eg: docker-compose –f docker-compose-mw.yaml up –d
- Check the state of the services 
  docker-compose –f <docker-compose-file> ps
  eg: docker-compose –f docker-compose-mw.yaml ps
  It should show table containing state as column with Up as a state.
- Deployment is done.

Similarly, updates can be done for all the services.

