# Traefik (Ingress / API Gateway)

**Estado en el Tech Radar:** 🟢 Adoptar
**Categoría:** Plataformas & Infraestructura
**Última revisión:** 2026-09-20

## Contexto

El cluster K3s necesita un punto de entrada que enrute el tráfico externo
(vía Proxy-Reverse y WAF, ver [waf-proxy-reverse.md](./waf-proxy-reverse.md))
hacia los microservicios correctos dentro del namespace `microservicios`.

## Decisión

Traefik se adopta como Ingress Controller del cluster K3s, cumpliendo el
rol de **API Gateway** de la plataforma.

## Alternativas consideradas

| Opción | Por qué no |
|---|---|
| **NGINX Ingress Controller** | Alternativa igualmente válida y muy extendida; se prioriza Traefik por su configuración nativa vía CRDs de Kubernetes y su integración directa con K3s (Traefik viene incluido por defecto en muchas distribuciones K3s), reduciendo piezas adicionales a mantener. |
| **API Gateway propio (microservicio custom)** | Reimplementar enrutamiento, TLS y balanceo de carga a mano tiene sentido si se necesita lógica de negocio en el gateway; para el rol de enrutamiento/ingress puro, un Ingress Controller maduro como Traefik resuelve el problema con menos código propio que mantener. |

## ⚠️ Punto a reconciliar con el catálogo de microservicios

En el capítulo 08 ya existía la idea de un microservicio propio
`fixia-apigateway` con responsabilidades explícitas (autenticación
centralizada, rate limiting, agregación de respuestas). Con Traefik como
Ingress Controller, hay que confirmar:

- ¿Traefik reemplaza por completo a ese microservicio (queda como
  responsabilidad de infraestructura, no de código de aplicación)?
- ¿O Traefik hace el ingress/enrutamiento de bajo nivel y sigue
  existiendo un servicio delgado detrás para lógica de gateway más
  específica (agregación, cross-cutting concerns de negocio)?

Por instrucción del equipo, el catálogo de microservicios del capítulo 08
no se modifica todavía — este punto queda registrado acá para resolverlo
cuando corresponda, sin tocar ese catálogo por ahora.

## Justificación para Fixia

1. **Nativo de Kubernetes/K3s.** Se configura vía CRDs (`IngressRoute`),
   sin una capa de configuración externa desacoplada del cluster.
2. **Descubrimiento automático de servicios.** Traefik detecta servicios
   nuevos dentro del cluster sin reconfiguración manual, relevante a
   medida que se agreguen microservicios al namespace correspondiente.
3. **Terminación TLS y enrutamiento en un solo componente**, reduciendo
   piezas de infraestructura frente a mantener un gateway custom más
   Ingress Controller por separado.

## Cómo se usa en el proyecto

- Vive en el namespace `ingress` del cluster K3s (ver
  [kubernetes.md](./kubernetes.md)).
- Recibe tráfico desde Proxy-Reverse/WAF (ver
  [waf-proxy-reverse.md](./waf-proxy-reverse.md)), no directamente de
  Internet.
- Valida JWT hacia el microservicio de Autenticación antes de rutear a
  microservicios de negocio (relación confirmada en el diagrama de
  infraestructura).

## Trade-offs / riesgos

- Menos control fino que un gateway 100% custom si a futuro se necesita
  lógica de negocio compleja en el borde (ej. agregación de múltiples
  respuestas en una sola).
- Curva de aprendizaje de la configuración específica de Traefik (CRDs)
  para quien no la conozca.

## Cuándo reconsiderar

Si aparece una necesidad de lógica de gateway que Traefik no resuelve
bien (agregación de respuestas, transformaciones complejas de payload),
evaluar sumar un servicio delgado detrás de Traefik en vez de forzar esa
lógica dentro de la configuración del Ingress.
