# HashiCorp Vault

**Estado en el Tech Radar:** 🟢 Adoptar
**Categoría:** Plataformas & Infraestructura
**Última revisión:** 2026-09-20

## Contexto

Fixia tiene múltiples microservicios en distintos lenguajes (ver
[lenguajes-frameworks/](../lenguajes-frameworks/)), varios de ellos
manejando datos sensibles (credenciales de base de datos, SDK de la
pasarela de pagos en Java — ver
[lenguajes-frameworks/java.md](../lenguajes-frameworks/java.md)). Ya se
mencionaba a Vault como gestor de secretos recomendado en varias páginas
de la wiki; el diagrama de infraestructura lo confirma como componente
real del cluster.

## Decisión

HashiCorp Vault se adopta como gestor centralizado de secretos, corriendo
en el namespace `secrets` del cluster K3s.

## Alternativas consideradas

| Opción | Por qué no |
|---|---|
| **Secrets nativos de Kubernetes (`Secret` objects)** | Los Secrets nativos de Kubernetes se almacenan codificados en base64, no cifrados por defecto, y carecen de rotación automática y auditoría fina; insuficiente para datos como credenciales de la pasarela de pagos. |
| **GitHub Actions Secrets únicamente** | Cubre secretos usados durante el pipeline de CI/CD, pero no resuelve la gestión de secretos en tiempo de ejecución dentro del cluster (ej. credenciales de base de datos que un microservicio necesita al arrancar). Ambos se usan, con roles distintos (ver [06-cicd-ambientes](../../06-cicd-ambientes/)). |

## Justificación para Fixia

1. **Punto único de gestión de secretos para todo el cluster**, sin
   importar el lenguaje del microservicio (Node.js, Python, Go, Java —
   ver [lenguajes-frameworks/](../lenguajes-frameworks/)).
2. **Rotación y auditoría**, relevantes especialmente para credenciales
   de base de datos (rotación cada 90 días, ver
   [10-seguridad-datos](../../10-seguridad-datos/)) y para el acceso al
   SDK de la pasarela de pagos.
3. **Ya funciona como supuesto en otras páginas de la wiki** (ver
   [tecnicas-metodos/mtls.md](../tecnicas-metodos/mtls.md) y
   [tecnicas-metodos/devops-cultura.md](../tecnicas-metodos/devops-cultura.md)),
   que ya asumían un gestor de secretos centralizado; esta página lo deja
   confirmado como decisión real, no solo supuesto.

## Cómo se usa en el proyecto

- Namespace `secrets` dentro del cluster K3s.
- Gestiona: credenciales de bases de datos por microservicio (ver
  [bases-de-datos.md](./bases-de-datos.md)), credenciales de MinIO (ver
  [minio.md](./minio.md)), y credenciales de integración con servicios
  externos (pasarela de pagos, SMTP, SMS/WhatsApp, Google Maps).
- Cada microservicio accede solo a los secretos que le corresponden
  (principio de mínimo privilegio, ver
  [10-seguridad-datos](../../10-seguridad-datos/)).

## Trade-offs / riesgos

- Vault es un componente crítico: si no está disponible, los
  microservicios que dependen de secretos dinámicos pueden no poder
  arrancar o renovar credenciales.
- Requiere una estrategia clara de backup y recuperación del propio Vault
  (que a su vez custodia el resto de los secretos del sistema).

## Cuándo reconsiderar

Baja probabilidad de cambio como decisión de base. Se reconsideraría solo
si el overhead operativo de mantener Vault disponible y respaldado
superara claramente el beneficio frente a una alternativa más simple.
