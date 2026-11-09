import argparse
import json
import sys
from pathlib import Path

import requests
import yaml
from azure.identity import ClientSecretCredential, DefaultAzureCredential
from fabric_cicd import (
    FabricWorkspace,
    change_log_level,
    constants,
    publish_all_items,
    unpublish_all_orphan_items,
)


REQUEST_TIMEOUT_SECONDS = 60


def get_workspace_id(workspace_name, headers):
    url = "https://api.fabric.microsoft.com/v1/workspaces"
    response = requests.get(url, headers=headers, timeout=REQUEST_TIMEOUT_SECONDS)
    if response.status_code != 200:
        return f"Error: {response.status_code}, {response.text}"

    for workspace in response.json().get("value", []):
        if workspace.get("displayName") == workspace_name:
            return workspace.get("id")

    return f"Error: Workspace {workspace_name} could not be found."


def get_communication_policy_base_url(workspace_id, headers):
    url = f"https://api.fabric.microsoft.com/v1/workspaces/{workspace_id}/networking/communicationPolicy"
    response = requests.get(url, headers=headers, timeout=REQUEST_TIMEOUT_SECONDS)
    if response.status_code != 200:
        print(
            f"Warning: Could not read communication policy for {workspace_id}: "
            f"{response.status_code}, {response.text}"
        )
        return "https://api.fabric.microsoft.com/"

    inbound_default_action = (
        response.json()
        .get("inbound", {})
        .get("publicAccessRules", {})
        .get("defaultAction", "")
    )
    if inbound_default_action == "Deny":
        return f"https://{workspace_id.replace('-', '')}.z{workspace_id[:2]}.w.api.fabric.microsoft.com"

    return "https://api.fabric.microsoft.com/"


def get_item_id(item_name, headers, url):
    response = requests.get(url, headers=headers, timeout=REQUEST_TIMEOUT_SECONDS)
    if response.status_code != 200:
        return f"Error: {response.status_code}, {response.text}"

    for item in response.json().get("value", []):
        print(f"Fabric item: {item}")
        if item.get("displayName") == item_name:
            return item.get("id")

    return f"Error: Item {item_name} could not found."


def cleanup_workspace(headers, workspace_api_url):
    while True:
        response = requests.get(
            f"{workspace_api_url}/folders",
            headers=headers,
            timeout=REQUEST_TIMEOUT_SECONDS,
        )
        if response.status_code != 200:
            print(f"Failed to fetch folders: {response.status_code}, {response.text}")
            return

        folders = response.json().get("value", [])
        if not folders:
            return

        for folder in folders:
            folder_id = folder.get("id")
            folder_name = folder.get("displayName")
            delete_response = requests.delete(
                f"{workspace_api_url}/folders/{folder_id}",
                headers=headers,
                timeout=REQUEST_TIMEOUT_SECONDS,
            )
            if delete_response.status_code not in (200, 202, 204):
                print(
                    f"Failed to delete folder {folder_name} ({folder_id}): "
                    f"{delete_response.status_code}, {delete_response.text}"
                )


def get_workspace_runtime_name(workload, stage):
    workspace_name = workload["workspace"]
    print(f"Original workspace name: {workspace_name} for stage {stage}")
    workspace_folder = workspace_name.replace( f"-{stage}-","-dev-")
    print(f"Runtime workspace folder set to {workspace_folder} for stage {stage}")
    if workload["disaster_recovery"] == "true":
        workspace_name = f"{workspace_name}_DR"
    return workspace_folder, workspace_name

# enviornment means ADP stage
def load_find_replace_map(parameter_file, environment):
    """Return {find_value: replace_value} for a given environment (ADP) from parameter.yml."""
    if not parameter_file.exists():
        return {}
    with parameter_file.open("r", encoding="utf-8") as fh:
        params = yaml.safe_load(fh) or {}
    mapping = {}
    for entry in params.get("find_replace", []) or []:
        find_value = entry.get("find_value")
        replace_value = (entry.get("replace_value") or {}).get(environment)
        if find_value is None or replace_value is None:
            continue
        mapping[str(find_value)] = str(replace_value)
    return mapping


def apply_find_replace(text, mapping):
    # Sort by length desc so longer keys win over shorter substrings.
    for find_value in sorted(mapping, key=len, reverse=True):
        text = text.replace(find_value, mapping[find_value])
    return text


