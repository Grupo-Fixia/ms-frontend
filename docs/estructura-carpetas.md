# Estructura de carpetas — ms-frontend

Estándar de organización del frontend de Fixia (Flutter). Aplica a todo el
código nuevo de `ms-frontend`. Si algo no encaja, se propone el cambio en este
documento mediante un PR antes de salirse de la regla.

## 1. Versión y alcance

| Elemento | Valor |
|---|---|
| Framework | Flutter **3.22.0** · Dart **3.4.0** (misma versión del `Dockerfile`) |
| Plataforma objetivo | Web (una sola app para clientes y técnicos — SAD, ADR-001) |
| Arquitectura | Clean Architecture por funcionalidad (wiki `07-calidad-arquitectura/clean-architecture.md`) |

## 2. Árbol general

```
ms-frontend/
├── assets/                 # Recursos estáticos declarados en pubspec.yaml
│   ├── brand/              #   logos del Brand Board
│   └── fonts/              #   tipografía Inter (+ licencia OFL)
├── docs/                   # Documentación del frontend (este archivo)
├── lib/
│   ├── main.dart           # Punto de entrada: tema, rutas e inyección de dependencias
│   ├── core/               # Código compartido por TODAS las funcionalidades
│   │   ├── config/         #   configuración de las APIs (URL base del backend)
│   │   ├── constants/      #   valores globales (ej. versión de la política de datos)
│   │   ├── theme/          #   tema según el Brand Board v1.0
│   │   └── validation/     #   reglas usadas por varias funcionalidades (ej. correo)
│   └── features/           # Una carpeta por actor y, dentro, una por funcionalidad
│       ├── auth/           #   común a todos los roles
│       │   └── login/      #     inicio y cierre de sesión (GC-236)
│       ├── home/           #   página de inicio pública (común a todos)
│       │   └── presentation/
│       ├── client/         #   funcionalidades del cliente
│       │   └── registration/   # registro de cliente (GC-234)
│       └── technician/     #   funcionalidades del técnico
│           └── registration/   # registro de técnico (GC-235)
├── test/                   # Espejo de lib/: misma ruta que el archivo probado
│   └── features/client/registration/...
└── web/                    # Archivos de la plataforma web (index.html, íconos)
```

### ¿Dónde va una funcionalidad nueva?

1. **¿La usan varios roles?** (login, perfil común, notificaciones) → `features/auth/` o una carpeta común con nombre del dominio.
2. **¿Es de un solo actor?** → `features/client/<funcionalidad>/` o `features/technician/<funcionalidad>/`.
3. **¿Es infraestructura transversal sin pantalla propia?** (tema, cliente HTTP, constantes) → `core/`.

## 3. Capas dentro de cada funcionalidad

Cada funcionalidad (`features/<actor>/<funcionalidad>/`) usa las capas de la
wiki. Solo se crean las que hagan falta.

```
registration/
├── domain/            # Entidades, reglas de validación y excepciones. Dart puro.
├── application/       # Casos de uso y puertos (interfaces de repositorios).
│   └── ports/
├── infrastructure/    # Implementación de los puertos: clientes HTTP, DTOs, mapeos.
└── presentation/      # Páginas, controladores (ChangeNotifier) y widgets propios.
    └── widgets/
```

**Regla de dependencia** (las flechas indican "puede importar"):

```
presentation ──► application ──► domain
infrastructure ──► application ──► domain
```

- `domain/` **no importa Flutter** (`package:flutter/...`) ni paquetes de red.
- `application/` solo conoce `domain/` y define los puertos (`abstract interface class`).
- `presentation/` nunca llama a HTTP directamente: usa los casos de uso.
- `infrastructure/` implementa los puertos; `main.dart` decide qué implementación se inyecta.
- Una funcionalidad **no importa** carpetas internas de otra. Lo que se comparta se mueve a `core/`.

## 4. Convenciones de nombres

