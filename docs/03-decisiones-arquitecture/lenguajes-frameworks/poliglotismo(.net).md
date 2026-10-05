# Poliglotismo Controlado (.NET y otros)

**Estado en el Tech Radar:** 🟣 Retener
**Categoría:** Lenguajes & Frameworks
**Última revisión:** 2026-08-24

## Contexto

Con una arquitectura de microservicios, cada equipo dueño de un dominio
podría, en teoría, elegir el lenguaje que prefiera para su servicio. Sin
control, esto deriva en un stack fragmentado difícil de mantener con un
equipo chico. Esta página fija la regla general para cualquier lenguaje
que no sea uno de los ya adoptados (Node.js/TypeScript, Python, React,
Go, Java — ver [README.md](./README.md)).

> **Nota de historial:** esta página originalmente incluía a Java
> (Spring Boot) como ejemplo de lenguaje en "Retener". Java dejó de
> aplicar acá porque surgió una necesidad concreta (integración con el
> SDK oficial de una pasarela de pagos, solo disponible en Java) que
> siguió el proceso de RFC descrito abajo y ganó su propia página de
> decisión: ver [java.md](./java.md). Es el caso de referencia de cómo
> funciona este proceso en la práctica — no una excepción a la regla,
> sino la regla funcionando como está pensada.

## Decisión

.NET (C#) queda en estado **Retener**: no se usa por defecto en ningún
microservicio nuevo. Cualquier lenguaje fuera de los ya adoptados (ver
[README.md](./README.md)) requiere una página de decisión propia y
aprobación explícita antes de usarse en producción.

## Alternativas consideradas

| Opción | Por qué no es el default hoy |
|---|---|
| **.NET (C#)** | Buena opción técnica en abstracto, pero sin una necesidad concreta de Fixia que la justifique frente a Node.js/Python/Go/Java ya adoptados, y el equipo no tiene especialización previa que reduzca el costo de adopción. |

## Justificación para Fixia

1. **Un equipo chico no puede sostener muchos stacks a la vez.** Cada
   lenguaje adicional implica: su propio pipeline de CI, su propio set de
   herramientas de linting/testing, y desarrolladores que sepan
   mantenerlo. Con Node.js/TypeScript, Python, Go y Java ya cubriendo
   todos los tipos de carga identificados (ver
   [README.md](./README.md#criterio-de-selección-por-tipo-de-carga)), sumar
   .NET sin una necesidad concreta es costo puro sin beneficio.
2. **Ningún dominio actual de Fixia exige específicamente lo que .NET
   resuelve mejor** (por ejemplo, integración profunda con ecosistema
   Microsoft). Si eso cambia — por ejemplo, una integración con un sistema
   externo que solo ofrezca SDK en .NET, el mismo tipo de motivo que
   sacó a Java de esta página — se evalúa puntualmente con el mismo
   proceso de RFC.
3. **Mantener el radar honesto.** Que .NET aparezca en "Retener" no
   significa que sea una mala tecnología: significa que, para el
   contexto actual de Fixia, no hay razón suficiente para pagar el costo
   de introducirla.

## Cómo se usa en el proyecto: proceso para sumar un lenguaje nuevo

1. Identificar una necesidad concreta que los lenguajes ya adoptados no
   cubren razonablemente (no "preferencia personal" ni "lo usé en otro
   trabajo"). El caso real de Java (ver [java.md](./java.md)) es el
   ejemplo de referencia: una dependencia obligada de un SDK externo,
   no una preferencia de equipo.
2. Seguir el proceso de RFC de tecnología en
   [CONTRIBUTING.md](../../../CONTRIBUTING.md): crear la página de
   decisión con la plantilla estándar, entrando en estado **Evaluar**
   (o directamente en un estado más avanzado si, como con Java, la
   necesidad ya es firme y no experimental — documentando por qué).
3. Validarlo primero en un spike o prueba de concepto cuando la
   necesidad lo permita; si la integración es obligatoria y sin
   alternativa real (como el SDK de pagos), documentar esa condición
   explícitamente en la página de decisión.
4. Delimitar el alcance con precisión: el lenguaje nuevo aplica **solo**
   a los microservicios que motivaron su adopción, no se vuelve una
   opción general disponible para cualquier equipo (ver el alcance
   acotado de Java a Pagos/Administración en [java.md](./java.md) como
   ejemplo).

## Trade-offs / riesgos de esta restricción

- Puede sentirse limitante si un desarrollador tiene fuerte experiencia
  previa en .NET y preferiría usarlo. Se prioriza la sostenibilidad del
  stack como equipo sobre la preferencia individual.
- Si en el futuro surge una integración externa que sí requiera .NET, el
  proceso de RFC permite incorporarlo sin fricción burocrática excesiva
  — la restricción es contra el poliglotismo sin criterio, no contra
  este lenguaje en sí.

## Cuándo reconsiderar

Cualquier propuesta concreta con una necesidad de negocio o técnica real
detrás, siguiendo el proceso de RFC. No se reconsidera "en general" sin
un caso de uso específico que lo motive.