# Docker

**Estado en el Tech Radar:** 🟢 Adoptar
**Categoría:** Plataformas & Infraestructura
**Última revisión:** 2026-08-24

## Contexto

Con una arquitectura de microservicios (ver
[01-contexto-proyecto/por-que-microservicios.md](../../01-contexto-proyecto/por-que-microservicios.md)),
cada dominio de negocio (Usuarios, Proveedores, Geolocalización, etc.) se
despliega como un componente independiente. Necesitamos una forma estándar
de empaquetar y ejecutar esos componentes, igual en la laptop de un
desarrollador que en el servidor on-premise.

## Decisión

Toda aplicación de Fixia se empaqueta como **imagen Docker**. Se usa
`docker-compose` para levantar ambientes locales de desarrollo.

## Alternativas consideradas

| Opción | Por qué no |
|---|---|
| **Despliegue directo en VM/servidor sin contenedores** | Genera el problema clásico de "en mi máquina funciona"; además, dificulta la futura migración a nube, ya que la app queda atada a la configuración específica del servidor. |
| **Otro runtime de contenedores (Podman, containerd directo)** | Docker tiene el ecosistema y la documentación más amplia, y es compatible con Kubernetes/K3s sin fricción, que es la dirección de orquestación que estamos evaluando. |

## Justificación para Fixia

1. **Portabilidad on-premise ↔ nube.** Esta es la razón principal: una
   imagen Docker corre igual en el servidor on-premise actual que en
   cualquier proveedor cloud a futuro (ver
   [google-cloud.md](./google-cloud.md)). Es la pieza clave que evita que
   la decisión de "on-premise hoy" se convierta en deuda técnica mañana.
2. **Consistencia entre microservicios heterogéneos.** Fixia probablemente
   termine con más de un lenguaje en su stack (ver
   [lenguajes-frameworks/](../lenguajes-frameworks/)) según el dominio
   (ej. Node.js para servicios de I/O como Solicitudes, Python para
   procesamiento de datos geoespaciales). Docker da una interfaz de
   despliegue uniforme sin importar el lenguaje interno de cada
   microservicio.
3. **Aislamiento por dominio.** Cada microservicio corre en su propio
   contenedor, reforzando el aislamiento de fallos que motivó la elección
   de microservicios en primer lugar.
4. **Entornos locales reproducibles.** Un desarrollador nuevo en el
   equipo puede levantar el microservicio en el que trabaja (y sus
   dependencias directas) con `docker-compose up`, sin instalar manualmente
   bases de datos o dependencias en su máquina.

## Cómo se usa en el proyecto

- Todo repositorio `fixia-msv-*` incluye un `Dockerfile` en su raíz (ver
  [08-estructura-microservicios](../../08-estructura-microservicios/)).
- `docker-compose.yml` se usa únicamente para desarrollo local, nunca
  como estrategia de orquestación en producción.
- Las imágenes se versionan con el número de build o tag de Git — nunca
  se usa `latest` en producción (ver
  [06-cicd-ambientes](../../06-cicd-ambientes/)).
- Las imágenes se escanean por vulnerabilidades antes de publicarse al
  registry interno (ver [10-seguridad-datos](../../10-seguridad-datos/)).

## Trade-offs / riesgos

- Overhead de aprendizaje para desarrolladores sin experiencia previa en
  contenedores.
- Sin una capa de orquestación (ver
  [k3s-kubernetes.md](./k3s-kubernetes.md)), Docker por sí solo no resuelve
  balanceo de carga, autoescalado ni recuperación automática ante fallos
  entre múltiples contenedores.

## Cuándo reconsiderar

Esta es una decisión de base con muy baja probabilidad de cambio; no se
espera reconsiderarla salvo un cambio radical de paradigma (ej. adopción
completa de una plataforma serverless donde el empaquetado en contenedor
ya no sea necesario).