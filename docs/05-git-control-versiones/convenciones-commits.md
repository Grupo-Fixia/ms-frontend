## 1. Objetivo


Establecer una convención uniforme para los mensajes de commit de todos los repositorios de **Fixia**, permitiendo:


- Mantener un historial de cambios claro, legible y navegable.

- Facilitar la trazabilidad bidireccional entre GitHub y Jira.

- Identificar rápidamente la naturaleza e impacto de cualquier cambio.

- Facilitar la generación automática de changelogs y notas de release.

- Automatizar validaciones mediante pipelines de CI/CD.

- Mantener consistencia técnica entre los diferentes microservicios y equipos.


La convención adoptada por Fixia está basada en **[Conventional Commits](https://www.conventionalcommits.org/)** e integrada directamente con la trazabilidad de Jira mediante la clave del ticket.


---


## 2. Regla General y Estructura


Todo commit realizado en los repositorios debe seguir la siguiente estructura estandarizada:


```text

<tipo>(<alcance>): <descripción> [CLAVE-JIRA]

Ejemplo:

Plaintext


feat(auth): agregar login con OAuth2 [PROJ-215]

Desglose de elementos:

ElementoObligatorioDescripción<tipo>SíNaturaleza o categoría del cambio introducido.(<alcance>)NoComponente, módulo, microservicio o contexto técnico afectado.<descripción>SíResumen breve, imperativo y descriptivo del cambio en minúsculas.[CLAVE-JIRA]SíIdentificador único del ticket en Jira (ej. [FIX-102], [PROJ-215]).

3. Tipos de Commit Permitidos

TipoUso principalEjemplofeatIncorporación de una nueva funcionalidad o capacidad.feat(auth): agregar autenticación mediante OAuth2 [PROJ-215]fixCorrección de un error o comportamiento incorrecto.fix(payments): corregir timeout en consulta de pagos [PROJ-330]docsCambios exclusivamente en la documentación técnica o READMEs.docs(api): actualizar documentación de endpoints [PROJ-401]styleAjustes de formato o estilo que no alteran la lógica del código (linter, espacios).style(api): aplicar formato estándar al controlador [PROJ-402]refactorReestructuración de código sin alterar su comportamiento funcional.refactor(users): separar lógica de validación del controlador [PROJ-410]testCreación, refactorización o actualización de pruebas unitarias/integración.test(auth): agregar pruebas para expiración de tokens [PROJ-415]choreTareas técnicas de mantenimiento, dependencias o configuración del repositorio.chore(ci): actualizar configuración del pipeline [PROJ-420]perfCambios enfocados exclusivamente en mejorar el rendimiento del sistema.perf(search): optimizar consulta de búsqueda de registros [PROJ-425]

4. Uso del Alcance (Scope)

El alcance ayuda a identificar de forma rápida qué capa o módulo del sistema fue intervenido.



Ejemplos comunes:

Funcionalidad / Módulo: feat(auth): ..., fix(notifications): ...


Capa del sistema: refactor(repository): ..., fix(api): ...


Contexto de dominio: test(registros): ...


Buenas prácticas para el alcance:

Debe ser corto, en minúsculas y descriptivo.


Debe mantener consistencia con la estructura de carpetas o módulos del repositorio.


Aunque es opcional, se recomienda fuertemente su uso en repositorios multi-módulo o microservicios.


5. Reglas de Redacción

Para garantizar mensajes limpios y profesionales:



Usar modo imperativo/presente en la descripción (ej. agregar, corregir, eliminar en lugar de agregado o corrigiendo).


Empezar en minúsculas y no incluir punto final.


Evitar descripciones genéricas o ambiguas.


❌ Ejemplos Incorrectos:

Plaintext


cambios [PROJ-215]

fix [PROJ-330]

actualización [PROJ-410]

cosas varias [PROJ-420]

✅ Ejemplos Correctos:

Plaintext


feat(auth): agregar autenticación con OAuth2 [PROJ-215]

fix(api): corregir timeout en endpoint de pagos [PROJ-330]

refactor(users): separar validaciones del controlador [PROJ-410]

6. Integración con Jira y Smart Commits

La clave de Jira permite vinculación automática en GitHub para auditar qué código resolvió cada requerimiento.



Smart Commits (Comandos ejecutables)

Si Smart Commits está habilitado, es posible interactuar directamente con Jira desde el mensaje del commit usando la sintaxis:



Plaintext


<tipo>(<alcance>): <descripción> [CLAVE-JIRA] #<comando> <parámetros>

ComandoAcción en JiraEjemplo de uso#commentAgrega un comentario al ticket.feat(auth): agregar login [PROJ-215] #comment Listo para QA#timeRegistra horas de trabajo en la tarea.feat(auth): agregar login [PROJ-215] #time 3h#close / #doneCierra la tarea en Jira.fix(api): corregir bug [PROJ-330] #close#in-reviewTransiciona el ticket a revisión.feat(auth): agregar login [PROJ-215] #in-review

⚠️ Regla de seguridad: Los comandos #close o #done solo deben usarse en el commit final que completa el trabajo y es integrado a la rama principal. No usarlos en commits intermedios de trabajo.


7. Commits Atómicos

Cada commit debe representar una única unidad lógica de cambio.



💡 Recomendado (Granularidad atómica):

Plaintext


feat(auth): agregar endpoint de login [PROJ-215]

test(auth): agregar pruebas unitarias de login [PROJ-215]

docs(auth): documentar contrato OpenAPI de login [PROJ-215]

🚫 Evitar (Commits "Monolíticos"):

Plaintext


feat: agregar login, modificar Dockerfile, actualizar documentación y corregir pagos [PROJ-215]

8. Seguridad y Manejo de Secretos

Queda estrictamente prohibido incluir secretos en los mensajes de commit o en el código commiteado.



No incluir:



Passwords o Tokens API.


Claves privadas (SSH, RSA, PGP).


Credenciales de BD o cloud.


Archivos .env no plantillados.


9. Validación Automática (Linter & Hooks)

Los repositorios cuentan con validaciones automáticas mediante Commitlint y Git Hooks (Husky) para garantizar el cumplimiento de estas normas antes de permitir un git push.



Se verifica automáticamente:



Existencia y formato de la clave de Jira [PROJ-XXX].


Uso de un <tipo> válido.


Formato del mensaje según la especificación.


10. Checklist de Autoevaluación

Antes de hacer git commit, responde las siguientes preguntas:



[ ] ¿El mensaje incluye la clave de Jira al final entre corchetes [CLAVE-JIRA]?


[ ] ¿El tipo de commit corresponde a la acción real realizada?


[ ] ¿La descripción es clara, concisa e imperativa?


[ ] ¿El commit contiene únicamente cambios relacionados entre sí?

"""


filename = "convenciones-commits-v2.md"

with open(filename, "w", encoding="utf-8") as f:

f.write(wiki_commits_md.strip())



print(f"File updated: {filename}")




```text?code_stdout&code_event_index=1

File updated: convenciones-commits-v2.md

Aquí tienes el documento completo e íntegro en sintaxis Markdown. Puedes copiar el bloque de código de abajo directamente a una página de tu GitHub Wiki (por ejemplo Convenciones-de-Commits.md) o descargar el archivo adjunto.



El archivo Markdown generado está listo para descargar aquí:



convenciones-commits-v2

MD

Abierto

Markdown


# 📝 Convenciones de Commits## 1. Objetivo


Establecer una convención uniforme para los mensajes de commit de todos los repositorios de **Fixia**, permitiendo:- Mantener un historial de cambios claro, legible y navegable.- Facilitar la trazabilidad bidireccional entre GitHub y Jira.- Identificar rápidamente la naturaleza e impacto de cualquier cambio.- Facilitar la generación automática de changelogs y notas de release.- Automatizar validaciones mediante pipelines de CI/CD.- Mantener consistencia técnica entre los diferentes microservicios y equipos.


La convención adoptada por Fixia está basada en **[Conventional Commits](https://www.conventionalcommits.org/)** e integrada directamente con la trazabilidad de Jira mediante la clave del ticket.


---## 2. Regla General y Estructura


Todo commit realizado en los repositorios debe seguir la siguiente estructura estandarizada:```text

<tipo>(<alcance>): <descripción> [CLAVE-JIRA]

Ejemplo:

Plaintext


feat(auth): agregar login con OAuth2 [PROJ-215]

Desglose de elementos:

ElementoObligatorioDescripción<tipo>SíNaturaleza o categoría del cambio introducido.(<alcance>)NoComponente, módulo, microservicio o contexto técnico afectado.<descripción>SíResumen breve, imperativo y descriptivo del cambio en minúsculas.[CLAVE-JIRA]SíIdentificador único del ticket en Jira (ej. [FIX-102], [PROJ-215]).

3. Tipos de Commit Permitidos

TipoUso principalEjemplofeatIncorporación de una nueva funcionalidad o capacidad.feat(auth): agregar autenticación mediante OAuth2 [PROJ-215]fixCorrección de un error o comportamiento incorrecto.fix(payments): corregir timeout en consulta de pagos [PROJ-330]docsCambios exclusivamente en la documentación técnica o READMEs.docs(api): actualizar documentación de endpoints [PROJ-401]styleAjustes de formato o estilo que no alteran la lógica del código (linter, espacios).style(api): aplicar formato estándar al controlador [PROJ-402]refactorReestructuración de código sin alterar su comportamiento funcional.refactor(users): separar lógica de validación del controlador [PROJ-410]testCreación, refactorización o actualización de pruebas unitarias/integración.test(auth): agregar pruebas para expiración de tokens [PROJ-415]choreTareas técnicas de mantenimiento, dependencias o configuración del repositorio.chore(ci): actualizar configuración del pipeline [PROJ-420]perfCambios enfocados exclusivamente en mejorar el rendimiento del sistema.perf(search): optimizar consulta de búsqueda de registros [PROJ-425]

4. Uso del Alcance (Scope)

El alcance ayuda a identificar de forma rápida qué capa o módulo del sistema fue intervenido.



Ejemplos comunes:

Funcionalidad / Módulo: feat(auth): ..., fix(notifications): ...


Capa del sistema: refactor(repository): ..., fix(api): ...


Contexto de dominio: test(registros): ...


Buenas prácticas para el alcance:

Debe ser corto, en minúsculas y descriptivo.


Debe mantener consistencia con la estructura de carpetas o módulos del repositorio.


Aunque es opcional, se recomienda fuertemente su uso en repositorios multi-módulo o microservicios.


5. Reglas de Redacción

Para garantizar mensajes limpios y profesionales:



Usar modo imperativo/presente en la descripción (ej. agregar, corregir, eliminar en lugar de agregado o corrigiendo).


Empezar en minúsculas y no incluir punto final.


Evitar descripciones genéricas o ambiguas.


❌ Ejemplos Incorrectos:

Plaintext


cambios [PROJ-215]

fix [PROJ-330]

actualización [PROJ-410]

cosas varias [PROJ-420]

✅ Ejemplos Correctos:

Plaintext


feat(auth): agregar autenticación con OAuth2 [PROJ-215]

fix(api): corregir timeout en endpoint de pagos [PROJ-330]

refactor(users): separar validaciones del controlador [PROJ-410]

6. Integración con Jira y Smart Commits

La clave de Jira permite vinculación automática en GitHub para auditar qué código resolvió cada requerimiento.



Smart Commits (Comandos ejecutables)

Si Smart Commits está habilitado, es posible interactuar directamente con Jira desde el mensaje del commit usando la sintaxis:



Plaintext


<tipo>(<alcance>): <descripción> [CLAVE-JIRA] #<comando> <parámetros>

ComandoAcción en JiraEjemplo de uso#commentAgrega un comentario al ticket.feat(auth): agregar login [PROJ-215] #comment Listo para QA#timeRegistra horas de trabajo en la tarea.feat(auth): agregar login [PROJ-215] #time 3h#close / #doneCierra la tarea en Jira.fix(api): corregir bug [PROJ-330] #close#in-reviewTransiciona el ticket a revisión.feat(auth): agregar login [PROJ-215] #in-review

⚠️ Regla de seguridad: Los comandos #close o #done solo deben usarse en el commit final que completa el trabajo y es integrado a la rama principal. No usarlos en commits intermedios de trabajo.


7. Commits Atómicos

Cada commit debe representar una única unidad lógica de cambio.



💡 Recomendado (Granularidad atómica):

Plaintext


feat(auth): agregar endpoint de login [PROJ-215]

test(auth): agregar pruebas unitarias de login [PROJ-215]

docs(auth): documentar contrato OpenAPI de login [PROJ-215]

🚫 Evitar (Commits "Monolíticos"):

Plaintext


feat: agregar login, modificar Dockerfile, actualizar documentación y corregir pagos [PROJ-215]

8. Seguridad y Manejo de Secretos

Queda estrictamente prohibido incluir secretos en los mensajes de commit o en el código commiteado.



No incluir:



Passwords o Tokens API.


Claves privadas (SSH, RSA, PGP).


Credenciales de BD o cloud.


Archivos .env no plantillados.


9. Validación Automática (Linter & Hooks)

Los repositorios cuentan con validaciones automáticas mediante Commitlint y Git Hooks (Husky) para garantizar el cumplimiento de estas normas antes de permitir un git push.



Se verifica automáticamente:



Existencia y formato de la clave de Jira [PROJ-XXX].


Uso de un <tipo> válido.


Formato del mensaje según la especificación.


10. Checklist de Autoevaluación

Antes de hacer git commit, responde las siguientes preguntas:



[ ] ¿El mensaje incluye la clave de Jira al final entre corchetes [CLAVE-JIRA]?


[ ] ¿El tipo de commit corresponde a la acción real realizada?


[ ] ¿La descripción es clara, concisa e imperativa?


[ ] ¿El commit contiene únicamente cambios relacionados entre sí?

Ejemplo:
Plaintext

feat(auth): agregar login con OAuth2 [PROJ-215]

Desglose de elementos:
Elemento	Obligatorio	Descripción
<tipo>	Sí	Naturaleza o categoría del cambio introducido.
(<alcance>)	No	Componente, módulo, microservicio o contexto técnico afectado.
<descripción>	Sí	Resumen breve, imperativo y descriptivo del cambio en minúsculas.
[CLAVE-JIRA]	Sí	Identificador único del ticket en Jira (ej. [FIX-102], [PROJ-215]).
3. Tipos de Commit Permitidos
Tipo	Uso principal	Ejemplo
feat	Incorporación de una nueva funcionalidad o capacidad.	feat(auth): agregar autenticación mediante OAuth2 [PROJ-215]
fix	Corrección de un error o comportamiento incorrecto.	fix(payments): corregir timeout en consulta de pagos [PROJ-330]
docs	Cambios exclusivamente en la documentación técnica o READMEs.	docs(api): actualizar documentación de endpoints [PROJ-401]
style	Ajustes de formato o estilo que no alteran la lógica del código (linter, espacios).	style(api): aplicar formato estándar al controlador [PROJ-402]
refactor	Reestructuración de código sin alterar su comportamiento funcional.	refactor(users): separar lógica de validación del controlador [PROJ-410]
test	Creación, refactorización o actualización de pruebas unitarias/integración.	test(auth): agregar pruebas para expiración de tokens [PROJ-415]
chore	Tareas técnicas de mantenimiento, dependencias o configuración del repositorio.	chore(ci): actualizar configuración del pipeline [PROJ-420]
perf	Cambios enfocados exclusivamente en mejorar el rendimiento del sistema.	perf(search): optimizar consulta de búsqueda de registros [PROJ-425]
4. Uso del Alcance (Scope)

El alcance ayuda a identificar de forma rápida qué capa o módulo del sistema fue intervenido.

Ejemplos comunes:

    Funcionalidad / Módulo: feat(auth): ..., fix(notifications): ...

    Capa del sistema: refactor(repository): ..., fix(api): ...

    Contexto de dominio: test(registros): ...

Buenas prácticas para el alcance:

    Debe ser corto, en minúsculas y descriptivo.

    Debe mantener consistencia con la estructura de carpetas o módulos del repositorio.

    Aunque es opcional, se recomienda fuertemente su uso en repositorios multi-módulo o microservicios.

5. Reglas de Redacción

Para garantizar mensajes limpios y profesionales:

    Usar modo imperativo/presente en la descripción (ej. agregar, corregir, eliminar en lugar de agregado o corrigiendo).

    Empezar en minúsculas y no incluir punto final.

    Evitar descripciones genéricas o ambiguas.

❌ Ejemplos Incorrectos:
Plaintext

cambios [PROJ-215]
fix [PROJ-330]
actualización [PROJ-410]
cosas varias [PROJ-420]

✅ Ejemplos Correctos:
Plaintext

feat(auth): agregar autenticación con OAuth2 [PROJ-215]
fix(api): corregir timeout en endpoint de pagos [PROJ-330]
refactor(users): separar validaciones del controlador [PROJ-410]

6. Integración con Jira y Smart Commits

La clave de Jira permite vinculación automática en GitHub para auditar qué código resolvió cada requerimiento.
Smart Commits (Comandos ejecutables)

Si Smart Commits está habilitado, es posible interactuar directamente con Jira desde el mensaje del commit usando la sintaxis:
Plaintext

<tipo>(<alcance>): <descripción> [CLAVE-JIRA] #<comando> <parámetros>

Comando	Acción en Jira	Ejemplo de uso
#comment	Agrega un comentario al ticket.	feat(auth): agregar login [PROJ-215] #comment Listo para QA
#time	Registra horas de trabajo en la tarea.	feat(auth): agregar login [PROJ-215] #time 3h
#close / #done	Cierra la tarea en Jira.	fix(api): corregir bug [PROJ-330] #close
#in-review	Transiciona el ticket a revisión.	feat(auth): agregar login [PROJ-215] #in-review

    ⚠️ Regla de seguridad: Los comandos #close o #done solo deben usarse en el commit final que completa el trabajo y es integrado a la rama principal. No usarlos en commits intermedios de trabajo.

7. Commits Atómicos

Cada commit debe representar una única unidad lógica de cambio.
💡 Recomendado (Granularidad atómica):
Plaintext

feat(auth): agregar endpoint de login [PROJ-215]
test(auth): agregar pruebas unitarias de login [PROJ-215]
docs(auth): documentar contrato OpenAPI de login [PROJ-215]

🚫 Evitar (Commits "Monolíticos"):
Plaintext

feat: agregar login, modificar Dockerfile, actualizar documentación y corregir pagos [PROJ-215]

8. Seguridad y Manejo de Secretos

Queda estrictamente prohibido incluir secretos en los mensajes de commit o en el código commiteado.

No incluir:

    Passwords o Tokens API.

    Claves privadas (SSH, RSA, PGP).

    Credenciales de BD o cloud.

    Archivos .env no plantillados.

9. Validación Automática (Linter & Hooks)

Los repositorios cuentan con validaciones automáticas mediante Commitlint y Git Hooks (Husky) para garantizar el cumplimiento de estas normas antes de permitir un git push.

Se verifica automáticamente:

    Existencia y formato de la clave de Jira [PROJ-XXX].

    Uso de un <tipo> válido.

    Formato del mensaje según la especificación.

10. Checklist de Autoevaluación

Antes de hacer git commit, responde las siguientes preguntas:

    [ ] ¿El mensaje incluye la clave de Jira al final entre corchetes [CLAVE-JIRA]?

    [ ] ¿El tipo de commit corresponde a la acción real realizada?

    [ ] ¿La descripción es clara, concisa e imperativa?

    [ ] ¿El commit contiene únicamente cambios relacionados entre sí?
    """

filename = "convenciones-commits-v2.md"
with open(filename, "w", encoding="utf-8") as f:
f.write(md_content.strip() + "\n")

print(f"File created: {filename}")


```text?code_stdout&code_event_index=1
File created: convenciones-commits-v2.md

Tu archivo Markdown con toda la información y formato corregido está listo:
Icono de MD
convenciones-commits-v2
 MD 
Vista Previa del Documento (convenciones-commits-v2.md)
Markdown

# 📝 Convenciones de Commits

## 1. Objetivo

Establecer una convención uniforme para los mensajes de commit de todos los repositorios de **Fixia**, permitiendo:

- Mantener un historial de cambios claro, legible y navegable.
- Facilitar la trazabilidad bidireccional entre GitHub y Jira.
- Identificar rápidamente la naturaleza e impacto de cualquier cambio.
- Facilitar la generación automática de changelogs y notas de release.
- Automatizar validaciones mediante pipelines de CI/CD.
- Mantener consistencia técnica entre los diferentes microservicios y equipos.

La convención adoptada por Fixia está basada en **[Conventional Commits](https://www.conventionalcommits.org/)** e integrada directamente con la trazabilidad de Jira mediante la clave del ticket.

---

## 2. Regla General y Estructura

Todo commit realizado en los repositorios debe seguir la siguiente estructura estandarizada:

```text
<tipo>(<alcance>): <descripción> [CLAVE-JIRA]

Ejemplo:
Plaintext

feat(auth): agregar login con OAuth2 [PROJ-215]

Desglose de elementos:
Elemento	Obligatorio	Descripción
<tipo>	Sí	Naturaleza o categoría del cambio introducido.
(<alcance>)	No	Componente, módulo, microservicio o contexto técnico afectado.
<descripción>	Sí	Resumen breve, imperativo y descriptivo del cambio en minúsculas.
[CLAVE-JIRA]	Sí	Identificador único del ticket en Jira (ej. [FIX-102], [PROJ-215]).
3. Tipos de Commit Permitidos
Tipo	Uso principal	Ejemplo
feat	Incorporación de una nueva funcionalidad o capacidad.	feat(auth): agregar autenticación mediante OAuth2 [PROJ-215]
fix	Corrección de un error o comportamiento incorrecto.	fix(payments): corregir timeout en consulta de pagos [PROJ-330]
docs	Cambios exclusivamente en la documentación técnica o READMEs.	docs(api): actualizar documentación de endpoints [PROJ-401]
style	Ajustes de formato o estilo que no alteran la lógica del código (linter, espacios).	style(api): aplicar formato estándar al controlador [PROJ-402]
refactor	Reestructuración de código sin alterar su comportamiento funcional.	refactor(users): separar lógica de validación del controlador [PROJ-410]
test	Creación, refactorización o actualización de pruebas unitarias/integración.	test(auth): agregar pruebas para expiración de tokens [PROJ-415]
chore	Tareas técnicas de mantenimiento, dependencias o configuración del repositorio.	chore(ci): actualizar configuración del pipeline [PROJ-420]
perf	Cambios enfocados exclusivamente en mejorar el rendimiento del sistema.	perf(search): optimizar consulta de búsqueda de registros [PROJ-425]
4. Uso del Alcance (Scope)

El alcance ayuda a identificar de forma rápida qué capa o módulo del sistema fue intervenido.

Ejemplos comunes:

    Funcionalidad / Módulo: feat(auth): ..., fix(notifications): ...

    Capa del sistema: refactor(repository): ..., fix(api): ...

    Contexto de dominio: test(registros): ...

Buenas prácticas para el alcance:

    Debe ser corto, en minúsculas y descriptivo.

    Debe mantener consistencia con la estructura de carpetas o módulos del repositorio.

    Aunque es opcional, se recomienda fuertemente su uso en repositorios multi-módulo o microservicios.

5. Reglas de Redacción

Para garantizar mensajes limpios y profesionales:

    Usar modo imperativo/presente en la descripción (ej. agregar, corregir, eliminar en lugar de agregado o corrigiendo).

    Empezar en minúsculas y no incluir punto final.

    Evitar descripciones genéricas o ambiguas.

❌ Ejemplos Incorrectos:
Plaintext

cambios [PROJ-215]
fix [PROJ-330]
actualización [PROJ-410]
cosas varias [PROJ-420]

✅ Ejemplos Correctos:
Plaintext

feat(auth): agregar autenticación con OAuth2 [PROJ-215]
fix(api): corregir timeout en endpoint de pagos [PROJ-330]
refactor(users): separar validaciones del controlador [PROJ-410]

6. Integración con Jira y Smart Commits

La clave de Jira permite vinculación automática en GitHub para auditar qué código resolvió cada requerimiento.
Smart Commits (Comandos ejecutables)

Si Smart Commits está habilitado, es posible interactuar directamente con Jira desde el mensaje del commit usando la sintaxis:
Plaintext

<tipo>(<alcance>): <descripción> [CLAVE-JIRA] #<comando> <parámetros>

Comando	Acción en Jira	Ejemplo de uso
#comment	Agrega un comentario al ticket.	feat(auth): agregar login [PROJ-215] #comment Listo para QA
#time	Registra horas de trabajo en la tarea.	feat(auth): agregar login [PROJ-215] #time 3h
#close / #done	Cierra la tarea en Jira.	fix(api): corregir bug [PROJ-330] #close
#in-review	Transiciona el ticket a revisión.	feat(auth): agregar login [PROJ-215] #in-review

    ⚠️ Regla de seguridad: Los comandos #close o #done solo deben usarse en el commit final que completa el trabajo y es integrado a la rama principal. No usarlos en commits intermedios de trabajo.

7. Commits Atómicos

Cada commit debe representar una única unidad lógica de cambio.
💡 Recomendado (Granularidad atómica):
Plaintext

feat(auth): agregar endpoint de login [PROJ-215]
test(auth): agregar pruebas unitarias de login [PROJ-215]
docs(auth): documentar contrato OpenAPI de login [PROJ-215]

🚫 Evitar (Commits "Monolíticos"):
Plaintext

feat: agregar login, modificar Dockerfile, actualizar documentación y corregir pagos [PROJ-215]

8. Seguridad y Manejo de Secretos

Queda estrictamente prohibido incluir secretos en los mensajes de commit o en el código commiteado.

No incluir:

    Passwords o Tokens API.

    Claves privadas (SSH, RSA, PGP).

    Credenciales de BD o cloud.

    Archivos .env no plantillados.

9. Validación Automática (Linter & Hooks)

Los repositorios cuentan con validaciones automáticas mediante Commitlint y Git Hooks (Husky) para garantizar el cumplimiento de estas normas antes de permitir un git push.

Se verifica automáticamente:

    Existencia y formato de la clave de Jira [PROJ-XXX].

    Uso de un <tipo> válido.

    Formato del mensaje según la especificación.

10. Checklist de Autoevaluación

Antes de hacer git commit, responde las siguientes preguntas:

    [ ] ¿El mensaje incluye la clave de Jira al final entre corchetes [CLAVE-JIRA]?

    [ ] ¿El tipo de commit corresponde a la acción real realizada?

    [ ] ¿La descripción es clara, concisa e imperativa?

    [ ] ¿El commit contiene únicamente cambios relacionados entre sí?


Gemini es una IA y puede cometer errores.
Analizando

# 📝 Convenciones de Commits

## 1. Objetivo

Establecer una convención uniforme para los mensajes de commit de todos los repositorios de **Fixia**, permitiendo:

- Mantener un historial de cambios claro, legible y navegable.
- Facilitar la trazabilidad bidireccional entre GitHub y Jira.
- Identificar rápidamente la naturaleza e impacto de cualquier cambio.
- Facilitar la generación automática de changelogs y notas de release.
- Automatizar validaciones mediante pipelines de CI/CD.
- Mantener consistencia técnica entre los diferentes microservicios y equipos.

La convención adoptada por Fixia está basada en **[Conventional Commits](https://www.conventionalcommits.org/)** e integrada directamente con la trazabilidad de Jira mediante la clave del ticket.

---

## 2. Regla General y Estructura

Todo commit realizado en los repositorios debe seguir la siguiente estructura estandarizada:

```text
<tipo>(<alcance>): <descripción> [CLAVE-JIRA]
```

**Ejemplo:**
```text
feat(auth): agregar login con OAuth2 [PROJ-215]
```

### Desglose de elementos:

| Elemento | Obligatorio | Descripción |
| :--- | :---: | :--- |
| `<tipo>` | Sí | Naturaleza o categoría del cambio introducido. |
| `(<alcance>)` | No | Componente, módulo, microservicio o contexto técnico afectado. |
| `<descripción>` | Sí | Resumen breve, imperativo y descriptivo del cambio en minúsculas. |
| `[CLAVE-JIRA]` | Sí | Identificador único del ticket en Jira (ej. `[FIX-102]`, `[PROJ-215]`). |

---

## 3. Tipos de Commit Permitidos

| Tipo | Uso principal | Ejemplo |
| :--- | :--- | :--- |
| `feat` | Incorporación de una nueva funcionalidad o capacidad. | `feat(auth): agregar autenticación mediante OAuth2 [PROJ-215]` |
| `fix` | Corrección de un error o comportamiento incorrecto. | `fix(payments): corregir timeout en consulta de pagos [PROJ-330]` |
| `docs` | Cambios exclusivamente en la documentación técnica o READMEs. | `docs(api): actualizar documentación de endpoints [PROJ-401]` |
| `style` | Ajustes de formato o estilo que no alteran la lógica del código (linter, espacios). | `style(api): aplicar formato estándar al controlador [PROJ-402]` |
| `refactor` | Reestructuración de código sin alterar su comportamiento funcional. | `refactor(users): separar lógica de validación del controlador [PROJ-410]` |
| `test` | Creación, refactorización o actualización de pruebas unitarias/integración. | `test(auth): agregar pruebas para expiración de tokens [PROJ-415]` |
| `chore` | Tareas técnicas de mantenimiento, dependencias o configuración del repositorio. | `chore(ci): actualizar configuración del pipeline [PROJ-420]` |
| `perf` | Cambios enfocados exclusivamente en mejorar el rendimiento del sistema. | `perf(search): optimizar consulta de búsqueda de registros [PROJ-425]` |

---

## 4. Uso del Alcance (Scope)

El alcance ayuda a identificar de forma rápida qué capa o módulo del sistema fue intervenido.

**Ejemplos comunes:**
- **Funcionalidad / Módulo:** `feat(auth): ...`, `fix(notifications): ...`
- **Capa del sistema:** `refactor(repository): ...`, `fix(api): ...`
- **Contexto de dominio:** `test(registros): ...`

**Buenas prácticas para el alcance:**
- Debe ser corto, en minúsculas y descriptivo.
- Debe mantener consistencia con la estructura de carpetas o módulos del repositorio.
- Aunque es opcional, se recomienda fuertemente su uso en repositorios multi-módulo o microservicios.

---

## 5. Reglas de Redacción

Para garantizar mensajes limpios y profesionales:

- Usar modo imperativo/presente en la descripción (ej. *agregar*, *corregir*, *eliminar* en lugar de *agregado* o *corrigiendo*).
- Empezar en minúsculas y no incluir punto final.
- Evitar descripciones genéricas o ambiguas.

### ❌ Ejemplos Incorrectos:
```text
cambios [PROJ-215]
fix [PROJ-330]
actualización [PROJ-410]
cosas varias [PROJ-420]
```

### ✅ Ejemplos Correctos:
```text
feat(auth): agregar autenticación con OAuth2 [PROJ-215]
fix(api): corregir timeout en endpoint de pagos [PROJ-330]
refactor(users): separar validaciones del controlador [PROJ-410]
```

---

## 6. Integración con Jira y Smart Commits

La clave de Jira permite vinculación automática en GitHub para auditar qué código resolvió cada requerimiento.

### Smart Commits (Comandos ejecutables)

Si Smart Commits está habilitado, es posible interactuar directamente con Jira desde el mensaje del commit usando la sintaxis:

```text
<tipo>(<alcance>): <descripción> [CLAVE-JIRA] #<comando> <parámetros>
```

| Comando | Acción en Jira | Ejemplo de uso |
| :--- | :--- | :--- |
| `#comment` | Agrega un comentario al ticket. | `feat(auth): agregar login [PROJ-215] #comment Listo para QA` |
| `#time` | Registra horas de trabajo en la tarea. | `feat(auth): agregar login [PROJ-215] #time 3h` |
| `#close` / `#done` | Cierra la tarea en Jira. | `fix(api): corregir bug [PROJ-330] #close` |
| `#in-review` | Transiciona el ticket a revisión. | `feat(auth): agregar login [PROJ-215] #in-review` |

> ⚠️ **Regla de seguridad:** Los comandos `#close` o `#done` solo deben usarse en el commit final que completa el trabajo y es integrado a la rama principal. No usarlos en commits intermedios de trabajo.

---

## 7. Commits Atómicos

Cada commit debe representar una única unidad lógica de cambio.

### 💡 Recomendado (Granularidad atómica):
```text
feat(auth): agregar endpoint de login [PROJ-215]
test(auth): agregar pruebas unitarias de login [PROJ-215]
docs(auth): documentar contrato OpenAPI de login [PROJ-215]
```

### �� Evitar (Commits "Monolíticos"):
```text
feat: agregar login, modificar Dockerfile, actualizar documentación y corregir pagos [PROJ-215]
```

---

## 8. Seguridad y Manejo de Secretos

Queda estrictamente prohibido incluir secretos en los mensajes de commit o en el código commiteado.

**No incluir:**
- Passwords o Tokens API.
- Claves privadas (SSH, RSA, PGP).
- Credenciales de BD o cloud.
- Archivos `.env` no plantillados.

---

## 9. Validación Automática (Linter & Hooks)

Los repositorios cuentan con validaciones automáticas mediante **Commitlint** y **Git Hooks (Husky)** para garantizar el cumplimiento de estas normas antes de permitir un `git push`.

Se verifica automáticamente:
- Existencia y formato de la clave de Jira `[PROJ-XXX]`.
- Uso de un `<tipo>` válido.
- Formato del mensaje según la especificación.

---

## 10. Checklist de Autoevaluación

Antes de hacer `git commit`, responde las siguientes preguntas:

- [ ] ¿El mensaje incluye la clave de Jira al final entre corchetes `[CLAVE-JIRA]`?
- [ ] ¿El tipo de commit corresponde a la acción real realizada?
- [ ] ¿La descripción es clara, concisa e imperativa?
- [ ] ¿El commit contiene únicamente cambios relacionados entre sí?

convenciones-commits-v2.md
Mostrando convenciones-commits-v2.md.
