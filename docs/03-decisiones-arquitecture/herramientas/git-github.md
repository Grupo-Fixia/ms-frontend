# Git + GitHub

**Estado en el Tech Radar:** 🟢 Adoptar
**Categoría:** Herramientas
**Última revisión:** 2026-08-24

## Contexto

Con más de una decena de repositorios previstos (un `apigateway`, varios
`msv-*`, `web-*`, `lib-*`, `infra-*` — ver
[08-estructura-microservicios](../../08-estructura-microservicios/)),
Fixia necesita una plataforma de control de versiones que soporte
colaboración entre equipos pequeños, revisión de código estructurada, y
automatización de CI/CD sin fricción.

## Decisión

Git como sistema de control de versiones, **GitHub** como plataforma de
alojamiento y colaboración.

## Alternativas consideradas

| Opción | Por qué no |
|---|---|
| **GitLab** | Alternativa sólida con CI/CD integrado, pero GitHub tiene mejor integración nativa con Jira ("GitHub for Jira") y un ecosistema de Actions más maduro para lo que necesita el flujo de Smart Commits (ver [jira.md](./jira.md)). |
| **Bitbucket** | Integración con Jira también existe (mismo dueño, Atlassian), pero el ecosistema de Actions/marketplace de GitHub es más amplio, y el equipo ya tiene familiaridad previa con GitHub. |
| **Git alojado on-premise (ej. Gitea, GitLab self-hosted)** | Sumaría una responsabilidad operativa más al equipo de DevOps (mantener el servidor de Git) sin un beneficio claro, dado que GitHub ya resuelve esto de forma gestionada y el resto de la infraestructura crítica sí es on-premise. |

## Justificación para Fixia

1. **Integración nativa con Jira mediante Smart Commits.** El flujo de
   trabajo Scrum de Fixia depende de que un commit pueda transicionar un
   ticket de Jira automáticamente (`#close`, `#time`, `#in-review`). Esto
   requiere la app "GitHub for Jira", que es más directa de configurar y
   mantener que integraciones equivalentes en otras plataformas.
2. **Self-hosted runners de GitHub Actions conviven bien con
   infraestructura on-premise.** Dado que Fixia opera on-premise hoy (ver
   [plataformas-infraestructura/on-premise.md](../plataformas-infraestructura/on-premise.md)),
   GitHub Actions permite mantener el procesamiento de CI local sin
   depender de un servidor de CI adicional.
3. **CODEOWNERS y protección de ramas nativas**, alineadas directamente
   con el modelo de 3 ramas (`main` / `test` / `producción`) que Fixia
   define como estándar organizacional (ver
   [05-git-control-versiones](../../05-git-control-versiones/)).

## Cómo se usa en el proyecto

- Todo repositorio sigue la convención de nombres
  `fixia-<tipo>-<nombre>` (ver
  [08-estructura-microservicios](../../08-estructura-microservicios/)).
- Estrategia de ramas de 3 niveles (`main` → `test` → `producción`) con
  protección de ramas configurada de forma idéntica en todos los repos
  (ver [05-git-control-versiones](../../05-git-control-versiones/)).
- Todo repositorio incluye `.github/CODEOWNERS` obligatorio.
- Convención de commits basada en Conventional Commits + Smart Commits
  para cierre automático de tareas en Jira.

## Trade-offs / riesgos

- Dependencia de un proveedor externo (GitHub) para una herramienta
  crítica del flujo de desarrollo; mitigado por ser una plataforma madura
  con alta disponibilidad histórica.
- El modelo de 3 ramas exige disciplina del equipo (nunca push directo a
  ramas protegidas); se refuerza con reglas de protección obligatorias,
  no solo convención verbal.

## Cuándo reconsiderar

Baja probabilidad de cambio. Se reconsideraría solo ante un cambio
estratégico de herramienta de gestión de proyecto (si Jira dejara de ser
la herramienta elegida, ver [jira.md](./jira.md)) que hiciera más
conveniente otra plataforma de Git con mejor integración nativa.