def list_lakehouses(headers, workspace_api_url):
    response = requests.get(
        f"{workspace_api_url}/items",
        headers=headers,
        timeout=REQUEST_TIMEOUT_SECONDS,
    )
    response.raise_for_status()
    return [
        item for item in response.json().get("value", [])
        if item.get("type") == "Lakehouse"
    ]


def rename_lakehouses(headers, base_api_url, workspace_id,
                      repository_directory, find_replace_map):
    """Rename each Lakehouse to its substituted displayName (e.g. dev->tst)."""
    print(f"Renaming Lakehouses in workspace {workspace_id} ...")
    workspace_api_url = f"{base_api_url.rstrip('/')}/v1/workspaces/{workspace_id}"
    lakehouses_by_name = {lh["displayName"]: lh["id"] for lh in list_lakehouses(headers, workspace_api_url)}

    for lh_dir in sorted(repository_directory.glob("*.Lakehouse")):
        source_display_name = lh_dir.stem
        target_display_name = apply_find_replace(source_display_name, find_replace_map)
        if target_display_name == source_display_name:
            continue
        lakehouse_id = lakehouses_by_name.get(source_display_name)
        if not lakehouse_id:
            # Already renamed (or never existed under source name) -> nothing to do
            continue

        url = f"{workspace_api_url}/items/{lakehouse_id}"
        body = {"displayName": target_display_name}
        response = requests.patch(
            url,
            headers=headers,
            data=json.dumps(body),
            timeout=REQUEST_TIMEOUT_SECONDS,
        )
        if response.status_code not in (200, 201, 202, 204):
            print(
                f"Failed to rename Lakehouse '{source_display_name}' -> "
                f"'{target_display_name}': {response.status_code}, {response.text}"
            )
        else:
            print(
                f"->Renamed Lakehouse '{source_display_name}' -> '{target_display_name}'"
            )


def apply_data_access_roles(headers, base_api_url, workspace_id,
                            repository_directory, find_replace_map, stage):
    """Upload data-access-roles.json for each Lakehouse folder in the repo."""
    print(f"Applying Lakehouse data access roles from {repository_directory} ...")
    workspace_api_url = f"{base_api_url.rstrip('/')}/v1/workspaces/{workspace_id}"
    lakehouses_by_name = {lh["displayName"]: lh["id"] for lh in list_lakehouses(headers, workspace_api_url)}
    print(f"Lakehouses in target workspace: {list(lakehouses_by_name.keys())}")

    for lh_dir in sorted(repository_directory.glob("*.Lakehouse")):
        roles_file = lh_dir / f"{stage}.data-access-roles.json"
        if not roles_file.exists():
            print(f"{roles_file} does not exist, thus skipping.")
            continue

        # Lakehouse display name in the target workspace may be either the source
        # name (fabric-cicd patches Lakehouses to the source displayName) or the
        # substituted name. Try both.
        source_display_name = lh_dir.stem
        substituted_display_name = apply_find_replace(source_display_name, find_replace_map)

        lakehouse_id = (
            lakehouses_by_name.get(source_display_name)
            or lakehouses_by_name.get(substituted_display_name)
        )
        display_name = source_display_name if source_display_name in lakehouses_by_name else substituted_display_name

        if not lakehouse_id:
            print(
                f"Lakehouse '{source_display_name}' (or '{substituted_display_name}') "
                f"not found in workspace {workspace_id}. Available: "
                f"{list(lakehouses_by_name.keys())}. Skipping data access roles."
            )
            continue

        raw = roles_file.read_text(encoding="utf-8")
        #substituted = apply_find_replace(raw, find_replace_map)
        # Always rewrite the placeholder sourcePath (00000000.../00000000...)
        # used in committed role files to the actual target workspace/lakehouse.
        substituted = raw.replace(
            "00000000-0000-0000-0000-000000000000/00000000-0000-0000-0000-000000000000",
            f"{workspace_id}/{lakehouse_id}",
        )
        try:
            roles = json.loads(substituted)
        except json.JSONDecodeError as exc:
            print(f"Failed to parse {roles_file} after substitution: {exc}")
            continue

        url = f"{workspace_api_url}/items/{lakehouse_id}/dataAccessRoles"
        request_headers = dict(headers)
        request_headers["If-Match"] = "*"
        body = {"value": roles}
        print(f"Applying data access roles to '{display_name}' ({lakehouse_id})")
        response = requests.put(
            url,
            headers=request_headers,
            data=json.dumps(body),
            timeout=REQUEST_TIMEOUT_SECONDS,
        )
        if response.status_code not in (200, 201, 202, 204):
            print(
                f"Failed to apply data access roles for '{display_name}': "
                f"{response.status_code}, {response.text}"
            )
        else:
            print(f"->Applied data access roles for '{display_name}'")


