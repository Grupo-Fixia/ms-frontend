# 🛡️ Protección de Datos y Privacidad

## 1. Objetivo
Asegurar el cumplimiento de regulaciones sobre datos personales, garantizando la confidencialidad, integridad y disponibilidad de la información técnica y privada almacenada en la plataforma **Fixia**.

---

## 2. Cifrado de Datos

- **Cifrado en Tránsito:** Uso obligatorio de **TLS 1.3** en todas las comunicaciones externas e internas (mTLS dentro del clúster de K3s para comunicación inter-servicio).
- **Cifrado en Reposo:** 
  - Bases de datos PostgreSQL/MongoDB con almacenamiento cifrado vía **AES-256**.
  - Datos sensibles (ej. identificación, métodos de pago, teléfono) cifrados a nivel de columna/documento con llaves gestionadas en el gestor de secretos.

---

## 3. Hash de Contraseñas
- Implementación obligatoria de **Argon2id** o **BCrypt** (factor de costo mínimo: 12) para el almacenamiento de credenciales de usuario.

---

## 4. Clasificación y Manejo de Datos (PII)

| Categoría de Dato | Ejemplos | Nivel de Cifrado | Política de Exposición |
| :--- | :--- | :---: | :--- |
| **Público** | Nombre del profesional, calificaciones, tarifas de servicio. | Ninguno | Accesible mediante la API pública. |
| **Restringido (PII)** | Correo electrónico, número de teléfono, dirección. | En tránsito + Reposo | Visible solo para las partes involucradas en una orden activa. |
| **Altamente Confidencial**| Documento de identidad, hash de claves, tokens bancarios. | Cifrado de columna (AES-256) | Nunca retornado en endpoints REST convencionales. |
