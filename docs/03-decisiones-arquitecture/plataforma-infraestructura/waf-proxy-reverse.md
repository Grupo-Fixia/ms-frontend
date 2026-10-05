# WAF + Proxy Reverse (borde de red)

**Estado en el Tech Radar:** 🟢 Adoptar
**Categoría:** Plataformas & Infraestructura
**Última revisión:** 2026-09-20

## Contexto

Antes de que el tráfico de Internet llegue a Traefik/K3s (ver
[traefik.md](./traefik.md)), Fixia necesita una capa de borde que filtre
tráfico malicioso y termine conexiones de forma controlada, dado que la
infraestructura es on-premise y expuesta directamente a Internet (ver
[on-premise.md](./on-premise.md)).

## Decisión

Se adopta una capa de borde compuesta por:
1. **WAF** (Web Application Firewall) — filtra tráfico HTTP malicioso
   antes de que llegue a la red interna.
2. **Proxy Reverse** (Nginx/HAProxy) — termina conexiones y las reenvía
   hacia Traefik dentro de la red interna (`192.168.1.0/24`).

El acceso administrativo (SSH) se realiza vía **VPN** (identificada en el
diagrama como "VPN Universidad"), no expuesto directamente a Internet.

## Alternativas consideradas

| Opción | Por qué no |
|---|---|
| **Exponer Traefik directamente a Internet, sin WAF ni proxy adicional** | Traefik ya hace terminación TLS y enrutamiento, pero un WAF dedicado agrega una capa de filtrado de ataques conocidos (inyección, XSS, bots) antes de que el tráfico llegue siquiera a la red interna — defensa en profundidad, no redundancia innecesaria. |
| **Acceso SSH directo a las VMs sin VPN** | Expondría puertos administrativos directamente a Internet; la VPN reduce drásticamente la superficie de ataque para tareas de administración. |

## Justificación para Fixia

1. **Defensa en profundidad en el borde de la red.** Con infraestructura
   on-premise expuesta directamente (sin las protecciones de borde que
   suele dar un proveedor cloud por defecto), un WAF es la primera línea
   de defensa antes de que cualquier tráfico llegue a la red interna.
2. **Separación clara entre acceso administrativo y tráfico de
   aplicación.** SSH vía VPN, tráfico de usuarios vía WAF + Proxy Reverse
   — dos caminos de entrada distintos, cada uno con su propio control.
3. **Coherente con la política de comunicación segura ya definida**
   (TLS obligatorio, deshabilitar protocolos inseguros — ver
   [10-seguridad-datos](../../10-seguridad-datos/)).

## Cómo se usa en el proyecto

- Orden del tráfico entrante: `Internet → WAF → Proxy Reverse → Traefik
  (dentro de la red interna) → microservicio de negocio`.
- Acceso administrativo: `VPN → SSH → VMs` (fuera del camino de tráfico
  de aplicación).
- El firewall/WAF y el proxy reverse son parte de la infraestructura
  gestionada por el equipo de DevOps (ver
  [tecnicas-metodos/devops-cultura.md](../tecnicas-metodos/devops-cultura.md)),
  documentados como Infraestructura como Código igual que el resto (ver
  [terraform.md](./terraform.md)).

## Trade-offs / riesgos

- Capas adicionales de red suman puntos de configuración y posible
  fuente de latencia o mala configuración si no se documentan bien las
  reglas de firewall.
- El WAF y el proxy reverse deben mantenerse actualizados para cubrir
  vulnerabilidades nuevas — requieren el mismo ciclo de parcheo que
  cualquier otro componente crítico de infraestructura.

## Cuándo reconsiderar

Si Fixia migra a un proveedor cloud (ver
[google-cloud.md](./google-cloud.md)), evaluar si el WAF/proxy propio se
reemplaza por servicios gestionados equivalentes del proveedor
(ej. Cloud Armor en GCP), reduciendo la carga operativa propia.