def apply_shortcuts(headers, base_api_url, workspace_id,
                    repository_directory, find_replace_map):
    """Create OneLake shortcuts for each Lakehouse folder in the repo."""
    print(f"Applying Lakehouse shortcuts from {repository_directory} ...")
    workspace_api_url = f"{base_api_url.rstrip('/')}/v1/workspaces/{workspace_id}"
    lakehouses_by_name = {lh["displayName"]: lh["id"] for lh in list_lakehouses(headers, workspace_api_url)}

    for lh_dir in sorted(repository_directory.glob("*.Lakehouse")):
        shortcuts_file = lh_dir / "shortcuts.metadata.json"
        if not shortcuts_file.exists():
            print(f"No shortcuts.metadata.json in {lh_dir.name}, skipping.")
            continue

        source_display_name = lh_dir.stem
        substituted_display_name = apply_find_replace(source_display_name, find_replace_map)
        lakehouse_id = (
            lakehouses_by_name.get(source_display_name)
            or lakehouses_by_name.get(substituted_display_name)
        )
        display_name = source_display_name if source_display_name in lakehouses_by_name else substituted_display_name

        if not lakehouse_id:
            print(
                f"Lakehouse '{source_display_name}' (or '{substituted_display_name}') "
                f"not found in workspace {workspace_id}. Skipping shortcuts."
            )
            continue

        raw = shortcuts_file.read_text(encoding="utf-8")
        substituted = apply_find_replace(raw, find_replace_map)
        try:
            shortcuts = json.loads(substituted)
        except json.JSONDecodeError as exc:
            print(f"Failed to parse {shortcuts_file} after substitution: {exc}")
            continue

        for shortcut in shortcuts:
            target = shortcut.get("target") or {}
            # API body wraps a single target type (oneLake/adlsGen2/amazonS3/...).
            # Strip the local 'type' discriminator if present.
            target.pop("type", None)
            body = {
                "name": shortcut.get("name"),
                "path": shortcut.get("path"),
                "target": target,
            }
            url = (
                f"{workspace_api_url}/items/{lakehouse_id}/shortcuts"
                "?shortcutConflictPolicy=CreateOrOverwrite"
            )
            response = requests.post(
                url,
                headers=headers,
                data=json.dumps(body),
                timeout=REQUEST_TIMEOUT_SECONDS,
            )
            if response.status_code not in (200, 201, 202):
                print(
                    f"Failed to create shortcut '{shortcut.get('name')}' on "
                    f"'{display_name}': {response.status_code}, {response.text}"
                )
            else:
                print(
                    f"->Created shortcut '{shortcut.get('name')}' at "
                    f"'{shortcut.get('path')}' on '{display_name}'"
                )

def replace_pipeline_connection_ids(repository_directory: Path, find_replace_map: dict):
    """
    Replace connection IDs in pipeline-content.json files for all *.DataPipeline folders.
    """
    print("Updating pipeline connection IDs using find_replace_map...")

    for pipeline_dir in repository_directory.glob("*.DataPipeline"):
        pipeline_file = pipeline_dir / "pipeline-content.json"

        if not pipeline_file.exists():
            print(f"No pipeline-content.json in {pipeline_dir}, skipping.")
            continue

        try:
            raw = pipeline_file.read_text(encoding="utf-8")
            data = json.loads(raw)
        except Exception as e:
            print(f"Failed to read/parse {pipeline_file}: {e}")
            continue

        updated = False

        activities = data.get("properties", {}).get("activities", [])
        for activity in activities:
            ext_refs = activity.get("externalReferences", {})
            connection_id = ext_refs.get("connection")

            if connection_id and connection_id in find_replace_map:
                new_value = find_replace_map[connection_id]
                print(
                    f"{pipeline_dir.name}: Replacing connection "
                    f"{connection_id} -> {new_value}"
                )
                activity["externalReferences"]["connection"] = new_value
                updated = True

        if updated:
            try:
                pipeline_file.write_text(
                    json.dumps(data, indent=2), encoding="utf-8"
                )
                print(f"Updated {pipeline_file}")
            except Exception as e:
                print(f"Failed to write {pipeline_file}: {e}")
        else:
            print(f"No replacements needed in {pipeline_file}")

