# 🔀 Guía Estándar de Pull Requests (PRs)

## 1. Objetivo

Establecer un proceso estandarizado y claro para la apertura, revisión, aprobación e integración de **Pull Requests (PRs)** en los repositorios de **Fixia**, con el fin de:

- Garantizar la calidad, legibilidad y mantenibilidad del código mediante revisiones por pares (Peer Reviews).
- Asegurar que ningún cambio entre a ramas protegidas (`develop`, `release`, `main`) sin cumplir con las pruebas y estándares del proyecto.
- Facilitar la trazabilidad entre el código propuesto, los requerimientos de negocio en **Jira** y los despliegues de **CI/CD**.
- Prevenir la introducción de fallos, vulnerabilidades o regresiones en entornos compartidos.

---

## 2. Reglas Generales de Creación

1. **Un PR por tarea de Jira:** Cada PR debe corresponder a un ticket específico de Jira (Feature, Fix, Refactor, etc.). Evitar PRs gigantescos que mezclen múltiples tareas no relacionadas.
2. **Rama base correcta:**
   - Para **`feature/`**, **`fix/`**, **`refactor/`**, **`chore/`** ➡️ Apuntar a **`develop`**.
   - Para **`release/`** ➡️ Apuntar a **`main`** (y posteriormente sincronizar con **`develop`**).
   - Para **`hotfix/`** ➡️ Apuntar a **`main`** y a **`develop`**.
3. **Estado de la rama:** Antes de abrir el PR, la rama debe estar rebasada (`git rebase`) respecto a la rama destino para evitar conflictos de integración.
4. **Pipelines en verde:** Los tests unitarios, linters y análisis de código estático deben ejecutar y pasar sin errores.

---

## 3. Nomenclatura del Título del PR

El título del Pull Request debe seguir exactamente la misma convención que los mensajes de commit:

```text
<tipo>(<alcance>): <descripción-breve> [CLAVE-JIRA]
```

### Ejemplos:
- `feat(auth): agregar autenticacion mediante OAuth2 [FIX-105]`
- `fix(payments): corregir timeout en consulta de transacciones [FIX-204]`
- `refactor(users): separar logica de validacion del controlador [FIX-312]`
- `hotfix(auth): corregir fallo de expiracion de JWT en produccion [FIX-911]`

---

## 4. Plantilla Estándar de Pull Request

Todos los PRs abiertos en GitHub deberán incluir el siguiente formato en su descripción:

```markdown
## 📌 Resumen del Cambio
Brief explicación de qué se implementó o corrigió en este PR y el motivo del cambio.

## 🔗 Ticket de Jira
- **Ticket:** [FIX-XXX](https://tu-dominio.atlassian.net/browse/FIX-XXX)

## 🛠️ Tipo de Cambio
- [ ] 🚀 Nueva funcionalidad (`feat`)
- [ ] 🐛 Corrección de error (`fix`)
- [ ] ⚙️ Tarea técnica o mantenimiento (`chore`)
- [ ] ♻️ Refactorización de código (`refactor`)
- [ ] 📚 Documentación (`docs`)
- [ ] ⚡ Mejora de rendimiento (`perf`)

## 🧪 Evidencias y Pruebas
Describir cómo se probaron estos cambios o adjuntar evidencias visuales (capturas de pantalla, logs de ejecución, respuestas de Postman/cURL, etc.).

- [x] Pruebas unitarias/integración ejecutadas localmente.
- [x] Capturas de pantalla o logs adjuntos.

## 📋 Checklist de Autoevaluación
- [ ] El título del PR sigue el formato `<tipo>(<alcance>): <descripción> [FIX-XXX]`.
- [ ] La rama origen está actualizada mediante `git rebase` con la rama de destino.
- [ ] No se subieron archivos innecesarios, temporales o secretos (`.env`, llaves, credenciales).
- [ ] El código cumple con las reglas de estilo del proyecto (linter/formatter).
- [ ] Todos los tests automáticos en el pipeline de CI se ejecutaron en verde.
```

---

## 5. Criterios y Roles para la Revisión

### Asignación de Revisores
- **Hacia `develop`:** Requiere la revisión y aprobación de al menos **1 desarrollador Senior o Tech Lead**.
- **Hacia `main` (Releases / Hotfixes):** Requiere la revisión y aprobación de al menos **2 miembros** (Tech Lead + DevOps/Senior Lead).

### Responsabilidades del Revisor
El revisor debe enfocar sus observaciones en:
- **Arquitectura y diseño:** Cumplimiento de patrones de diseño, separación de responsabilidades y modularidad.
- **Seguridad:** Ausencia de vulnerabilidades (SQL injection, XSS, exposición de datos sensibles, manejo adecuado de autenticación/autorización).
- **Rendimiento:** Evitar consultas N+1 a base de datos, bucles ineficientes o algoritmos pesados.
- **Mantenibilidad y Limpieza:** Código legible, nombres claros de variables/funciones y ausencia de código muerto o comentado.

---

## 6. Estrategia de Integración (Merge Strategy)

Una vez aprobado el PR y superadas las validaciones de CI/CD, se procederá al merge según las siguientes reglas:

| Rama Destino | Tipo de Trabajo | Estrategia de Merge Recomendada | Razón |
| :--- | :--- | :--- | :--- |
| **`develop`** | `feature/`, `fix/`, `refactor/`, `chore/` | **Squash and Merge** | Combina todos los commits temporales de la rama en un único commit limpio en `develop`. |
| **`main`** | `release/`, `hotfix/` | **Create a Merge Commit** | Mantiene la historia completa de lanzamientos y facilita el tagging semántico. |

---

## 7. Cierre y Limpieza

1. **Eliminación de la rama:** Después de integrar con éxito el PR, la rama remota de trabajo debe ser eliminada (GitHub lo realiza automáticamente si está activado *Auto-delete head branches*).
2. **Actualización en Jira:** Asegurarse de que el ticket pase al estado correspondiente (**In QA**, **Done**, etc.) o utilizar los Smart Commits en la resolución final.
