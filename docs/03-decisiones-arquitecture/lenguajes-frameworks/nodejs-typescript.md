# Node.js + TypeScript

**Estado en el Tech Radar:** 🟢 Adoptar
**Categoría:** Lenguajes & Frameworks
**Última revisión:** 2026-08-24

## Contexto

La mayoría de los microservicios de Fixia son de carga **I/O-bound**:
reciben una request HTTP, consultan una base de datos o llaman a otro
microservicio, y devuelven una respuesta (Usuarios, Proveedores,
Solicitudes, Notificaciones, el API Gateway). Necesitamos un lenguaje por
defecto para este tipo de trabajo, que sea también el que la mayoría del
equipo pueda mantener sin especialización previa.

## Decisión

Node.js con TypeScript es el lenguaje/framework **por defecto** para
microservicios backend de tipo orquestación de APIs, salvo que el dominio
justifique explícitamente otra elección (ver
[README.md](./README.md#criterio-de-selección-por-tipo-de-carga)).

## Alternativas consideradas

| Opción | Por qué no como default |
|---|---|
| **JavaScript sin tipado** | Sin TypeScript, se pierde detección temprana de errores en contratos entre microservicios (especialmente relevante dado el estándar JSON estricto que define Fixia, ver [07-calidad-arquitectura](../../07-calidad-arquitectura/)). |
| **Java (Spring Boot)** | Mayor curva de setup y verbosidad para el tipo de servicios CRUD/orquestación que domina el catálogo actual; ver [poliglotismo-controlado.md](./poliglotismo-controlado.md) para cuándo sí se justificaría. |
| **.NET (C#)** | Válido técnicamente, pero introduce un ecosistema de herramientas y runtime distinto sin un beneficio claro sobre Node.js para este tipo de carga, y el equipo no tiene especialización previa en .NET. |
| **Go** | Buen candidato para servicios de altísima concurrencia, pero no fue evaluado formalmente todavía; queda como candidato futuro si algún dominio lo justifica (ver proceso de RFC en [CONTRIBUTING.md](../../../CONTRIBUTING.md)). |

## Justificación para Fixia

1. **Mismo lenguaje que el frontend (React).** Reduce la fricción de
   contexto: un desarrollador full-stack puede moverse entre el backend de
   Solicitudes y el frontend del portal sin cambiar de lenguaje mental.
2. **Modelo asíncrono no bloqueante**, adecuado para microservicios que
   pasan la mayor parte del tiempo esperando respuesta de una base de
   datos u otro microservicio (justo el perfil de Usuarios, Proveedores,
   Solicitudes).
3. **TypeScript refuerza el contrato JSON entre microservicios.** El
   estándar JSON de Fixia (camelCase, ISO 8601, estructura de respuesta
   estándar — ver [07-calidad-arquitectura](../../07-calidad-arquitectura/))
   se beneficia directamente de tipado estático: los DTOs se validan en
   tiempo de compilación, no solo en tiempo de ejecución.
4. **Curva de contratación/onboarding más accesible** que alternativas
   como Java/.NET para el tamaño de equipo actual de Fixia.

## Cómo se usa en el proyecto

- Todo microservicio Node.js sigue la estructura de Clean Architecture
  definida en [07-calidad-arquitectura](../../07-calidad-arquitectura/)
  (`domain/`, `application/`, `infrastructure/`, `interfaces/`).
- Linter y formateo obligatorios: ESLint + Prettier (ver
  [Políticas de Código y Revisión](../../04-gobierno-ciclo-vida/) del
  documento base).
- Los ejemplos de código de referencia de toda la wiki (pipelines,
  patrones, tests) usan TypeScript/Node.js salvo que se indique lo
  contrario, precisamente porque es el default del proyecto.

## Trade-offs / riesgos

- No es la opción más eficiente para procesamiento intensivo de CPU
  (cálculos geoespaciales complejos, por ejemplo) — por eso esos dominios
  usan Python (ver [python-fastapi.md](./python-fastapi.md)) en vez de
  forzar Node.js en todos los casos.
- El ecosistema npm tiene una superficie de ataque de dependencias mayor
  que otros ecosistemas; se mitiga con escaneo de dependencias obligatorio
  en CI (ver [10-seguridad-datos](../../10-seguridad-datos/)).

## Cuándo reconsiderar

Si un microservicio de este tipo de carga demuestra cuellos de botella de
rendimiento que Node.js no puede resolver de forma razonable (poco
probable para el perfil I/O-bound descrito), se evaluaría puntualmente,
no como cambio de default general.