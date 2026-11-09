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

$TriggerNames = "maintenance_start_trigger","maintenance_end_trigger" `
    ,"Trg_SP_Infra_process_order","TRG_DB_DR_BACKUP","Trg_Infra_DB_Stats_runner" `
    ,"Trg_infra_table_dist_report","trg_permission_audit_runner","generate_maintenance_schedule_trigger"
$ExistingTriggers = Get-AzSynapseTrigger -WorkspaceName $SynapseWorkspaceName

# Remove Given Triggers
foreach ($TriggerName in $TriggerNames) {
    $Trigger = $ExistingTriggers |  Where-Object { $_.Name -eq $TriggerName }
    if ($null -ne $Trigger){
        #Triggers need to be in the Stopped state for them to be deletable
        & "./SynapseStartStopTriggers.ps1" `
            -SynapseTriggerName $Trigger.Name `
            -SynapseWorkspaceName $SynapseWorkspaceName `
            -Action "stop"

        Write-Host "Removing Trigger: $TriggerName"
        Remove-AzSynapseTrigger `
            -WorkspaceName $SynapseWorkspaceName `
            -Name $TriggerName `
            -Force `
            -Verbose
    }
}
