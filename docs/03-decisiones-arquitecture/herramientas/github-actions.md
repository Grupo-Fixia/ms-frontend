# GitHub Actions

**Estado en el Tech Radar:** 🟢 Adoptar
**Categoría:** Herramientas
**Última revisión:** 2026-08-24

## Contexto

Cada microservicio de Fixia necesita un pipeline de CI/CD: build, tests,
análisis de calidad (Quality Gate), y despliegue a los distintos
ambientes. Con decenas de repositorios previstos, la herramienta de CI/CD
debe ser fácil de replicar y mantener consistente entre repos.

## Decisión

GitHub Actions, con **self-hosted runners** ubicados en la infraestructura
on-premise actual.

## Alternativas consideradas

| Criterio | GitHub Actions | Jenkins |
|---|---|---|
| Integración con Jira | Nativa vía "GitHub for Jira" | Requiere plugins adicionales |
| Mantenimiento | Gestionado, sin servidor propio que administrar | Requiere administrar servidor/agentes |
| Versionado del pipeline | Vive junto al código (`.github/workflows`) | Configuración separada (Jenkinsfile o UI) |
| Curva de adopción | Baja, sintaxis YAML simple | Media/alta |
| Runners on-premise | Soportado (self-hosted runners) | Soportado (nativo) |
| Escalabilidad a nube futura | Acciones oficiales para AWS/Azure/GCP | Requiere plugins por proveedor |

Jenkins fue la alternativa principal evaluada, dado que es el estándar
histórico de la industria para CI/CD on-premise. Se descartó como default
por el mantenimiento adicional que implica administrar servidor y
agentes, sin un beneficio claro sobre GitHub Actions para el tamaño actual
del equipo de DevOps.

## Justificación para Fixia

1. **Cero servidor de CI adicional que mantener.** El equipo de DevOps de
   Fixia es reducido; no tener que administrar un servidor Jenkins además
   de la infraestructura de los microservicios reduce carga operativa
   directa.
2. **El pipeline vive junto al código.** Cada repositorio `fixia-msv-*`
   define su propio `.github/workflows/`, lo que mantiene el pipeline
   versionado con el mismo Git Workflow que el resto del código (ver
   [git-github.md](./git-github.md)), en vez de una configuración
   centralizada separada.
3. **Self-hosted runners resuelven la necesidad on-premise actual sin
   cerrar la puerta a runners cloud.** Esto está directamente alineado con
   la estrategia de portabilidad de toda la infraestructura (ver
   [plataformas-infraestructura/on-premise.md](../plataformas-infraestructura/on-premise.md)):
   el mismo pipeline puede correr en runners cloud el día que Fixia migre,
   sin reescribir el flujo de CI/CD.
4. **Integración directa con Jira**, necesaria para que el estado de un
   ticket refleje automáticamente el estado de su pipeline asociado.

## Cómo se usa en el proyecto

- Estructura estándar por repositorio:
  `ci.yml` (build + tests en cada PR), `cd-staging.yml` (despliegue
  automático a test), `cd-production.yml` (despliegue a producción,
  manual/aprobado).
- Etapas del pipeline CI: checkout, dependencias, lint, tests unitarios,
  tests de integración, build de imagen Docker, análisis de seguridad
  (SAST/dependencias), publicación del artefacto.
- Runners self-hosted en red segmentada, sin acceso directo a producción
  salvo por el paso de despliegue autorizado.
- Ver detalle completo de ambientes, secrets y aprobaciones en
  [06-cicd-ambientes](../../06-cicd-ambientes/).

## Trade-offs / riesgos

- Los self-hosted runners son responsabilidad del equipo de DevOps
  (parcheo, seguridad, disponibilidad) — a diferencia de runners
  gestionados por GitHub en la nube.
- Menor cantidad de plugins de terceros maduros que Jenkins para
  integraciones muy específicas o legacy.

## Cuándo reconsiderar

- Si el volumen de pipelines crece a un punto donde los self-hosted
  runners on-premise se vuelven un cuello de botella real (no solo
  percibido), evaluar sumar runners cloud (ya soportado sin cambiar de
  herramienta) antes de migrar de plataforma de CI/CD.