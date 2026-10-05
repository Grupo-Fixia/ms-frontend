# WhatsApp

**Estado en el Tech Radar:** 🟣 Retener  
**Categoría:** Herramientas / Integraciones Externas  
**Última revisión:** 2026-08-24  

## Contexto

Se analizó la posibilidad de utilizar WhatsApp (vía WhatsApp Business API) como canal principal para la comunicación entre el cliente y el técnico, o para el envío de notificaciones push de nuevos contactos (RF-034, RF-035).

## Decisión

WhatsApp se clasifica en estado **Retener (Decidido no usar para el MVP)**: no se integra ni se utiliza como canal de mensajería o notificación para el producto en la versión MVP.

## Alternativas consideradas

| Opción | Por qué se eligió sobre WhatsApp |
| --- | --- |
| **Canal de chat in-app y notificaciones Push (Firebase Cloud Messaging)** | Mantiene al usuario dentro de la plataforma Fixia, protege los datos de contacto directo de las partes (revelación progresiva RN-005), y permite registrar la bitácora inmutable de eventos de comunicación (RF-055) sin depender de costos por mensaje de la API de WhatsApp. |

## Justificación para Fixia

1. **Cumplimiento de Reglas de Negocio y Privacidad (RN-005):** Revelar el número telefónico directamente hacia WhatsApp rompe la regla de revelación progresiva de datos y expone PII prematuramente antes de que el contacto esté habilitado.
2. **Control de la experiencia y trazabilidad (RF-033, RF-055):** La comunicación realizada en un chat externo (WhatsApp) no puede ser auditada por el sistema para resolver disputas, validar la declaración de servicios o registrar el historial de interacción.
3. **Estructura de Costos:** La API oficial de WhatsApp Business cobra por conversación iniciada, lo cual resulta inviable para el modelo monetario sin cobro anticipado de Fixia en la etapa MVP.

## Estado en el Radar: Definición de "Retener"

Aplica bajo la definición de **Tecnología que se decidió NO adoptar** para la arquitectura actual del MVP. Cualquier intento de desviar la comunicación o notificaciones hacia WhatsApp fuera de la aplicación requiere una justificación formal y un cambio en la arquitectura de la aplicación.

## Trade-offs / riesgos

* Los usuarios finales (clientes y técnicos) están ampliamente familiarizados con WhatsApp, por lo que requerirán adaptarse al módulo de mensajería interno (*in-app*) de Fixia.

## Cuándo reconsiderar

Se reconsiderará únicamente en Fase 2 si se evalúa implementar notificaciones transaccionales unidireccionales (SMS/WhatsApp) exclusivamente para técnicos sin conectividad de datos activa, previo análisis de costos de API.
