#!/bin/bash

# Variables
GITLAB_URL="http://gitlab.ks2.tech"
PRIVATE_TOKEN="glpat-w7zR5sSaoZx5EpktB-sr" 
#GROUP_ID="319"

RESPONSE=""
PROJECT_ID=""
GROUP_ID=""

# Leer archivo Yaml
parse_yaml() {
  
  local prefix=$2
  local s='[[:space:]]*'
  local w='[a-zA-Z0-9_]*'
  local fs=$(echo @|tr @ '\034')
  
  sed "h;s/^[^:]*//;x;s/:.*$//;y/-/_/;G;s/\n//" $1 |
  sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
      -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" |
  awk -F$fs '{
    indent = length($1)/2;
    vname[indent] = $2;

    for (i in vname) {if (i > indent) {delete vname[i]}}
    if (length($3) > 0) {
        vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
        printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
    }
  }'
}

eval $(parse_yaml $1 "GitLab_")

# Crear un grupo
create_group() {
  GROUP_NAME=$1
  GROUP_PATH=$2  # El path del grupo en la URL de GitLab (sin espacios ni caracteres especiales)

  RESPONSE=$(curl --silent --request POST "$GITLAB_URL/api/v4/groups" \
    --header "PRIVATE-TOKEN: $PRIVATE_TOKEN" \
    --header "Content-Type: application/json" \
    --data "{
      \"name\": \"$GROUP_NAME\",
      \"path\": \"$GROUP_PATH\"
    }")


  GROUP_ID=$(echo "$RESPONSE" | grep -o '"id":[0-9]*' | grep -o '[0-9]*' | head -n 1)
  echo "(i) Grupo creado con ID: $GROUP_ID"
  echo $GROUP_ID
}

# Crear proyectos
create_project() {
  PROJECT_NAME=$1
  #GROUP_ID=$2

  RESPONSE=$(curl --silent --request POST "$GITLAB_URL/api/v4/projects" \
    --header "PRIVATE-TOKEN: $PRIVATE_TOKEN" \
    --header "Content-Type: application/json" \
    --data "{
      \"name\": \"$PROJECT_NAME\",
      \"namespace_id\": \"$GROUP_ID\"
    }")

  PROJECT_ID=$(echo "$RESPONSE" | grep -o '"id":[0-9]*' | grep -o '[0-9]*' | head -n 1)

  echo $PROJECT_ID
}

# Crear una variables
create_variable() {
  PROJECT_ID=$1
  VARIABLE_KEY=$2
  VARIABLE_VALUE=$3
  VARIABLE_PROTECTED=$4

  curl --request POST "$GITLAB_URL/api/v4/projects/$PROJECT_ID/variables" \
    --header "PRIVATE-TOKEN: $PRIVATE_TOKEN" \
    --header "Content-Type: application/json" \
    --data "{
      \"key\": \"$VARIABLE_KEY\",
      \"value\": \"$VARIABLE_VALUE\",
      \"protected\": $VARIABLE_PROTECTED
    }"
}

# Crear Pipelines
# Crear archivo .gitlab-ci.yml en el proyecto
create_pipeline() {
  PROJECT_ID=$1
  CI_YML_CONTENT=$2

  echo $CI_YML_CONTENT

  curl --request POST "$GITLAB_URL/api/v4/projects/$PROJECT_ID/repository/files/.gitlab-ci.yml" \
    --header "PRIVATE-TOKEN: $PRIVATE_TOKEN" \
    --header "Content-Type: application/json" \
    --data "{
      \"branch\": \"main\",
      \"content\": \"$CI_YML_CONTENT\",
      \"commit_message\": \"Add CI/CD pipeline configuration\"
    }"
}

# Leer el contenido del archivo .gitlab-ci.yml
read_ci_yml() {
  CI_YML_FILE=".gitlab-ci.yml"
  if [ ! -f "$CI_YML_FILE" ]; then
    echo "Archivo $CI_YML_FILE no encontrado!"
    exit 1
  fi
  CI_YML_CONTENT=$(cat $CI_YML_FILE | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/"/\\"/g')
  echo $CI_YML_CONTENT
}

# Crear una nueva rama y establecerla como predeterminada
create_and_set_default_branch() {
  PROJECT_ID=$1
  NEW_BRANCH=$2

  # Crear la nueva rama desde main
  curl --request POST "$GITLAB_URL/api/v4/projects/$PROJECT_ID/repository/branches" \
    --header "PRIVATE-TOKEN: $PRIVATE_TOKEN" \
    --header "Content-Type: application/json" \
    --data "{
      \"branch\": \"$NEW_BRANCH\",
      \"ref\": \"main\"
    }"

  # Establecer la nueva rama como predeterminada
  curl --request PUT "$GITLAB_URL/api/v4/projects/$PROJECT_ID" \
    --header "PRIVATE-TOKEN: $PRIVATE_TOKEN" \
    --header "Content-Type: application/json" \
    --data "{
      \"default_branch\": \"$NEW_BRANCH\"
    }"
}

# Habilitar un runner específico para un proyecto
enable_runner_for_project() {
  PROJECT_ID=$1
  RUNNER_ID=$2

  curl --request POST "$GITLAB_URL/api/v4/projects/$PROJECT_ID/runners" \
    --header "PRIVATE-TOKEN: $PRIVATE_TOKEN" \
    --header "Content-Type: application/json" \
    --data "{
      \"runner_id\": \"$RUNNER_ID\"
    }"
}

# Crear grupo:
GROUP_NAME="DevOps Grupo Creado Automaticamente"
GROUP_PATH=${GROUP_NAME// /"_"}  # <- Este valor debe ser único
echo "(i) Creando Grupo $GROUP_NAME en GibLab."
create_group "$GROUP_NAME" "$GROUP_PATH"

# Crear proyecto y variables
PROJECT_NAME="a-new-test-project-8"
echo "(i) Creando proyecto $PROJECT_NAME en el grupo $GROUP_NAME."
create_project "$PROJECT_NAME"

echo "(i) Creando variables."
create_variable $PROJECT_ID "MY_VARIABLE" "my_value" false
create_variable $PROJECT_ID "ANOTHER_VARIABLE" "another_value" true

echo "(i) Creando Pipeline."
CI_YML_CONTENT=$(read_ci_yml)
create_pipeline $PROJECT_ID "$CI_YML_CONTENT"

NEW_BRANCH="devel"
echo "(i) Creando Rama $NEW_BRANCH."
create_and_set_default_branch $PROJECT_ID $NEW_BRANCH

RUNNER_ID="30"
echo "(i) Creando Rama $NEW_BRANCH."
enable_runner_for_project $PROJECT_ID $RUNNER_ID

echo "(i) Variables creadas con éxito para el proyecto $PROJECT_NAME (PROJECT ID: $PROJECT_ID)."

