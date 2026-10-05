# Terraform

**Estado en el Tech Radar:** 🟢 Adoptar
**Categoría:** Plataformas & Infraestructura
**Última revisión:** 2026-08-24

## Contexto

Fixia opera on-premise hoy (ver [on-premise.md](./on-premise.md)) con
planes de eventual migración a nube. Toda infraestructura (servidores,
redes, contenedores) necesita definirse de forma reproducible y
versionada, en vez de configurarse manualmente servidor por servidor.

## Decisión

Toda la infraestructura de Fixia se define como código usando
**Terraform**, complementado con **Ansible** para configuración de
servidores y despliegues.

## Alternativas consideradas

| Opción | Por qué no |
|---|---|
| **Configuración manual de servidores** | No reproducible, no versionada, alto riesgo de "server drift" (el servidor real termina distinto de lo documentado). Inviable para una migración futura a nube. |
| **Ansible como única herramienta (sin Terraform)** | Ansible es excelente para configuración de servidores existentes, pero no está pensado como herramienta principal de aprovisionamiento declarativo de infraestructura (redes, recursos cloud) de la forma en que lo está Terraform. Se usan ambas, cada una en su rol. |
| **Herramientas nativas de un solo proveedor cloud (ej. CloudFormation)** | Atarían a Fixia a un proveedor específico antes incluso de decidir a cuál migrar. Terraform es agnóstico de proveedor: mismo lenguaje (HCL) para on-premise (vía proveedores como vSphere) y para AWS/Azure/GCP a futuro. |

## Justificación para Fixia

1. **Agnóstico de proveedor — la pieza clave de la estrategia de
   migración.** Terraform permite describir la infraestructura on-premise
   actual y, el día de mañana, describir infraestructura en GCP (ver
   [google-cloud.md](./google-cloud.md)) con la misma herramienta y
   lenguaje, sin reescribir procesos ni reentrenar al equipo de DevOps.
2. **Reproducibilidad para checklist de bootstrap.** El checklist de
   bootstrap de un microservicio nuevo (ver
   [08-estructura-microservicios](../../08-estructura-microservicios/))
   exige que la infraestructura necesaria (base de datos propia, red,
   etc.) pueda crearse de forma consistente. Terraform hace esto posible
   sin intervención manual repetida.
3. **Versionado igual que el código de negocio.** Toda la infraestructura
   se versiona en Git, siguiendo el mismo Git Workflow que el resto de
   los microservicios (ver
   [05-git-control-versiones](../../05-git-control-versiones/)), lo que
   permite Pull Requests, revisión y rollback de cambios de
   infraestructura igual que de código de aplicación.

## Cómo se usa en el proyecto

- El código de infraestructura vive en un repositorio propio, tipo
  `fixia-infra-terraform` (ver convención de nombres en
  [08-estructura-microservicios](../../08-estructura-microservicios/)).
- Terraform se usa para aprovisionar: redes, servidores/VMs on-premise
  (vía proveedor vSphere o equivalente), y a futuro recursos cloud.
- Ansible se usa para configuración posterior de esos servidores
  (paquetes, usuarios, hardening) y para despliegues específicos.
- Cambios de infraestructura pasan por Pull Request, igual que cualquier
  otro cambio de código (ver
  [05-git-control-versiones](../../05-git-control-versiones/)).

## Trade-offs / riesgos

- Curva de aprendizaje de HCL (el lenguaje de Terraform) para quien no lo
  conozca.
- El estado de Terraform (`.tfstate`) es un componente crítico que debe
  gestionarse con cuidado (almacenamiento remoto seguro, bloqueo
  concurrente) para evitar corrupción o pérdida.

## Cuándo reconsiderar

Esta es una decisión de base con baja probabilidad de cambio. Se
reconsideraría solo si Fixia decidiera atarse permanentemente a un único
proveedor cloud y aprovechar herramientas nativas muy específicas de ese
proveedor — escenario que hoy no está planeado, dado que la estrategia
explícita es mantener portabilidad.