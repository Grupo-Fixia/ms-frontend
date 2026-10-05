# InfluxDB

**Estado en el Tech Radar:** 🟠 Evaluar  
**Categoría:** Plataformas & Infrastructure / Base de Datos  
**Última revisión:** 2026-08-24  

## Contexto

Fixia genera eventos métricos continuos derivados de las interacciones de los usuarios, latencias en búsquedas geoespaciales, tiempos de respuesta de endpoints y el registro inmutable de transiciones de estado de los contactos (RF-055). El equipo analiza la conveniencia de utilizar una base de datos de series temporales (*Time-Series Database*) para almacenar y consultar estas métricas operativas de alto rendimiento.

## Decisión

InfluxDB en estado **Evaluar**: se explora su viabilidad en entornos de prueba de concepto (PoC) para la ingesta y monitoreo de métricas de rendimiento y eventos en tiempo real, sin ser aún parte de la arquitectura de producción.

## Alternativas consideradas

| Opción | Por qué no (todavía) |
| --- | --- |
| **Prometheus** | Excelente para métricas de infraestructura (CPU, Memoria), pero menos flexible para analítica de eventos de negocio con alta cardinalidad en comparación con InfluxDB. |
| **Almacenar métricas en la base de datos relacional/Firebase principal** | Degrada el rendimiento de la base de datos relacional/documental al saturarla con escrituras masivas de eventos no transaccionales. |

## Justificación para Fixia

1. **Optimización para datos de series temporales:** Permite almacenar y consultar millones de eventos indexados por tiempo (marcas temporales - RNF-006) de forma altamente eficiente.
2. **Integración con dashboards de monitoreo (ej. Grafana):** Facilita la visualización en tiempo real de indicadores operativos, latencias de búsqueda (RNF-001) y tasas de conversión de contactos.

## Por qué está en "Evaluar" y no en "Probar" o "Adoptar"

Dado que el MVP de Fixia se apoya inicialmente en Firebase y en la bitácora de eventos integrada (RF-055), no se requiere una base de datos de series temporales dedicada en producción durante la fase inicial. InfluxDB se mantiene en **Evaluar** para validar si el volumen de eventos justifica agregar este componente de infraestructura.

## Cómo se usa en el proyecto (mientras está en Evaluar)

* Exclusivamente en pruebas de concepto (Spikes) y entornos de desarrollo locales.
* **Prohibido** su despliegue en el entorno de producción del MVP o como dependencia crítica de los microservicios del núcleo.

## Trade-offs / riesgos

* Añade complejidad operativa y costo de infraestructura al stack si se despliega prematuramente.
* Requiere aprendizaje de la sintaxis de consulta específica de InfluxDB (Flux / InfluxQL).

## Cuándo reconsiderar

* Pasa a **Probar** si la carga de métricas y la auditoría de eventos en producción saturan la base de datos principal y se requiere desempacar la analítica temporal a un servicio dedicado.
* Se descarta si las necesidades de monitoreo del MVP quedan completamente cubiertas con el registro de eventos en Firebase/CloudWatch/Grafana sin una base de datos dedicada.
