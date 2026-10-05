# DevOps (Cultura y Práctica)

**Estado en el Tech Radar:** 🟢 Adoptar
**Categoría:** Técnicas & Métodos
**Última revisión:** 2026-08-24

## Contexto

Con microservicios independientes desplegándose por separado (ver
[01-contexto-proyecto/por-que-microservicios.md](../../01-contexto-proyecto/por-que-microservicios.md)),
Fixia necesita definir **quién es responsable de qué pasa después del
merge**: ¿el equipo de desarrollo entrega el código y otro equipo lo
despliega y opera, o el mismo equipo que lo construye es responsable de
que corra bien en producción?

## Decisión

Fixia adopta DevOps como práctica de trabajo: los equipos de desarrollo
son responsables end-to-end de sus microservicios (código, tests,
pipeline, y participación en la operación), apoyados por un rol/equipo
DevOps que provee la plataforma, estándares y herramientas comunes — no
que "recibe" el código para desplegarlo de forma aislada.

## Alternativas consideradas

| Opción | Por qué no |
|---|---|
| **Equipo de Operaciones separado (modelo tradicional Dev vs Ops)** | Genera fricción y lentitud exactamente donde Fixia necesita velocidad: cada despliegue requeriría coordinación entre dos equipos distintos, contradiciendo el motivo de elegir microservicios (equipos dueños end-to-end de su dominio). |
| **Cada equipo totalmente autónomo, sin estándares comunes de DevOps** | Sin un rol que vele por consistencia entre repositorios (pipelines, ambientes, secretos), cada microservicio terminaría con su propia forma de desplegarse, perdiendo las ventajas de la plantilla de bootstrap estándar (ver [08-estructura-microservicios](../../08-estructura-microservicios/)). |

## Justificación para Fixia

1. **Coherente con "equipos dueños de un dominio completo"**, la
   justificación original de microservicios: si un equipo es dueño de
   Solicitudes pero no puede desplegarlo ni ver sus métricas en
   producción, en la práctica no es realmente dueño del dominio.
2. **Reduce el tiempo entre "código listo" y "código en producción"**,
   relevante para un negocio donde la disponibilidad de búsqueda y
   matching en tiempo real es la propuesta de valor central.
3. **El rol de DevOps se especializa en la plataforma común** (runners
   self-hosted, Terraform, K3s, observabilidad — ver
   [plataformas-infraestructura/](../plataformas-infraestructura/)), no
   en desplegar manualmente cada microservicio.

## Cómo se usa en el proyecto

- Cada equipo de desarrollo es responsable de: su pipeline de CI/CD
  (`.github/workflows/`), sus tests, y de responder a incidentes de su
  propio dominio en el esquema de guardia/on-call (ver
  [12-gestion-incidentes](../../12-gestion-incidentes/)).
- El rol/equipo DevOps es responsable de: la infraestructura compartida
  (Terraform, runners, observabilidad), la plantilla de bootstrap de
  microservicios, y la aprobación final de despliegues a producción (ver
  [11-ambientes-despliegues](../../11-ambientes-despliegues/)).
- El paso `test → producción` siempre requiere aprobación manual de un
  Tech Lead o DevOps — es el único punto donde el modelo introduce un
  control centralizado deliberado, por el riesgo que implica producción.

## Trade-offs / riesgos

- Requiere que desarrolladores tengan cierto conocimiento operativo
  (leer logs, entender un dashboard de Grafana), no solo saber escribir
  código de negocio.
- Sin un rol DevOps con autoridad clara sobre estándares comunes, el
  modelo puede degradar en fragmentación (cada equipo reinventando su
  propio pipeline).

## Cuándo reconsiderar

Si el equipo crece mucho y la carga operativa distribuida entre
desarrolladores empieza a afectar la velocidad de entrega de
funcionalidad, evaluar reforzar el equipo DevOps central antes de volver
a un modelo Dev/Ops separado.
