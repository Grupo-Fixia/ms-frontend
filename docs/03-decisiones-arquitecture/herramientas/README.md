# Herramientas

Decisiones sobre **con qué herramientas trabaja el equipo** día a día:
control de versiones, gestión de proyecto, CI/CD, calidad de código,
comunicación y diseño.

| Herramienta | Estado en el radar | Para qué | Página |
|---|---|---|---|
| Git + GitHub | 🟢 Adoptar | Control de versiones y colaboración | [git-github.md](./git-github.md) |
| GitHub Actions | 🟢 Adoptar | CI/CD | [github-actions.md](./github-actions.md) |
| Jira | 🟢 Adoptar | Gestión de proyecto (Scrum) | [jira.md](./jira.md) |
| SonarQube | 🟢 Adoptar | Quality Gate / análisis estático | [sonarqube.md](./sonarqube.md) |
| GitHub Copilot | 🟡 Probar | Asistencia de código con IA | [github-copilot.md](./github-copilot.md) |
| VS Code, Figma, Slack, Grafana, Draw.io/Mermaid, Confluence, Notion | Ver detalle | Herramientas de apoyo | [herramientas-complementarias.md](./herramientas-complementarias.md) |

## Criterio general para elegir una herramienta

A diferencia de un lenguaje de programación, una herramienta suele ser más
fácil de reemplazar sin reescribir código de negocio — pero más cara de
cambiar en términos de **hábito del equipo** y de **integraciones ya
construidas** (ej. Smart Commits entre GitHub y Jira). Por eso, toda
herramienta que se vuelve "Adoptar" en el radar debe tener:

1. Una integración clara con el resto del flujo (no una isla aislada).
2. Una razón de por qué se prefirió sobre alternativas directas del
   mercado, no solo "es popular".
3. Una política operativa concreta documentada en el capítulo
   correspondiente (Git Workflow, CI/CD, Calidad, etc.).

## Cómo se conecta con el resto de la wiki

Estas páginas explican el **por qué**. La operación día a día de cada
herramienta vive en su capítulo correspondiente:

- Git + GitHub → política completa en
  [05-git-control-versiones](../../05-git-control-versiones/)
- GitHub Actions → pipelines y ambientes en
  [06-cicd-ambientes](../../06-cicd-ambientes/)
- SonarQube → umbrales del Quality Gate en
  [07-calidad-arquitectura](../../07-calidad-arquitectura/)
- Jira → ceremonias y flujo de estados en
  [04-gobierno-ciclo-vida](../../04-gobierno-ciclo-vida/)