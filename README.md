# iSHARE Satellite

<img align="right" src="docs/assets/isharelogo-small.png">

The iSHARE satellite is an application that safeguards trust in a
dataspace. It functions as a register of participants. Participants
can call the satellite API to verify each other. When you verify that
a participant is registered in the satellite, you know that this
participant has signed which agreements and the participant is indeed a part of a dataspace, also on a "legal
level". 

Service consumers will often connect with service providers to request data. Service providers should then verify the service consumer's status of participant in the dataspace by making an API call to the satellite.

> [!NOTE]
> Please subscribe to update group so that you get important communications about the Satellite. You can send request to join the group https://groups.google.com/a/ishare.eu/g/testsats/about


---
⚠️ IMPORTANT

All satellites which are deployed with version v1.x.x will need to be upgraded to v2.x.x once the upgrade of the iSHARE Foundation satellite is complete. Note, without upgrade your satellite may still seem operational, however, when you want to make changes to participants information it will throw errors until you have upgraded the version to v2.x.x. Kindly follow the upgrade guide in v2.x.x for upgrade instructions.
---

## Deployment Guide

iSHARE Satellite component can be deployed in various ways and on variety of servers and/or containers locally or on hyperscalers and can be configured for high availablity, redundancy and with additional security mechanisms when required. The following guide is meant to be **reference** for deploying all satellite components into one linux server (Virtual Machine) using docker and docker compose. Providing additional guides and maintaining them is out of scope of iSHARE Foundation, however, we highly encourage participants to perform these steps themselves or publish such guide as community driven open source guide. Please reach out to iSHARE Foundation support team for discussing possiblities to get support for doing different deployment then the one below and/or for publishing repository for alternative models contributed by you.

See [INSTALL.md](docs/INSTALL.md) for fresh installations on Ubuntu Linux machine using docker and docker-compose.

## Backup and Restore Guide

See [FullBackupRestore.md](docs/FullBackupRestore.md) for Ubuntu Linux machine using docker and docker-compose installations.

## Upgrade to version 2.x of satellite from 1.x

See [migration.md](docs/migration.md) for Ubuntu Linux machine using docker and docker-compose installations.

## License Notice and Copyright

All the files contained in this repository are by default copyright of
iSHARE Foundation unless stated otherwise.  All the files contained in
this repository are by default subject to AGPL-3.0 License unless
stated otherwise.

> Copyright (C) 2022  iSHARE Foundation
>
> This program is free software: you can redistribute it and/or modify
> it under the terms of the GNU Affero General Public License as
> published by the Free Software Foundation, either version 3 of the
> License, or (at your option) any later version.
>
> This program is distributed in the hope that it will be useful, but
> WITHOUT ANY WARRANTY; without even the implied warranty of
> MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
> Affero General Public License for more details.
>
>
> You should have received a copy of the GNU Affero General Public
> License along with this program.  If not, see
> <https://www.gnu.org/licenses/>.
