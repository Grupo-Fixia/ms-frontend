# Google Cloud

**Estado en el Tech Radar:** 🟠 Evaluar
**Categoría:** Plataformas & Infraestructura
**Última revisión:** 2026-08-24

## Contexto

Fixia opera on-premise hoy (ver [on-premise.md](./on-premise.md)), pero el
crecimiento esperado del negocio — más zonas geográficas, picos de demanda
variables, necesidad de autoescalado — hace probable una migración a nube
en el mediano plazo. Antes de comprometerse con un proveedor, se evalúa
Google Cloud Platform (GCP) como candidato.

## Decisión

GCP está en estado de **Evaluar**: no hay una decisión tomada todavía.
Esta página documenta por qué es el candidato principal a evaluar primero,
no una confirmación de adopción.

## Alternativas consideradas

| Opción | Estado de la evaluación |
|---|---|
| **AWS** | Candidato válido, mayor cuota de mercado y catálogo de servicios más amplio. Pendiente de evaluación formal con el mismo criterio que GCP. |
| **Azure** | Candidato válido, especialmente si en el futuro hay integraciones con servicios Microsoft. Pendiente de evaluación formal. |
| **Google Cloud** | Candidato principal a evaluar primero (ver justificación abajo). |
| **Multi-cloud desde el inicio** | Descartado por ahora: añade complejidad operativa significativa sin un beneficio claro para el tamaño actual del equipo. Gracias a Terraform y Docker (ver páginas relacionadas), la decisión de proveedor no compromete la portabilidad futura de todos modos. |

## Justificación para evaluar Google Cloud primero

1. **Buen soporte de servicios geoespaciales**, relevante para los
   dominios de Geolocalización y Búsqueda/Matching (ver
   [01-contexto-proyecto/mapa-dominios-negocio.md](../../01-contexto-proyecto/mapa-dominios-negocio.md)),
   que son el corazón técnico de Fixia.
2. **Compatibilidad directa con la estrategia de K3s/Kubernetes.**
   Google es el origen de Kubernetes y GKE (Kubernetes gestionado en GCP)
   tiene una curva de migración natural desde K3s (ver
   [k3s-kubernetes.md](./k3s-kubernetes.md)), reduciendo el riesgo técnico
   de la migración si se confirma esta ruta.
3. **Terraform tiene soporte de primer nivel para GCP**, consistente con
   la decisión ya tomada en [terraform.md](./terraform.md).

Importante: esta justificación es para **priorizar la evaluación**, no
para adoptar. La decisión final de proveedor debe compararse también
contra AWS y Azure con costos reales y una prueba piloto, como indica el
checklist de migración.

## Cómo se usa en el proyecto (mientras está en Evaluar)

- No se despliega ningún componente de producción en GCP todavía.
- Se permite una prueba piloto acotada (ver checklist en
  [09-infraestructura-devops](../../09-infraestructura-devops/)) con un
  servicio no crítico, para validar costos y curva de adopción real.
- Cualquier prueba debe documentarse como una actualización a esta misma
  página, con datos concretos (costo estimado, tiempo de setup,
  fricciones encontradas).

## Trade-offs / riesgos

- Costo variable más alto que on-premise en el corto plazo si el tráfico
  no lo justifica todavía.
- Riesgo de decidir un proveedor sin haber comparado formalmente
  alternativas (mitigado exigiendo evaluación explícita antes de mover
  esta tecnología a "Probar" o "Adoptar").

## Cuándo reconsiderar / avanzar

- Pasa a **Probar** cuando exista una prueba piloto real con un servicio
  no crítico, con costos y aprendizajes documentados.
- Pasa a **Adoptar** solo después de una comparación formal contra AWS y
  Azure, siguiendo el checklist completo de
  [09-infraestructura-devops/preparacion-migracion.md](../../09-infraestructura-devops/).