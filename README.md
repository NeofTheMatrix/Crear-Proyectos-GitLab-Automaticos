# Crear-Proyectos-GitLab-Automaticos

Script de python para configurar grupos de repositorios en GitLab, útil en el area de DevOps para iniciar nuevos proyectos y crear los pipelines automáticamente, ya que puedes configurar el archivo de pipeline "gitlab-ci.yml" en el parámetro "pipeline:" de cada proyecto del grupo.

Se deja en este repositorio un archivo "config_gitlab_group_projects.yml" de ejemplo.

## Cómo usar:

  python Create_GitLab_ProjectsGroup.py <Archivo .yml con la configuracion>

Ejemplo:

  python3 Create_GitLab_ProjectsGroup.py config_gitlab_group_projects.yml
  
Si el nombre del archivo .yml no es proporcionado, el script usará por defecto el archivo *config.yaml* o *config.yml* que se encuentre en el mismo directorio.
