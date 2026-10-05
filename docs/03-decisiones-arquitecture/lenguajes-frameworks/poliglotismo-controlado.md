# Poliglotismo Controlado (Java, .NET y otros)

**Estado en el Tech Radar:** 🟣 Retener
**Categoría:** Lenguajes & Frameworks
**Última revisión:** 2026-08-24

## Contexto

Con una arquitectura de microservicios, cada equipo dueño de un dominio
podría, en teoría, elegir el lenguaje que prefiera para su servicio. Sin
control, esto deriva en un stack fragmentado difícil de mantener con un
equipo chico. Esta página fija la regla general para cualquier lenguaje
que no sea uno de los ya adoptados (Node.js/TypeScript, Python, React).

## Decisión

Java (Spring Boot) y .NET (C#) quedan en estado **Retener**: no se usan
por defecto en ningún microservicio nuevo. Cualquier lenguaje fuera de los
ya adoptados (ver [README.md](./README.md)) requiere una página de
decisión propia y aprobación explícita antes de usarse en producción.

## Alternativas consideradas

Esta página no compara Java vs .NET entre sí (ninguno está en uso hoy),
sino que documenta **por qué ninguno de los dos es el default**, frente a
lo ya adoptado:

| Opción | Por qué no es el default hoy |
|---|---|
| **Java (Spring Boot)** | Fuerte candidato técnico para servicios con alta necesidad de tipado estricto y ecosistema enterprise, pero mayor verbosidad y tiempo de setup que Node.js para el perfil de microservicios I/O-bound que domina el catálogo actual de Fixia. No hay hoy un dominio que exija específicamente lo que Java resuelve mejor que las opciones ya adoptadas. |
| **.NET (C#)** | Mismo razonamiento: buena opción técnica en abstracto, pero sin una necesidad concreta de Fixia que la justifique frente a Node.js/Python, y el equipo no tiene especialización previa que reduzca el costo de adopción. |

## Justificación para Fixia

1. **Un equipo chico no puede sostener muchos stacks a la vez.** Cada
   lenguaje adicional implica: su propio pipeline de CI, su propio set de
   herramientas de linting/testing, y desarrolladores que sepan
   mantenerlo. Con Node.js/TypeScript, Python y React ya cubriendo todos
   los tipos de carga identificados (ver
   [README.md](./README.md#criterio-de-selección-por-tipo-de-carga)), sumar
   Java o .NET sin una necesidad concreta es costo puro sin beneficio.
2. **Ningún dominio actual de Fixia exige específicamente lo que Java o
   .NET resuelven mejor** (por ejemplo, integración profunda con
   ecosistema Microsoft, o necesidades enterprise específicas de Java).
   Si eso cambia — por ejemplo, una integración con un sistema externo que
   solo ofrezca SDK en uno de estos lenguajes — se evalúa puntualmente.
3. **Mantener el radar honesto.** Que estas tecnologías aparezcan en
   "Retener" no significa que sean malas: significa que, para el contexto
   actual de Fixia, no hay razón suficiente para pagar el costo de
   introducirlas.

## Cómo se usa en el proyecto: proceso para sumar un lenguaje nuevo

1. Identificar una necesidad concreta que los lenguajes ya adoptados no
   cubren razonablemente (no "preferencia personal" ni "lo usé en otro
   trabajo").
2. Seguir el proceso de RFC de tecnología en
   [CONTRIBUTING.md](../../../CONTRIBUTING.md): crear la página de
   decisión con la plantilla estándar, entrando en estado **Evaluar**.
3. Validarlo primero en un spike o prueba de concepto, nunca directo en
   un microservicio de producción.
4. Solo pasa a **Probar** con evidencia real de uso, siguiendo el mismo
   camino que Python siguió (ver
   [python-fastapi.md](./python-fastapi.md)) antes de ganarse su lugar
   como opción válida para cierto tipo de carga.

## Trade-offs / riesgos de esta restricción

- Puede sentirse limitante si un desarrollador tiene fuerte experiencia
  previa en Java o .NET y preferiría usarlo. Se prioriza la
  sostenibilidad del stack como equipo sobre la preferencia individual.
- Si en el futuro surge una integración externa que sí requiera uno de
  estos lenguajes, el proceso de RFC permite incorporarlo sin fricción
  burocrática excesiva — la restricción es contra el poliglotismo sin
  criterio, no contra estos lenguajes en sí.

## Cuándo reconsiderar

Cualquier propuesta concreta con una necesidad de negocio o técnica real
detrás, siguiendo el proceso de RFC. No se reconsidera "en general" sin
un caso de uso específico que lo motive.