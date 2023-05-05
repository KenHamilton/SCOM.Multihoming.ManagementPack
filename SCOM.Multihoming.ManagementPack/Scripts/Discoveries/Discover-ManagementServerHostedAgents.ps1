param(
    $sourceId,
    $managedEntityId
)

# Clear any previous errors
$Error.Clear()

#Defaults
$MOMapi = new-object -comObject "MOM.ScriptAPI"
$EventID = "1321"
$Whoami = WhoAmI
$ScriptStartTime = Get-Date
$ScriptStartTimeString = "{0:MM/dd/yyyy hh:mm:ss}" -f [datetime]$ScriptStartTime
#$RMSeManagementServer = "csovscom1.oceania.cshare.net"
$LogEnabled = $true
$ScriptName = "Discover-ManagementServerHostedAgents.ps1"

# Log Script Start
$momapi.LogScriptEvent($ScriptName,$EventID,0,"`nScript is starting. `n Running as ($Whoami). `nStart Time $ScriptStartTimeString")

# Load SCOM PowerShell Module and connect to Management Group
Import-Module OperationsManager
$momapi.LogScriptEvent($ScriptName,$EventID,0,"`nConnecting to SCOM ManagementGroup")

$DiscoveryData = $MOMapi.CreateDiscoveryData(0, $SourceId, $ManagedEntityId)

# Collect ManagementServers and associated Agents
$momapi.LogScriptEvent($ScriptName,$EventID,0,"`nCollecting Management Servers and associated agents")
$SCOMManagementServers = Get-SCOMManagementServer | Where-object{$_.IsGateway -eq $false} | Sort-Object PrincipalName | Select *, @{Label="Agents";Exp={Get-SCOMAgent -ManagementServer $_}}
$SCOMManagementServerNames = $SCOMManagementServers.PrincipalName | Out-String
$momapi.LogScriptEvent($ScriptName,$EventID,0,"`nSCOM Management Servers`: $($SCOMManagementServers.Count)`n$SCOMManagementServerNames`nTotal Agents`: $($SCOMManagementServers.Agents.Count)")
    
foreach($SCOMManagementServer in $SCOMManagementServers){        

    # Create Group Instance
    [string]$SCOMManagementServerPrincipalName    = $SCOMManagementServer.PrincipalName
    [string]$MSGroupDisplayName          = "Management Server Agent Group $SCOMManagementServerPrincipalName"
    $SCOMManagementServerHostedAgentsGroupInstance = $DiscoveryData.CreateClassInstance("$MPElement[Name='SCOM.Modular.Multihoming.Group.ManagementServerHostedAgents']$")
    $SCOMManagementServerHostedAgentsGroupInstance.AddProperty("$MPElement[Name='SCOM.Modular.Multihoming.Group.ManagementServerHostedAgents']/ManagementServer$", $SCOMManagementServerPrincipalName)
    $SCOMManagementServerHostedAgentsGroupInstance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $MSGroupDisplayName)
    $DiscoveryData.AddInstance($SCOMManagementServerHostedAgentsGroupInstance)
    if($LogEnabled -eq $true){$momapi.LogScriptEvent($ScriptName,$EventID,0,"`nAdd SCOM ManagementServer Multi-Homing Group`: $MSGroupDisplayName")}
    
        foreach($Agent in $SCOMManagementServer.Agents){
        [string]$AgentName = $Agent.PrincipalName
        $AgentInstance = $DiscoveryData.CreateClassInstance("$MPElement[Name='SC!Microsoft.SystemCenter.Agent']$")
        $AgentInstance.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $AgentName)
        $RelationshipInstance = $DiscoveryData.CreateRelationshipInstance("$MPElement[Name='MSIL!Microsoft.SystemCenter.InstanceGroupContainsEntities']$")
        $RelationshipInstance.Source = $SCOMManagementServerHostedAgentsGroupInstance
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