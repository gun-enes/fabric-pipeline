# Define script arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $SynapseWorkspaceName,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [int]
    $CheckPastDaysOfPipelineRuns = 1,

    [Parameter(Mandatory = $false, ValueFromRemainingArguments = $true)]
    [string[]]
    $Remaining
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

# Get Timestamp
$timestamp = Get-Date -AsUTC

# Get Pipelines
# Get-AzSynapsePipeline fails to deserialize some pipelines, with error:
# The requested operation requires an element of type 'Number', but the target element has type 'String'.
# So the pipeline list is fetched directly via REST instead.
$pipelines = (& "./Invoke-RestMethodWithRetry.ps1" `
                -Method "GET" `
                -Uri "https://$($SynapseWorkspaceName).dev.azuresynapse.net/pipelines?api-version=2020-12-01").value
$pipelineNames = $pipelines.Name

Write-Host "Pipeline list: $($pipelineNames -join ',')"

# Get Pipeline Runs
foreach ($pipelineName in $pipelineNames) {
    Write-Output "Checking runs for pipeline '$($pipelineName)'."
    $pipelineRuns = Get-AzSynapsePipelineRun `
        -WorkspaceName $SynapseWorkspaceName `
        -PipelineName $pipelineName `
        -RunStartedAfter $timestamp.AddDays(-$CheckPastDaysOfPipelineRuns) `
        -RunStartedBefore $timestamp

    foreach ($pipelineRun in $pipelineRuns) {
        if ($pipelineRun.Status -eq "InProgress") {
            Write-Output "Pipeline with Name '$($pipelineName)' is still in progress (Run ID: '$($pipelineRun.RunId)'). Waiting for pipeline to complete run."

            do {
                # Sleep for 1 second
                Start-Sleep -Seconds 1

                # Get status of pipeline run
                $pipelineRun = Get-AzSynapsePipelineRun `
                    -WorkspaceName $SynapseWorkspaceName `
                    -PipelineRunId $pipelineRun.RunId
            } while (
                $pipelineRun.Status -eq "InProgress"
            )

            Write-Output "Pipeline with Name '$($pipelineName)' completed with status '$($pipelineRun.Status)' (Run ID: '$($pipelineRun.RunId)')."
        }
    }
}
