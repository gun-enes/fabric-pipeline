BeforeAll {
    function Test-pl_root_infra_maintenance_start () {
        $beforePipelineStart = Get-Date
        try{
            . "./InvokeAndWaitForSynapsePipeline.ps1"
            InvokeAndWaitForSynapsePipeline -WorkspaceName "synw-tdp-e2e001-dev-mgmt" -PipelineName "pl_root_infra_maintenance_start" -TimeoutMinutes 40
        }
        catch{
            Write-Host "exception: $_"
        }

        $afterPipelineFinish = Get-Date

        $sqlPool = Get-AzSynapseSqlPool -WorkspaceName "synw-tdp-e2e001-dev-mgmt" -Name "sqlPool001"
        $pipelineRun = Get-AzSynapsePipelineRun -WorkspaceName "synw-tdp-e2e001-dev-mgmt" -RunStartedAfter $beforePipelineStart -RunStartedBefore $afterPipelineFinish -PipelineName "pl_root_infra_maintenance_start"

        @{
            runStatus = $pipelineRun.Status
            poolState = $sqlPool.Status
        }
    }

    function Test-pl_root_infra_maintenance_end () {
        $beforePipelineStart = Get-Date
        try{
            . "./InvokeAndWaitForSynapsePipeline.ps1"
            InvokeAndWaitForSynapsePipeline -WorkspaceName "synw-tdp-e2e001-dev-mgmt" -PipelineName "pl_root_infra_maintenance_end" -TimeoutMinutes 40
        }
        catch{
            Write-Host "exception: $_"
        }
        $afterPipelineFinish = Get-Date

        $sqlPool = Get-AzSynapseSqlPool -WorkspaceName "synw-tdp-e2e001-dev-mgmt" -Name "sqlPool001"
        $pipelineRun = Get-AzSynapsePipelineRun -WorkspaceName "synw-tdp-e2e001-dev-mgmt" -RunStartedAfter $beforePipelineStart -RunStartedBefore $afterPipelineFinish -PipelineName "pl_root_infra_maintenance_end"

        @{
            runStatus = $pipelineRun.Status
            poolState = $sqlPool.Status
        }
    }

    function Test-pl_root_infra_pipe_process_order () {
        $beforePipelineStart = Get-Date

        Invoke-Sqlcmd `
            -ConnectionString "$env:SQL_CONNECTION_STRING" `
            -Query "EXEC [mgmt_xtinfra].[sp_infra_schema_order_create_or_update] 'tdp_core', 'synapse_tst';"

        do {
            Start-Sleep -Seconds 10
            $afterPipelineInvoked = Get-Date
            $pipelineRun = Get-AzSynapsePipelineRun -WorkspaceName "synw-tdp-e2e001-dev-mgmt" -RunStartedAfter $beforePipelineStart -RunStartedBefore $afterPipelineInvoked -PipelineName "pl_root_infra_pipe_process_order"
        } while($pipelineRun -eq $null)

        while ($pipelineRun.Status -in ("InProgress", "Queued")){
            Start-Sleep -Seconds 10
            $pipelineRun = Get-AzSynapsePipelineRun -WorkspaceName "synw-tdp-e2e001-dev-mgmt" -PipelineRunId $pipelineRun.RunId
            Write-Host "Current pipeline status: $($pipelineRun.Status)"
            $elapsed += 10

            if ($elapsed -ge 1200) {
                throw "Pipeline pl_root_infra_pipe_process_order timed out after 20 minutes."
            }
        }

        $schemaCreated = Invoke-Sqlcmd `
            -ConnectionString "$env:SQL_CONNECTION_STRING" `
            -Query "SELECT 1 FROM [sys].[schemas] WHERE [name] = 'tdp_core_synapse_tst';"

        if($schemaCreated.Count -gt 0){
            Write-Host "Schema exists"
            $schemaExists = $true
        }
        else{
            Write-Host "Schema does NOT exist"
            $schemaExists = $false
        }

        @{
            runStatus = $pipelineRun.Status
            processingCompleted = $schemaExists
        }
    }

    function Test-pl_root_infra_create_downtime_triggers () {
        $beforePipelineStart = Get-Date
        $triggerHour = $beforePipelineStart.Hour

        Invoke-Sqlcmd `
            -ConnectionString "$env:SQL_CONNECTION_STRING" `
            -Query "EXEC [mgmt_xtinfra].[sp_infra_schedule_create] 'synapse_tst_schedule', 'start', $triggerHour, '*', '*', '*', 1000, 'tdp_core';"

        do{
            Start-Sleep -Seconds 10
            $afterPipelineInvoked = Get-Date
            $pipelineRun = Get-AzSynapsePipelineRun -WorkspaceName "synw-tdp-e2e001-dev-mgmt" -RunStartedAfter $beforePipelineStart -RunStartedBefore $afterPipelineInvoked -PipelineName "pl_root_infra_create_downtime_triggers"
        } while($pipelineRun -eq $null)

        while ($pipelineRun.Status -in ("InProgress", "Queued")){
            Start-Sleep -Seconds 10
            $pipelineRun = Get-AzSynapsePipelineRun -WorkspaceName "synw-tdp-e2e001-dev-mgmt" -PipelineRunId $pipelineRun.RunId
            Write-Host "Current pipeline status: $($pipelineRun.Status)"
            $elapsed += 10

            if ($elapsed -ge 1200) {
                throw "Pipeline pl_root_infra_create_downtime_triggers timed out after 20 minutes."
            }
        }

        $maintenanceTriggers = Get-AzSynapseTrigger -WorkspaceName "synw-tdp-e2e001-dev-mgmt" | Where {$_.Name.StartsWith("trg_maintenance_stop_")}

        $triggerTypeCheck = $maintenanceTriggers | Where-Object {$_.Properties.ToString() -ne "Azure.Analytics.Synapse.Artifacts.Models.ScheduleTrigger"}
        $triggerStateCheck = $maintenanceTriggers | Where-Object {$_.Properties.RuntimeState -ne "Started"}
        $triggerPipelineCheck = $maintenanceTriggers | Where-Object {$_.Properties.Pipelines.PipelineReference.ReferenceName -ne "pl_root_infra_maintenance_end"}
        $triggerHourCheck = $maintenanceTriggers | Where-Object {$_.Properties.Recurrence.Schedule.Hours -ne $triggerHour}

        $results = Invoke-Sqlcmd `
            -ConnectionString "$env:SQL_CONNECTION_STRING" `
            -Query "SELECT * FROM [mgmt_xtinfra].[infra_expanded_schedule] WHERE [key] = 'synapse_tst_schedule' AND [schedule_action] = 'start' ORDER BY [schedule_time] ASC;"

        $expectedDates = 1..30 | ForEach-Object { ($beforePipelineStart).AddDays($_).ToString("yyyy-MM-ddTHH:00:00Z") }
        $createdDates = $results | Select-Object -ExpandProperty schedule_time
        Write-Host "Created dates: $createdDates"
        Write-Host "ExpectedDates: $expectedDates"

        $expandedScheduleCheck = $true
        for ($i = 0; $i -lt $createdDates.Count; $i++) {
            if ($createdDates[$i] -ne $expectedDates[$i]) {
                Write-Host "  createdDates: $($createdDates[$i])"
                Write-Host "  expectedDates: $($expectedDates[$i])"
                $expandedScheduleCheck = $false
            }
        }

        @{
            runStatus = $pipelineRun.Status
            datesExists = $expandedScheduleCheck
            typeControl = $triggerTypeCheck.Count
            stateControl = $triggerStateCheck.Count
            pipelineControl = $triggerPipelineCheck.Count
            hourControl = $triggerHourCheck.Count
        }
    }

    function Test-Triggers () {
        $ExistingTriggers = Get-AzSynapseTrigger -WorkspaceName "synw-tdp-e2e001-dev-mgmt"

        $trg_dispatch = $ExistingTriggers | Where {$_.Name -eq "trg_dispatch"}
        $trg_dispatchType = $trg_dispatch.Properties.ToString()
        $trg_dispatchState = $trg_dispatch.Properties.RuntimeState
        $trg_dispatchHour = $trg_dispatch.Properties.Recurrence.Schedule.Hours

        $results = Invoke-Sqlcmd `
            -ConnectionString "$env:SQL_CONNECTION_STRING" `
            -Query "SELECT * FROM [mgmt_xtinfra].[infra_expanded_schedule] WHERE [schedule_action] = 'start';"
        $createdDates = $results | Select-Object -ExpandProperty schedule_time
        $trg_dispatchDates = $createdDates | Where {$_.DayOfWeek -in ("Tuesday","Friday") -and $_ -le (Get-Date).AddDays(7)}
        Write-Host "trg_dispatch dates: $trg_dispatchDates"

        if($trg_dispatchDates.Count -gt 0){
            $trg_dispatchHourCheck = $trg_dispatchHour -in $trg_dispatchDates
        }
        else{
            $trg_dispatchHourCheck = $trg_dispatchHour -eq 12
        }


        $trg_schedule_created = $ExistingTriggers | Where {$_.Name -eq "trg_schedule_created"}
        $trg_schedule_createdType = $trg_schedule_created.Properties.ToString()
        $trg_schedule_createdState = $trg_schedule_created.Properties.RuntimeState

        $trg_order_created = $ExistingTriggers | Where {$_.Name -eq "trg_order_created"}
        $trg_order_createdType = $trg_order_created.Properties.ToString()
        $trg_order_createdState = $trg_order_created.Properties.RuntimeState

        $trg_ms_maintenance_events = $ExistingTriggers | Where {$_.Name -eq "trg_ms_maintenance_events"}
        $trg_ms_maintenance_eventsType = $trg_ms_maintenance_events.Properties.ToString()
        $trg_ms_maintenance_eventsState = $trg_ms_maintenance_events.Properties.RuntimeState

        @{
            trg_dispatchType = $trg_dispatchType
            trg_dispatchState = $trg_dispatchState
            trg_dispatchHourControl = $trg_dispatchHourCheck
            trg_schedule_createdType = $trg_schedule_createdType
            trg_schedule_createdState = $trg_schedule_createdState
            trg_order_createdType = $trg_order_createdType
            trg_order_createdState = $trg_order_createdState
            trg_ms_maintenance_eventsType = $trg_ms_maintenance_eventsType
            trg_ms_maintenance_eventsState = $trg_ms_maintenance_eventsState
        }

    }
}

