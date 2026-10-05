# Catálogo de Microservicios de Fixia

> **Leyenda de estado:** ✅ Confirmado · 🟡 Propuesto (pendiente de
> confirmar) · ❓ Abierto (falta información)

| # | Microservicio | Repositorio propuesto | Lenguaje | Estado del lenguaje | Notas |
|---|---|---|---|---|---|
| 1 | API Gateway | `fixia-apigateway` | Node.js/TypeScript | 🟡 Propuesto (default del proyecto) | Confirmado: no es dueño de datos propios. |
| 2 | Autenticación | `fixia-msv-autenticacion` | Node.js/TypeScript | 🟡 Propuesto (default del proyecto) | Perfil I/O-bound de credenciales/JWT. |
| 3 | Descubridor | `fixia-msv-descubridor` | Python (FastAPI) | 🟡 Propuesto (perfil geoespacial, ver [python-fastapi.md](../03-decisiones-arquitectura/lenguajes-frameworks/python-fastapi.md)) | Fusiona el antiguo "Búsqueda y Matching" + "Geolocalización". |
| 4 | Orquestador (Saga) | `fixia-msv-orquestador` | Node.js/TypeScript | 🟡 Propuesto (default del proyecto) | ❓ Patrón Saga sin página de decisión todavía (ver [estructura-interna.md](./estructura-interna.md)). |
| 5 | Gestión de Servicios/Pagos | `fixia-msv-servicios-pagos` | Java (Spring Boot) | ✅ Confirmado (ver [java.md](../03-decisiones-arquitectura/lenguajes-frameworks/java.md)) | ❓ `java.md` todavía referencia el nombre anterior `fixia-msv-pagos` — actualizar cuando se confirme este nombre. |
| 6 | Procesamiento | `fixia-msv-procesamiento` | Go | ✅ Confirmado (ver [go.md](../03-decisiones-arquitectura/lenguajes-frameworks/go.md)) | Ingesta y procesamiento de datos de alto volumen. |
| 7 | Calificaciones y Métricas | `fixia-msv-calificaciones` | Node.js/TypeScript | 🟡 Propuesto (default del proyecto) | — |
| 8 | Verificación | `fixia-msv-verificacion` | ❓ Sin confirmar | ❓ Abierto | ¿Es este el microservicio que usa Java (parte del alcance "Administración" en [java.md](../03-decisiones-arquitectura/lenguajes-frameworks/java.md)), o queda en el lenguaje por defecto? |
| 9 | Operación (Panel Admin) | `fixia-msv-operacion` | ❓ Sin confirmar | ❓ Abierto | Mismo punto que Verificación: falta confirmar si es este el que integra el SDK de pagos en Java, o si ninguno de los dos lo hace directamente. |
| 10 | Mensajería *(serverless)* | `fixia-msv-mensajeria` (nombre y tipo de repo pendientes, ver [convencion-nombres.md](./convencion-nombres.md)) | ❓ Sin confirmar | ❓ Abierto | Plataforma serverless sin página de decisión en `plataforma-infraestructura/` todavía. |

## Frontends (no confirmados en el diagrama de microservicios)

El diagrama que compartiste solo mostraba microservicios de backend. Se
asume que van a existir al menos estos dos frontends (ya justificados en
[react.md](../03-decisiones-arquitectura/lenguajes-frameworks/react.md)),
pero no están confirmados contra el diagrama real:

| Frontend | Repositorio propuesto | Consume principalmente |
|---|---|---|
| Portal de clientes/proveedores | `fixia-web-portal` | API Gateway → Descubridor, Autenticación, Orquestador, Gestión de Servicios/Pagos |
| Panel de administración | `fixia-web-admin` | API Gateway → Operación (Panel Admin), Verificación |

## Resumen de pendientes de este catálogo

Todos estos puntos deben resolverse con la documentación adicional antes
de considerar este catálogo definitivo (ver también los pendientes de
[01-contexto-proyecto/mapa-dominios-negocio.md](../01-contexto-proyecto/mapa-dominios-negocio.md)):

1. Confirmar si existe un microservicio de perfil de cliente/proveedor
   separado de Autenticación.
2. Confirmar el lenguaje de Verificación y Operación (Panel Admin), y
   cuál de los dos (si alguno) integra el SDK de pagos en Java —
   necesario para corregir el alcance documentado en
   [java.md](../03-decisiones-arquitectura/lenguajes-frameworks/java.md).
3. Confirmar nombre de repositorio definitivo de Gestión de
   Servicios/Pagos y actualizar `java.md` en consecuencia.
4. Resolver el tipo de repositorio para componentes serverless (ver
   [convencion-nombres.md](./convencion-nombres.md)).
5. Crear la página de decisión del patrón Saga en
   `03-decisiones-arquitectura/tecnicas-metodos/`.
6. Crear la página de decisión de la plataforma serverless elegida en
   `03-decisiones-arquitectura/plataforma-infraestructura/`.
7. Confirmar si `fixia-web-portal` y `fixia-web-admin` son correctos o si
   el diagrama real de frontends difiere.