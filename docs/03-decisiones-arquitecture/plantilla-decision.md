# Plantilla: Página de Decisión

Toda página que documente una herramienta, lenguaje, framework o patrón
dentro de `03-decisiones-arquitectura/` debe seguir esta estructura. El
objetivo es que cualquier desarrollador nuevo pueda entender, en una sola
página, no solo *qué* usamos sino *por qué*.

No es necesario llenar cada sección con muchas líneas — una tabla o dos
párrafos claros son preferibles a relleno genérico copiado de internet.

---

## [Nombre de la herramienta/decisión]

**Estado en el Tech Radar:** Adoptar / Probar / Evaluar / Retener
**Categoría:** Lenguajes y Frameworks / Plataformas e Infraestructura / Herramientas / Técnicas y Métodos
**Última revisión:** AAAA-MM-DD

### Contexto

¿Qué problema estamos resolviendo? ¿En qué parte de Fixia aplica? (ej.
"búsqueda de proveedores por geolocalización", "pipeline de CI",
"comunicación entre microservicios"). Si aplica, referenciar el dominio de
negocio correspondiente en
[01-contexto-proyecto/mapa-dominios-negocio.md](../../01-contexto-proyecto/mapa-dominios-negocio.md).

### Decisión

Qué elegimos, en una frase clara y sin ambigüedad.

### Alternativas consideradas

| Opción | Por qué no |
|---|---|
| ... | ... |

### Justificación para Fixia

Por qué esta opción encaja con nuestro contexto específico: equipo actual,
escala esperada, infraestructura on-premise hoy, plan de migración a nube,
dominio de negocio geolocalizado, requisitos de seguridad de datos
sensibles, etc. **No** debe ser una justificación genérica ("es lo más
popular", "tiene buena documentación") sin conexión a un motivo concreto
de Fixia.

### Cómo se usa en el proyecto

La política concreta: convenciones, configuración mínima, ejemplo de
código o de configuración si aplica.

### Trade-offs / riesgos

Qué sacrificamos al elegir esto. Toda decisión tiene un costo; nombrarlo
explícitamente ayuda a que futuras revisiones no lo redescubran desde cero.

### Cuándo reconsiderar

Señales concretas de que esta decisión debería revisarse (ej. "si el
equipo supera 15 desarrolladores", "si migramos a nube antes de 2027", "si
el volumen de búsquedas por segundo supera X").

---

## Ejemplo de uso

Para ver esta plantilla ya aplicada a un caso real, ver cualquier página
dentro de `03-decisiones-arquitectura/`, por ejemplo la de Docker o la de
Clean Architecture.