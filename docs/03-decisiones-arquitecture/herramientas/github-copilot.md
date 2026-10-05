# GitHub Copilot

**Estado en el Tech Radar:** 🟡 Probar
**Categoría:** Herramientas
**Última revisión:** 2026-08-24

## Contexto

El equipo evalúa herramientas de asistencia de código con IA para acelerar
tareas repetitivas (boilerplate, tests, documentación), sin comprometer
las políticas de calidad y seguridad ya definidas.

## Decisión

GitHub Copilot en estado **Probar**: habilitado para uso individual de
desarrolladores, sin ser todavía un requisito ni una parte formal del
pipeline.

## Alternativas consideradas

| Opción | Por qué no (todavía) |
|---|---|
| **Otros asistentes de código de terceros** | No evaluados formalmente aún; Copilot se prioriza por su integración nativa con GitHub, ya adoptado como plataforma central (ver [git-github.md](./git-github.md)). |
| **Sin asistente de IA** | Válido como posición conservadora, pero el equipo quiere medir el impacto real en velocidad antes de descartarlo sin evaluar. |

## Justificación para Fixia

1. **Integración nativa con el flujo ya existente en GitHub**, sin
   herramientas adicionales que instalar o mantener por separado.
2. **Potencial de acelerar tareas de bajo riesgo** (tests unitarios
   siguiendo un patrón ya establecido, documentación de funciones,
   boilerplate de estructura Clean Architecture) que hoy consumen tiempo
   repetitivo del equipo.

## Por qué está en "Probar" y no en "Adoptar"

El código generado por IA debe pasar exactamente por el mismo Code Review
y Quality Gate que cualquier otro código (ver
[07-calidad-arquitectura](../../07-calidad-arquitectura/) y
[sonarqube.md](./sonarqube.md)) — no hay una vía rápida de aprobación por
haber sido asistido por Copilot. Se mantiene en "Probar" hasta confirmar
que esto se respeta consistentemente y que no introduce riesgos de
seguridad (ej. sugerencias con licencias inciertas, código con
vulnerabilidades sutiles).

## Cómo se usa en el proyecto (mientras está en Probar)

- Uso permitido para cualquier desarrollador que quiera probarlo.
- **Prohibido** aceptar sugerencias de Copilot para: credenciales,
  configuración de secretos, o cualquier código relacionado a
  autenticación/autorización sin revisión humana exhaustiva (ver
  [10-seguridad-datos](../../10-seguridad-datos/)).
- Todo código generado con asistencia de IA se revisa con el mismo
  estándar de Code Review que el resto (ver
  [07-calidad-arquitectura](../../07-calidad-arquitectura/)): el autor del
  PR sigue siendo responsable del código que introduce, sin importar
  quién (o qué) lo escribió.

## Trade-offs / riesgos

- Riesgo de sugerencias de código con licencias de origen incierto.
- Riesgo de sobreconfianza: aceptar sugerencias sin revisión crítica,
  especialmente en lógica de negocio sensible (ej. cálculo de pagos,
  validaciones de seguridad).
- Costo de licenciamiento por desarrollador.

## Cuándo reconsiderar

- Pasa a **Adoptar** si, tras un período de prueba, el equipo confirma
  mejora de velocidad medible sin incidentes de calidad o seguridad
  atribuibles a código generado por IA.
- Se descarta si se detectan patrones recurrentes de código problemático
  aceptado sin suficiente escrutinio en Code Review.