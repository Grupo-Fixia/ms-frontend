# 🔒 Módulo 10: Seguridad y Protección de Datos

## 📌 Descripción del Módulo

Este módulo define la arquitectura de seguridad, estrategias de gestión de identidad, políticas de privacidad de la información y administración de secretos para la plataforma **Fixia**.

El diseño asegura la protección de los datos de los usuarios y el cumplimiento de los estándares modernos de ciberseguridad en arquitecturas distribuidas.

---

## 🗂️ Contenido de la Sección

| Archivo | Descripción |
| :--- | :--- |
| **[`autenticacion-autorizacion.md`](./autenticacion-autorizacion.md)** | Especificaciones de OAuth2, JWT firmados con RS256, estructura del payload y modelo de permisos RBAC. |
| **[`proteccion-datos-privacidad.md`](./proteccion-datos-privacidad.md)** | Políticas de cifrado en tránsito (TLS 1.3 / mTLS) y reposo (AES-256), hashing con Argon2id/BCrypt y clasificación PII. |
| **[`gestion-secretos.md`](./gestion-secretos.md)** | Integración con administradores de secretos (HashiCorp Vault / External Secrets Operator), inyección segura y rotación de claves. |

---

## 🛡️ Checklist de Seguridad para Desarrolladores

- [ ] ¿El nuevo endpoint valida permisos mediante RBAC?
- [ ] ¿Cualquier dato PII sensible está excluido de las respuestas HTTP públicas y de los logs en JSON?
- [ ] ¿Se eliminaron credenciales o URLs hardcodeadas del código fuente?
- [ ] ¿Los campos de entrada aplican validación y sanitización estricta contra SQLi y XSS?
