# MinIO

**Estado en el Tech Radar:** 🟢 Adoptar
**Categoría:** Plataformas & Infraestructura
**Última revisión:** 2026-09-20

## Contexto

El microservicio de ingesta y procesamiento de datos (Go, ver
[lenguajes-frameworks/go.md](../lenguajes-frameworks/go.md)) necesita un
almacenamiento tipo *lakehouse* para los datos procesados, además del
storage estructurado que ya cubren las bases de datos relacionales (ver
[bases-de-datos.md](./bases-de-datos.md)). On-premise no hay acceso nativo
a un servicio de object storage tipo S3 gestionado por un proveedor cloud.

## Decisión

MinIO se adopta como almacenamiento de objetos compatible con S3,
corriendo dentro del cluster K3s (namespace `storage`), expuesto en los
puertos `9000` (API) y `9801` (consola).

## Alternativas consideradas

| Opción | Por qué no |
|---|---|
| **Amazon S3 u otro object storage cloud** | Requeriría conectividad hacia un proveedor cloud desde infraestructura on-premise, contradiciendo la etapa actual del proyecto (ver [on-premise.md](./on-premise.md)); además introduce costo variable y dependencia externa antes de necesitarla. |
| **Almacenamiento en disco local sin capa de objetos (solo Local Volumes)** | Los `Local Volumes` ya se usan para storage de bases de datos (ver [kubernetes.md](./kubernetes.md)), pero no ofrecen la interfaz S3 que necesita un pipeline de datos tipo lakehouse (versionado de objetos, acceso por API estándar). |

## Justificación para Fixia

1. **API compatible con S3.** Permite usar el ecosistema estándar de
   herramientas de datos (clientes S3, librerías de lakehouse) sin
   atarse a una API propietaria, y facilita una futura migración a un
   object storage cloud real sin reescribir el código de acceso a datos.
2. **Encaja con la arquitectura on-premise actual.** Corre como parte del
   mismo cluster K3s, sin requerir infraestructura adicional fuera de la
   red interna (ver [on-premise.md](./on-premise.md)).
3. **Pieza central del pipeline de ingesta.** MinIO es el destino final
   de los datos que Kafka/Debezium capturan y que el microservicio de
   Procesamiento en Go transforma (ver
   [kafka.md](./kafka.md) y [debezium-cdc.md](./debezium-cdc.md)).

## Cómo se usa en el proyecto

- Namespace `storage` dentro del cluster K3s.
- Puerto `9000` para la API S3, puerto `9801` para la consola web
  administrativa.
- Credenciales de acceso gestionadas vía HashiCorp Vault (ver
  [vault.md](./vault.md)), no hardcodeadas en configuración.

## Trade-offs / riesgos

- MinIO on-premise no tiene la durabilidad/redundancia geográfica de un
  proveedor cloud; el riesgo de pérdida de datos depende enteramente de
  la política de backups del cluster (ver checklist de
  [09-infraestructura-devops](../../09-infraestructura-devops/)).
- Requiere que el equipo de DevOps opere y monitoree un componente de
  storage adicional.

## Cuándo reconsiderar

Si el volumen de datos del lakehouse crece más allá de lo que la
infraestructura on-premise puede sostener con garantías aceptables de
durabilidad, evaluar migrar a un object storage cloud gestionado,
aprovechando la compatibilidad de API S3 para minimizar el cambio.
