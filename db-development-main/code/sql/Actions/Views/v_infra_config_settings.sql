CREATE VIEW [Actions].[v_infra_config_settings]
AS
WITH expected_settings AS (
    SELECT
        wic.workspace_name,
        wic.synapse_workspace_msi_name,
        cfg.name,
        'disabled' AS default_value
    FROM mgmt_xtinfra.infra_workspace_identity_config AS wic
    CROSS JOIN (
        SELECT 'on-pause-pipeline-wait-opt-out' AS name
        UNION ALL
        SELECT 'opt-in-for-ms-maintenance'
    ) AS cfg
)
SELECT
    es.workspace_name,
    es.synapse_workspace_msi_name AS synapse_workspace,
    es.name,
    ISNULL(cs.value, es.default_value) AS value,
    ISNULL(cs.created_at, GETUTCDATE()) AS created_at,
    ISNULL(cs.modified_at, GETUTCDATE()) AS modified_at,
    cs.requestor
FROM expected_settings AS es
LEFT JOIN mgmt_xtinfra.infra_config_settings AS cs
    ON es.workspace_name = cs.workspace_name
   AND es.name = cs.name;
GO
