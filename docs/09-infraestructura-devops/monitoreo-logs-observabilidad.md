# 📊 Monitoreo, Logs y Observabilidad

## 1. Objetivo
Garantizar la visibilidad completa del estado de la infraestructura y microservicios de **Fixia** mediante la recolección centralizada de métricas, trazas distribuidas y logs.

---

## 2. Stack de Observabilidad

| Dominio | Herramienta / Componente | Propósito |
| :--- | :--- | :--- |
| **Métricas** | Prometheus + Grafana | Recolección de métricas de CPU, memoria, throughput y HTTP latencies. |
| **Logs Centralizados** | Loki + Promtail | Agregación de logs de contenedor en tiempo real. |
| **Trazabilidad Distribución**| OpenTelemetry + Jaeger | Tracing end-to-end de peticiones HTTP/Kafka a través de microservicios. |
| **Alertamiento** | Prometheus Alertmanager | Notificaciones inmediatas a Discord/Slack/PagerDuty ante fallos. |

---

## 3. Estándares de Logging
- **Formato:** Los logs deben ser emitidos estructurados estrictamente en **JSON** a `stdout`/`stderr`.
- **Trace IDs:** Todo log de aplicación debe incluir `trace_id` y `span_id` para correlacionar con Jaeger.

```json
{
  "timestamp": "2026-08-27T18:45:00Z",
  "level": "INFO",
  "service": "fixia-order-service",
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "message": "Orden #10492 creada exitosamente",
  "user_id": 4821
}
```
