# 01. Contexto del Proyecto

## ¿Qué es Fixia?

Fixia es una plataforma que conecta a personas que necesitan un servicio del
hogar o profesional (plomería, pintura, electricidad, limpieza, jardinería,
etc.) con proveedores de ese servicio disponibles cerca de su ubicación
geográfica.

En términos de producto, Fixia es un **marketplace hiperlocal de servicios
bajo demanda**: dos lados de usuarios (clientes y proveedores) que la
plataforma debe emparejar de forma rápida, confiable y segura, usando la
ubicación geográfica como variable central del negocio.

## Actores principales

| Actor | Descripción |
|---|---|
| **Cliente** | Persona que busca contratar un servicio puntual cerca de su ubicación. |
| **Proveedor** | Profesional o empresa que ofrece uno o más servicios en una zona geográfica. |
| **Administrador / Soporte** | Equipo interno de Fixia que modera, verifica proveedores y da soporte a incidencias. |
| **Plataforma (sistema)** | El conjunto de microservicios que hace el matching, gestiona solicitudes, pagos y reputación. |

## Objetivos del negocio que condicionan la arquitectura

Estos objetivos son el motivo por el cual muchas decisiones técnicas de esta
wiki no son "las de moda", sino las que responden a necesidades concretas de
Fixia:

1. **Tiempo de respuesta bajo en búsqueda por proximidad.** El core del
   producto es "mostrar proveedores disponibles cerca de mí en segundos".
   Esto empuja decisiones como aislar la búsqueda/geolocalización en su
   propio dominio, con su propia estrategia de escalado e indexado espacial.
2. **Confianza y seguridad como diferenciador.** El cliente deja entrar a un
   desconocido a su casa. Verificación de proveedores, reseñas, y manejo
   estricto de datos personales y de ubicación no son "nice to have": son
   la propuesta de valor. Esto condiciona las políticas de la sección
   [10-seguridad-datos](../10-seguridad-datos/).
3. **Picos de demanda no uniformes.** La demanda varía por zona, hora y
   estacionalidad (ej. pintura en primavera, plomería tras una tormenta).
   Necesitamos poder escalar componentes de forma independiente, no la
   aplicación completa.
4. **Equipo pequeño hoy, crecimiento esperado.** La arquitectura debe
   permitir que equipos chicos sean dueños de dominios completos sin
   pisarse, y que se puedan sumar más equipos sin reescribir el sistema.
5. **Infraestructura on-premise hoy, con horizonte de migración a nube.**
   Ver [09-infraestructura-devops](../09-infraestructura-devops/).

## Contenido de este capítulo

- [por-que-microservicios.md](./por-que-microservicios.md) — justificación
  arquitectónica de fondo: por qué microservicios y no un monolito, aplicado
  al contexto real de Fixia (no una justificación genérica de blog).
- [mapa-dominios-negocio.md](./mapa-dominios-negocio.md) — los dominios de
  negocio identificados, sus responsabilidades y cómo se relacionan entre sí.
  Este mapa es el que luego se traduce 1 a 1 en el catálogo de
  microservicios (ver [08-estructura-microservicios](../08-estructura-microservicios/)).

## Cómo usar este capítulo

Antes de leer cualquier decisión técnica puntual (lenguaje, framework,
herramienta) en el capítulo 03, se recomienda leer este capítulo completo.
La mayoría de las justificaciones de "por qué elegimos X" hacen referencia
directa a los objetivos de negocio y dominios definidos acá.