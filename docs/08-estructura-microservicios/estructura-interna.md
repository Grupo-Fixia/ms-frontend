# Estructura Interna Estándar de un Microservicio

## Estructura de carpetas

Todo microservicio de Fixia, sin importar el lenguaje, sigue la misma
organización de Clean Architecture (ver justificación completa en
[03-decisiones-arquitectura/tecnicas-metodos/clean-architecture.md](../03-decisiones-arquitectura/tecnicas-metodos/clean-architecture.md)):

```
fixia-msv-<nombre>/
├── src/
│   ├── domain/           # Entidades y reglas de negocio puras
│   ├── application/      # Casos de uso, interfaces de repositorios (puertos)
│   ├── infrastructure/   # Implementación de DB, clientes externos
│   └── interfaces/       # Controllers REST, DTOs
├── tests/
│   ├── unit/
│   └── integration/
├── .github/
│   ├── workflows/        # Pipelines CI/CD
│   └── CODEOWNERS
├── docs/
│   └── openapi.yaml      # Contrato de API
├── Dockerfile
├── docker-compose.yml    # Para desarrollo local
├── .env.example
└── README.md
```

## Adaptación por lenguaje

La estructura conceptual (4 capas, regla de dependencia hacia adentro) es
igual en todos los lenguajes del stack, pero la convención de carpetas
concreta se adapta al idioma de cada uno:

| Lenguaje | Convención de carpetas | Página de decisión |
|---|---|---|
| Node.js/TypeScript | `src/domain/`, `src/application/`, etc. (tal cual el esquema de arriba) | [nodejs-typescript.md](../03-decisiones-arquitectura/lenguajes-frameworks/nodejs-typescript.md) |
| Python (FastAPI) | Mismo esquema, adaptado a paquetes Python (`__init__.py` por carpeta) | [python-fastapi.md](../03-decisiones-arquitectura/lenguajes-frameworks/python-fastapi.md) |
| Go | Organización por paquetes Go en vez de carpetas anidadas estrictas, manteniendo la misma separación conceptual | [go.md](../03-decisiones-arquitectura/lenguajes-frameworks/go.md) |
| Java (Spring Boot) | Paquetes Java por capa (`com.fixia.<servicio>.domain`, `.application`, etc.) | [java.md](../03-decisiones-arquitectura/lenguajes-frameworks/java.md) |

## ⚠️ Pendiente: estructura interna del Orquestador (Saga)

El microservicio Orquestador introduce el patrón Saga (ver punto
pendiente en
[01-contexto-proyecto/mapa-dominios-negocio.md](../01-contexto-proyecto/mapa-dominios-negocio.md)),
que todavía no tiene página de decisión propia en
`03-decisiones-arquitectura/tecnicas-metodos/`. Antes de fijar su
estructura interna definitiva, hay que resolver:

- ¿El Orquestador tiene una capa `domain/` propia (si coordina un
  concepto de negocio real, como "el ciclo de vida completo de una
  solicitud"), o es puramente `application/` (casos de uso que invocan a
  otros microservicios sin dueño de datos propio)?
- ¿Dónde vive la definición de cada Saga (los pasos y sus
  compensaciones)? Se propone una carpeta adicional
  `src/sagas/` una vez que se confirme el diseño, pero esto es una
  propuesta a validar, no una convención ya decidida.

## Checklist de bootstrap para un microservicio nuevo

- [ ] Nombre del repositorio sigue la convención (ver
      [convencion-nombres.md](./convencion-nombres.md)).
- [ ] Lenguaje elegido según el criterio de
      [lenguajes-frameworks/README.md](../03-decisiones-arquitectura/lenguajes-frameworks/README.md),
      o justificado con una página de decisión propia si es una
      excepción (ver ejemplo real en
      [java.md](../03-decisiones-arquitectura/lenguajes-frameworks/java.md)).
- [ ] Estructura de 3 ramas configurada (`main`, `test`, `producción`)
      con protección aplicada (ver
      [05-git-control-versiones](../05-git-control-versiones/)).
- [ ] Pipeline de CI/CD con Quality Gate al 85% configurado (ver
      [06-cicd-ambientes](../06-cicd-ambientes/)).
- [ ] Base de datos propia y exclusiva, si el microservicio la requiere
      (no compartida con otro microservicio — ver
      [10-seguridad-datos](../10-seguridad-datos/)).
- [ ] Documentación OpenAPI publicada en `docs/openapi.yaml`.
- [ ] Health check endpoint (`/health`) implementado para monitoreo.
- [ ] Registrado en el API Gateway (ruta configurada).
- [ ] Circuit breaker configurado para llamadas a otros microservicios,
      si aplica (ver
      [03-decisiones-arquitectura/tecnicas-metodos/](../03-decisiones-arquitectura/tecnicas-metodos/)).
- [ ] README documenta qué patrones de diseño aplica y por qué.