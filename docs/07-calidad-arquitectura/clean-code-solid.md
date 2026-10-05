# 🧹 Código Limpio (Clean Code) y Principios SOLID

## 1. Objetivo

Fijar las reglas de codificación y diseño orientado a objetos / funcional para mantener la base de código de **Fixia** legible, mantenible, fácil de probar y escalable.

---

## 2. Principios SOLID

### 1. S - Single Responsibility Principle (SRP)
- **Regla:** Una clase o módulo debe tener **una y solo una razón para cambiar**.
- **Ejemplo:** Un `UserService` no debe construir respuestas HTTP ni enviar correos electrónicos directamente. Cada tarea se delega a su componente especializado.

### 2. O - Open/Closed Principle (OCP)
- **Regla:** El código debe estar **abierto para extensión, pero cerrado para modificación**.
- **Ejemplo:** Usar polimorfismo o estrategia (*Strategy Pattern*) para agregar nuevos métodos de pago sin alterar el código existente del procesador.

### 3. L - Liskov Substitution Principle (LSP)
- **Regla:** Las clases derivadas deben ser sustituibles por sus clases base sin alterar la corrección del programa.
- **Ejemplo:** Si `Square` hereda de `Rectangle`, modificar el ancho no debe alterar inesperadamente el alto rompiendo el comportamiento base.

### 4. I - Interface Segregation Principle (ISP)
- **Regla:** Es preferible tener muchas interfaces pequeñas y específicas que una interfaz gigante y multipropósito.
- **Ejemplo:** Separar `ReadableRepository` y `WritableRepository` en lugar de una interfaz monolítica de base de datos.

### 5. D - Dependency Inversion Principle (DIP)
- **Regla:** Depender de **abstracciones (interfaces)**, no de implementaciones concretas.
- **Ejemplo:** El caso de uso depende de la interfaz `UserRepository`, no de `PostgresUserRepository`.

---

## 3. Reglas Esenciales de Clean Code

1. **Nombres Significativos:** Variables y funciones con nombres descriptivos. Evitar abreviaturas ambiguas (`usr`, `calc()`, `temp`).
2. **Funciones Pequeñas:** Cada función debe realizar una sola acción, tener pocas líneas de código (idealmente < 20) y un número mínimo de parámetros (máximo 3).
3. **Manejo Explicito de Excepciones:** No atrapar excepciones genéricas (`catch (Exception e)`) ni dejarlas vacías. Usar excepciones de dominio personalizadas.
4. **Comentarios Justificados:** El código debe ser autodocumentado. Comentar **el porqué** de una decisión compleja, no **el qué** hace el código.
