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

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [int]
    $CheckPastDaysOfPipelineRuns = 1,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [bool]
    $WaitForPipelineRuns = $true,

    [Parameter(Mandatory = $false, ValueFromRemainingArguments = $true)]
    [string[]]
    $Remaining
)

try {
    $ErrorActionPreference = "Stop"

    # Set Azure Context
    Write-Output "Setting Azure context set to subscription ID '$($SubscriptionId)'."
    $context = Set-AzContext `
        -Subscription $SubscriptionId
    Write-Output "Azure context set to subscription ID '$($context.Subscription.Id)'."

    # Get Synapse Workspace
    $workspace = Get-AzSynapseWorkspace `
        -Name $SynapseWorkspaceName
    Write-Output "Workspace with ID '$($workspace.Id)' found."

    # Get Synapse Triggers
    $triggers = Get-AzSynapseTrigger `
        -WorkspaceName $SynapseWorkspaceName
    $triggerNames = @()
    $stoppedTriggerNames = @()

    # Stop all triggers
    foreach ($trigger in $triggers) {
        $stopped = & $PSScriptRoot/SynapseStartStopTriggers.ps1 -SynapseTriggerName ($trigger).Name -SynapseWorkspaceName $SynapseWorkspaceName -Action "stop"
        if ($stopped -eq "stopped") {
            $stoppedTriggerNames += $trigger.Name
        }
        # Append to List of Trigger names
        $triggerNames += $trigger.Name
    }
    if ($WaitForPipelineRuns -eq $true) {
        & $PSScriptRoot/SynapseWaitForPipelines.ps1 -SynapseWorkspaceName $SynapseWorkspaceName -CheckPastDaysOfPipelineRuns $CheckPastDaysOfPipelineRuns
    }
    Write-Output "Successfully prepared Azure Synapse Workspace '$($SynapseWorkspaceName)' in Azure subscription '$($SubscriptionId)' for rollout of changes."
}
finally {
    # Print stopped trigger names
    $triggerNamesOutput = $triggerNames -join ","
    Write-Output "Triggers: $($triggerNamesOutput)"

    # Print out stopped trigger names
    $stoppedTriggerNamesOutput = $stoppedTriggerNames -join ","
    Write-Output "Stopped Triggers: $($stoppedTriggerNamesOutput)"
}
