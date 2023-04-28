param(
    $sourceId,
    $managedEntityId
)

# Clear any previous errors
$Error.Clear()

#Defaults
$MOMapi = new-object -comObject "MOM.ScriptAPI"
$EventID = "1320"
$Whoami = WhoAmI
$ScriptStartTime = Get-Date
$ScriptStartTimeString = "{0:MM/dd/yyyy hh:mm:ss}" -f [datetime]$ScriptStartTime
#$RMSeManagementServer = "csovscom1.oceania.cshare.net"
$LogEnabled = $true
$ScriptName = "Discover-GatewayHostedAgents.ps1"

# Log Script Start
$momapi.LogScriptEvent($ScriptName,$EventID,0,"`nScript is starting. `n Running as ($Whoami). `nStart Time $ScriptStartTimeString")

# Load SCOM PowerShell Module and connect to Management Group
Import-Module OperationsManager
$momapi.LogScriptEvent($ScriptName,$EventID,0,"`nConnecting to SCOM ManagementGroup")

$DiscoveryData = $MOMapi.CreateDiscoveryData(0, $SourceId, $ManagedEntityId)

# Collect Gateways and associated Agents
$momapi.LogScriptEvent($ScriptName,$EventID,0,"`nCollecting Gateways and associated agents")
$SCOMGateways = Get-SCOMGatewayManagementServer | Sort-Object PrincipalName | Select *, @{Label="Agents";Exp={Get-SCOMAgent -ManagementServer $_}}
$SCOMGatewayNames = $SCOMGateways.PrincipalName | Out-String
$momapi.LogScriptEvent($ScriptName,$EventID,0,"`nSCOM Gateways`: $($SCOMGateways.Count)`n$SCOMGatewayNames`nTotal Agents`: $($SCOMGateways.Agents.Count)")
    
foreach($SCOMGateway in $SCOMGateways){        

    # Create Group Instance
    [string]$SCOMGatewayPrincipalName    = $SCOMGateway.PrincipalName
    [string]$GWGroupDisplayName          = "Gateway Agent Group $SCOMGatewayPrincipalName"
    $SCOMGatewayHostedAgentsGroupInstance = $DiscoveryData.CreateClassInstance("$MPElement[Name='SCOM.Multihoming.Group.GatewayHostedAgents']$")
    $SCOMGatewayHostedAgentsGroupInstance.AddProperty("$MPElement[Name='SCOM.Multihoming.Group.GatewayHostedAgents']/Gateway$", $SCOMGatewayPrincipalName)
    $SCOMGatewayHostedAgentsGroupInstance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $GWGroupDisplayName)
    $DiscoveryData.AddInstance($SCOMGatewayHostedAgentsGroupInstance)
    if($LogEnabled -eq $true){$momapi.LogScriptEvent($ScriptName,$EventID,0,"`nAdd SCOM Gateway Multi-Homing Group`: $GWGroupDisplayName")}
    
        foreach($Agent in $SCOMGateway.Agents){
        [string]$AgentName = $Agent.PrincipalName
        $AgentInstance = $DiscoveryData.CreateClassInstance("$MPElement[Name='SC!Microsoft.SystemCenter.Agent']$")
        $AgentInstance.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $AgentName)
        $RelationshipInstance = $DiscoveryData.CreateRelationshipInstance("$MPElement[Name='MSIL!Microsoft.SystemCenter.InstanceGroupContainsEntities']$")
        $RelationshipInstance.Source = $SCOMGatewayHostedAgentsGroupInstance
        $RelationshipInstance.Target = $AgentInstance
        $DiscoveryData.AddInstance($RelationshipInstance)
    }  
    
}

# Log Script End
$ScriptEndTime = Get-Date
$ScriptEndTimeString = "{0:MM/dd/yyyy hh:mm:ss}" -f [datetime]$ScriptEndTime
$ScriptDuration = ($ScriptEndTime - $ScriptStartTime).TotalSeconds

$momapi.LogScriptEvent($ScriptName,$EventID,0,"`nScript has completed. `n Running as ($Whoami). `nDuration $ScriptDuration Seconds")

IF ($Error) { 
    $momapi.LogScriptEvent($ScriptName,$EventID,1,"`n FATAL ERROR: `n Error is: ($Error).")
}

$DiscoveryData