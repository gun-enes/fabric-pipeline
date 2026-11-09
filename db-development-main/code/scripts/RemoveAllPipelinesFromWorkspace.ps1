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

do {

    $pipelines = Get-AzSynapsePipeline -WorkspaceName $SynapseWorkspaceName
    if($pipelines.Count -gt 0){
        $allNames = $pipelines.Name
        Write-Host "All available pipeline names: $allNames"

        $excludeNames = $pipelines.Activities.Pipeline.ReferenceName +
            $pipelines.Activities.IfTrueActivities.Pipeline.ReferenceName +
            $pipelines.Activities.IfFalseActivities.Pipeline.ReferenceName +
            $pipelines.Activities.Activities.Pipeline.ReferenceName +
            $pipelines.Activities.Activities.IfFalseActivities.Pipeline.ReferenceName +
            $pipelines.Activities.Activities.IfTrueActivities.Pipeline.ReferenceName
        Write-Host "Referenced pipeline names: $excludeNames"

        $removeList = $allNames | Where {$_ -notin $excludeNames}
        Write-Host "Following pipelines will be removed in this batch: $removeList"

        # Remove Pipelines
        foreach ($PipelineName in $removeList) {
            # Get Synapse Pipeline
            Write-Host "Reading Pipeline '$($PipelineName)' from Synapse Workspace '$($SynapseWorkspaceName)'"
            $pipeline = & "./Invoke-RestMethodWithRetry.ps1" `
                -Method "GET" `
                -Uri "https://$($SynapseWorkspaceName).dev.azuresynapse.net/pipelines/$($PipelineName)?api-version=2020-12-01"

            Write-Host "Removing Pipeline: $($pipeline.Name)"
            try{
                $response = & "./Invoke-RestMethodWithRetry.ps1" `
                    -Method DELETE `
                    -Uri "https://$($SynapseWorkspaceName).dev.azuresynapse.net/pipelines/$($pipeline.Name)?api-version=2020-12-01"
                Write-Host "Delete Pipeline '$($pipeline.Name)' successfully."
            } catch {
                throw "Failed to delete Pipeline '$($pipeline.Name)'.", $_
            }
        }
        Start-Sleep -Seconds 5
    }
} while (
    $pipelines.Count -gt 0
)
