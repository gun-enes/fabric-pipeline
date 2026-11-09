BEGIN
    --- variables for looping through extensions
    DECLARE @ext_name AS NVARCHAR(20);
    DECLARE @extsCounter INT = 1;
    DECLARE @extsTotal INT;

    -- EXTENSIONS
    PRINT ('[EXT] Extension SPF Role Assignment Execution')
    SET @extsTotal = (
        SELECT COUNT(*)
        FROM [mgmt_xtinfra].[infra_workspace_identity_config]
        WHERE [workspace_type] = 'extension'
    );
    PRINT ('[EXT] Found: ' + CAST(@extsTotal AS NVARCHAR(20)) + ' extensions');
    WHILE @extsCounter <= @extsTotal
        BEGIN
            --set variables
            SET @ext_name = (
                SELECT [workspace_name]
                FROM [mgmt_xtinfra].[infra_workspace_identity_config]
                WHERE [workspace_type] = 'extension' AND [type_index] = @extsCounter
            );
            PRINT ('[EXT] Considering extension: ' + @ext_name);

            EXEC [mgmt_xtinfra].[sp_infra_ext_spf_user_role_assignments] @ext_name = @ext_name;

            PRINT ('[EXT] Finished assigning SPF roles to identity users for the extension: ' + @ext_name)
            SET @extsCounter = @extsCounter + 1;
        END
END
