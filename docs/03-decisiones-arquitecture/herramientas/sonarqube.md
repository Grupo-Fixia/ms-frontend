# SonarQube

**Estado en el Tech Radar:** 🟢 Adoptar
**Categoría:** Herramientas
**Última revisión:** 2026-08-24

## Contexto

Fixia exige un umbral mínimo de calidad de código (85% de cobertura,
entre otras métricas) antes de poder fusionar a `main` en cualquier
repositorio (ver
[07-calidad-arquitectura](../../07-calidad-arquitectura/)). Ese umbral
necesita medirse de forma automática y consistente en todos los
repositorios, sin depender del criterio subjetivo de cada revisor.

## Decisión

SonarQube (o SonarCloud, según se resuelva la infraestructura de hosting)
como herramienta de análisis estático de calidad, integrada como paso
obligatorio del pipeline de CI.

## Alternativas consideradas

| Opción | Por qué no |
|---|---|
| **Solo linter (ESLint/Pylint) sin Quality Gate centralizado** | Un linter detecta problemas de estilo y algunos errores, pero no mide cobertura, duplicación, ni mantenibilidad de forma agregada y comparable entre repositorios distintos lenguajes (Node.js, Python). |
| **Codecov (solo cobertura)** | Cubre solo una de las métricas exigidas (cobertura); SonarQube cubre cobertura, duplicación, mantenibilidad, confiabilidad y seguridad en una sola herramienta con un único Quality Gate configurable. |
| **Revisión manual de métricas por el revisor humano** | No escalable ni consistente; el objetivo del Quality Gate es que el criterio de "listo para fusionar" no dependa de qué tan estricto sea el revisor de turno. |

## Justificación para Fixia

1. **Un único criterio de calidad, aplicable a un stack políglota.**
   Fixia usa más de un lenguaje (Node.js/TypeScript por defecto, Python
   para dominios geoespaciales — ver
   [lenguajes-frameworks/](../lenguajes-frameworks/)). SonarQube soporta
   ambos con el mismo concepto de Quality Gate, evitando tener criterios
   de calidad distintos según el lenguaje del microservicio.
2. **Bloqueo automático en el pipeline**, no una sugerencia opcional. Esto
   es clave para que el umbral del 85% (ver
   [07-calidad-arquitectura](../../07-calidad-arquitectura/)) sea una
   regla real y no una aspiración que se ignora bajo presión de entrega.
3. **Detecta vulnerabilidades y code smells además de cobertura**,
   relevante para un sistema que maneja datos sensibles (ubicación, pagos,
   PII — ver [10-seguridad-datos](../../10-seguridad-datos/)), sumando una
   capa más de defensa además del escaneo de dependencias.

## Cómo se usa en el proyecto

- El Quality Gate se ejecuta en cada Pull Request hacia `main`.
- Umbrales obligatorios: cobertura ≥ 85%, duplicación ≤ 3%,
  mantenibilidad A/B, confiabilidad A, seguridad A (0 vulnerabilidades
  críticas/altas), 0 code smells críticos.
- Si no se cumple el umbral, el PR no puede fusionarse, salvo aprobación
  explícita y documentada de un Tech Lead para casos excepcionales (ej.
  código legado en migración, registrado como `tech-debt` en Jira).
- Ver configuración completa del pipeline en
  [06-cicd-ambientes](../../06-cicd-ambientes/) y umbrales detallados en
  [07-calidad-arquitectura](../../07-calidad-arquitectura/).

## Trade-offs / riesgos

- Puede generar fricción en etapas tempranas de un microservicio nuevo,
  donde alcanzar 85% de cobertura desde el primer commit requiere
  disciplina desde el día uno.
- Falsos positivos ocasionales en reglas de code smells que requieren
  ajuste de configuración por parte del equipo.

## Cuándo reconsiderar

Baja probabilidad de cambio como herramienta. El umbral específico (85%)
sí puede revisarse en la auditoría semestral (ver
[04-gobierno-ciclo-vida](../../04-gobierno-ciclo-vida/)) si la evidencia
muestra que es demasiado alto o bajo para el ritmo real del equipo.