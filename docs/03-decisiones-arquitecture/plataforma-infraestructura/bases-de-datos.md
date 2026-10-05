# Bases de Datos: PostgreSQL por defecto, MongoDB como excepción

**Estado en el Tech Radar:** 🟢 Adoptar (PostgreSQL) · 🟡 Probar (MongoDB, acotado)
**Categoría:** Plataformas & Infraestructura
**Última revisión:** 2026-09-20

## Contexto

El principio Database per Service (ver
[10-seguridad-datos](../../10-seguridad-datos/)) exige que cada
microservicio sea dueño de su propia base de datos, pero no fijaba
todavía qué motor usar por defecto. El diagrama de infraestructura
confirma PostgreSQL para la mayoría de los microservicios, y MongoDB para
uno puntual.

## Decisión

**PostgreSQL** es el motor de base de datos por defecto para todo
microservicio nuevo. **MongoDB** se usa como excepción puntual donde el
modelo de datos lo justifique, siguiendo el mismo espíritu de
"poliglotismo controlado" ya aplicado a lenguajes (ver
[lenguajes-frameworks/poliglotismo-controlado.md](../lenguajes-frameworks/poliglotismo-controlado.md)).

## Alternativas consideradas

| Opción | Por qué no como default |
|---|---|
| **MongoDB como default general** | La mayoría de los dominios de Fixia (usuarios, servicios, pagos, calificaciones) tienen datos altamente relacionales con necesidad de integridad referencial y transacciones ACID estrictas — el punto fuerte de PostgreSQL, no el de un motor documental. |
| **Un motor distinto por cada microservicio, sin criterio** | Fragmentaría innecesariamente el conocimiento operativo del equipo de DevOps (backups, monitoreo, tuning) sin un beneficio claro para la mayoría de los casos. |

## Justificación para Fixia

1. **PostgreSQL cubre bien la mayoría de los dominios**: `ms-services`,
   `ms-orders`, `ms-pago`, `ms-grading` y la parte estructurada de
   `ms-communication` tienen datos con relaciones claras y necesidad de
   consistencia transaccional (especialmente crítico en pagos, ver
   [lenguajes-frameworks/java.md](../lenguajes-frameworks/java.md)).
2. **MongoDB se usa puntualmente en `ms-communication`** (conviviendo con
   una base PostgreSQL en el mismo microservicio), probablemente para
   contenido con esquema más flexible o de alto volumen de escritura
   (ej. historial de mensajes/conversaciones) donde un esquema rígido
   relacional agregaría fricción sin beneficio.
3. **Consistente con el criterio ya usado para lenguajes**: un motor por
   defecto que cubre la mayoría de los casos, y una excepción puntual
   justificada por el tipo de dato, no por preferencia.

## ⚠️ Punto a confirmar

`ms-communication` aparece con **dos bases de datos** (PostgreSQL y
MongoDB) en el mismo microservicio. Antes de fijar esto como patrón
aceptado, conviene confirmar con el equipo:

- ¿Qué datos concretos vive en cada motor dentro de ese microservicio?
- ¿Sigue respetando que ambas bases son de uso exclusivo de
  `ms-communication` (nadie más las consulta directamente), o hay algún
  acceso cruzado a validar?

## Cómo se usa en el proyecto

- Todo microservicio nuevo usa PostgreSQL salvo justificación explícita
  documentada (siguiendo el proceso de RFC, ver
  [CONTRIBUTING.md](../../../CONTRIBUTING.md)).
- Cada base de datos corre dentro del cluster K3s, con almacenamiento en
  volúmenes locales (ver [kubernetes.md](./kubernetes.md)).
- Credenciales de conexión gestionadas vía Vault (ver
  [vault.md](./vault.md)), con usuario dedicado de mínimo privilegio por
  microservicio (ver [10-seguridad-datos](../../10-seguridad-datos/)).
- Ambos motores son fuente de captura para el pipeline de CDC (ver
  [debezium-cdc.md](./debezium-cdc.md)).

## Trade-offs / riesgos

- Mantener dos motores de base de datos implica dos configuraciones de
  backup, monitoreo y tuning distintas para el equipo de DevOps.
- Un microservicio con dos bases de datos (`ms-communication`) es más
  complejo de operar y de razonar que uno con una sola — se debe
  justificar explícitamente por qué no conviene separar esos datos en
  dos microservicios distintos.

## Cuándo reconsiderar

Si aparecen más microservicios que necesiten un motor distinto a
PostgreSQL sin una justificación tan clara como la de `ms-communication`,
revisar si se está perdiendo disciplina en el criterio de "excepción
justificada, no preferencia".
