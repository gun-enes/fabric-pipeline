# Fabric Workspace CI/CD

This repository deploys Fabric workspace items and then applies Lakehouse-specific post-deployment configuration.

## Current workflow behavior

- Deploys Fabric items from repository folders to target workspaces.
- Renames Lakehouse display names after publish when `parameter.yml` maps stage-specific names.
- Updates data access roles when `data-access-roles.json` exists in a Lakehouse folder.
- Creates or overwrites OneLake shortcuts when `shortcuts.metadata.json` exists in a Lakehouse folder.
- Supports stage-aware item ID mapping from `parameter.yml` for higher environments.
- Resolves API endpoint type (public/private networking) using the workspace communication policy.

### Important

Post-deployment notebook execution has been removed from the deployment flow.

## GitHub repository secrets setup

Go to repository settings:

- Settings
- Security -> Secrets and variables -> [Actions](.resources/Environment_Secrets.png)

Example environment secrets:

| Environment | Secret Name | Value (example) |
| --- | --- | --- |
| dev | TENANTID | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx |
| dev | CLIENTID | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx |
| dev | CLIENTSECRET | your-secret-value |

## Run workflow input

Under Enter workspace name and disaster recovery in [Run Workflow](.resources/Run_Workflow.png), provide a JSON array.
Workspace names must match repository workspace folders shown in [Workspace Folders](.resources/Workspace_Folders.png).

Example:

```json
[{"workspace":"ws-contoso-cr050-dev-warehouse","disaster_recovery":"false"}]
```

Fields:

- `workspace`: workspace folder name
- `disaster_recovery`: `true` or `false` (if `true`, `_DR` is appended to runtime workspace name)

For item selection, enter a list of Fabric item types to deploy:

```json
["DataPipeline","Environment","Notebook","Report","SemanticModel","Lakehouse","CopyJob","Warehouse","Dataflow"]
```

Use Select environment to choose the target stage (`dev`, `tst`, `prd`).

## How to use parameter.yml

Official reference:

- https://microsoft.github.io/fabric-cicd/0.3.1/how_to/parameterization/

### Location

`parameter.yml` must be placed in the root of the workspace repository directory used by deployment.

Example:

- `workspace/ws-contoso-cr050-dev-warehouse/parameter.yml`

### Why it matters in this repo

This deployment uses `parameter.yml` for environment-specific replacements, post-publish Lakehouse renames, shortcut payload substitution, and mapping the target Lakehouse item ID used by the data access roles step.

### Supported sections (most used)

- `find_replace`: generic string replacement (supports optional filters)
- `key_value_replace`: key-based replacement in JSON/YAML using JSONPath
- `spark_pool`: environment pool mapping for Environment items
- `semantic_model_binding`: semantic model connection binding after deployment

### Minimal example for this repo

```yaml
find_replace:
	- find_value: "-dev-"
		replace_value:
			tst: "-tst-"
			prd: "-prd-"

	- find_value: "09bc1698-67d7-4b51-a7c3-bc720b48c5bb" # lh_lakehouse_dev
		replace_value:
			tst: "926e0c1f-d350-4cfc-888e-bd99b4c2452e"
			prd: "<prd-lakehouse-id>"
```

### Recommended filters

Use filters to limit replacement scope and avoid accidental replacements:

- `item_type`
- `item_name`
- `file_path`

Example:

```yaml
find_replace:
	- find_value: "<old-guid>"
		replace_value:
			tst: "<new-guid>"
		item_type: "Notebook"
		file_path: "**/notebook-content.py"
```

### Dynamic replacements

You can use built-in dynamic variables in `replace_value`, for example:

- `$workspace.$id` for target workspace ID
- `$items.Lakehouse.<ItemName>.$id` for deployed Lakehouse item ID

These are useful when IDs differ per environment and should be resolved automatically at deployment time.

### Validation and behavior notes

