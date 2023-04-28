#=================================================================================
#  Multi-Home Agents to a new SCOM Management Group if not assigned to it yet
#
#  Author: Kevin Holman
#  v1.6
#=================================================================================
param([string]$MGtoADD, [string]$MStoASSIGN)

# Manual Testing section - put stuff here for manually testing script - typically parameters:
# $MGtoADD = "MGNAME"
# $MStoASSIGN = "ManagementServerName.domain.com"

# Constants section - modify stuff here:
# Assign script name variable for use in event logging.
$ScriptName = "Add-MultiHomeManagementGroup.ps1"
$EventID = "1300"

# Starting Script section - All scripts get this
# Gather the start time of the script
$StartTime = Get-Date
#Set variable to be used in logging events
$whoami = whoami
# Load MOMScript API
$momapi = New-Object -comObject MOM.ScriptAPI
#Log script event that we are starting task
$momapi.LogScriptEvent($ScriptName, $EventID, 0, "`nScript is starting. `n Running as ($whoami). `nParameters passed: `nMG to ADD: ($MGtoADD). `nMS to ASSIGN: ($MStoASSIGN).")

# Begin MAIN script section

#Check to see if defaults were not changed and stop
IF ($MGtoADD -eq "MGNAME" -or $MStoASSIGN -eq "ManagementServerName.domain.com") {
    #The default value for the management group name or management server name was not changed via override.  This is a misconfiguration.  Log critical event and terminate.
    $momapi.LogScriptEvent($ScriptName, $EventID, 1, "`nFATAL ERROR: Invalid MGNAME or MSNAME was used. `nMG to ADD: ($MGtoADD). `nMS to ASSIGN: ($MStoASSIGN). `nTerminating script.")
    EXIT
}

# Load SCOM Agent Scripting Module
$Error.Clear()
$AgentCfg = New-Object -ComObject "AgentConfigManager.MgmtSvcCfg"

IF ($Error) {
    #Error loading agent scripting object
    $momapi.LogScriptEvent($ScriptName, $EventID, 1, "`nFATAL ERROR: Attempting to load the SCOM Agent scripting objects. `nError is ($Error). `nTerminating script.")
    EXIT
}

# Get Agent Management groups
$MGs = $AgentCfg.GetManagementGroups()

IF (!($MGs)) {
    #No management groups were gathered.  Something broke.  Log critical event and terminate
    $momapi.LogScriptEvent($ScriptName, $EventID, 1, "`nFATAL ERROR: No management groups were found on this agent, which means a scripting error. `nTerminating script.")
    EXIT
}

[array]$MGListArr = @()
[string]$MGListStr = ""

#Loop through each and create an array and comma seperated list
foreach ($MG in $MGs) {
    $AgentMGName = $MG.managementGroupName.ToUpper()
    $MGListArr = $MGListArr + $AgentMGName
    $MGListStr = $MGListStr + $AgentMGName + ", "
}
$MGlistStr = $MGlistStr.TrimEnd(", ")


IF ($MGListArr -notcontains $MGtoADD) {
    #The agent is not multi-homed yet.  Multihome it.
    #Check to see how many management groups are already homed.
    $MGListCount = $MGListArr.Count
    IF ($MGListCount -ge 4) {
        #The agent is already multihomed to 4 management groups  Log a bad event and output the names of the MGs
        $momapi.LogScriptEvent($ScriptName, $EventID, 1, "`nFATAL ERROR: 4 Management Groups are already homed to this agent. No more can be added. `nTerminating script.")
        EXIT
    }
    ELSE {
        $momapi.LogScriptEvent($ScriptName, $EventID, 0, "`nMultihoming this agent to MG: ($MGtoADD) and MS: ($MStoASSIGN).")
        $AgentCfg.AddManagementGroup($MGtoADD, $MStoASSIGN, 5723)
        $RestartRequired = $true
    }
}
ELSE {
    #The agent is already multihomed to the intended management group. Do nothing. Log event.
    $momapi.LogScriptEvent($ScriptName, $EventID, 0, "`nThis agent is already multihomed to Management Group: ($MGtoADD). `nThe MG List on this agent is: ($MGlistStr). `nNo changes will be made.")
}
# End MAIN script section

# End of script section
#Log an event for script ending and total execution time.
$EndTime = Get-Date
$ScriptTime = ($EndTime - $StartTime).TotalSeconds
$momapi.LogScriptEvent($ScriptName, $EventID, 0, "`nScript Completed. `nScript Runtime: ($ScriptTime) seconds.")

IF ($RestartRequired) {
    # Restart Agent
    $momapi.LogScriptEvent($ScriptName, $EventID, 0, "`nA change to the agent management group membership was made and a restart of the agent is required. `nRestarting now.")
    #We need a reliable way to restart the SCOM Agent out of band so that tasks can complete with success
    $Command = "Start-Sleep -s 5;Restart-Service HealthService"
    $Process = ([wmiclass]"root\cimv2:Win32_ProcessStartup").CreateInstance()
    $Process.ShowWindow = 0
    $Process.CreateFlags = 16777216
    ([wmiclass]"root\cimv2:Win32_Process").Create("powershell.exe $Command") | Out-Null
}
