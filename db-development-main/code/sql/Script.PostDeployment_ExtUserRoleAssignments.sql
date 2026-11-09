BEGIN
    -- EXTENSIONS
    PRINT ('[EXT] Extension Role Assignment Execution')
    SET @extsCounter = 1;
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

            --create users + assign all roles
            EXEC [mgmt_xtinfra].[sp_infra_ext_user_role_assignments] @ext_name = @ext_name;

            PRINT ('[EXT] Finished assigning roles to identity users for the extension: ' + @ext_name)
            SET @extsCounter = @extsCounter + 1;
        END
END
