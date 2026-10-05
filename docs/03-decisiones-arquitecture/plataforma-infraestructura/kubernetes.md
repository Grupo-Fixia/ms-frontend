# Kubernetes (K3s)

**Estado en el Tech Radar:** 🟢 Adoptar (actualizado — antes 🟡 Probar)
**Categoría:** Plataformas & Infraestructura
**Última revisión:** 2026-09-20

## Contexto

Esta página reemplaza a la evaluación inicial de K3s. Con el diagrama de
infraestructura del MVP (2026-09-20), K3s dejó de ser una prueba acotada
y pasó a ser la plataforma de orquestación **confirmada y en
implementación** para todo el sistema.

## Decisión

K3s corre sobre 8 VMs on-premise (red interna `192.168.1.0/24`):

| Nodo | Rol | Specs |
|---|---|---|
| VM-01 | Control Plane (Master) | 6 GB RAM / 4 vCPU / 250 GB disco |
| VM-02, VM-03, VM-04 | Workers (Test) | mismas specs |
| VM-05, VM-06, VM-07, VM-08 | Workers (Prod) | mismas specs |

Todas las VMs corren Ubuntu, en una misma red interna, sin rack ni UPS
dedicado (características documentadas explícitamente como limitación
conocida del MVP, no como estándar deseado a futuro).

Red del CNI del cluster: `10.42.0.0/16`.

## Por qué pasa de "Probar" a "Adoptar"

Los criterios que la página original fijaba para subir de anillo ya se
cumplieron: el número de microservicios previstos (ver
[08-estructura-microservicios](../../08-estructura-microservicios/))
justifica la orquestación, y el equipo ya definió la topología completa
de namespaces, no solo un piloto aislado.

## Organización por namespaces

| Namespace | Contenido |
|---|---|
| `ingress` | Traefik (ver [traefik.md](./traefik.md)) |
| `microservicios` | Los microservicios de negocio (ver [08-estructura-microservicios](../../08-estructura-microservicios/)) |
| `messaging` | Kafka en modo KRaft (ver [kafka.md](./kafka.md)) |
| `storage` | MinIO (ver [minio.md](./minio.md)) |
| `secrets` | HashiCorp Vault (ver [vault.md](./vault.md)) |
| `cdc` | Debezium Connect (ver [debezium-cdc.md](./debezium-cdc.md)) |
| `observability` | Prometheus, Grafana, Loki, Alertmanager (ver [observabilidad.md](./observabilidad.md)) |

Los servicios de datos (PostgreSQL por microservicio + MongoDB, ver
[bases-de-datos.md](./bases-de-datos.md)) corren dentro del cluster,
sobre volúmenes locales (`Local Volumes`), no en un servicio de storage
gestionado externo — coherente con la etapa on-premise actual (ver
[on-premise.md](./on-premise.md)).

## Separación Test / Prod dentro del mismo cluster

A diferencia de un esquema con clusters físicamente separados por
ambiente, Fixia separa Test y Prod mediante **worker pools distintos
dentro del mismo cluster K3s** (3 workers Test, 4 workers Prod). Esto es
una decisión de costo para el MVP: un solo control plane que administrar,
a cambio de un aislamiento más débil entre ambientes que el que daría un
cluster separado.

## Trade-offs / riesgos (actualizado)

- **Aislamiento Test/Prod más débil de lo ideal**, al compartir el mismo
  control plane y la misma red interna. Un incidente de recursos
  (ej. un pod de Test consumiendo CPU/memoria de forma descontrolada)
  podría, en teoría, afectar a Prod si no hay límites de recursos
  (`ResourceQuota`/`LimitRange`) bien configurados por namespace.
- **Sin rack ni UPS dedicado**: un corte de energía afecta control plane
  y los 7 workers a la vez — no hay redundancia física real todavía.
- Se mantienen los riesgos ya documentados originalmente (curva de
  aprendizaje del equipo, punto único de falla si el clúster no se
  monitorea).

## Cuándo reconsiderar

- Separar Test y Prod en clusters físicamente distintos si el negocio
  crece lo suficiente como para justificar el costo de un segundo
  control plane.
- Sumar redundancia física (rack, UPS, réplicas del control plane) antes
  de considerar esta infraestructura apta para más que un MVP.
