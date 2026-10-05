# Convención de Nombres de Repositorio

## Patrón

```
<prefijo-organizacion>-<tipo>-<nombre-del-servicio>
```

| Componente | Descripción | Ejemplo |
|---|---|---|
| `prefijo-organizacion` | Prefijo fijo de la organización/producto | `fixia` |
| `tipo` | Tipo de componente (ver tabla de tipos) | `msv`, `apigateway`, `web` |
| `nombre-del-servicio` | Nombre corto y descriptivo en minúsculas, sin abreviaturas ambiguas | `descubridor`, `procesamiento` |

## Tipos de repositorio permitidos

| Tipo | Significado | Ejemplo de nombre completo |
|---|---|---|
| `apigateway` | Puerta de entrada única a los microservicios (único por organización/dominio, no lleva nombre adicional) | `fixia-apigateway` |
| `msv` | Microservicio de negocio | `fixia-msv-descubridor`, `fixia-msv-procesamiento` |
| `web` | Frontend / aplicación web | `fixia-web-portal`, `fixia-web-admin` |
| `lib` | Librería o paquete compartido entre microservicios | `fixia-lib-common`, `fixia-lib-auth` |
| `job` | Procesos batch, tareas programadas o workers asíncronos | `fixia-job-reportes` |
| `infra` | Código de infraestructura (Terraform, Ansible, manifiestos K3s) | `fixia-infra-terraform` |

## ⚠️ Pendiente de definir: prefijo para componentes serverless

El microservicio de **Mensajería** está marcado como *serverless* (ver
[01-contexto-proyecto/mapa-dominios-negocio.md](../01-contexto-proyecto/mapa-dominios-negocio.md)),
y ninguno de los tipos de esta tabla fue pensado originalmente para ese
caso. Dos opciones a resolver cuando llegue la documentación adicional:

1. Usar `msv` igual (`fixia-msv-mensajeria`) y documentar el runtime
   serverless como un detalle de infraestructura de ese repositorio
   puntual, no como un tipo de repositorio distinto.
2. Introducir un tipo nuevo, ej. `fn` (function/serverless), si se
   prevén más componentes serverless a futuro (`fixia-fn-mensajeria`).

Hasta resolver esto, el catálogo (ver
[catalogo-microservicios-fixia.md](./catalogo-microservicios-fixia.md))
usa la opción 1 como nombre **propuesto**, no confirmado.

## Reglas de nomenclatura

- Todo en minúsculas, palabras separadas por guion medio (`-`), nunca
  guion bajo ni camelCase.
- El `nombre-del-servicio` debe reflejar el dominio de negocio, no la
  tecnología (`fixia-msv-descubridor`, no `fixia-msv-python-busqueda`).
  Esto es especialmente relevante ahora que el proyecto es políglota (ver
  [03-decisiones-arquitectura/lenguajes-frameworks/](../03-decisiones-arquitectura/lenguajes-frameworks/)):
  el lenguaje interno de un microservicio nunca debe filtrarse al nombre
  del repositorio.
- Nombres en singular o plural deben ser consistentes entre todos los
  microservicios (recomendado: sustantivo que describe la función, no
  necesariamente plural — ej. `descubridor`, `orquestador`, no
  `descubridores`).
- Prohibido usar nombres genéricos como `fixia-msv-api` o
  `fixia-msv-service` que no identifiquen el dominio.

## Nombres compuestos

Cuando el nombre de negocio tiene más de una palabra (ej. "Gestión de
Servicios/Pagos" o "Calificaciones y Métricas"), se abrevia a la idea
central en kebab-case, evitando nombres largos:

| Nombre de negocio | Repositorio propuesto |
|---|---|
| Gestión de Servicios/Pagos | `fixia-msv-servicios-pagos` |
| Calificaciones y Métricas | `fixia-msv-calificaciones` |
| Orquestador (Saga) | `fixia-msv-orquestador` |
| Operación (Panel Admin) | `fixia-msv-operacion` |

Ver el catálogo completo, incluyendo los nombres marcados como
pendientes de confirmar, en
[catalogo-microservicios-fixia.md](./catalogo-microservicios-fixia.md).