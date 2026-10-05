# 🔑 Gestión de Secretos y Llaves de Seguridad

## 1. Objetivo
Definir la arquitectura y procesos para la administración, rotación y aprovisionamiento seguro de secretos, claves criptográficas y credenciales en el ecosistema **Fixia**.

---

## 2. Estrategia de Gestión de Secretos

Queda estrictamente prohibido incluir contraseñas, claves privadas, tokens de API o cadenas de conexión en el repositorio de código.

```text
               +-----------------------------------+
               |  HashiCorp Vault / External Secret|
               +-----------------+-----------------+
                                 |
               +-----------------v-----------------+
               | Kubernetes External Secrets (ESO) |
               +-----------------+-----------------+
                                 |
               +-----------------v-----------------+
               |   K3s Native Secrets (etcd)       |
               +-----------------------------------+
```

---

## 3. Reglas de Manejo e Inyección
1. **Inyección en Tiempo de Ejecución:** Los secretos se inyectan en los contenedores como variables de entorno o volúmenes montados temporalmente (`tmpfs`).
2. **Secretos en CI/CD:** Uso exclusivo de **GitHub Actions Secrets** para pipelines de automatización.
3. **Rotación:** Rotación de llaves públicas/privadas de firma JWT cada **90 días**. Rotación inmediata en caso de cualquier sospecha de vulneración.
