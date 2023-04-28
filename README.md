# SCOM.Modular.Multihoming.ManagementPack
SCOM Management Pack for Multi-Homing Agents to a new Management Group with automatic Gateway discovery.

This code is based on a [Management Pack authored by Kevin Holman](https://github.com/thekevinholman/MultiHomeSCOMAgents)

This MP differs to the original by making it Management Group agnostic, automatically discovering all SCOM Gateways in your Management Group and create relevant groups containing agents hosted by those Gateways. Customisation for your Management Group no longer needs to be done before importing.

## Important!
[**VSAE**](https://www.microsoft.com/en-us/download/details.aspx?id=104504) is required.
Ensure you update the project to seal the management pack before importing.
