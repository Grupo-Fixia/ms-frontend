# Herramientas Complementarias

**Última revisión:** 2026-08-24

Estas herramientas tienen menor impacto arquitectónico que las de las
páginas anteriores (no condicionan cómo se construye o despliega el
software), por lo que se agrupan en una sola página con una justificación
más breve. Si alguna crece en importancia o genera controversia, se separa
a su propia página siguiendo la
[plantilla de decisión](../../00-inicio/plantilla-decision.md).

## VS Code

**Estado:** 🟢 Adoptar · **Uso:** editor de código recomendado.

Se recomienda por su ecosistema de extensiones para TypeScript, Python y
Docker (los pilares del stack, ver
[lenguajes-frameworks/](../lenguajes-frameworks/)), y por ser gratuito, lo
que evita fricción de licenciamiento para nuevos desarrolladores. No es
obligatorio: cualquier editor es válido siempre que el código resultante
respete linter y formateo estándar del repositorio.

## Figma

**Estado:** 🟢 Adoptar · **Uso:** diseño de UI/UX del portal y backoffice.

Elegido por ser el estándar de facto para diseño colaborativo de interfaces
y por su buena integración con flujos de handoff a desarrollo frontend
(React, ver [lenguajes-frameworks/react.md](../lenguajes-frameworks/react.md)).

## Slack

**Estado:** 🟢 Adoptar · **Uso:** comunicación del equipo y notificaciones automatizadas.

Usado como canal de notificaciones de CI/CD (fallos de pipeline, alertas
de Alertmanager) y de comunicación diaria del equipo. Se prefiere sobre
WhatsApp para comunicación de trabajo porque permite canales temáticos,
integraciones con GitHub Actions/Grafana, e historial searchable — WhatsApp
queda para comunicación informal o de contacto rápido, no como canal
oficial de alertas o decisiones de equipo.

## Grafana (+ Prometheus)

**Estado:** 🟢 Adoptar · **Uso:** dashboards de métricas de infraestructura y aplicación.

Elegido junto con Prometheus por ser el estándar de facto de observabilidad
open source, con buen soporte para métricas de contenedores/K3s (ver
[plataformas-infraestructura/k3s-kubernetes.md](../plataformas-infraestructura/k3s-kubernetes.md)).
Detalle operativo completo en
[09-infraestructura-devops](../../09-infraestructura-devops/).

## Draw.io y Mermaid

**Estado:** 🟢 Adoptar · **Uso:** diagramas técnicos (arquitectura, flujos).

Mermaid se prioriza para diagramas que viven **dentro** de esta wiki (como
el mapa de dominios en
[01-contexto-proyecto](../../01-contexto-proyecto/mapa-dominios-negocio.md)),
porque se renderiza nativamente en Markdown de GitHub sin depender de
imágenes externas versionadas por separado. Draw.io se usa para diagramas
más complejos o que requieren edición visual fina, exportados como imagen
cuando Mermaid no alcanza.

## Confluence

**Estado:** 🟡 Probar · **Uso:** evaluado como alternativa de documentación, no adoptado para esta wiki.

Fixia decidió que esta wiki técnica vive en un repositorio de GitHub (ver
[00-inicio/README.md](../../00-inicio/README.md)), no en Confluence, para
mantener la documentación versionada junto al mismo flujo de Pull Requests
que el código. Confluence se mantiene en estado "Probar" como candidato
para documentación **no técnica** (ej. procesos de soporte al cliente,
documentación para el equipo de Administración/Backoffice) que no requiere
el rigor de versionado de una wiki técnica.

## Notion

**Estado:** 🟠 Evaluar · **Uso:** sin un caso de uso confirmado todavía.

Aparece en el radar como candidato a evaluar para notas rápidas o gestión
personal de tareas, pero no reemplaza a Jira (gestión formal de proyecto,
ver [jira.md](./jira.md)) ni a esta wiki (documentación técnica
versionada).

## Cuándo separar una de estas herramientas a su propia página

Si una herramienta de esta lista empieza a condicionar decisiones de
arquitectura (por ejemplo, si Grafana requiriera una configuración
específica que afecte cómo se instrumentan los microservicios), se le crea
una página propia completa con la plantilla estándar.