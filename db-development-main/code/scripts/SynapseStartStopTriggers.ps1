# Define script arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $SynapseTriggerName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $SynapseWorkspaceName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet("start", "stop")]
    [string]
    $Action,

    [Parameter(Mandatory = $false, ValueFromRemainingArguments = $true)]
    [string[]]
    $Remaining
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

# Get Synapse Trigger
Write-Host "Reading Trigger '$($SynapseTriggerName)' from Synapse Workspace '$($SynapseWorkspaceName)'"
$trigger = & "./Invoke-RestMethodWithRetry.ps1" `
    -Method "GET" `
    -Uri "https://$($SynapseWorkspaceName).dev.azuresynapse.net/triggers/$($SynapseTriggerName)?api-version=2020-12-01"

Write-Host "Checking Trigger '$($trigger.Name)' with status $($trigger.Properties.RuntimeState)"

if (($trigger.Properties.RuntimeState -eq "Started" -and $Action -eq "stop") -or ($trigger.Properties.RuntimeState -ne "Started" -and $Action -eq "start")) {
    Write-Host "$($Action) Trigger '$($trigger.Name)'"

    # Both options are currently failing: https://github.com/Azure/azure-powershell/issues/16368
    # $success = Stop-AzSynapseTrigger `
    #     -WorkspaceName $SynapseWorkspaceName `
    #     -Name $trigger.Name -Verbose -AsJob
    # $trigger | Stop-AzSynapseTrigger

    # Workaround: Call API Endpoint manually

    try{
        $response = & "./Invoke-RestMethodWithRetry.ps1" `
            -Method POST `
            -Uri "https://$($SynapseWorkspaceName).dev.azuresynapse.net/triggers/$($trigger.Name)/$($Action)?api-version=2020-12-01" `
            -MaxRetries 5
        Write-Host "$($Action) Trigger '$($trigger.Name)' successfully."
        if($Action -eq "start") {
            return "started";
        } else {
            return "stopped";
        }
    } catch {
        throw "Failed to $($Action) trigger '$($trigger.Name)'.", $_
    }
}
