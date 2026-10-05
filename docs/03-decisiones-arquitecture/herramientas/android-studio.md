# Android Studio

**Estado en el Tech Radar:** 🟢 Adoptar  
**Categoría:** Herramientas  
**Última revisión:** 2026-08-24  

## Contexto

El proyecto Fixia incluye una aplicación móvil única (con vistas diferenciadas para Cliente y Técnico) orientada primariamente al mercado colombiano para plataformas Android e iOS. Se requiere un entorno de desarrollo integrado (IDE) oficial para la compilación, emulación, depuración y empaquetado de la versión Android de la aplicación.

## Decisión

Android Studio como IDE oficial y estándar para el desarrollo nativo/híbrido Android, gestión de emuladores (AVD), perfilado de rendimiento y generación de binarios (`.apk` / `.aab`).

## Alternativas consideradas

| Opción | Por qué no |
| --- | --- |
| **VS Code con plugins de Android** | Útil para editar código fuente (ej. Flutter/React Native), pero carece de las herramientas avanzadas de depuración nativa, profilado de memoria/CPU, gestión de SDKs nativos y firma de binarios que ofrece Android Studio. |
| **Desarrollo sin emulador local (solo en dispositivos físicos)** | Reduce la velocidad de prueba de QA para múltiples resoluciones, tamaños de pantalla (desde 5 pulgadas - RNF-013) y versiones de sistema operativo. |

## Justificación para Fixia

1. **Entorno oficial y completo de desarrollo:** Incluye los SDKs, herramientas de construcción (`Gradle`) y analizadores de código nativo necesarios para garantizar la compatibilidad con el sistema operativo Android.
2. **Herramientas de profilado de rendimiento:** Permite medir el consumo de memoria, CPU, tráfico de red y rendimiento de batería de la aplicación móvil en tiempo real.
3. **Emulación de condiciones reales:** Facilita la simulación de pérdida de conectividad (necesaria para validar el comportamiento offline RNF-004) y cambios de coordenadas geográficas para las pruebas de ubicación.

## Cómo se usa en el proyecto

* Compilación, depuración y firma de la aplicación móvil Fixia para Android.
* Emulación de dispositivos de gama baja/media con pantallas de 5 pulgadas (cumplimiento de RNF-013).
* Profilado de consumo de datos y memoria durante las pruebas de QA en ambiente local.

## Trade-offs / riesgos

* **Alto consumo de recursos de hardware:** Requiere equipos de desarrollo con suficiente RAM (mínimo 16 GB) para ejecutar el IDE y el emulador de Android simultáneamente.
* Curva de configuración inicial de SDKs, variables de entorno y emuladores.

## Cuándo reconsiderar

Indesplazable para la capa móvil Android. Se mantiene como herramienta estándar en la categoría de desarrollo móvil.
