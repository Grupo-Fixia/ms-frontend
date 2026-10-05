# Gemini

**Estado en el Tech Radar:** 🟡 Probar  
**Categoría:** Herramientas  
**Última revisión:** 2026-08-24  

## Contexto

El equipo explora herramientas de Inteligencia Artificial Generativa como asistentes para la estructuración de documentación técnica, diseño de escenarios de prueba QA, refactorización conceptual y apoyo en el análisis de requisitos o estándares de arquitectura.

## Decisión

Gemini en estado **Probar**: habilitado como herramienta de asistencia individual para ideación, documentación, generación de escenarios de calidad y refactorización conceptual, sin ser parte del pipeline automatizado ni fuente de código directo sin validación humana.

## Alternativas consideradas

| Opción | Por qué no (todavía) |
| --- | --- |
| **Otras IAs generativas de propósito general** | Evaluadas en paralelo; Gemini se prueba prioritariamente por su capacidad de procesamiento de contexto extenso y soporte en estructuración de documentos extensos (SRS, ADRs). |
| **Prohibir el uso de IAs generativas** | Posición innecesariamente conservadora; el equipo busca aprovechar el incremento en productividad para tareas de documentación y diseño de pruebas siempre que exista supervisión humana. |

## Justificación para Fixia

1. **Aceleración en la generación de artefactos QA y arquitectura:** Facilita la redacción de plantillas de escenarios de calidad (ISO/IEC 25010), matrices de prueba y borradores de documentación ejecutiva.
2. **Apoyo en el análisis de código y buenas prácticas:** Permite consultar rápidamente alternativas de refactorización bajo principios SOLID y Clean Code antes de llevarlas al código final.

## Por qué está en "Probar" y no en "Adoptar"

Se mantiene en **Probar** para evaluar que la información técnica generada sea verificada exhaustivamente antes de incorporarse al proyecto, garantizando que no se introduzcan alucinaciones, sesgos o inconsistencias con las reglas de negocio de Fixia.

## Cómo se usa en el proyecto (mientras está en Probar)

* Asistencia en la redacción y estructuración de documentos de arquitectura (SAD, SRS) y casos de prueba.
* **Prohibido:** Introducir credenciales, claves privadas, tokens, PII (Información Personal Identificable de usuarios/técnicos) o datos reales en las consultas (*prompts*).
* Todo artefacto o código sugerido debe ser revisado y validado técnicamente por el desarrollador o el QA Lead antes de incorporarse al repositorio o a Confluence.

## Trade-offs / riesgos

* Riesgo de alucinaciones en reglas de negocio específicas de Fixia o algoritmos complejos.
* Riesgo de privacidad si se ingresa información confidencial o sensible del sistema en herramientas externas.

## Cuándo reconsiderar

* Pasa a **Adoptar** si demuestra ser un estándar efectivo para acelerar la creación de documentación de calidad sin inconsistencias detectadas en revisiones.
* Se descarta si el equipo incurre en errores de documentación o seguridad por confiar ciegamente en las respuestas sin la debida revisión.
