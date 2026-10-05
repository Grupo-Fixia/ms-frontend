# Python (FastAPI)

**Estado en el Tech Radar:** 🟡 Probar
**Categoría:** Lenguajes & Frameworks
**Última revisión:** 2026-08-24

## Contexto

Los dominios de **Geolocalización** y **Búsqueda y Matching** (ver
[01-contexto-proyecto/mapa-dominios-negocio.md](../../01-contexto-proyecto/mapa-dominios-negocio.md))
no son simples CRUDs: involucran cálculo de proximidad geográfica,
ranking de candidatos por múltiples variables (distancia, rating,
disponibilidad) y, a futuro, probablemente algún componente de
recomendación. Este tipo de carga se beneficia de un ecosistema distinto
al de Node.js.

## Decisión

Python con FastAPI se usa, en estado de **Probar**, para microservicios
cuya carga principal sea geoespacial o de procesamiento/análisis de datos.
No es el default general del proyecto (ver
[nodejs-typescript.md](./nodejs-typescript.md)).

## Alternativas consideradas

| Opción | Por qué no |
|---|---|
| **Node.js también para estos dominios** | El ecosistema de librerías geoespaciales y de análisis de datos en Node.js es sensiblemente más limitado que en Python; forzarlo hubiese significado reinventar herramientas ya maduras en otro lenguaje. |
| **Django en vez de FastAPI** | Django trae mucho más de lo necesario (ORM propio, admin panel, templates) para microservicios que exponen una API delgada; FastAPI es más liviano y está pensado desde el inicio para APIs con validación de tipos, similar en espíritu a TypeScript. |
| **Un lenguaje especializado en geoprocesamiento (ej. herramientas GIS dedicadas)** | Sobredimensionado para las necesidades actuales de Fixia; Python con librerías geoespaciales estándar cubre el caso de uso sin introducir una herramienta completamente nueva al stack. |

## Justificación para Fixia

1. **Ecosistema geoespacial maduro.** Librerías como GeoPandas, Shapely o
   clientes de índices espaciales permiten resolver cálculos de
   proximidad y radios de búsqueda sin reinventar geometría desde cero —
   justo el tipo de trabajo que hace Geolocalización.
2. **Ecosistema de datos/análisis**, relevante para Búsqueda y Matching,
   que combina múltiples señales (distancia, rating, disponibilidad) para
   ordenar resultados, y que eventualmente podría incorporar un modelo de
   recomendación más sofisticado sin cambiar de lenguaje.
3. **FastAPI mantiene el mismo espíritu de tipado y contrato explícito**
   que TypeScript en Node.js (usa type hints de Python + Pydantic), lo que
   mantiene consistencia con el estándar JSON del resto del sistema (ver
   [07-calidad-arquitectura](../../07-calidad-arquitectura/)) sin sacrificar
   el beneficio del ecosistema Python.

## Por qué está en "Probar" y no en "Adoptar"

Se está validando en el dominio de Geolocalización/Búsqueda antes de
confirmarlo como estándar para ese tipo de carga, para asegurar que:

- El rendimiento real en producción justifica mantener un segundo
  lenguaje en el stack.
- El equipo puede sostener el mantenimiento de microservicios Python sin
  que se vuelva un cuello de botella (menos desarrolladores con
  experiencia Python que con Node.js/TypeScript hoy).

## Cómo se usa en el proyecto (mientras está en Probar)

- Uso limitado a los microservicios de Geolocalización y Búsqueda/Matching
  (ver
  [08-estructura-microservicios/catalogo-microservicios-fixia.md](../../08-estructura-microservicios/catalogo-microservicios-fixia.md)).
- Sigue la misma estructura de Clean Architecture que los microservicios
  Node.js (`domain/`, `application/`, `infrastructure/`, `interfaces/`),
  adaptada a convenciones Python (PEP8).
- El contrato de API expuesto sigue el mismo estándar JSON que el resto
  del sistema — el lenguaje interno no debe filtrarse en la forma de la
  respuesta.

## Trade-offs / riesgos

- Segundo lenguaje en el stack implica dos configuraciones de linter,
  dos tipos de pipeline de CI, y un equipo que debe cubrir competencia en
  ambos.
- Riesgo de que "Probar" se extienda indefinidamente sin una evaluación
  formal de resultados.

## Cuándo reconsiderar

- Pasa a **Adoptar** (para este tipo de carga específico, no como
  reemplazo general de Node.js) si, tras un ciclo de varios sprints en
  producción, demuestra estabilidad y el equipo confirma capacidad de
  mantenimiento sostenida.
- Se reconsideraría el uso de Python si el rendimiento real no supera de
  forma significativa a una implementación equivalente en Node.js, dado
  que mantener un segundo lenguaje tiene costo operativo.