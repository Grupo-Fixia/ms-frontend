# Jira

**Estado en el Tech Radar:** 🟢 Adoptar
**Categoría:** Herramientas
**Última revisión:** 2026-08-24

## Contexto

Fixia sigue metodología Scrum (ver
[04-gobierno-ciclo-vida](../../04-gobierno-ciclo-vida/)) con sprints de 2
semanas, y necesita que todo el trabajo (historias, tareas, bugs) quede
representado como ticket, trazable hasta el commit y el Pull Request que
lo resuelve.

## Decisión

Jira como herramienta de gestión de proyecto, integrada con GitHub
mediante la app "GitHub for Jira" y Smart Commits.

## Alternativas consideradas

| Opción | Por qué no |
|---|---|
| **Trello** | Demasiado simple para el nivel de trazabilidad que exige la política de "ningún commit sin ticket asociado"; no tiene flujo de estados configurable ni Smart Commits equivalentes. |
| **Linear** | Herramienta moderna y ágil, con buena integración a GitHub, pero sin la profundidad de reporting y configuración de flujos de Jira que un equipo con múltiples microservicios y dominios necesita a mediano plazo. |
| **GitHub Issues (sin Jira)** | Suficiente para proyectos pequeños de un solo repositorio, pero Fixia tiene múltiples repositorios (`fixia-msv-*`, `fixia-web-*`, etc.); Jira permite una vista unificada de todo el trabajo del equipo sin importar en qué repositorio termine el código. |

## Justificación para Fixia

1. **Trazabilidad obligatoria entre negocio y código.** La política de
   Fixia exige que ningún commit o PR exista sin un ticket de Jira
   asociado (ver
   [04-gobierno-ciclo-vida](../../04-gobierno-ciclo-vida/)). Jira, vía
   Smart Commits, permite que un commit transicione automáticamente el
   estado del ticket (`#in-review`, `#close`), sin trabajo manual
   duplicado entre herramientas.
2. **Vista unificada a través de múltiples repositorios.** Con una
   arquitectura de microservicios, el trabajo de un sprint puede tocar
   varios repositorios a la vez (ej. un cambio en Solicitudes que también
   requiere un cambio en Notificaciones). Jira centraliza ese trabajo en
   un solo backlog, mientras que el código vive distribuido en GitHub.
3. **Soporta el ciclo de vida completo definido en ISO/IEC/IEEE 12207**
   (acuerdo, proyecto, implementación, soporte, operación — ver
   [04-gobierno-ciclo-vida/estandares-internacionales.md](../../04-gobierno-ciclo-vida/)),
   con tipos de ticket diferenciados (Story, Task, Bug, Spike) que
   reflejan distintas fases de ese ciclo.

## Cómo se usa en el proyecto

- Todo trabajo se representa como ticket: Story, Task, Bug o Subtarea.
- Flujo de estados: `Backlog → To Do → In Progress → In Review (PR) →
  QA/Testing → Done`.
- Smart Commits habilitados: comandos `#comment`, `#time`, `#close`,
  `#in-review` en el mensaje de commit.
- `#close` solo se usa en el commit del PR que se fusiona a `main`, nunca
  en commits intermedios de una rama `feature/*`.
- Todo commit debe llevar la clave de Jira (`PROJ-XXX`); se valida por
  hook de pre-commit o check de CI.

## Trade-offs / riesgos

- Costo de licenciamiento por usuario, a diferencia de GitHub Issues
  (incluido) o Trello (plan gratuito limitado).
- Configuración de flujos de estado requiere mantenimiento consciente:
  si el estado destino de un comando Smart Commit (ej. `#close`) no
  existe en el workflow del proyecto, el comando falla silenciosamente.

## Cuándo reconsiderar

Si el overhead de mantener Jira (configuración, licencias) supera
claramente el valor de trazabilidad que aporta, para un equipo que
eventualmente decida operar con un único repositorio o con necesidades de
gestión mucho más simples que las actuales.