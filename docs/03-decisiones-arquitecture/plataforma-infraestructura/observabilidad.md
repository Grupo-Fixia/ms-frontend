# Observabilidad: Prometheus, Grafana, Loki, Alertmanager

**Estado en el Tech Radar:** 🟢 Adoptar
**Categoría:** Plataformas & Infraestructura
**Última revisión:** 2026-09-20

> Esta página reemplaza y amplía la entrada breve de Grafana que existía
> en [herramientas/herramientas-complementarias.md](../herramientas/herramientas-complementarias.md),
> ahora que se confirma como un stack completo de 4 componentes, no una
> herramienta aislada.

## Contexto

Con microservicios corriendo en varios lenguajes y namespaces (ver
[kubernetes.md](./kubernetes.md)), Fixia necesita observabilidad
centralizada: métricas, logs y alertas en un solo lugar, sin que cada
equipo tenga que resolverlo por su cuenta.

## Decisión

Se adopta el stack: **Prometheus** (métricas), **Grafana** (dashboards),
**Loki** (logs centralizados) y **Alertmanager** (alertas), corriendo en
el namespace `observability` del cluster K3s.

## Alternativas consideradas

| Opción | Por qué no |
|---|---|
| **ELK Stack (Elasticsearch, Logstash, Kibana)** | Mencionado como alternativa válida de logging en el diseño original; se prioriza Loki por su integración más liviana con Grafana y menor consumo de recursos que Elasticsearch — relevante dado que la infraestructura on-premide tiene recursos limitados por VM (6-8 GB RAM, ver [kubernetes.md](./kubernetes.md)). |
| **Datadog / New Relic (SaaS de observabilidad)** | Requeriría enviar métricas y logs fuera de la red on-premise a un proveedor externo, y suma costo variable; no se justifica en la etapa actual del proyecto (ver [on-premise.md](./on-premise.md)). |

## Justificación para Fixia

1. **Stack liviano, coherente con recursos limitados on-premise.**
   Prometheus + Loki consumen sensiblemente menos recursos que
   alternativas tipo ELK, importante en VMs de 6-8 GB RAM.
2. **Un solo panel (Grafana) para métricas y logs**, reduciendo el número
   de herramientas distintas que el equipo de DevOps reducido debe
   dominar (ver [tecnicas-metodos/devops-cultura.md](../tecnicas-metodos/devops-cultura.md)).
3. **Alertmanager conecta directamente con los canales ya adoptados**
   (Slack, ver
   [herramientas/herramientas-complementarias.md](../herramientas/herramientas-complementarias.md)),
   sin necesitar integración adicional.
4. **Cubre tanto la infraestructura como el pipeline de datos**: monitorea
   desde el uso de CPU/memoria de los nodos hasta el lag de los
   conectores de Debezium (ver [debezium-cdc.md](./debezium-cdc.md)).

## Cómo se usa en el proyecto

- Namespace `observability` dentro del cluster K3s.
- Todo microservicio expone un endpoint de métricas compatible con
  Prometheus y un `/health` (ver
  [08-estructura-microservicios](../../08-estructura-microservicios/)).
- Logs de todos los microservicios se centralizan en Loki, consultables
  desde Grafana.
- Alertas críticas (ej. caída de un microservicio, lag alto de CDC) se
  notifican vía Alertmanager al canal de Slack correspondiente (ver
  [12-gestion-incidentes](../../12-gestion-incidentes/)).

## Trade-offs / riesgos

- Cuatro componentes adicionales que el equipo de DevOps debe mantener
  disponibles y actualizados.
- Sin alta disponibilidad configurada para el propio stack de
  observabilidad, un fallo en él deja al equipo "ciego" justo cuando más
  se necesita visibilidad — se recomienda tratarlo con la misma
  prioridad de disponibilidad que los microservicios críticos.

## Cuándo reconsiderar

Si el volumen de métricas/logs supera lo que la infraestructura
on-premise puede sostener con buen rendimiento, evaluar externalizar
parte del stack (por ejemplo, retención de logs de largo plazo) a un
almacenamiento distinto.
