# Confluence

**Estado en el Tech Radar:** 🟢 Adoptar  
**Categoría:** Herramientas  
**Última revisión:** 2026-08-24  

## Contexto

El proyecto Fixia exige una gestión centralizada y estructurada de la documentación técnica, arquitectónica (ADRs), funcional (SRS, casos de uso), actas de reunión y guías de *onboarding* para los integrantes del equipo (desarrolladores, QA, Product Owner y evaluadores académicos).

## Decisión

Confluence como la plataforma centralizada para la documentación del proyecto, gestión del conocimiento y especificación de requisitos.

## Alternativas consideradas

| Opción | Por qué no |
| --- | --- |
| **Documentación distribuida solo en repositorios Git (Archivos Markdown)** | Aunque los archivos Markdown son excelentes para documentación cercana al código (`README.md`, ADRs), no facilitan la colaboración en tiempo real con roles no técnicos (ej. Product Owner, analistas) ni la organización jerárquica de minutas o requisitos de negocio. |
| **Google Docs / Drive** | Carece de trazabilidad estructurada de arquitectura, integración nativa con Jira y organización modular por espacios de trabajo técnicos. |

## Justificación para Fixia

1. **Integración nativa con Jira:** Permite vinculación entre requisitos funcionales (ej. RF-001 a RF-061) y reglas de negocio con las historias de usuario y tareas de desarrollo en tiempo real.
2. **Organización jerárquica y colaborativa:** Facilita la creación de una base de conocimiento centralizada con control de versiones de páginas, comentarios y aprobaciones.
3. **Estandarización de plantillas:** Permite usar plantillas homogéneas para minutas de reuniones, especificación de requisitos (SRS) y registros de decisiones de arquitectura (ADRs).

## Cómo se usa en el proyecto

* Centralización del SRS (Especificación de Requisitos de Software) y del modelo de negocio.
* Documentación del onboarding del equipo, guías de ambiente local y políticas de arquitectura.
* Vinculación de páginas de contexto con las épicas y tickets de Jira.

## Trade-offs / riesgos

* Riesgo de obsolescencia si el equipo no mantiene la disciplina de actualizar la documentación a la par con el código.
* Costo potencial de licenciamiento o restricciones de almacenamiento en planes gratuitos al escalar el equipo.

## Cuándo reconsiderar

Se reconsideraría únicamente si el equipo decide migrar el 100% de la documentación hacia un enfoque *Docs-as-Code* alojado exclusivamente en el repositorio de GitHub mediante un generador de sitios estáticos (ej. MkDocs/Docusaurus).
