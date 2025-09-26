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
    # Set a specific annotation for each file
    file_specific_annotations = {
        "DemoApplication.java": {"controller.devfile.io/mount-path": "/tmp/projects/spring-web/src/main/java/com/example/demo"},
        "application.properties": {"controller.devfile.io/mount-path": "/tmp/projects/spring-web/src/main/resources"},
        "settings.json": {"controller.devfile.io/mount-path": "/tmp/projects/spring-web/.vscode"},
        "pom.xml": {"controller.devfile.io/mount-path": "/tmp/projects/spring-web"},
        "extensions.json": {"controller.devfile.io/mount-path": "/tmp/projects/spring-web/.vscode"}
    }
    # Use the annotation for the first (and only) file in file_list
    base_annotations = {
        "controller.devfile.io/mount-as": "subpath"
    }
    file_name = list(file_list)[0]
    annotations = base_annotations.copy()
    if file_name in file_specific_annotations:
        annotations.update(file_specific_annotations[file_name])
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
    # Explicitly declare the set of file names
    files = {"DemoApplication.java", "application.properties", "pom.xml", "extensions.json", "settings.json"}
    for filename in files:
        configmap_name = filename.replace('.', '-').lower()
        create_configmap(namespace, configmap_name, [filename])
