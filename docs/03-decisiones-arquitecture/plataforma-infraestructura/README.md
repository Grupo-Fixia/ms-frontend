# Plataformas & Infraestructura

Decisiones sobre **dónde y cómo se despliegan** los microservicios de
Fixia: hoy on-premise, con un camino explícito de preparación hacia nube.

| Tecnología | Estado en el radar | Página |
|---|---|---|
| On-Premise | 🟣 Retener (estado actual) | [on-premise.md](./on-premise.md) |
| Docker | 🟢 Adoptar | [docker.md](./docker.md) |
| K3s / Kubernetes | 🟡 Probar | [k3s-kubernetes.md](./k3s-kubernetes.md) |
| Terraform | 🟢 Adoptar | [terraform.md](./terraform.md) |
| Google Cloud | 🟠 Evaluar | [google-cloud.md](./google-cloud.md) |

## Hilo conductor de estas decisiones

Ninguna de estas páginas se puede leer de forma aislada: todas responden a
la misma tensión de fondo, documentada en detalle en cada una:

> Fixia opera hoy **on-premise** por costo y control, pero el crecimiento
> esperado (más zonas geográficas, más proveedores, picos de demanda
> variables por región) hace muy probable una migración a nube en el
> mediano plazo. Cada decisión de infraestructura se evalúa también por
> qué tan fácil hace (o difícil) esa futura migración.

Esto explica, por ejemplo, por qué se elige Docker + Terraform desde el
día uno (portables entre on-premise y nube) y por qué K3s está en
"Probar" y no en "Adoptar" todavía: se está validando que el overhead de
Kubernetes se justifique con el número actual de microservicios antes de
comprometerse por completo.