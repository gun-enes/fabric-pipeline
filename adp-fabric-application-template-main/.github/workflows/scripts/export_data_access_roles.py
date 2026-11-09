import os
import argparse
import requests
from pathlib import Path
import json

# -----------------------------
# CONFIG
# -----------------------------
parser = argparse.ArgumentParser(description="Export Lakehouse Data Access Roles from Fabric.")
parser.add_argument("--tenant-id", default=os.environ.get("TENANT_ID", ""))
parser.add_argument("--client-id", default=os.environ.get("CLIENT_ID", ""))
parser.add_argument("--client-secret", default=os.environ.get("CLIENT_SECRET", ""))
parser.add_argument("--workspace-id", default=os.environ.get("WORKSPACE_ID", ""))
parser.add_argument("--workspace-name", default=os.environ.get("WORKSPACE_NAME", ""))
parser.add_argument("--output-dir", default=os.environ.get("OUTPUT_DIR", "workspace"))
args = parser.parse_args()

TENANT_ID = args.tenant_id
CLIENT_ID = args.client_id
CLIENT_SECRET = args.client_secret
WORKSPACE_NAME = args.workspace_name

AUTH_URL = f"https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token"

# -----------------------------
# AUTH
# -----------------------------
def get_token():
    payload = {
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "scope": "https://api.fabric.microsoft.com/.default",
        "grant_type": "client_credentials"
    }
    r = requests.post(AUTH_URL, data=payload)
    r.raise_for_status()
    return r.json()["access_token"]


# -----------------------------
# WORKSPACE RESOLUTION
# -----------------------------
def resolve_workspace_id(token):
    if args.workspace_id:
        return args.workspace_id

    url = "https://api.fabric.microsoft.com/v1/workspaces"
    headers = {"Authorization": f"Bearer {token}"}

    while url:
        r = requests.get(url, headers=headers)
        r.raise_for_status()
        data = r.json()

        for ws in data.get("value", []):
            if ws.get("displayName", "").lower() == WORKSPACE_NAME.lower():
                print(f"Resolved workspace: {WORKSPACE_NAME} -> {ws['id']}")
                return ws["id"]

        url = data.get("continuationUri")

    raise ValueError("Workspace not found")


# -----------------------------
# GET LAKEHOUSES
# -----------------------------
def get_lakehouses(token, workspace_id):
    url = f"https://api.fabric.microsoft.com/v1/workspaces/{workspace_id}/items"
    headers = {"Authorization": f"Bearer {token}"}

    lakehouses = []

    while url:
        r = requests.get(url, headers=headers)
        r.raise_for_status()
        data = r.json()

        for item in data.get("value", []):
            if item.get("type", "").lower() == "lakehouse":
                lakehouses.append(item)

        url = data.get("continuationUri")

    return lakehouses


# -----------------------------
# GET DATA ACCESS ROLES (PAGINATED)
# -----------------------------
def get_data_access_roles(token, workspace_id, item_id):
    base_url = f"https://api.fabric.microsoft.com/v1/workspaces/{workspace_id}/items/{item_id}/dataAccessRoles"
    headers = {"Authorization": f"Bearer {token}"}

    roles = []
    continuation_token = None

    while True:
        url = base_url
        if continuation_token:
            url += f"?continuationToken={continuation_token}"

        r = requests.get(url, headers=headers)

        if r.status_code == 404:
            print(f"  ⚠️ Roles not supported for {item_id}")
            return None

        if r.status_code == 403:
            print(f"  ⚠️ Access denied for {item_id}")
            return None

        r.raise_for_status()
        data = r.json()

        page_roles = data.get("value", [])
        roles.extend(page_roles)

        print(f"    Retrieved {len(page_roles)} roles (total: {len(roles)})")

        continuation_token = data.get("continuationToken")
        if not continuation_token:
            break

    return {
        "value": roles,
        "count": len(roles)
    }


# -----------------------------
# SAVE
# -----------------------------
def save_roles(workspace_name, lakehouse_name, roles_json, base_output):
    folder = (
        base_output
        / f"{lakehouse_name}.Lakehouse"
    )

    folder.mkdir(parents=True, exist_ok=True)

    file_path = folder / "data-access-roles.json"

    with open(file_path, "w", encoding="utf-8") as f:
        json.dump(roles_json, f, indent=2)

    print(f"  ✅ Saved: {file_path}")


# -----------------------------
# MAIN
# -----------------------------
if __name__ == "__main__":
    try:
        token = get_token()
        workspace_id = resolve_workspace_id(token)

        lakehouses = get_lakehouses(token, workspace_id)

        print(f"Found {len(lakehouses)} Lakehouse(s)")

        base_output = Path(args.output_dir)
        
        for lh in lakehouses:
            name = lh.get("displayName", "unknown")
            item_id = lh["id"]

            print(f"\nProcessing Lakehouse: {name}")

            roles = get_data_access_roles(token, workspace_id, item_id)

            if roles:
                save_roles(WORKSPACE_NAME, name, roles, base_output)

        print("\n✅ Done")

    except Exception as e:
        print(f"Error: {e}")
        exit(1)