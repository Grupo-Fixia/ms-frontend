# Terminal (CLI) 

**Estado en el Tech Radar:** 🟢 Adoptar  
**Categoría:** Herramientas  
**Última revisión:** 2026-08-24  

## Contexto

El desarrollo y la operación de Fixia requieren la ejecución de comandos para la gestión de contenedores, despliegues en pipelines de CI/CD, scripts de migración de datos geográficos en Python, comandos de versión con Git y compilación de microservicios. Se necesita un entorno de línea de comandos estandarizado y portable para el equipo de ingeniería.

## Decisión

Uso de la Terminal / CLI (Command Line Interface) como canal principal e indispensable para la automatización, configuración de entorno, versionamiento y ejecución de scripts de desarrollo y operaciones.

## Alternativas consideradas

| Opción | Por qué no |
| --- | --- |
| **Depender exclusivamente de interfaces gráficas (GUIs)** | Las GUIs (ej. clientes gráficos de Git o administradores de base de datos visuales) limitan la automatización, no son reproducibles en pipelines de CI/CD desatendidos (*headless*) y pueden diferir entre sistemas operativos. |
| **Scripts manuales sin soporte CLI estándar** | Dificulta la integración continua y la reproducibilidad de entornos entre los desarrolladores y los servidores de Staging/Producción. |

## Justificación para Fixia

1. **Reproducibilidad y automatización:** Todos los pasos de compilación, ejecución de Quality Gates (SonarQube) y despliegue se definen mediante comandos de terminal reproducibles tanto localmente como en GitHub Actions / CI Pipelines.
2. **Compatibilidad multiplataforma:** Permite estandarizar las herramientas del proyecto (Docker, Git, Python, Java CLI) independientemente de si el desarrollador utiliza macOS, Linux o Windows (vía WSL2).
3. **Eficiencia en la administración de infraestructura:** Esencial para la interacción rápida con servicios de nube, ejecución de comandos de Docker y gestión de scripts geoespaciales.

## Cómo se usa en el proyecto

* Ejecución de comandos de control de versiones (`git`).
* Ejecución local de microservicios y contenedores (`docker`, `docker-compose`).
* Ejecución de pruebas unitarias, escaneos estáticos y scripts de migración/analítica de datos.
* Configuración de pipelines en la infraestructura de CI/CD (ver `06-cicd-ambientes`).

## Trade-offs / riesgos

* Requiere curva de aprendizaje para desarrolladores menos familiarizados con la línea de comandos avanzada o scripts Shell/Bash.
* Riesgo de ejecución accidental de comandos destructivos en entornos locales o remotos si no se cuenta con los permisos adecuados.

## Cuándo reconsiderar

Indesplazable. Es una herramienta fundamental e inmodificable para el desarrollo de software y la ingeniería de operaciones.
