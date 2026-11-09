$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

function InvokeAndWaitForSynapsePipeline {
    param (
        [string]$WorkspaceName,
        [string]$PipelineName,
        [int]$TimeoutMinutes = 10
    )

    Write-Host "Triggering pipeline '$PipelineName' in workspace '$WorkspaceName'..."
    $run = Invoke-AzSynapsePipeline -WorkspaceName $WorkspaceName -PipelineName $PipelineName
    $runId = $run.RunId
    Write-Host "[$PipelineName] Run ID: $runId"

    $elapsed = 0
    do {
        Start-Sleep -Seconds 30
        $runStatus = Get-AzSynapsePipelineRun -WorkspaceName $WorkspaceName -PipelineRunId $runId
        Write-Host "[$PipelineName] Current status: $($runStatus.Status)"
        $elapsed += 30

        if ($elapsed -ge ($TimeoutMinutes * 60)) {
            throw "[$PipelineName] Pipeline timed out after $TimeoutMinutes minutes."
        }
    } while ($runStatus.Status -in ("InProgress", "Queued"))

    Write-Host "[$PipelineName] Final status: $($runStatus.Status)"
    if ($runStatus.Status -ne "Succeeded") {
        $errorMessage = $runStatus.Message
        $details = "[$PipelineName] Pipeline execution failed with status: $($runStatus.Status)"
        if ($errorMessage) {
            $details += "`nMessage: $errorMessage"
        }
        throw $details
    }

    Write-Host "[$PipelineName] Pipeline succeeded."
}
