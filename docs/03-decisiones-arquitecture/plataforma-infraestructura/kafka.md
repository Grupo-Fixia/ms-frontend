# Kafka (modo KRaft)

**Estado en el Tech Radar:** 🟢 Adoptar (confirma la evaluación de [tecnicas-metodos/event-driven.md](../tecnicas-metodos/event-driven.md))
**Categoría:** Plataformas & Infraestructura
**Última revisión:** 2026-09-20

## Contexto

La técnica de comunicación Event-Driven (ver
[tecnicas-metodos/event-driven.md](../tecnicas-metodos/event-driven.md))
estaba evaluando RabbitMQ o Kafka como broker de mensajería, sin decisión
tomada. El diagrama de infraestructura confirma Kafka.

## Decisión

Kafka en **modo KRaft** (sin dependencia de ZooKeeper) es el broker de
eventos del sistema, corriendo en el namespace `messaging` del cluster K3s.

## Alternativas consideradas

Ver comparación completa RabbitMQ vs Kafka en
[tecnicas-metodos/event-driven.md](../tecnicas-metodos/event-driven.md).
Esta página documenta específicamente por qué **KRaft** y no Kafka con
ZooKeeper:

| Opción | Por qué no |
|---|---|
| **Kafka con ZooKeeper (modo clásico)** | KRaft elimina la dependencia de un componente adicional (ZooKeeper) a operar y monitorear, relevante para un equipo de DevOps reducido operando on-premise (ver [on-premise.md](./on-premise.md)). |

## Justificación para Fixia

1. **Un componente menos que operar.** KRaft simplifica la arquitectura
   del broker eliminando ZooKeeper, coherente con la filosofía general de
   minimizar piezas operativas dado el tamaño actual del equipo de
   DevOps (ver [tecnicas-metodos/devops-cultura.md](../tecnicas-metodos/devops-cultura.md)).
2. **Habilita el pipeline de CDC.** Kafka es el canal que conecta
   Debezium (captura de cambios de las bases de datos, ver
   [debezium-cdc.md](./debezium-cdc.md)) con el microservicio de
   ingesta/procesamiento de datos (ver
   [lenguajes-frameworks/go.md](../lenguajes-frameworks/go.md)), formando
   el pipeline hacia el lakehouse en MinIO.
3. **Throughput y durabilidad probados**, adecuados tanto para eventos de
   dominio (ej. `solicitud_aceptada`) como para el volumen de cambios de
   datos capturados vía CDC.

## Cómo se usa en el proyecto

- Namespace `messaging` dentro del cluster K3s (ver
  [kubernetes.md](./kubernetes.md)).
- Dos flujos de datos distintos comparten el mismo broker:
  1. Eventos de dominio entre microservicios (ver
     [tecnicas-metodos/event-driven.md](../tecnicas-metodos/event-driven.md)).
  2. Streams de CDC desde Debezium hacia el pipeline de ingesta (ver
     [debezium-cdc.md](./debezium-cdc.md)).
- Autenticación y cifrado de canal siguen la política general de
  comunicación entre componentes (ver
  [10-seguridad-datos](../../10-seguridad-datos/)).

## Trade-offs / riesgos

- Kafka es más pesado operativamente que RabbitMQ para casos de uso
  simples; se acepta el costo porque también resuelve el caso de uso de
  CDC/streaming, no solo mensajería de eventos de dominio.
- Sin ZooKeeper, KRaft es un modo relativamente más nuevo del proyecto
  Kafka; requiere seguir de cerca la documentación oficial ante
  actualizaciones de versión.

## Cuándo reconsiderar

Si en la práctica los dos casos de uso (eventos de dominio vs. streams de
CDC) requieren garantías muy distintas y conviene separarlos en dos
tecnologías distintas, reevaluar mantenerlos en el mismo broker.
