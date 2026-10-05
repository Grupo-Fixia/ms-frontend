# Java (Spring Boot)

**Estado en el Tech Radar:** 🟢 Adoptar (acotado a Pagos y Administración/Backoffice)
**Categoría:** Lenguajes & Frameworks
**Última revisión:** 2026-08-24

## Contexto

El dominio de **Pagos** (ver
[01-contexto-proyecto/mapa-dominios-negocio.md](../../01-contexto-proyecto/mapa-dominios-negocio.md))
necesita integrarse con una pasarela de pago externa cuyo SDK oficial —el
que recibe soporte, actualizaciones de seguridad y cumplimiento del
proveedor— está distribuido únicamente para JVM/Java. Reimplementar ese
protocolo desde cero en Node.js o Python significaría mantener una
integración no oficial (firma de requests, validación de webhooks,
manejo de reintentos) sin respaldo del proveedor, en el dominio de mayor
sensibilidad del sistema.

**Administración/Backoffice** necesita operar directamente sobre esos
mismos pagos (reembolsos manuales, conciliación, resolución de disputas),
por lo que hereda la misma dependencia del SDK.

## Decisión

Java con Spring Boot se adopta para los microservicios `fixia-msv-pagos`
y `fixia-msv-administracion` (ver nombres definitivos en
[08-estructura-microservicios](../../08-estructura-microservicios/)),
como caso delimitado y explícito de excepción al lenguaje por defecto del
proyecto. **No** es el lenguaje por defecto general de Fixia — ver
[README.md](./README.md).

## Alternativas consideradas

| Opción | Por qué no |
|---|---|
| **Reimplementar el protocolo del gateway en Node.js/TypeScript sin SDK oficial** | Implica mantener manualmente firma de requests, validación de webhooks y actualizaciones de seguridad sin soporte del proveedor — riesgo inaceptable en el dominio más sensible del sistema (dinero). |
| **Microservicio intermediario en Java solo para el SDK, consumido por Pagos en Node.js** | Agrega una capa de indirección y un punto de falla adicional sin resolver el problema de fondo: igual se necesita un componente en Java, ahora con más partes móviles. |
| **.NET (C#) en vez de Java** | Válido si el SDK de la pasarela también ofrece bindings .NET oficiales con igual nivel de soporte; se prioriza Java salvo que se confirme lo contrario al cerrar el proveedor definitivo (ver [poliglotismo-controlado.md](./poliglotismo-controlado.md), donde .NET se mantiene en Retener). |

## Justificación para Fixia

1. **Soporte oficial y actualizado del proveedor de pagos.** Usar el SDK
   oficial en Java asegura recibir actualizaciones de seguridad y
   cumplimiento directamente del proveedor — crítico en un dominio con
   los requisitos de cifrado y auditoría más estrictos de todo el sistema
   (ver [10-seguridad-datos](../../10-seguridad-datos/)).
2. **Reduce superficie de riesgo en el dominio más sensible.** Evita
   mantener una reimplementación propia de lógica de firma, validación de
   webhooks y reintentos — exactamente el tipo de código donde un error
   tiene el mayor costo posible para el negocio.
3. **Administración comparte la dependencia por necesidad operativa real,
   no por conveniencia.** El equipo de soporte necesita ejecutar
   reembolsos manuales y conciliar transacciones directamente contra el
   proveedor. Mantener dos implementaciones distintas del mismo protocolo
   (una en Pagos, otra reinventada en Administración) duplicaría el
   riesgo de seguridad en lugar de contenerlo en un solo lugar.
4. **Spring Boot aporta manejo maduro de transacciones**, un beneficio
   adicional —no el motivo principal— para un dominio que exige
   consistencia estricta.

## Cómo se usa en el proyecto

- Aplica **exclusivamente** a `fixia-msv-pagos` y
  `fixia-msv-administracion`. No se usa Java en ningún otro microservicio
  sin una justificación equivalente documentada.
- Sigue la misma Clean Architecture que el resto del sistema
  (`domain/`, `application/`, `infrastructure/`, `interfaces/`, ver
  [tecnicas-metodos/clean-architecture.md](../tecnicas-metodos/clean-architecture.md)),
  adaptada a convenciones idiomáticas de Java/Spring (paquetes por capa).
- **El cliente del SDK del proveedor de pagos vive aislado en
  `infrastructure/`**, sin filtrar sus tipos hacia `domain/` ni
  `application/`. Esto es particularmente importante acá: permite, en
  teoría, cambiar de proveedor de pago sin reescribir la lógica de
  negocio.
- Se recomienda extraer la integración con el SDK a una librería interna
  compartida (tipo `fixia-lib-pagos-sdk`, ver convención `lib` en
  [08-estructura-microservicios](../../08-estructura-microservicios/)),
  para que Pagos y Administración no dupliquen el cliente del SDK.
- Linter y formateo: Checkstyle + Google Java Format (o el estándar que
  el equipo confirme), con el mismo rigor que ESLint/Prettier en Node.js.
- El contrato de API expuesto sigue el estándar JSON del resto del
  sistema (camelCase, ISO 8601, estructura estándar de respuesta) — el
  lenguaje interno no debe filtrarse en la forma de la respuesta.

## Trade-offs / riesgos

- **Tercer/cuarto lenguaje en el stack** (sumado a Node.js, Python y Go):
  más pipelines de CI que mantener, y menos desarrolladores del equipo
  con experiencia Java hoy que con Node.js.
- Mayor verbosidad y tiempo de setup que Node.js para la parte del
  servicio que, fuera de la integración con el SDK, sigue siendo
  básicamente orquestación de APIs.
- Riesgo de atarse innecesariamente al proveedor de pago si el
  aislamiento en `infrastructure/` no se respeta con disciplina.
- Riesgo de precedente: que un microservicio nuevo sin esta necesidad de
  integración use Java "porque ya lo tenemos en el stack". Se contiene
  exigiendo que cualquier uso de Java fuera de Pagos/Administración pase
  por el mismo proceso de RFC que cualquier lenguaje nuevo (ver
  [CONTRIBUTING.md](../../../CONTRIBUTING.md)).

## Cuándo reconsiderar

- Si el proveedor de pago cambia a uno con SDK oficial y con igual nivel
  de soporte en Node.js o Python, evaluar el costo de migrar Pagos fuera
  de Java contra el beneficio de reducir un lenguaje del stack.
- Si Administración dejara de necesitar acceso directo al SDK (por
  ejemplo, si toda esa lógica se expusiera vía API interna de Pagos en
  vez de acceso directo al cliente del proveedor), reevaluar si
  Administración podría volver al lenguaje por defecto del proyecto.