# 🏛️ Arquitectura Limpia (Clean Architecture)

## 1. Objetivo

Establecer los principios y la estructura en capas para los microservicios de **Fixia**, desacoplando la lógica de negocio central de los marcos de trabajo (frameworks), bases de datos, interfaces de usuario y servicios de terceros.

---

## 2. Diagrama de Capas (Onion / Hexagonal)

La arquitectura sigue el principio de dependencia: **las capas internas no deben saber nada de las capas externas**.

```text
               +-----------------------------------+
               |     Adaptadores de Entrada        |
               | (Controllers, GraphQL, CLI, Kafka)|
               +-----------------+-----------------+
                                 |
               +-----------------v-----------------+
               |       Casos de Uso (Application)  |
               |     (Use Cases, Services, DTOs)   |
               +-----------------+-----------------+
                                 |
               +-----------------v-----------------+
               |       Dominio Central (Domain)    |
               |    (Entities, Value Objects)      |
               +-----------------+-----------------+
                                 ^
               +-----------------+-----------------+
               |    Adaptadores de Salida          |
               | (Repositories, DB, ORM, APIs Ext) |
               +-----------------------------------+
```

---

## 3. Descripción de las Capas

### A. Capa de Dominio (`domain`)
- **Responsabilidad:** Es el corazón del sistema. Contiene los modelos de negocio (Entities), Objetos de Valor (Value Objects) y reglas empresariales puras.
- **Regla de Oro:** **Cero dependencias externas**. No debe importar frameworks (Spring, FastAPI), annotations de ORMs (JPA, Hibernate, Pydantic) ni librerías de infraestructura.

### B. Capa de Aplicación (`application`)
- **Responsabilidad:** Modela los casos de uso del sistema. Intercala entidades de dominio y coordina el flujo de datos.
- **Componentes:** Use Cases, Services, DTOs de entrada/salida y definición de interfaces (Ports/Contratos) para repositorios o clientes externos.

### C. Capa de Adaptadores / Infraestructura (`infrastructure`)
- **Responsabilidad:** Implementa los detalles técnicos e integraciones externas.
- **Componentes:**
  - **Entrada (Inbound):** Controladores REST, GraphQL, Consumidores de Kafka/RabbitMQ.
  - **Salida (Outbound):** Implementación de Repositorios (PostgreSQL, MongoDB), Clientes HTTP, adaptadores para AWS/S3.

---

## 4. Estructura Estándar de Carpetas

```text
src/
├── domain/
│   ├── models/
│   ├── exceptions/
│   └── value_objects/
├── application/
│   ├── use_cases/
│   ├── dtos/
│   └── ports/          # Interfaces (Repositories, External Services)
└── infrastructure/
    ├── adapters/
    │   ├── persistence/ # Implementación de DB (JPA, SQLAlchemy)
    │   └── messaging/   # Producers / Consumers (Kafka)
    └── entrypoints/     # REST Controllers / Routers
