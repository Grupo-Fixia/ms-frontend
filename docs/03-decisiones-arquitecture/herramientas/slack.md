# Slack

**Estado en el Tech Radar:** 🟢 Adoptar  
**Categoría:** Herramientas  
**Última revisión:** 2026-08-24  

## Contexto

Fixia requiere un canal de comunicación asíncrono y en tiempo real que permita la coordinación rápida entre los integrantes del equipo (desarrolladores, QA Lead, DevOps, Product Owner) y la recepción centralizada de notificaciones de herramientas del ecosistema (GitHub, Jira, SonarQube).

## Decisión

Slack como la herramienta oficial de comunicación, mensajería instantánea y centralización de alertas operativas del equipo.

## Alternativas consideradas

| Opción | Por qué no |
| --- | --- |
| **WhatsApp / Mensajería personal** | Mezcla la vida personal con la profesional, informaliza las decisiones técnicas y carece de integración con herramientas de CI/CD, trazabilidad por hilos (*threads*) y búsqueda avanzada. |
| **Microsoft Teams** | Mayor consumo de recursos, menor agilidad en la integración con webhooks de herramientas dev de código abierto y flujo de usuario menos optimizado para equipos ágiles pequeños. |

## Justificación para Fixia

1. **Centralización de notificaciones del pipeline:** Integración con GitHub Actions, Jira y SonarQube para recibir alertas automáticas cuando un Pull Request es abierto, un *Quality Gate* falla o un despliegue en Staging concluye.
2. **Organización por canales temáticos:** Permite separar la conversación por dominios (`#dev-backend`, `#dev-frontend`, `#qa-bugs`, `#general`, `#alerts-cicd`), evitando el ruido de información.
3. **Trazabilidad de decisiones rápidas:** Mantiene discusiones tontas o técnicas mediante hilos (*threads*), evitando la saturación del canal principal.

## Cómo se usa en el proyecto

* Comunicación diaria asíncrona y sincronía de dudas técnicas.
* Canal automatizado de alertas para fallas en builds de CI/CD y reportes de Quality Gates.
* Coordinación de revisiones de código (*Code Reviews*) entre pares.

## Trade-offs / riesgos

* Pérdida de historial de mensajes en el plan gratuito al superar el límite de mensajes recientes retenidos.
* Riesgo de interrupción o sobrecarga de notificaciones si no se configuran correctamente las reglas de alertas.

## Cuándo reconsiderar

Si los límites de historial de la versión gratuita entorpecen el rastreo de conversaciones pasadas y se evalúa migrar a alternativas *open source* auto-hospedadas como Mattermost.
