# Debezium (Change Data Capture)

**Estado en el Tech Radar:** 🟡 Probar
**Categoría:** Plataformas & Infraestructura
**Última revisión:** 2026-09-20

## Contexto

El microservicio de Procesamiento (Go, ver
[lenguajes-frameworks/go.md](../lenguajes-frameworks/go.md)) necesita
alimentarse de los cambios que ocurren en las bases de datos
transaccionales de los demás microservicios (ver
[bases-de-datos.md](./bases-de-datos.md)), sin acoplarse directamente a
ellas ni violar el principio Database per Service (ver
[10-seguridad-datos](../../10-seguridad-datos/)).

## Decisión

Debezium (vía Kafka Connect) se adopta, en estado **Probar**, como
mecanismo de Change Data Capture (CDC): lee los logs de cambios de las
bases PostgreSQL/MongoDB y publica esos cambios como eventos en Kafka.

## Alternativas consideradas

| Opción | Por qué no |
|---|---|
| **Consultas periódicas (polling) a cada base de datos** | Añade carga innecesaria a las bases transaccionales y latencia; CDC lee directamente del log de transacciones sin impactar el rendimiento de las consultas de negocio. |
| **Cada microservicio publica sus propios eventos de dominio manualmente para todo** | Válido y ya se usa para eventos de negocio explícitos (ver [tecnicas-metodos/event-driven.md](../tecnicas-metodos/event-driven.md)), pero no cubre el caso de ingesta masiva de datos para el lakehouse sin que cada equipo tenga que instrumentar manualmente cada cambio de tabla relevante. |

## Justificación para Fixia

1. **Desacopla el pipeline de datos de la lógica de negocio.** Un
   microservicio no necesita saber que sus cambios de datos terminan en
   un lakehouse — Debezium lee el log de la base de datos sin requerir
   código adicional en el microservicio dueño de esos datos.
2. **Respeta Database per Service.** El microservicio de Procesamiento
   nunca consulta directamente la base de datos de otro microservicio
   (ver [10-seguridad-datos](../../10-seguridad-datos/)); recibe los
   cambios ya publicados como eventos en Kafka.
3. **Se apoya en la infraestructura ya adoptada** (Kafka, ver
   [kafka.md](./kafka.md)), sin sumar un broker de mensajería adicional
   solo para este caso de uso.

## Por qué está en "Probar"

Es un componente nuevo en el stack, cuya configuración específica por
motor de base de datos (PostgreSQL vs. MongoDB, ver
[bases-de-datos.md](./bases-de-datos.md)) y cuyo impacto real en el
rendimiento de las bases de origen todavía no está validado en
producción.

## Cómo se usa en el proyecto

- Corre en el namespace `cdc` del cluster K3s, como conectores de Kafka
  Connect.
- Captura cambios de las bases PostgreSQL de los microservicios y de la
  base MongoDB de `ms-communication` (ver
  [bases-de-datos.md](./bases-de-datos.md)), publicándolos en Kafka.
- El microservicio de Procesamiento (Go) consume esos streams para
  alimentar el lakehouse en MinIO (ver [minio.md](./minio.md)).

## Trade-offs / riesgos

- Configuración adicional por cada base de datos que se quiera capturar
  (habilitar logical replication en PostgreSQL, oplog en MongoDB).
- Un conector de Debezium mal configurado o caído puede generar retraso
  (lag) en los datos que llegan al lakehouse — se debe monitorear como
  parte del stack de observabilidad (ver
  [observabilidad.md](./observabilidad.md)).

## Cuándo reconsiderar

Pasa a **Adoptar** cuando esté validado en producción con al menos las
fuentes de datos principales (PostgreSQL y MongoDB) capturando cambios de
forma estable y monitoreada.
