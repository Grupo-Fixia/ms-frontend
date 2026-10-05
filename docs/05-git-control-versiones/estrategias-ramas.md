# 🌿 Estrategia de Ramificación (Gitflow & Convenios de Ramas)

## 1. Objetivo

Establecer un flujo de trabajo estructurado y estandarizado para la creación, integración y despliegue de código en los repositorios de **Fixia**, garantizando:

- Aislamiento de código en desarrollo para prevenir impactos en entornos estables.
- Trazabilidad directa entre la rama, el ticket de Jira y el desarrollador.
- Despliegues continuos, seguros y automatizados mediante pipelines CI/CD.
- Revisiones de código eficientes mediante Pull Requests (PRs).

---

## 2. Ramas Principales y Permanentes

El modelo se basa en una adaptación de **Gitflow**, manteniendo tres ramas con propósitos y reglas de protección claramente definidos:

| Rama | Propósito | Entorno Asociado | Protección |
| :--- | :--- | :--- | :--- |
| **`main`** | Código en producción estable y probado. | **Producción** | Push directo prohibido. Requiere PR + 2 aprobaciones + tests en verde. |
| **`release`** | Preparación de versión candidatada a producción (RC). | **Staging / Pre-producción** | Push directo prohibido. Solo se integran hotfixes o ajustes finales. |
| **`develop`** | Rama principal de desarrollo donde convergen las características de la iteración. | **QA / Dev** | Push directo prohibido. Requiere PR + 1 aprobación + CI en verde. |

---

## 3. Nomenclatura Estándar de Ramas de Trabajo

Toda rama temporal creada por un desarrollador debe seguir estrictamente la siguiente convención:

```text
<tipo>/<clave-jira>-<descripción-corta>
```

### Tipos de Ramas Permitidos:

| Tipo | Propósito | Rama de Origen | Rama de Destino | Ejemplo |
| :--- | :--- | :--- | :--- | :--- |
| **`feature/`** | Desarrollar nueva funcionalidad o requerimiento de negocio. | `develop` | `develop` | `feature/FIX-105-login-oauth2` |
| **`fix/`** | Corregir un error o fallo técnico detectado en QA o Dev. | `develop` | `develop` | `fix/FIX-204-timeout-pagos` |
| **`hotfix/`** | Corrección crítica urgente de un fallo directamente en Producción. | `main` | `main` y `develop` | `hotfix/FIX-911-fail-autenticacion` |
| **`refactor/`** | Reestructuración de código sin cambios en el comportamiento externo. | `develop` | `develop` | `refactor/FIX-312-separar-servicios` |
| **`chore/`** | Tareas técnicas, actualización de dependencias o configuración CI/CD. | `develop` | `develop` | `chore/FIX-401-actualizar-deps` |
| **`release/`** | Preparación y estabilización de un release de versión. | `develop` | `main` y `develop` | `release/v1.2.0` |

---

## 4. Reglas de Redacción para Nombres de Ramas

- **Minúsculas exclusivamente:** Usar siempre letras minúsculas (ej. `feature/` y no `Feature/`).
- **Separador guion medio (`-`):** Separar las palabras mediante guiones cortos. No usar espacios ni guiones bajos (`_`).
- **Clave Jira obligatoria:** Toda rama de trabajo debe incluir el identificador exacto del ticket de Jira inmediatamente después del prefijo.
- **Sin caracteres especiales:** Evitar tildes, `ñ`, acentos o símbolos especiales.

### ❌ Ejemplos Incorrectos:
```text
login_page
feature_login
fix/error-pagos
FEATURE/FIX105-login
feature/FIX-105_login_oauth2
```

### ✅ Ejemplos Correctos:
```text
feature/FIX-105-login-oauth2
fix/FIX-204-timeout-pagos
hotfix/FIX-911-error-token-expirado
refactor/FIX-312-optimizacion-consultas
chore/FIX-401-dockerfile-multistage
```

---

## 5. Flujo de Trabajo (Step-by-Step Workflow)

### Paso 1: Creación de la Rama
Partir siempre de la última versión de `develop` (o `main` si es un `hotfix` crítico):

```bash
git checkout develop
git pull origin develop
git checkout -b feature/FIX-105-login-oauth2
```

### Paso 2: Desarrollo y Commits
Realizar cambios aplicando las convenciones de commits:

```bash
git add .
git commit -m "feat(auth): implementar flujo de autorizacion con OAuth2 [FIX-105]"
```

### Paso 3: Mantener la Rama Actualizada (Rebase)
Antes de abrir un Pull Request, sincronizar la rama con los cambios recientes de `develop`:

```bash
git fetch origin
git rebase origin/develop
```

> 💡 **Nota:** Si existen conflictos, resolverlos localmente y continuar con `git rebase --continue`. Evitar *merge commits* innecesarios en ramas de feature.

### Paso 4: Publicación de la Rama
Publicar la rama en el repositorio remoto:

```bash
git push -u origin feature/FIX-105-login-oauth2
```

---

## 6. Políticas de Pull Requests (PR)

Toda integración a `develop`, `release` o `main` se realiza mediante Pull Requests.

### Requisitos mínimos para aprobar un PR:
1. **Título del PR:** Debe seguir la misma sintaxis que el commit: `<tipo>(<alcance>): <descripción> [CLAVE-JIRA]`.
2. **Plantilla de PR completa:** Descripción del cambio, evidencias de prueba (capturas/logs) y checklist de autoevaluación.
3. **Revisores asignados:** Al menos **1 aprobación** de un Senior / Tech Lead para `develop`, y **2 aprobaciones** para `main`.
4. **CI/CD Status:** Todas las pruebas unitarias, linters y análisis estático de código (SonarQube/GitHub Actions) deben estar en verde.
5. **Estrategia de Integración:**
   - **Squash and Merge:** Opción preferida para integrar `feature/` o `fix/` en `develop` (mantiene el historial limpio).
   - **Merge Commit:** Usado para integrar `release/` o `hotfix/` a `main` (conserva el punto de tag y versión).

---

## 7. Manejo de Hotfixes (Emergencias en Producción)

Cuando ocurre una falla crítica en producción que requiere corrección inmediata:

1. **Crear rama desde `main`:**
   ```bash
   git checkout main
   git pull origin main
   git checkout -b hotfix/FIX-911-error-token-expirado
   ```
2. **Aplicar corrección y validar localmente.**
3. **Abrir PR hacia `main` y hacia `develop`** para asegurar que la solución no se pierda en futuros desarrollos.
4. **Etiquetar la versión (Tag):** Al integrar a `main`, generar el tag semántico correspondiente (ej. `v1.0.1`).

---

## 8. Limpieza de Ramas

Para evitar acumulación de ramas obsoletas en el repositorio remoto:

- Se configurará la eliminación automática de ramas (*Auto-delete head branches*) en GitHub tras completar el merge de un PR.
- Las ramas temporales (`feature/`, `fix/`, `hotfix/`) no deben permanecer abiertas por más de 14 días.

---

## 9. Checklist para Desarrolladores

Antes de solicitar revisión de un PR, asegúrate de haber cumplido:
- [ ] Mi rama se creó a partir del estado más reciente de `develop` (o `main` para hotfix).
- [ ] El nombre de la rama incluye el tipo correcto y la clave de Jira (`<tipo>/FIX-XXX-nombre`).
- [ ] Hice `git rebase` con `develop` antes de hacer push.
- [ ] Todos mis commits siguen las convenciones del equipo.
- [ ] Los pipelines automatizados pasaron exitosamente.

