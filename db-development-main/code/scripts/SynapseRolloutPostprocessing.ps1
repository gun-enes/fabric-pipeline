# Define script arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $SubscriptionId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $SynapseWorkspaceName,

    [Parameter(Mandatory = $false, ValueFromRemainingArguments = $true)]
    [string[]]
    $Remaining
)

$ErrorActionPreference = "Stop"

Write-Output "Setting Azure context set to subscription ID '$($SubscriptionId)'."
# Set Azure Context
$context = Set-AzContext `
    -Subscription $SubscriptionId
Write-Output "Azure context set to subscription ID '$($context.Subscription.Id)'."

# Get Synapse Workspace
$workspace = Get-AzSynapseWorkspace `
    -Name $SynapseWorkspaceName
Write-Output "Workspace with ID '$($workspace.Id)' found."

Write-Output "Starting critical triggers."
$criticalTriggers = "trg_order_created","trg_schedule_created","trg_ms_maintenance_events"
foreach ($triggerName in $criticalTriggers) {
    & $PSScriptRoot/SynapseStartStopTriggers.ps1 -SynapseTriggerName $triggerName -SynapseWorkspaceName $SynapseWorkspaceName -Action "start"
}
Write-Output "Finished starting critical triggers."

Write-Output "Successfully ran post-processing for Azure Synapse Workspace '$($SynapseWorkspaceName)' in Azure subscription '$($SubscriptionId)' after rollout of changes."