| Qué | Regla | Ejemplo |
|---|---|---|
| Carpetas y archivos | `snake_case`, en inglés | `client_registration_page.dart` |
| Archivos de una funcionalidad | prefijo con el nombre de la funcionalidad | `client_registration_controller.dart` |
| Clases | `PascalCase` | `ClientRegistrationPage` |
| Casos de uso | verbo + objeto | `RegisterClient`, `LoginUser` |
| Puertos | sustantivo + `Repository` | `ClientRegistrationRepository` |
| Implementaciones HTTP | `Http` + puerto | `HttpClientRegistrationRepository` |
| Tests | mismo nombre + `_test.dart`, misma ruta bajo `test/` | `client_registration_page_test.dart` |
| Textos de la interfaz | en español, tono del Brand Board ("Claro y directo") | `'Crea tu cuenta'` |

## 5. Código compartido (`core/`)

- `core/theme/fixia_theme.dart` es **el único tema** de la app (Brand Board v1.0). No se definen colores ni tipografías sueltos en las páginas: se usan `FixiaColors`, `FixiaTheme` y `FixiaDecorations`.
- `core/constants/` guarda valores globales; por ejemplo `dataPolicyVersion` (`v1.0`, acordada con backend).
- `core/config/api_config.dart` define la URL base del backend (`ApiConfig.usersBaseUrl`): se fija al compilar con `--dart-define=USERS_API_BASE_URL=...` y por defecto es `http://localhost`, el origen que sirve Traefik. Ninguna funcionalidad escribe URLs del backend a mano.
- `core/validation/` guarda reglas que usan varias funcionalidades; por ejemplo `EmailRule`, que comparten el registro y el inicio de sesión.
- Algo pasa a `core/` cuando lo necesita **más de una** funcionalidad.

## 6. Compatibilidad con Flutter 3.22

El build de QA usa la imagen `instrumentisto/flutter:3.22.0`. No usar APIs que no existen en 3.22 o que cambiaron de tipo después:

| No usar | Usar en su lugar |
|---|---|
| `Color.withValues(alpha: …)` | `Color.withOpacity(…)` |
| `ThemeData(cardTheme: CardThemeData(…))` / `CardTheme(…)` | `FixiaDecorations.card` (el tipo cambió entre versiones) |
| `DropdownButtonFormField(initialValue: …)` | `DropdownButtonFormField(value: …)` |
| `flutter_lints` 4.x o superior | `flutter_lints: ^3.0.0` |

Al leer respuestas del backend, decodificar siempre como UTF-8 (`utf8.decode(response.bodyBytes)`): `ms-users` responde `application/problem+json` sin `charset` y, si no, las tildes llegan dañadas (TD V1, DEF-02).

## 7. Sesión y seguridad

- El access token y el perfil viven **solo en memoria** (`SessionStore`).
- Con "Mantener sesión iniciada", el refresh token se guarda en el navegador (`localStorage`, vía `shared_preferences`) para restaurar la sesión al reabrir la app. Es un riesgo conocido: un script malicioso en la página (XSS) podría leerlo. Se mitiga porque el backend lo invalida en cada uso (rotación) y al cerrar sesión. Sin esa opción no se guarda nada.
- Al cerrar sesión se revocan los tokens en ms-users; si el access token ya venció (dura 15 minutos), primero se renueva para poder revocar el refresh token.

## 8. Antes de abrir un PR

Desde la raíz de `ms-frontend`, con Flutter 3.22.0:

```bash
flutter analyze                 # debe decir: No issues found!
flutter test --coverage         # debe decir: All tests passed!
tool/check_coverage.sh          # cobertura de líneas >= 80 % (Quality Gate de la wiki)
flutter build web --release
```

El workflow `ci` de GitHub Actions corre esos mismos pasos (analyze, pruebas y
cobertura) en cada PR y push a `develop` y `Qa`; si alguno falla, el PR queda
con el check en rojo y no se construye ni despliega la imagen de QA. El reporte
`coverage/lcov.info` queda como artefacto del workflow.

Y seguir las convenciones de ramas, commits y PRs de la wiki (`05-git-control-versiones/`).
