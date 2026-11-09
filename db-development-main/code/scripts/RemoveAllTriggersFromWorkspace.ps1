[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $SynapseWorkspaceName,

    [Parameter(Mandatory = $false, ValueFromRemainingArguments = $true)]
    [string[]]
    $Remaining
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$ExistingTriggers = Get-AzSynapseTrigger -WorkspaceName $SynapseWorkspaceName

# Remove Given Triggers
foreach ($Trigger in $ExistingTriggers.Name) {
        # Triggers need to be in the Stopped state for them to be deletable
    & "./SynapseStartStopTriggers.ps1" `
        -SynapseTriggerName $Trigger `
        -SynapseWorkspaceName $SynapseWorkspaceName `
        -Action "stop"

    # Get Synapse Trigger
    Write-Host "Reading Trigger '$($Trigger)' from Synapse Workspace '$($SynapseWorkspaceName)'"
    $trigger = & "./Invoke-RestMethodWithRetry.ps1" `
        -Method "GET" `
        -Uri "https://$($SynapseWorkspaceName).dev.azuresynapse.net/triggers/$($Trigger)?api-version=2020-12-01"

    Write-Host "Checking Trigger '$($trigger.Name)' with status $($trigger.Properties.RuntimeState)"

    Write-Host "Removing Trigger: $($trigger.Name)"
    try{
        $response = & "./Invoke-RestMethodWithRetry.ps1" `
            -Method DELETE `
            -Uri "https://$($SynapseWorkspaceName).dev.azuresynapse.net/triggers/$($trigger.Name)?api-version=2020-12-01"
        Write-Host "Delete Trigger '$($trigger.Name)' successfully."
    } catch {
        throw "Failed to delete trigger '$($trigger.Name)'.", $_
    }
}
