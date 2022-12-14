
![](isharelogo.png)

APRIL 12, 2022

iSHARE FOUNDATION



iSHARE SATELLITE DEPLOYMENT GUIDE

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

[***4.5. &nbsp; &nbsp; Deploy the UI and middleware applications***](#_Toc106354337)

[***? &nbsp; &nbsp; Keycloak setup -Application settings***](#_Toc106354338)

[***? &nbsp; &nbsp; Configure keycloak***](#_Toc106354339)

[***5. &nbsp; &nbsp; Initial user setup***](#user_setup)

[***5.3. &nbsp; &nbsp; Set up email notifications***](#_Toc106354341)

[***5.4. &nbsp; &nbsp; Enable 2FA for users***](#_Toc106354342)

[***6. &nbsp; &nbsp; Commands for managing Docker services***](#_Toc106354343)

[***7. &nbsp; &nbsp; Reference updates deployment procedure***](#_Toc106354344)

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

- <span style="color:grey"> 443/TCP,80/TCP for Application middleware and UI. </span>
-  <span style="color:grey"> 7051/TCP and 8051/TCP for HLF Peers. </span>
- <span style="color:grey"> 8443/TCP for keyCloak instance (user management backend) 
- <span style="color:grey"> Optionally, 8081/TCP for explorer instance (hyperledger explorer) – open to outside only if require access from outside your own network, maybe necessary when hosted on cloud </span>.

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

|<p>git clone [https://github.com/iSHAREScheme/iSHARESatellite.git](https://github.com/iSHAREScheme/VM-Model-iSHARE-Satellites.git)</p><p>cd iSHARESatellite </p>|
| :- |


If you want to change the default passwords (recommended and mandatory for production environments) please follow these steps, else skip this chapter.

Following are the services which uses username and password as credentials for authentication:

- <span style="color:grey"> Postgres DB for Application </span>
- <span style="color:grey"> Explorer DB for Explorer </span>
- <span style="color:grey"> Postgres DB for Keycloak </span>

<br>

<h3 align="center"> Steps to configure password for changing HLF Explorer’s DB:</h3>

<br>

|<p> cd iSHARESatellite/templates </p>|
| :- |

 Open explorer-docker-compose-template.yaml in the text editor. <br>
Under *services* section, change the password for explorerdb by referring below snippet under environment: <br> <br>
explorerdb: <br>
 &nbsp;  &nbsp; image: hyperledger/explorer-db:latest <br>
 &nbsp;  &nbsp; container\_name: explorerdb <br>
 &nbsp;  &nbsp; hostname: explorerdb <br>
 &nbsp;  &nbsp; environment: <br>
 &nbsp;  &nbsp;  &nbsp;  &nbsp; - DATABASE\_DATABASE=fabricexplorer <br>
 &nbsp;  &nbsp;  &nbsp;  &nbsp; - DATABASE\_USERNAME=hppoc <br>
 &nbsp;  &nbsp;  &nbsp;  &nbsp; - DATABASE\_PASSWORD=password

<br>

Same Password has be configured for explorer service under environment, refer below snippet:

<br>

explorer: <br>
&nbsp;  &nbsp; image: hyperledger/explorer:latest <br>
&nbsp;  &nbsp; container\_name: explorer <br>
&nbsp;  &nbsp; hostname: explorer <br>
&nbsp;  &nbsp; environment: <br>
&nbsp;  &nbsp; &nbsp;  &nbsp;- DATABASE\_HOST=explorerdb <br>
&nbsp;  &nbsp; &nbsp;  &nbsp;- DATABASE\_DATABASE=fabricexplorer <br>
&nbsp;  &nbsp; &nbsp;  &nbsp;- DATABASE\_USERNAME=hppoc <br>
&nbsp;  &nbsp; &nbsp;  &nbsp;- DATABASE\_PASSWD=password <br> <br>

Open app-mw-config-template.yaml in the text editor, configure password in explorer db connection string. Check below:

|<p>explorerDb: postgresql://hppoc:password@explorerdb:5432/fabricexplorer?sslmode=disable </p>|
| :- |

<br> <br>

<h3 align="center">Steps to configure password for Application middleware postgres DB</h3>

<br>

|<p> cd iSHARESatellite/templates </p>|
|:-|

<br>

Open docker-compose-mw-template.yaml in a text editor and look for below snippet : <br>

**app-postgres: <br>
&nbsp;  &nbsp; image: postgres:9 <br>
&nbsp;  &nbsp; restart: always <br>
&nbsp;  &nbsp; environment: <br>
&nbsp;  &nbsp; &nbsp;  &nbsp; POSTGRES\_USER: admin <br>
&nbsp;  &nbsp; &nbsp;  &nbsp; POSTGRES\_PASSWORD: adminpw** <br>

Change password for admin user under environment section and save. <br> <br> <br>



Open hlf-mw-config-template.yaml file in a text editor and look for the below snippet and lower end of the file: <br>

**ishareConfig: <br> 
&nbsp;  &nbsp; middlewareConfig: <br>
&nbsp;  &nbsp; postgres\_connection\_url: postgresql:// <br> admin:adminpw@app-postgres:5432/ishare?sslmode=disable** <br> 

Change the password adminpw in connection string with password configured in docker-compose-mw.yaml. <br> <br> <br>

Open app-mw-config-template.yaml file in a text editor and look for the below snippet: <br>

**ishareConfig: <br>
&nbsp;  &nbsp; middlewareConfig: <br>
&nbsp;  &nbsp; postgres\_connection\_url: postgresql://admin:adminpw@app-postgres:5432/ishare?sslmode=disable** <br> 

Change the password adminpw in connection string with password configured in docker-compose-mw.yaml. <br> <br> <br>


<h3 align="center"> Steps to configure password for Application Keycloak service </h3>

<br> 

|<p> cd iSHARESatellite/keycloak/postgres </p>|
|:-|

<br>

Open init-db.sql in a text editor: <br>

**CREATE USER keycloak WITH ENCRYPTED PASSWORD 'keycloak';**

Change password from **keycloak** to desired password. Password should be under single quotes. <br> <br>

|<p> cd iSHARESatellite/keycloak/p>|
|:-|

<br>

Open keycloak-docker-compose.yaml in a text editor,look for below snippet

**keycloak:
&nbsp;  &nbsp; image: jboss/keycloak:11.0.2 <br>
&nbsp;  &nbsp; container\_name: keycloak <br>
&nbsp;  &nbsp; ports: <br>
&nbsp;  &nbsp; &nbsp; - 8443:8443 <br>
environment: <br>
&nbsp;  &nbsp; &nbsp; - KEYCLOAK\_USER=admin <br>
&nbsp;  &nbsp; &nbsp; - KEYCLOAK\_PASSWORD=admin <br>
&nbsp;  &nbsp; &nbsp; - DB\_VENDOR=postgres <br>
&nbsp;  &nbsp; &nbsp; - DB\_ADDR=keycloakpostgres <br>
&nbsp;  &nbsp; &nbsp; - DB\_DATABASE=keycloak <br>
&nbsp;  &nbsp; &nbsp; - DB\_USER=keycloak <br>
&nbsp;  &nbsp; &nbsp; - DB\_PASSWORD=keycloak**

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

|<p>git clone [https://github.com/iSHAREScheme/iSHARESatellite.git](https://github.com/iSHAREScheme/VM-Model-iSHARE-Satellites.git)</p><p>cd iSHARESatellite </p>|
| :- |

<br>

To install and ensure all the necessary packages are available in the system, use the below script to verify (reboot the system on completion, if necessary).

<br>

|bash prerequsites.sh|
| :- |

<br>

|cd iSHARESatellite/scripts |
| :- |

<br>

Configure environment variables to initialize scripts. See env variables with example below:

![](Environment_var_tab.PNG)

<br>

|<p>export ORG\_NAME=newsatellite<br>export SUB\_DOMAIN=test.example.com<br>export ENVIRONMENT=test</p>|
| :- |

<br>

To generate HLF fabric ca certs, use the below command :

|<p>bash fabric-ca-cert.sh </p><p></p>|
| :- |

<br>

Creating HLF Fabric CA instance:

|bash fabric-ca.sh|
| :- |

<br>

*Validation*

Navigate to *iSHARESatellite / hlf /\<Environment\>/\<orgName\>/ fabric-ca* directory. <br>
Check the presence of the docker\_data folder. <br>
To ensure all the HLF Fabric is running, use below commands and check the status.

**docker-compose -f iSHARESatellite/hlf/\<Environment\>/\<orgName\>/fabric-ca/docker-compose-fabric-ca.yaml ps** 

<br>

Register and Enroll users and peers

|bash registerAndEnroll.sh|
| :- |

<br> 

Create HLF Peer instances, it will spun up instances of  HLF Peers and CouchDB 

|bash peer.sh|
| :- |

<br>

*Validation*

Navigate to *iSHARESatellite / hlf /\<Environment\>/\<orgName\>/ peers* directory.

Check the presence of the docker\_data folder. <br>
To ensure all the HLF Peer is running, use below commands to check the status. 


**docker-compose -f iSHARESatellite/hlf/\<Environment\>/\<orgName\>/peers/docker-compose-hlf.yaml ps**

<br>

HLF Peer instances needs to be a part of  iSHARE Foundation HLF network, for that HLF peers needs to reachable over the internet. Previous script peer.sh creates two HLF peer instance with hostname peer<num>.<ORG\_NAME>.<SUB\_DOMAIN> and they listen at port 7051 and 8051 TCP. Make sure that necessary firewall settings are updated to allow access to these peers over internet . Map dns entries for Peers hostname with server IP address ex:

If  **ORG\_NAME=newsatellite** and **SUB\_DOMAIN=test.example.com**, then

**peer0.\<orgname\>.\<subdomain\>  - peer0.newsatellite.test.example.com**, and 

**peer1.\<orgname\>.\<subdomain\>  - peer1.newsatellite.test.example.com**

<br>

![](peer_names.PNG)

<br>

The Hyperledger fabric node is deployed, now follow next chapter to register your node in the network.

<br> <br>

# 4.3. &nbsp; <a id="reg_node"> Register your node </a>  
<br> 

Share details with iSHARE foundation to register your node on iSHARE network
Now generate the organization definition file which iSHARE Foundation (HLF Channel Admin) would require inorder to onboard your new satellite. Use the below command to create an org definition.



|bash orgDefinition.sh|
| :- |

<br>

Find the <orgName>.json at *hlf /\<ENVIRONMENT\>/\<ORG\_NAME\>* folder. <br>
Note: <orgName>.json file has to be shared securely, as it contains x509 certificates of the new satellite. <br>
Send this file as well as following details to iSHARE foundation.

<br><br>


1. # 4.4. &nbsp; <a id="join_net"> Join the network </a>

<br>

Join the network with information received from iSHARE Foundation. You should receive following information and files from iSHARE Foundation:

**Files: Copy these files in the VM** 

- CA cert file of HLF ordering service (ORDERER\_TLS\_CA\_CERT)
- Genesis.block file 
- Channel .tx file 

Note: you need to copy Genesis.block and channel .tx file to the same folder which contains the iSHARESatellite folder

**Values for following variables**

- ORDERER\_ADDRESS - one of the ordering services hostname and port
- CHANNEL\_NAME - channel name in which a particular satellite is on boarded
- CHAINCODE\_NAME - chaincode (smart contract) which is defined in chaincode definition committed
- CHAINCODE\_VERSION -  chaincode version defined in chaincode definition committed
- CHAINCODE\_SEQUENCE - sequence number associated with chaincode 
- CHAINCODE\_POLICY - chaincode policy string used while commiting chaincode definition in the HLF network

Once the above details is known, move the copy of ORDERER\_TLS\_CA\_CERT file in the VM and follow below steps. <br>
Export these Environment variables:.

![](Environment_var_tab_2.png)



|<p>export ORG\_NAME=\<orgname\> <br>export SUB\_DOMAIN=\<sub-domain\> <br> export PEER\_COUNT=2 <br> export ORDERER\_COUNT=0 <br> export ENVIRONMENT=test<br> export ORDERER\_TLS\_CA\_CERT=\<path-to-orderer-ca-cert\> <br> export ORDERER\_ADDRESS=\<orderer-hostname-with-port\> <br> export CHANNEL\_NAME=\<channelname\> <br> export ANCHOR\_PEER\_HOSTNAME=\<hostname-of-one-the-hlf-peer\> <br> export ANCHOR\_PEER\_PORT\_NUMBER=\<port-number-of-one-the-hlf-peer\><br> export CHAINCODE\_NAME=\<chaincode-name\> <br> export CHAINCODE\_SEQUENCE=\<chaincode-version\> <br> export CHAINCODE\_VERSION=\<chaincode-version\> <br> export CHAINCODE\_POLICY=\<chaincode-policy\> export PEER\_ADMIN\_MSP\_DIR=/\<path\>/app/\<orgname\>/users /Admin/msp </p>|
| :- |

<br>

Join the HLF channel using below script:
|<p>cd iSHARESatellite/scripts</p><p>bash joinchannel.sh</p>|
| :- |

<br>

Anchor peer for new satellite:
|<p>bash anchorPeer.sh</p>|
| :- |

<br>

Install chaincode in new satellite peer
|<p>bash installChaincode.sh</p>|
| :- |

<br>

Approve the chaincode for new satellite peer
|<p>bash approveChaincode.sh</p>|
| :- |

<br>

Create chaincode instance
|<p>bash chaincode.sh</p>|
| :- |

Create HLF explorer instance:
|<p>bash explorer.sh</p>|
| :- |

Your node is now on network!

<br> <br>


# 4.5. &nbsp; <a id="deploy"> Deploy the UI and middleware applications </a>


|<p>**Note: Steps to configure Private key (of the eIDAS) certificate in production environment could differ to accommodate your organizations policies. <br> For test environments currently we configure the private keys in VM itself which is not very secure. But since we issue you test eIDAS certificates it is usually no issue.Please contact us if you wish to configure private keys differently.**</p>|
| :- |

Export these environment variables to initialize scripts:

<br>

![](Environment_var_tab_3.PNG)



|<p>export ORG\_NAME=\<myorg\><br>export SUB\_DOMAIN=\<test.example.com\><br>export KeycloakHostName=\<myorg-keycloak-test.example.com\><br>export CHANNEL\_NAME=\<mychannel\><br>export CHAINCODE\_NAME=\<ccname\><br>export UIHostName=\<myorg-test.example.com\><br>export MiddlwareHostName=\<myorg-mw-test.example.com\><br>export ENVIRONMENT=\<test\> export PARTY\_ID=\<party\_id\><br>export PARTY\_NAME=\<party\_name\>|
| :- |

<br>

*Configure HTTPS (SSL/TLS):* <br>

To configure SSL (HTTPS) you would need the certificate and private key file from your CA. <br>
Copy SSL certs for the application inside “ssl” directory with a cert file named tls.crt and a private key file named tls.key.

Copy the public certificate (pem file) to {base\_dir}/ssl/tls.crt
Copy the private key (key file) to {base\_dir}/ssl/tls.key

Note: SSL certs should be a wild card certificate of your domain name like \*.example.com.

<br>

*Configure Signing certificate (e.g. your eIDAS certificate):*

Copy/Move RSA public cert and private key (e.g. your eIDAS certificate) in jwt-rsa folder. Jwt-rsa folder should contain following files with given names below:

- jwtRSA256-private.pem – RSA private key (unecrypted) file for jwt signing  
  - The certificate file should begin with "-----BEGIN RSA PRIVATE KEY-----"  and end with "-----END RSA PRIVATE KEY-----"
- jwtRSA256-public.pem - public cert for jwt signing
  - The certificate file should contain the whole chain of certificate and begin with "-----BEGIN CERTIFICATE-----" and end with "-----END CERTIFICATE-----"

Note: For production environments you should have received your Qualified Seal digital certificate as specified in iSHARE, from your chosen Certificate Authority. When requesting you can request the certificate in p12 file format.

For test environments you can request your certificates using following link:<a> https://ca7.isharetest.net:8442/ejbca/ra </a>. <br>
Please note: use "postpone" option during request. Once your request is approved you will get a link via email to download the certificate.

*Instructions to convert your p12 file on linux using openssl:*

  
To extract the public certificate from p12 compatible with required format<br>openssl pkcs12 -in <p12 file> -nokeys -passin <p12 password> | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > \<output filename\>(hint: jwtRSA256-public.pem). <br>

To extract the unencrypted private key from p12 compatible with required format:  <br> 
openssl pkcs12 -in <p12 file> -nocerts -nodes -passin <p12 password> | openssl rsa > <output filename>(hint: jwtRSA256-private.pem).


You can also use following script to automate above and extract certificate in various formats: <br> 
<https://github.com/iSHAREScheme/code-snippets/tree/master/Cert_Key_Extractor>

<br> <br>

#### *Configure environment and deploy applications:*

<br>

Copy “genesis.block” and “channel.tx” files in middleware folder. These files were shared by iSHARE foundation to you earlier.

<br>

Create Keycloak Instance using below command, It listens at port 8443.

|<p> cd iSHARESatellite/scripts </p> <p> bash keycloak.sh </p>|
| :- |

<br>

Create middleware instances using below command. 

|<p> bash middleware.sh</p>|
| :- |

<br>

Create UI and Nginx instances:

|<p>bash deployUI.sh</p>| 
| :- |

<br>

*Configure DNS for your applications:* <br> 
Map dns entries for application services with server IP address for these environment variables:

**UIHostName** (ex: myorg-test.example.com A record 123.0.0.23, example.com is the domain name for the applications UI and 123.0.0.23 is the server’s public IP)

**MiddlwareHostName** (ex: myorg-mw-test.example.com A record 123.0.0.23, example.com is the domain name for the applications middleware and 123.0.0.23 is the server’s public IP)

**KeycloakHostName** (ex: myorg-keycloak-test.example.com A record 123.0.0.23, example.com is the domain name for the applications keycloak and 123.0.0.23 is the server’s public IP) 


|**Full Record Name**|**Record Type**|**Value**|**TTL**|
| :- | :- | :- | :- |
|<UIHostName>|A|12.9.7.6|1min|
|<MiddlwareHostName>|A|12.9.7.6|1min|
|<KeycloakHostName>|A|12.9.7.6|1min|

<br> 
Now your satellite is deployed! Note finish next chapter to be able to use the application.

<br> <br> <br>


# ? <a>Configure Keycloak </a>

Steps for RedirectURL configuration in keycloak

1. Login as administrator user
1. ` `Click on *Clients* under left menu bar and select *frontend* as ClientID

`                                                                                                                                                                             `![](keycloakurl1.png)

1. In *frontend* settings form, find *RootURL*, *valid RedirectURLs, Web Origins* and add the entries as follows:

`            `*RootURL* – the values to this input should be UI application URL

`            `example: <https://satelliteone-demo.example.com>

`            `*Valid Redirect URLs* – it includes multiple values as URLs.

1. UI application URL with \* as route example - [https://satelliteone-demo.example.com/](https://satelliteone-demo.krypc.com/)\*
1. Keycloak URL with \* as route example - <https://satelliteone-demo.exapmle.com:8443/>\*

`            `*Web Origins -* the values to this input should be keycloak URL with \* as route example -

`           `[https://satelliteone-demo.example.com:8443/](https://satelliteone-demo.krypc.com:8443/)\*

`            `Find below Image as reference

`           `![](keycloakurl2.png)



1. ` `Match all the settings as below image and save it. Redirection settings has been changed successfully.

![](keycloakurl3.png)

![](keycloakurl4.png)

<br> <br>

# 5. <a id="U_setup"> Initial user setup </a>

Now that you have installed satellite, to access it first setup a Satellite admin user with following procedure

NOTE: Once you have setup initial user, you can add your colleagues via satellite UI which is very straight forward, so you do not need to follow same procedure for adding other users. Also, make sure to secure keycloak environment as per your organization policy so only limited users can login into keycloak admin console. Additionally, you can set more stricter password and user policies via keycloak admin console.

Keycloak URL is accessible over the browser example -  <https://satellite.example.com:8443/auth>.

Steps for Keycloak user creation

1. Click on administrator console and login with seeded admin user refer to below screenshots.

![](keycloakuser1.png)

`           `![](keycloakuser2.png)

Note: username and password for admin could be found in keycloak-docker-compose.yaml inside keycloak directory for project folder.

1. Once logged in successfully, click on users in left menu

![](keycloakuser3.png)

1. Click on Add User button on right side of it

![](keycloakuser4.png)

1. Fill all the details in Add user form, refer below image and click save.

Note : username and email should be email id.

` `![](keycloakuser5.png)

1. Click on Attribute tab, add the following attributes with values and save.

Note: Attributes are mandatory. 

|**Attribute Name**|**Attribute Value**|
| :- | :- |
|**partyId**|ID of the participant that this user belongs. Usually, the satellite ID|
|**partyName**|Name of the participant corresponding to the partyId|

![](keycloakuser6.png)

1. Click on credentials tab, enter the password for the user created as follows and set the password

![](keycloakuser7.png)

1. ` `Click on Role Mapping tab, find Client Roles dropdown and select frontend

![](keycloakuser8.png)

1. Under Available Roles, select satelliteAdmin and click on Add Selected button

![](keycloakuser9.png)

User is created, and you can proceed to use satellite UI with newly created User and start registering participants.

<br> <br> <br>

# ? <a> Set up email notifications </a>

Note: you need an email account using which notifications can be sent to users. Following steps explain setting up notifications using google email. Make sure you created app password in the google account as you would need that to configure it here.

For other providers please refer to values and settings from that provider.

Steps for Email Notification under keycloak administrator login:

1. Login as administrator user 
1. Click on Realm Settings under left menu bar

`         `![](keycloakemail1.png)

1. Click on Email tab, fill all the necessary details as below image and save it. Email notification will be enabled.

`         `![](keycloakemail2.png)

`    `Note: Form inputs for *From* and *username* should be valid emailID. Password should be app password configured in the mail account.

 <br> <br> <br>

 # ? <a> Enable 2FA for users </a> 

Setting up the 2FA for new devices(configured device lost/new device to configure with existing users)

Keycloak administrator is having the provision to enable this feature

Login with the Keycloak admin credential and goto **Manage --> Users -->** select the User to reset 2FA.

Goto **Credentials** tab and delete the **“otp”** type and confirm

![](keycloak2fa1.png)

Goto Details tab and select the **"Required user action"** as **Configure OTP** and save.

![](keycloak2fa2.png)

![](keycloak2fa3.png)

Inform the user to login with existing credentials and configure the new 2FA in the new device.

Application will allow to use the existing credentials with new 2FA.


You are now ready with your Satellite. Login with the user you created in step 5.2 using the application link <UIHostName> setup in previous chapter.

<br> <br> <br>

# ? <a> Commands for managing Docker services </a>

To check the status of docker containers:

|docker-compose -f <docker-compose-file> ps|
| :- |
To stop the container

|docker-compose -f <docker-compose-file> down|
| :- |
To restart containers 

|docker-compose -f <docker-compose-file> restart|
| :- |
To bring containers up and running

|docker-compose -f <docker-compose-file> up -d|
| :- |
To get the logs of containers

|docker-compose -f <docker-compose-file> logs <service-name-in-compose-file>|
| :- |


<br> <br> <br>

# ? <a> Reference updates deployment procedure </a>

Following is general procedure for updates deployment. When new updates are available to be deployed iSHARE foundation will inform you with additional details about the deployment.

You will find docker-compose files in following path in project directory. Using these docker-compose files all the docker services will be managed. 

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

`             `image: isharefoundation/ishare-satellite-app-mw:<tag>

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

