import time, yaml, sys, os
from kubernetes import client, config
from kubernetes.client.rest import ApiException

NAMESPACE = os.environ.get("CHE_USER_NAMESPACE", "che-user")
MANIFEST_FILE = os.environ.get("DW_FILE", "devworkspace.yaml")
GROUP = "workspace.devfile.io"
VERSION = "v1alpha2"
PLURAL = "devworkspaces"
DELETE_MODE = os.environ.get("DW_DELETE", "false").lower() == "true"

# Utility: create namespace if missing
def ensure_namespace(namespace):
    v1 = client.CoreV1Api()
    try:
        v1.read_namespace(namespace)
    except ApiException as e:
        if e.status == 404:
            v1.create_namespace(client.V1Namespace(metadata=client.V1ObjectMeta(name=namespace)))
            print(f"Created namespace '{namespace}'")
        else:
            raise

# Utility: delete DevWorkspace
def kdelete(crd_api, name):
    return crd_api.delete_namespaced_custom_object(GROUP, VERSION, NAMESPACE, PLURAL, name)

# Utility: delete PVC and release PV
def cleanup_pvc_and_pv(ws_name):
    v1 = client.CoreV1Api()
    label_selector = f"app.kubernetes.io/part-of=che,app.kubernetes.io/name=devworkspace,app.kubernetes.io/instance={ws_name}"
    pvcs = v1.list_namespaced_persistent_volume_claim(NAMESPACE, label_selector=label_selector).items
    for pvc in pvcs:
        pvc_name = pvc.metadata.name
        print(f"Deleting PVC: {pvc_name}")
        v1.delete_namespaced_persistent_volume_claim(pvc_name, NAMESPACE)
        # Release PV
        if pvc.spec.volume_name:
            pv = v1.read_persistent_volume(pvc.spec.volume_name)
            if pv.spec.claim_ref:
                pv.spec.claim_ref = None
                v1.patch_persistent_volume(pv.metadata.name, {"spec": {"claimRef": None}})
                print(f"Released PV: {pv.metadata.name}")

# Utility: release PV for workspace PVCs (before deleting workspace)
def release_pv_for_workspace(ws_name, namespace):
    v1 = client.CoreV1Api()
    label_selector = f"app.kubernetes.io/part-of=che,app.kubernetes.io/name=devworkspace,app.kubernetes.io/instance={ws_name}"
    pvcs = v1.list_namespaced_persistent_volume_claim(namespace, label_selector=label_selector).items
    for pvc in pvcs:
        if pvc.spec.volume_name:
            pv = v1.read_persistent_volume(pvc.spec.volume_name)
            if pv.spec.claim_ref:
                v1.patch_persistent_volume(pv.metadata.name, {"spec": {"claimRef": None}})
                print(f"Released PV: {pv.metadata.name}")

def main():
    try:
        config.load_kube_config()
    except Exception:
        config.load_incluster_config()

    with open(MANIFEST_FILE, "r") as f:
        manifest = yaml.safe_load(f)

    # Patch manifest with env vars
    ws_name = os.environ.get("CHE_WORKSPACE_NAME")
    user_name = os.environ.get("CHE_USER_NAME")
    namespace = os.environ.get("CHE_USER_NAMESPACE", "che-user")
    if ws_name:
        manifest["metadata"]["name"] = ws_name
    if namespace:
        manifest["metadata"]["namespace"] = namespace
    if user_name:
        manifest.setdefault("spec", {})["user"] = user_name
    name = manifest["metadata"]["name"]

    crd_api = client.CustomObjectsApi()
    ensure_namespace(namespace)

    if DELETE_MODE:
        release_pv_for_workspace(name, namespace)
        try:
            kdelete(crd_api, name)
            print(f"Deleted DevWorkspace '{name}' in namespace '{namespace}'.")
        except ApiException as e:
            if e.status == 404:
                print(f"DevWorkspace '{name}' not found for deletion.")
            else:
                raise
        print("Cleanup complete.")
        return 0

    # Create or patch the DevWorkspace
    try:
        _ = crd_api.get_namespaced_custom_object(GROUP, VERSION, namespace, PLURAL, name)
        crd_api.patch_namespaced_custom_object(GROUP, VERSION, namespace, PLURAL, name, manifest)
        print(f"Patched DevWorkspace '{name}' in namespace '{namespace}'.")
    except ApiException as e:
        if e.status == 404:
            crd_api.create_namespaced_custom_object(GROUP, VERSION, namespace, PLURAL, manifest)
            print(f"Created DevWorkspace '{name}' in namespace '{namespace}'.")
        else:
            raise

    timeout_s = int(os.environ.get("DW_TIMEOUT_SECONDS", "900"))  # 15 min
    poll = 5
    waited = 0
    last_phase = None
    while waited < timeout_s:
        time.sleep(poll)
        waited += poll
        ws = crd_api.get_namespaced_custom_object(GROUP, VERSION, namespace, PLURAL, name)
        phase = ws.get("status", {}).get("phase")
        conditions = ws.get("status", {}).get("conditions", [])
        urls = ws.get("status", {}).get("routing", {}).get("endpoints", []) or ws.get("status", {}).get("endpoints", [])
        if phase != last_phase:
            print(f"Status phase: {phase}")
            last_phase = phase
        if urls:
            try:
                lines = []
                for ep in urls:
                    if isinstance(ep, dict):
                        epname = ep.get("name")
                        url = ep.get("url") or ep.get("exposedEndpoint", {}).get("url")
                        if url:
                            lines.append(f"- {epname or 'endpoint'}: {url}")
                    elif isinstance(ep, str):
                        lines.append(f"- {ep}")
                if lines:
                    print("Endpoints:\n" + "\n".join(lines))
            except Exception:
                pass
        if phase in ("Running", "Succeeded"):
            print("Workspace is ready.")
            return 0
        for c in conditions or []:
            if c.get("type") in ("Failed", "Error") or c.get("status") == "False" and c.get("type") == "Ready":
                print(f"[{c.get('type')}] {c.get('reason')}: {c.get('message')}")
    print("Timed out waiting for DevWorkspace to become Running.")
    return 1

if __name__ == "__main__":
    sys.exit(main())
