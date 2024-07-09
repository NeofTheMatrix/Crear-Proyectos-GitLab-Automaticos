import yaml
import requests
import subprocess
import argparse
import os

def read_ci_yml(file_path):
    try:
        with open(file_path, 'r') as file:
            content = file.read()
            # Reemplaza las nuevas líneas con \n
            content = content.replace('\n', '\\n')
            # Escapa las comillas dobles
            content = content.replace('"', '\\"')
        return content
    except FileNotFoundError:
        print(f"Archivo {file_path} no encontrado!")
        exit(1)

def create_group(gitlab_url, private_token, group_name):
    url = f"{gitlab_url}/api/v4/groups"
    headers = {"PRIVATE-TOKEN": private_token}
    data = {"name": group_name, "path": group_name.lower()}
    response = requests.post(url, headers=headers, json=data)
    response.raise_for_status()
    return response.json()["id"]

def create_project(gitlab_url, private_token, group_id, project_name):
    url = f"{gitlab_url}/api/v4/projects"
    headers = {"PRIVATE-TOKEN": private_token}
    data = {"name": project_name, "namespace_id": group_id}
    response = requests.post(url, headers=headers, json=data)
    response.raise_for_status()
    return response.json()["id"]

def create_variable(gitlab_url, private_token, project_id, key, value, protected):
    url = f"{gitlab_url}/api/v4/projects/{project_id}/variables"
    headers = {"PRIVATE-TOKEN": private_token}
    data = {"key": key, "value": value, "protected": protected}
    response = requests.post(url, headers=headers, json=data)
    response.raise_for_status()

def create_pipeline(gitlab_url, private_token, project_id, pipeline_file):
    with open(pipeline_file, 'r') as file:
        pipeline_content = file.read()
    
    url = f"{gitlab_url}/api/v4/projects/{project_id}/repository/files/.gitlab-ci.yml"
    headers = {"PRIVATE-TOKEN": private_token}
    data = {
        "branch": "main",
        "content": pipeline_content,
        "commit_message": "Add CI pipeline"
    }
    response = requests.post(url, headers=headers, json=data)
    response.raise_for_status()

def create_branch(gitlab_url, private_token, project_id, branch_name):
    url = f"{gitlab_url}/api/v4/projects/{project_id}/repository/branches"
    headers = {"PRIVATE-TOKEN": private_token}
    data = {"branch": branch_name, "ref": "main"}
    response = requests.post(url, headers=headers, json=data)
    response.raise_for_status()

def set_default_branch(gitlab_url, private_token, project_id, branch_name):
    url = f"{gitlab_url}/api/v4/projects/{project_id}"
    headers = {"PRIVATE-TOKEN": private_token}
    data = {"default_branch": branch_name}
    response = requests.put(url, headers=headers, json=data)
    response.raise_for_status()

def enable_runner(gitlab_url, private_token, project_id, runner_id):
    # Ruta completa al script bash
    bash_script = "./Enable_GitLab_Runner.sh"

    # Argumentos para el script bash
    args = [bash_script, str(project_id), str(runner_id), gitlab_url, private_token]

    # Llama al script bash y espera a que termine
    process = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = process.communicate()

    # Verifica el estado de retorno del script bash
    if process.returncode != 0:
        print(f"(X) Error al ejecutar el script bash: {stderr.decode('utf-8')}")
        exit(1)

def get_user_id(gitlab_url, private_token, username):
    url = f"{gitlab_url}/api/v4/users"
    headers = {"PRIVATE-TOKEN": private_token}
    params = {"username": username}
    response = requests.get(url, headers=headers, params=params)
    response.raise_for_status()
    users = response.json()
    if users:
        return users[0]["id"]
    else:
        print(f"(X) Usuario {username} no encontrado!")
        exit(1)

def add_member_to_group(gitlab_url, private_token, group_id, user_id, access_level):
    url = f"{gitlab_url}/api/v4/groups/{group_id}/members"
    headers = {"PRIVATE-TOKEN": private_token}
    data = {"user_id": user_id, "access_level": access_level}
    response = requests.post(url, headers=headers, json=data)
    response.raise_for_status()

def main(config_file):
    with open(config_file, "r") as file:
        config = yaml.safe_load(file)
    
    gitlab_url = config["GitLab_Url"]
    private_token = config["private_token"]
    group_name = config["group"]
    
    group_id = create_group(gitlab_url, private_token, group_name)

    for maintainer in config.get("maintainers", []):
        user_id = get_user_id(gitlab_url, private_token, maintainer.lstrip('@'))
        add_member_to_group(gitlab_url, private_token, group_id, user_id, 40)  # 40 is the access level for Maintainers

    for developer in config.get("developers", []):
        user_id = get_user_id(gitlab_url, private_token, developer.lstrip('@'))
        add_member_to_group(gitlab_url, private_token, group_id, user_id, 30)  # 30 is the access level for Developers

    for project_name, project_config in config["projects"].items():
        project_id = create_project(gitlab_url, private_token, group_id, project_name)

        for var_key, var_config in project_config.get("vars", {}).items():
            create_variable(gitlab_url, private_token, project_id, var_key, var_config["value"], var_config.get("protected", False))

        pipeline_file = project_config.get("pipeline", "")
        if pipeline_file:
            create_pipeline(gitlab_url, private_token, project_id, pipeline_file)

        for branch_name, branch_config in project_config.get("branch", {}).items():
            create_branch(gitlab_url, private_token, project_id, branch_name)
            if branch_config.get("default"):
                set_default_branch(gitlab_url, private_token, project_id, branch_name)

        for runner_id in project_config.get("runners", {}).values():
            enable_runner(gitlab_url, private_token, project_id, runner_id)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Crear proyectos en GitLab a partir de un archivo de configuración YAML.")
    parser.add_argument("config_file", nargs='?', default=None, help="Ruta al archivo de configuración YAML")
    args = parser.parse_args()

    # Verificar si se proporcionó un archivo de configuración; de lo contrario, usar el predeterminado
    if args.config_file:
        config_file = args.config_file
    else:
        if os.path.exists("config.yaml"):
            config_file = "config.yaml"
        elif os.path.exists("config.yml"):
            config_file = "config.yml"
        else:
            print("(X) No se encontró ningún archivo de configuración predeterminado (config.yaml o config.yml) y no se proporcionó ningún archivo como parámetro.")
            exit(1)

    main(config_file)
