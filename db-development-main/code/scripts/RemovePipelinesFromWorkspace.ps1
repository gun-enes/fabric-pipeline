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

$PipelineNames = @(
    "failSafeEnd",
    "process_schedule_orders",
    "testFileFilteringForRestore",
    "TestDynatraceCalls",
    "BackupAllTables_grpDivision_1group_bckWithHeaders",
    "BackupAllTables_grpDivision_1group_sequential_bck",
    "BackupAllTables_grpDivision_2groups_bckWithHeaders",
    "BackupAllTables_grpDivision_2groups_sequential_bck",
    "BackupAllTables_grpDivision_4groups_bckWithHeaders",
    "BackupAllTables_grpDivision_4groups_sequential_bck",
    "RestoreAllTables_grpDivision_1group_Restore",
    "infra-maintenance-end",
    "infra-maintenance-resume-sqlpools",
    "infra-maintenance-start",
    "checkOptOutMode",
    "checkManagementTriggers",
    "checkActivePipelines",
    "infra-maintenance-pause-sqlpools",
    "infra-maintenance-start-triggers",
    "infra-maintenance-stop-triggers",
    "infra-create-downtime-triggers",
    "process_schedules",
    "infra-create-json-schedules",
    "infra-gatherstats-terminate",
    "infra-gatherstats-start",
    "failSafeStart",
    "infra_db_stats",
    "Infra_pipe_process_order",
    "infra_table_dist_report",
    "pl_permission_audit",
    "controlSQLPool",
    "checkSQLPoolStatus",
    "initializeVariables",
    "pl_root_fail_safe_start",
    "pl_infra_trigger_ms_maintenance",
    "DR_DB_BACKUP",
    "DR_DB_IMPORT",
    "pl_root_infra_db_stats"
)
$ExistingPipelinesNames = (Get-AzSynapsePipeline -WorkspaceName $SynapseWorkspaceName).Name

# Remove Given Pipelines
foreach ($PipelineName in $PipelineNames) {
    if ($ExistingPipelinesNames -contains $PipelineName){
        Write-Host "Removing Pipeline: $PipelineName"
        Remove-AzSynapsePipeline `
            -WorkspaceName $SynapseWorkspaceName `
            -Name $PipelineName `
            -Force `
            -Verbose
    }
}
