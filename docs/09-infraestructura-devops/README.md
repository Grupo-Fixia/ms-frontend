# 🛠️ Módulo 09: Infraestructura, DevOps y Observabilidad

## 📌 Descripción del Módulo

Este módulo consolida las especificaciones técnicas, arquitecturas de despliegue, estándares de contenerización, automatización de CI/CD y observabilidad para todo el ecosistema de microservicios de **Fixia**.

El objetivo es proveer una base de infraestructura resiliente, escalable y reproducible basada en contenedores Docker y orquestación con K3s.

---

## 🗂️ Contenido de la Sección

| Archivo | Descripción |
| :--- | :--- |
| **[`docker-y-microservicios.md`](./docker-y-microservicios.md)** | Estándares de contenerización, plantillas de `Dockerfile` multi-stage para Java 21 (Spring Boot) y Python 3.12 (FastAPI), y buenas prácticas de seguridad. |
| **[`k3s-cluster-setup.md`](./k3s-cluster-setup.md)** | Configuración del clúster K3s, topología de nodos, controladores Ingress (Traefik) y especificación de Manifiestos YAML con probes de salud. |
| **[`ci-cd-pipelines.md`](./ci-cd-pipelines.md)** | Flujos de trabajo automatizados con **GitHub Actions** para pruebas, compilación de imágenes y despliegues continuos en K3s. |
| **[`monitoreo-logs-observabilidad.md`](./monitoreo-logs-observabilidad.md)** | Arquitectura de observabilidad centralizada con Prometheus, Grafana, Loki y Jaeger, incluyendo estándares para formato JSON y trazabilidad distribuida. |

---

## 🚀 Guía Rápida de Despliegue Local

### Prerrequisitos
- Docker Engine `v24+` y Docker Compose `v2.20+`
- Cluster K3s local (o Minikube/k3d)
- `kubectl` configurado

### Comandos Frecuentes

1. **Construir imagen localmente (Ejemplo: Java Service):**
   ```bash
   docker build -t fixia/fixia-order-service:dev -f docker/Dockerfile .
   ```

2. **Aplicar manifiestos en el clúster local:**
   ```bash
   kubectl apply -f k8s/ -n fixia-dev
   ```

3. **Verificar logs estructurados:**
   ```bash
   kubectl logs -l app=fixia-order-service -n fixia-dev -f
