# fabric-pipeline

Fabric items (template) + per-environment parameter files, deployed with
[fabric-cicd](https://microsoft.github.io/fabric-cicd/) from GitHub Actions.

```
pl_demo.DataPipeline/            # template – written by Fabric Git integration from the DEV workspace
pl_process_tables.DataPipeline/  # second pipeline: loops over a table list (array parameter)
parameters/{dev,test,prod}.yml   # per-environment values (fabric-cicd parameter format)
deploy/deploy.py             # publishes items to the target workspace
.github/workflows/deploy-fabric.yml  # manual run: pick dev/test/prod
```

## Flow

1. Build in the DEV workspace (Git-connected to this repo) and commit from Fabric.
2. For each value that differs per environment, add an entry to `parameters/*.yml`.
3. Actions → **Deploy Fabric items** → Run workflow → choose environment.

## One-time setup

1. **Service principal**: create an Entra app registration + client secret.
2. **Fabric tenant settings** (admin portal): enable *Service principals can use Fabric APIs*
   (scope it to a security group containing the SP).
3. **Workspaces**: add the SP as *Contributor* (or Admin) on the test and prod workspaces.
   Only the DEV workspace is Git-connected; test/prod are deployed to only by the workflow.
4. **GitHub Environments** (Settings → Environments): create `dev`, `test`, `prod`, each with
   - secrets: `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`
   - variable: `FABRIC_WORKSPACE_ID` (that environment's workspace GUID)
   - optionally required reviewers on `prod`.

## Adding an environment-specific value

1. Find the JSONPath of the value in the item's file, e.g.
   `$.properties.parameters.batch_size.defaultValue` in `pl_demo.DataPipeline/pipeline-content.json`.
2. Add the **same** `key_value_replace` entry to `parameters/dev.yml`, `test.yml` and `prod.yml`,
   each with its own value (keyed by the env name).
3. Quote strings; leave numbers and booleans unquoted to keep their JSON type.

Other tools in the parameter file (see `parameters/*.yml` for examples):
- JSONPath filters to reach activity settings: `$.properties.activities[?(@.name=="Wait Before Run")]...`
- Dynamic values resolved at deploy time: `$workspace.$id`, `$items.Lakehouse.<name>.$id`
- `find_replace` for a literal (e.g. a dev GUID) that appears in many places
