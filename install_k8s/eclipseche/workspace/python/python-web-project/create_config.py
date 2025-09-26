import os
import sys
from kubernetes import client, config

def create_configmap(namespace, configmap_name, file_list):
    config.load_kube_config()
    v1 = client.CoreV1Api()

    # Check if ConfigMap exists
    try:
        v1.read_namespaced_config_map(configmap_name, namespace)
        print(f"ConfigMap '{configmap_name}' already exists in namespace '{namespace}'. Skipping creation.")
        return
    except client.exceptions.ApiException as e:
        if e.status != 404:
            print(f"Error checking ConfigMap '{configmap_name}': {e}")
            return
        # If 404, proceed to create

    data = {}
    for filename in file_list:
        with open(filename, 'r') as f:
            data[filename] = f.read()

    labels = {
        "controller.devfile.io/mount-to-devworkspace": "true",
        "controller.devfile.io/watch-configmap": "true"
    }
    
    # Set a specific annotation for each file based on its relative path
    file_path = list(file_list)[0]
    relative_path = os.path.relpath(file_path, '.')
    mount_path = f"/tmp/projects/{os.path.dirname(relative_path)}" if os.path.dirname(relative_path) != '.' else "/tmp/projects"
    
    base_annotations = {
        "controller.devfile.io/mount-as": "subpath",
        "controller.devfile.io/mount-path": mount_path
    }
    annotations = base_annotations.copy()
    configmap = client.V1ConfigMap(
        metadata=client.V1ObjectMeta(name=configmap_name, labels=labels, annotations=annotations),
        data=data
    )

    v1.create_namespaced_config_map(namespace=namespace, body=configmap)
    print(f"ConfigMap '{configmap_name}' created in namespace '{namespace}'.")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python create_config.py <namespace>")
        sys.exit(1)

    namespace = sys.argv[1]
    # Traverse through all files in current working directory
    files = []
    for root, dirs, filenames in os.walk('.'):
        for filename in filenames:
            if filename != 'create_config.py':  # Skip the script itself
                files.append(os.path.join(root, filename))
    
    for filepath in files:
        filename = os.path.basename(filepath)
        configmap_name = filename.replace('.', '-').lower()
        create_configmap(namespace, configmap_name, [filepath])
