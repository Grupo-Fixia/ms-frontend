# On-Premise

**Estado en el Tech Radar:** 🟣 Retener (estado actual del proyecto)
**Categoría:** Plataformas & Infraestructura
**Última revisión:** 2026-08-24

## Contexto

Fixia necesita decidir dónde corre su infraestructura: servidores propios
(on-premise) o un proveedor de nube público (AWS/Azure/GCP) desde el día
uno.

## Decisión

La infraestructura actual de Fixia corre **on-premise**. No es una
decisión permanente: es el punto de partida, con una preparación activa
para una eventual migración a nube (ver [google-cloud.md](./google-cloud.md)).

## Alternativas consideradas

| Opción | Por qué no (por ahora) |
|---|---|
| **Nube pública desde el día 1** | Costo mensual más alto en etapa temprana con tráfico incierto; para un producto que todavía está validando product-market fit en zonas geográficas específicas, el costo variable de nube no se justifica frente a hardware propio ya disponible. |
| **Híbrido desde el inicio** | Añade complejidad operativa (dos entornos que mantener) sin un beneficio claro todavía, dado que el equipo de DevOps es reducido. |

## Justificación para Fixia

1. **Costo controlado en etapa de validación.** Fixia está probando su
   modelo de negocio en un número acotado de zonas geográficas. El tráfico
   es predecible y el hardware propio ya cubre esa demanda sin el costo
   variable de nube.
2. **Control total sobre datos sensibles.** Dado que Fixia maneja
   ubicación en tiempo real y datos de verificación de proveedores (ver
   [10-seguridad-datos](../../10-seguridad-datos/)), operar on-premise
   durante la etapa inicial simplifica el cumplimiento y la auditoría,
   sin depender de la configuración de seguridad de un tercero.
3. **No es una decisión que nos encierra.** Todas las demás decisiones de
   esta subcarpeta (Docker, Terraform) se eligieron específicamente
   porque son portables a nube sin reescritura. On-premise es el punto de
   partida, no una apuesta a largo plazo cerrada.

## Cómo se usa en el proyecto

- Los pipelines de CI/CD usan **runners self-hosted** ubicados en la
  infraestructura on-premise (ver
  [herramientas/github-actions.md](../herramientas/github-actions.md)).
- Toda infraestructura se define como código (Terraform/Ansible) desde
  ahora, aunque hoy apunte a servidores propios, para no tener que
  reescribir procesos al migrar.
- Los runners deben estar en una red segmentada, sin acceso directo a
  producción salvo por el paso de despliegue autorizado (ver
  [10-seguridad-datos](../../10-seguridad-datos/)).

## Trade-offs / riesgos

- **Escalado manual más lento** ante picos de demanda inesperados
  (ej. una campaña de marketing exitosa en una zona nueva), comparado con
  el autoescalado nativo de nube.
- **Responsabilidad total de continuidad** (backups, DRP, hardware) recae
  en el equipo de DevOps interno, sin SLAs de un proveedor cloud.
- **Menor elasticidad geográfica**: expandir a una zona geográfica lejana
  del datacenter actual puede implicar latencia adicional en
  Geolocalización y Búsqueda, dos dominios sensibles a tiempo de
  respuesta (ver
  [01-contexto-proyecto](../../01-contexto-proyecto/mapa-dominios-negocio.md)).

## Cuándo reconsiderar

- Si Fixia se expande a una nueva región geográfica alejada del
  datacenter actual, donde la latencia afecte la experiencia de búsqueda.
- Si el costo operativo de mantener y escalar hardware propio supera al
  costo proyectado de nube para el tráfico real observado.
- Ver el checklist completo de preparación para migración en
  [09-infraestructura-devops](../../09-infraestructura-devops/).