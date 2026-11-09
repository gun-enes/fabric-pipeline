BEGIN
    -- IDENTITY CONFIG
    TRUNCATE TABLE [mgmt_xtinfra].[infra_workspace_identity_config]

    -- insert mgmt identities
    INSERT INTO [mgmt_xtinfra].[infra_workspace_identity_config] (
        [admin_group_name],
        [contributor_group_name],
        [operations_group_name],
        [reader_group_name],
        [service_principal_name],
        [service_principal_name_tf_plan],
        [synapse_workspace_msi_name],
        [workspace_name],
        [workspace_type],
        [type_index]
    )
    SELECT
        [admin_group_name],
        [contributor_group_name],
        [operations_group_name],
        [reader_group_name],
        [service_principal_name],
        [service_principal_name_tf_plan],
        [synapse_workspace_msi_name],
        'management',
        'management',
        1
    FROM
        OPENJSON (@mgmt_json) WITH (
            [admin_group_name] nvarchar(128) '$.identity.admin_group_name',
            [contributor_group_name] nvarchar(128) '$.identity.contributor_group_name',
            [operations_group_name] nvarchar(128) '$.identity.operations_group_name',
            [reader_group_name] nvarchar(128) '$.identity.reader_group_name',
            [service_principal_name] nvarchar(128) '$.identity.service_principal_name',
            [service_principal_name_tf_plan] nvarchar(128) '$.identity.service_principal_name_tf_plan',
            [synapse_workspace_msi_name] nvarchar(128) '$.identity.synapse_workspace_msi_name'
        )

    -- insert core identities
    INSERT INTO [mgmt_xtinfra].[infra_workspace_identity_config] (
        [admin_group_name],
        [contributor_group_name],
        [operations_group_name],
        [reader_group_name],
        [service_principal_name],
        [synapse_workspace_msi_name],
        [actions_group_name],
        [workspace_name],
        [workspace_type],
        [type_index]
    )
    SELECT
        [admin_group_name],
        [contributor_group_name],
        [operations_group_name],
        [reader_group_name],
        [service_principal_name],
        [synapse_workspace_msi_name],
        [actions_group_name],
        [name],
        'core',
        1
    FROM
        OPENJSON (@core_json) WITH (
            [admin_group_name] nvarchar(128) '$.identity.admin_group_name',
            [contributor_group_name] nvarchar(128) '$.identity.contributor_group_name',
            [operations_group_name] nvarchar(128) '$.identity.operations_group_name',
            [reader_group_name] nvarchar(128) '$.identity.reader_group_name',
            [service_principal_name] nvarchar(128) '$.identity.service_principal_name',
            [synapse_workspace_msi_name] nvarchar(128) '$.identity.synapse_workspace_msi_name',
            [actions_group_name] nvarchar(128) '$.identity.actions_group_name',
            [name] nvarchar(MAX) '$.app_schema[0]'
        )

    -- insert ext identities
    INSERT INTO [mgmt_xtinfra].[infra_workspace_identity_config] (
        [admin_group_name],
        [contributor_group_name],
        [operations_group_name],
        [reader_group_name],
        [service_principal_name],
        [synapse_workspace_msi_name],
        [workspace_name],
        [workspace_type],
        [type_index]
    )
    SELECT
        [admin_group_name],
        [contributor_group_name],
        [operations_group_name],
        [reader_group_name],
        [service_principal_name],
        [synapse_workspace_msi_name],
        [name],
        'extension',
        ROW_NUMBER() OVER (ORDER BY [name] ASC)
    FROM
        OPENJSON (@ext_json) WITH (
            [admin_group_name] nvarchar(128) '$.identity.admin_group_name',
            [contributor_group_name] nvarchar(128) '$.identity.contributor_group_name',
            [operations_group_name] nvarchar(128) '$.identity.operations_group_name',
            [reader_group_name] nvarchar(128) '$.identity.reader_group_name',
            [service_principal_name] nvarchar(128) '$.identity.service_principal_name',
            [synapse_workspace_msi_name] nvarchar(128) '$.identity.synapse_workspace_msi_name',
            [name] nvarchar(MAX) '$.ext_schema_name[0]'
        )

    -- REPORTING GROUP CONFIG
    TRUNCATE TABLE [mgmt_xtinfra].[infra_workspace_reporting_groups_config]

    -- insert mgmt reporting group members
    INSERT INTO [mgmt_xtinfra].[infra_workspace_reporting_groups_config] (
        [reporting_group_name],
        [workspace_name],
        [workspace_type],
        [type_index]
    )
    SELECT
        [reporting_group_name],
        'management',
        'management',
        ROW_NUMBER() OVER (ORDER BY [reporting_group_name] ASC)
    FROM
        OPENJSON (@mgmt_json, '$.identity.reporting_group_name') WITH (
            [reporting_group_name] nvarchar(128) '$'
        )

    -- insert core reporting group members
    INSERT INTO [mgmt_xtinfra].[infra_workspace_reporting_groups_config] (
        [reporting_group_name],
        [workspace_name],
        [workspace_type],
        [type_index]
    )
    SELECT
        [rg].[reporting_group_name],
        [cr].[workspace_name],
        'core',
        ROW_NUMBER() OVER (ORDER BY [rg].[reporting_group_name] ASC)
    FROM
        OPENJSON (@core_json) WITH (
            [reporting_groups] nvarchar(MAX) '$.identity.reporting_group_name' AS JSON,
            [workspace_name] nvarchar(128) '$.app_schema[0]'
        ) AS [cr]
    CROSS APPLY
        OPENJSON ([cr].[reporting_groups]) WITH (
            [reporting_group_name] nvarchar(128) '$'
        ) AS [rg]

    -- insert ext reporting group members
    INSERT INTO [mgmt_xtinfra].[infra_workspace_reporting_groups_config] (
        [reporting_group_name],
        [workspace_name],
        [workspace_type],
        [type_index]
    )
    SELECT
        [rg].[reporting_group_name],
        [ext].[workspace_name],
        'extension',
        ROW_NUMBER() OVER (PARTITION BY [ext].[workspace_name] ORDER BY [rg].[reporting_group_name] ASC)
    FROM
        OPENJSON (@ext_json) WITH (
            [reporting_groups] nvarchar(MAX) '$.identity.reporting_group_name' AS JSON,
            [workspace_name] nvarchar(128) '$.ext_schema_name[0]'
        ) AS [ext]
    CROSS APPLY
        OPENJSON ([ext].[reporting_groups]) WITH (
            [reporting_group_name] nvarchar(128) '$'
        ) AS [rg]

    -- STORAGE CONFIG
    TRUNCATE TABLE [mgmt_xtinfra].[infra_workspace_storage_config]

    -- insert mgmt storage details
    INSERT INTO [mgmt_xtinfra].[infra_workspace_storage_config] (
        [eds_name],
        [account_name],
        [container_name],
        [workspace_name]
    )
    SELECT
        [eds_name],
        [account_name],
        [container_name],
        'management'
    FROM
        OPENJSON (@mgmt_json, '$.storage') WITH (
            [eds_name] nvarchar(128) '$.name',
            [account_name] nvarchar(128) '$.account_name',
            [container_name] nvarchar(128) '$.container_name'
        )

    -- insert core storage details
    INSERT INTO [mgmt_xtinfra].[infra_workspace_storage_config] (
        [eds_name],
        [account_name],
        [container_name],
        [workspace_name]
    )
    SELECT
        [strg].[eds_name],
        [strg].[account_name],
        [strg].[container_name],
        [cr].[name]
    FROM
        OPENJSON (@core_json) WITH (
            [storage] nvarchar(MAX) '$.storage' AS JSON,
            [name] nvarchar(128) '$.app_schema[0]'
        ) AS [cr]
    CROSS APPLY
        OPENJSON ([cr].[storage]) WITH (
            [eds_name] nvarchar(128) '$.name',
            [account_name] nvarchar(128) '$.account_name',
            [container_name] nvarchar(128) '$.container_name'
        ) AS [strg]

    -- insert ext storage details
    INSERT INTO [mgmt_xtinfra].[infra_workspace_storage_config] (
        [eds_name],
        [account_name],
        [container_name],
        [workspace_name]
    )
    SELECT
        [strg].[eds_name],
        [strg].[account_name],
        [strg].[container_name],
        [ext].[name]
    FROM
        OPENJSON (@ext_json) WITH (
            [storage] nvarchar(MAX) '$.storage' AS JSON,
            [name] nvarchar(128) '$.ext_schema_name[0]'
        ) AS [ext]
    CROSS APPLY
        OPENJSON ([ext].[storage]) WITH (
            [eds_name] nvarchar(128) '$.name',
            [account_name] nvarchar(128) '$.account_name',
            [container_name] nvarchar(128) '$.container_name'
        ) AS [strg]
END