Describe 'Test-Synapse-Artifacts' {
    It 'Validates workspace triggers' {
        $pipelineResult = Test-Triggers
        $pipelineResult.trg_dispatchType | Should -Be "Azure.Analytics.Synapse.Artifacts.Models.ScheduleTrigger"
        $pipelineResult.trg_dispatchState | Should -Be "Started"
        $pipelineResult.trg_dispatchHourControl | Should -Be $true
        $pipelineResult.trg_schedule_createdType | Should -Be "Azure.Analytics.Synapse.Artifacts.Models.BlobEventsTrigger"
        $pipelineResult.trg_schedule_createdState | Should -Be "Started"
        $pipelineResult.trg_order_createdType | Should -Be "Azure.Analytics.Synapse.Artifacts.Models.BlobEventsTrigger"
        $pipelineResult.trg_order_createdState | Should -Be "Started"
        $pipelineResult.trg_ms_maintenance_eventsState | Should -Be "Started"
        $pipelineResult.trg_ms_maintenance_eventsType | Should -Be "Azure.Analytics.Synapse.Artifacts.Models.BlobEventsTrigger"
    }


    It 'Executes pl_root_infra_maintenance_start pipeline and validate results' {
        $pipelineResult = Test-pl_root_infra_maintenance_start
        $pipelineResult.runStatus | Should -Be "Succeeded"
        $pipelineResult.poolState | Should -Be "Paused"
    }

    It 'Executes pl_root_infra_maintenance_end pipeline and validate results' {
        $pipelineResult = Test-pl_root_infra_maintenance_end
        $pipelineResult.runStatus | Should -Be "Succeeded"
        $pipelineResult.poolState | Should -Be "Online"
    }

    Context "pl_root_infra_pipe_process_order" {
        It 'Executes pl_root_infra_pipe_process_order pipeline and validate results' {
            $pipelineResult = Test-pl_root_infra_pipe_process_order
            $pipelineResult.runStatus | Should -Be "Succeeded"
            $pipelineResult.processingCompleted | Should -Be $true
        }

        AfterAll {
            Invoke-Sqlcmd `
            -ConnectionString "$env:SQL_CONNECTION_STRING" `
            -Query "EXEC [mgmt_xtinfra].[sp_infra_schemalink_run_to_version] 'downgrade', 9999, 0, 'tdp_core', 'reader', 'tdp_core_synapse_tst', 'reader';
            EXEC [mgmt_xtinfra].[sp_infra_schemalink_run_to_version] 'downgrade', 9999, 0, 'tdp_core', 'writer', 'tdp_core_synapse_tst', 'writer';
            EXEC [mgmt_xtinfra].[sp_infra_schemalink_run_to_version] 'downgrade', 9999, 0, 'tdp_core', 'deployer', 'tdp_core_synapse_tst', 'deployer';
            EXEC [mgmt_xtinfra].[sp_infra_schema_run_to_version] 'downgrade', 9999, 0, 'tdp_core_synapse_tst';"
        }
    }

    Context "pl_root_infra_create_downtime_triggers" {
        It 'Executes pl_root_infra_create_downtime_triggers pipeline and validate results' {
            $pipelineResult = Test-pl_root_infra_create_downtime_triggers
            $pipelineResult.runStatus | Should -Be "Succeeded"
            $pipelineResult.datesExists | Should -Be $true
            $pipelineResult.typeControl | Should -Be 0
            $pipelineResult.stateControl | Should -Be 0
            $pipelineResult.pipelineControl | Should -Be 0
            $pipelineResult.hourControl | Should -Be 0
        }

        AfterAll {
            Invoke-Sqlcmd `
            -ConnectionString "$env:SQL_CONNECTION_STRING" `
            -Query "DELETE FROM [mgmt_xtinfra].[infra_schedule] WHERE [key] = 'synapse_tst_schedule'; DELETE FROM [mgmt_xtinfra].[infra_expanded_schedule] WHERE [key] = 'synapse_tst_schedule';"

            $maintenanceTriggers = Get-AzSynapseTrigger -WorkspaceName "synw-tdp-e2e001-dev-mgmt" | Where {$_.Name.StartsWith("trg_maintenance_stop_")}
            $maintenanceTriggers | Stop-AzSynapseTrigger
            $maintenanceTriggers | Remove-AzSynapseTrigger -Force
        }
    }
}
