# 🎨 Patrones de Diseño Estándar en Fixia

## 1. Objetivo

Definir el catálogo de patrones de diseño recomendados dentro de la arquitectura de **Fixia**, unificando criterios de implementación entre desarrolladores.

---

## 2. Patrones Creacionales

### A. Factory Method / Abstract Factory
- **Uso:** Creación de objetos complejos sin acoplar la clase cliente a la implementación concreta.
- **Caso en Fixia:** Generación de clientes de pasarelas de pago (Stripe, MercadoPago, PayU) según la configuración de la transacción.

### B. Builder
- **Uso:** Construcción de objetos complejos paso a paso, especialmente útil para DTOs, Entidades con muchos atributos o configuraciones de test.
- **Caso en Fixia:** Uso de `@Builder` de Lombok en Java o modelos de Pydantic con constructores fluidos en Python.

---

## 3. Patrones Estructurales

### A. Adapter
- **Uso:** Permitir que interfaces incompatibles trabajen juntas.
- **Caso en Fixia:** Adaptar librerías de terceros (ej. SDKs de AWS o proveedores de SMS) a los puertos (`Ports`) de nuestra capa de dominio.

### B. Decorator
- **Uso:** Añadir funcionalidades a objetos dinámicamente sin alterar su estructura.
- **Caso en Fixia:** Añadir caché (Redis) o logging a la capa de repositorios sin modificar las consultas base.

---

## 4. Patrones Comportamentales

### A. Strategy
- **Uso:** Definir una familia de algoritmos, encapsular cada uno y hacerlos intercambiables en tiempo de ejecución.
- **Caso en Fixia:** Algoritmos de cálculo de comisiones para técnicos/profesionales según el tipo de servicio.

### B. Observer / Publish-Subscribe
- **Uso:** Notificar a múltiples objetos sobre eventos de cambio de estado.
- **Caso in Fixia:** Publicación y consumo de eventos de dominio mediante **Apache Kafka** (ej. `OrdenCreadaEvent`).

### C. Command / CQRS (Command Query Responsibility Segregation)
- **Uso:** Separar las operaciones de lectura (Queries) de las operaciones de escritura/modificación (Commands) para optimizar rendimiento y escalabilidad.