def main():
    change_log_level("DEBUG")

    parser = argparse.ArgumentParser(description="Process Azure Pipeline arguments.")
    parser.add_argument("--stage", type=str, help="GitHub stage (dev, tst, prd)")
    parser.add_argument("--workdir", type=str, help="GitHub work dir")
    parser.add_argument("--branch", type=str, help="current GitHub branch")
    parser.add_argument("--workspace", type=str, help="workspace name and access")
    parser.add_argument("--aztenantid", type=str, help="tenant ID")
    parser.add_argument("--azclientid", type=str, help="SP client ID")
    parser.add_argument("--azspsecret", type=str, help="SP secret")
    parser.add_argument("--items_in_scope", type=str, help="Defines the item types to be deployed")
    args = parser.parse_args()

    if args.azclientid:
        token_credential = ClientSecretCredential(
            client_id=args.azclientid,
            client_secret=args.azspsecret,
            tenant_id=args.aztenantid,
        )
        print("Client Secret Credential ...")
    else:
        token_credential = DefaultAzureCredential()
        print("Default Azure Credential ...")

    branch = args.branch.replace("refs/heads/", "")
    print(f"Branch set to {branch}")

    scope = "https://api.fabric.microsoft.com/.default"
    token = token_credential.get_token(scope)
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json",
    }

    workloads = json.loads(args.workspace)
    print(f"Workspace and access {args.workspace}")
    for workload in workloads:
        print(f'workload: {workload["workspace"]}')
        workspace_folder, workspace_name = get_workspace_runtime_name(workload, args.stage)

        print(f"Obtaining GUID for {workspace_name}")
        workspace_id = get_workspace_id(workspace_name, headers)
        if workspace_id.startswith("Error"):
            errmsg = (
                f"{workspace_id}. Perhaps workspace name is set incorrectly in the variable group "
                f"or does not map to branch name {workspace_name}"
            )
            raise ValueError(errmsg)
        print(f"Workspace ID for {workspace_name} set to {workspace_id}")

        base_api_url = get_communication_policy_base_url(workspace_id, headers)
        workspace_api_url = f"{base_api_url.rstrip('/')}/v1/workspaces/{workspace_id}"
        cleanup_workspace(headers, workspace_api_url)

        repository_directory = Path(args.workdir) / "workspace" / workspace_folder
        item_types = [t.strip() for t in args.items_in_scope.strip("[]").split(",") if t.strip()]

        # Lakehouse and Warehouse items cannot be updated once they exist.
        # Exclude them from publish scope if they already exist in the target workspace.
        existing_items_resp = requests.get(
            f"{workspace_api_url}/items", headers=headers, timeout=REQUEST_TIMEOUT_SECONDS
        )
        existing_items_resp.raise_for_status()
        existing_types = {item["type"] for item in existing_items_resp.json().get("value", [])}
        skip_if_exists = {"Lakehouse", "Warehouse"}
        skipped = skip_if_exists & existing_types
        if skipped:
            print(f"Items of type {skipped} already exist in workspace — excluding from publish scope.")
            item_types = [t for t in item_types if t not in skipped]

        constants.FABRIC_API_ROOT_URL = base_api_url
        constants.DEFAULT_API_ROOT_URL = base_api_url
        target_workspace = FabricWorkspace(
            workspace_id=workspace_id,
            environment=args.stage,
            repository_directory=str(repository_directory),
            item_type_in_scope=item_types,
            token_credential=token_credential,
        )

        find_replace_map = load_find_replace_map(
            repository_directory / "parameter.yml", args.stage
        )

        #replace_pipeline_connection_ids(repository_directory, find_replace_map)

        print("Publish branch to workspace...")
        print(f"Using workspace {base_api_url}...")
        print(f"Constants API: {constants.FABRIC_API_ROOT_URL}")
        publish_all_items(target_workspace)

        rename_lakehouses(
            headers, base_api_url, workspace_id, repository_directory, find_replace_map
        )
        apply_data_access_roles(
            headers, base_api_url, workspace_id, repository_directory, find_replace_map, args.stage
        )
        apply_shortcuts(
            headers, base_api_url, workspace_id, repository_directory, find_replace_map
        )

        unpublish_all_orphan_items(target_workspace)


if __name__ == "__main__":
    main()
