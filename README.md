# iSHARE Satellite

<img align="right" src="docs/assets/isharelogo-small.png">

The satellite is an application that safeguards trust in a
dataspace. It functions as a register of participants. Participants
can call the satellite API to verify each other. When you verify that
a participant is registered in the satellite, you know that this
participant has signed the agreement, and can be held legally viable;
the participant is indeed a part of the dataspace, also on a "legal
level". Service consumers will often connect with service providers to request data. Service providers should then verify the service consumer's status of 
participance in the dataspace by making an API call to the satellite.

---
⚠️ IMPORTANT

All satellites which are deployed with version v1.x.x will need to be upgraded to v2.x.x once the upgrade of the iSHARE Foundation satellite is complete. Note, without upgrade your satellite may still seem operational, however, when you want to make changes to participants information it will throw errors until you have upgraded the version to v2.x.x. Kindly follow the upgrade guide in v2.x.x for upgrade instructions.
---

## Deployment Guide

See [INSTALL.md](./INSTALL.md).

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