- Environment keys in `replace_value` must match your deployment environment values (`dev`, `tst`, `prd`) or replacement is skipped.
- `_ALL_` can be used to apply one replacement value to all environments.
- If `parameter.yml` is invalid, deployment can fail during parameter validation.
- Filter values, item types, and item names are case-sensitive.

### Common mistakes seen in this repo

- Environment key mismatch in `replace_value`:
	using keys that do not match the selected stage (`dev`, `tst`, `prd`) causes replacements to be skipped.

- Missing stage mapping for promoted environments:
	`parameter.yml` has `tst` values but no `prd` values, which can break higher-stage deployments.

- No filters on broad `find_replace` rules:
	replacing GUIDs globally without `item_type`, `item_name`, or `file_path` can modify unintended files.

- Lakehouse/item name mismatch:
	dynamic item variables and mapping logic require exact item names (including case and spaces).

- Wrong `parameter.yml` placement:
	the file must be in the root of the workspace repository directory used by deployment, not in a parent/global folder.

## How to use data-access-roles.json

Official reference:

- https://learn.microsoft.com/en-us/rest/api/fabric/core/onelake-data-access-security/create-or-update-data-access-roles?tabs=HTTP

### Important (preview API)

The OneLake Data Access Security API is in preview and is intended for evaluation and development purposes only. It is not recommended for production use.

### Where to place the file

Place `data-access-roles.json` in each Lakehouse folder where roles should be applied.

Example:

- `workspace/ws-contoso-cr050-dev-warehouse/lh_sales.Lakehouse/data-access-roles.json`

If this file is missing, the deployment skips the data access roles update for that workspace.

### API call used by this repository

During deployment, the script sends:

- `PUT https://api.fabric.microsoft.com/v1/workspaces/{workspaceId}/items/{itemId}/dataAccessRoles`

The request body is loaded from `data-access-roles.json` after stage-specific find/replace values are applied.

### Required permissions

- Delegated scope: `OneLake.ReadWrite.All`
- Supported identities include User and Service Principal/Managed Identity (see API docs for latest details).

### Minimal file structure

```json
{
	"value": [
		{
			"name": "ReaderRead",
			"kind": "Policy",
			"decisionRules": [
				{
					"effect": "Permit",
					"permission": [
						{
							"attributeName": "Path",
							"attributeValueIncludedIn": ["*"]
						},
						{
							"attributeName": "Action",
							"attributeValueIncludedIn": ["Read"]
						}
					]
				}
			],
			"members": {
				"microsoftEntraMembers": [],
				"fabricItemMembers": []
			}
		}
	]
}
```

### Known behavior and troubleshooting

- If the target item does not support Universal Security in your tenant/capacity, API responses can include `UniversalSecurityFeatureDisabledForArtifactType`.
- The script logs the target workspace ID, item ID, endpoint, and API response to simplify troubleshooting.
- For higher environments, item IDs and other stage-specific values can be resolved through `parameter.yml` before calling the API.

## How to use shortcuts.metadata.json

Place `shortcuts.metadata.json` in each Lakehouse folder that should create OneLake shortcuts after deployment.

Example:

- `workspace/ws-contoso-cr050-dev-warehouse/lh_sales.Lakehouse/shortcuts.metadata.json`

The file should contain a JSON array of shortcut definitions. During deployment, the script applies the same `parameter.yml` replacements used for other promoted artifacts and then calls the Fabric shortcuts API with `CreateOrOverwrite` conflict handling.

Minimal example:

```json
[
	{
		"name": "raw-sales",
		"path": "Files/raw",
		"target": {
			"type": "oneLake",
			"oneLake": {
				"workspaceId": "<target-workspace-id>",
				"itemId": "<target-lakehouse-id>",
				"path": "Files/raw"
			}
		}
	}
]
```

## Folder structure

- Workflow definitions: `.github/workflows`
- Deployment scripts: `.github/workflows/scripts`
- Deployment entry point: `.github/workflows/scripts/deploy-to-fabric.py`
- Workspace content: `workspace/ws-<workspace_name>`



