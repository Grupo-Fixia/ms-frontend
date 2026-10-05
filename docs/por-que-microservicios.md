# Por qué Microservicios (y no un Monolito)

**Estado:** Decisión adoptada
**Categoría:** Arquitectura de fondo
**Última revisión:** 2026-08-24

## Contexto

Al iniciar Fixia existían dos caminos razonables: un **monolito modular**
(más simple de operar con un equipo chico) o una **arquitectura de
microservicios** (más compleja operativamente, pero más alineada al
crecimiento esperado). Esta página documenta por qué se eligió la segunda,
específicamente para este proyecto — no como regla general de la industria.

## Decisión

Fixia se construye como una arquitectura de microservicios, organizados por
dominio de negocio (ver [mapa-dominios-negocio.md](./mapa-dominios-negocio.md)),
comunicados vía API Gateway, REST/gRPC para llamadas síncronas y eventos
para procesos asíncronos.

## Alternativas consideradas

| Opción | Por qué no la elegimos como base |
|---|---|
| **Monolito modular** | Más rápido de arrancar, pero acopla el ciclo de despliegue de "búsqueda por geolocalización" (que necesita escalar agresivo y frecuente) con el de "gestión de reseñas" (que casi no cambia). Un pico de tráfico en búsqueda obligaría a escalar todo el sistema. |
| **Monolito + colas internas ("modular monolith" con mensajería)** | Reduce parte del problema de escalado, pero no resuelve el aislamiento de fallos: un bug en el módulo de pagos puede tumbar la búsqueda. Para un negocio donde "un desconocido entra a tu casa", el aislamiento de fallos en verificación/seguridad es crítico. |
| **Serverless puro (FaaS) por función** | Válido a futuro para picos muy específicos (ej. notificaciones), pero hoy la infraestructura es on-premise (ver [09-infraestructura-devops](../09-infraestructura-devops/)) y no hay proveedor serverless disponible sin migrar antes a nube. |

## Justificación para Fixia

1. **Los dominios de Fixia tienen perfiles de carga muy distintos.**
   Búsqueda/matching por geolocalización se lee constantemente y debe
   responder en milisegundos; pagos se escribe con menos frecuencia pero
   exige consistencia fuerte; notificaciones son ráfagas asíncronas. Separar
   estos dominios permite escalar y optimizar cada uno con su propia
   estrategia (cache, réplicas de lectura, colas), en vez de una única
   configuración de compromiso para todo el sistema.

2. **Los perfiles de seguridad son distintos por dominio.**
   Los datos de ubicación en tiempo real y los datos de pago tienen
   requisitos de cifrado, retención y auditoría más estrictos que, por
   ejemplo, las reseñas. El principio *Database per Service* (ver
   [10-seguridad-datos](../10-seguridad-datos/)) permite aplicar controles de
   acceso distintos por dominio sin arriesgar el resto del sistema si uno
   se ve comprometido.

3. **Aislamiento de fallos alineado a la propuesta de valor.**
   Si el servicio de notificaciones falla, un cliente no debería quedarse
   sin poder buscar un plomero. Con microservicios y patrones como
   *Circuit Breaker* (ver [07-calidad-arquitectura](../07-calidad-arquitectura/)),
   un dominio no crítico puede degradarse sin tumbar el flujo principal de
   negocio.

4. **Equipos pequeños, dueños de un dominio completo.**
   Con microservicios, un equipo (aunque sea de 2-3 personas) puede ser
   dueño end-to-end de "Proveedores" o "Solicitudes", desde el modelo de
   datos hasta el despliegue, sin coordinar cada cambio con el resto del
   equipo. Esto es más sostenible a medida que Fixia contrate más
   desarrolladores, y evita el "monolito distribuido por miedo a tocar
   código ajeno".

5. **Preparación para migración a nube.**
   Servicios ya contenerizados y desacoplados son más fáciles de migrar
   incrementalmente (dominio por dominio) a un proveedor cloud, en vez de
   requerir un "big bang" de migración de todo el sistema a la vez.

## Cómo se aplica en el proyecto

- Cada dominio de negocio se traduce en un microservicio con prefijo
  `fixia-msv-*` (ver
  [convencion-nombres.md](../08-estructura-microservicios/convencion-nombres.md)).
- Cada microservicio sigue Clean Architecture y es dueño exclusivo de su
  base de datos.
- Toda comunicación externa entra por un único API Gateway
  (`fixia-apigateway`).
- La comunicación entre microservicios es síncrona (REST/gRPC) para
  consultas que requieren respuesta inmediata, y asíncrona (eventos) para
  procesos que pueden desacoplarse en el tiempo (ej. enviar una notificación
  después de que se acepta una solicitud).

## Trade-offs / riesgos que asumimos

- **Mayor complejidad operativa**: más repositorios, más pipelines, más
  puntos de monitoreo. Se mitiga con la plantilla de bootstrap estándar
  (ver [08-estructura-microservicios](../08-estructura-microservicios/)) y
  con Infraestructura como Código.
- **Consistencia eventual entre dominios**: por ejemplo, una solicitud
  aceptada y la actualización de disponibilidad del proveedor no ocurren en
  una única transacción de base de datos. Se maneja con eventos y con
  diseño explícito de qué operaciones toleran consistencia eventual y
  cuáles no (pagos, no).
- **Curva de aprendizaje inicial** para el equipo en patrones distribuidos
  (Circuit Breaker, eventos, trazabilidad distribuida).

## Cuándo reconsiderar esta decisión

- Si el equipo de desarrollo se mantiene con menos de 4-5 personas por más
  de un año y el overhead operativo de microservicios supera claramente el
  beneficio de escalado independiente.
- Si el volumen de usuarios/proveedores no justifica escalado diferenciado
  por dominio (señal de que un monolito modular hubiese bastado).