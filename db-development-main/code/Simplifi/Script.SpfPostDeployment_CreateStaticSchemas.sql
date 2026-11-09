BEGIN
    EXEC [mgmt_xtinfra].[sp_infra_core_spf_create_static_schemas];
    EXEC [mgmt_xtinfra].[sp_infra_extension_spf_create_static_schemas];
END
