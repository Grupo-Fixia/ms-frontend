# ☸️ Configuración e Infraestructura K3s Cluster

## 1. Objetivo
Definir la arquitectura de orquestación de contenedores ligera con **K3s** para desplegar el ecosistema de microservicios de **Fixia** en alta disponibilidad y bajo consumo de recursos.

---

## 2. Arquitectura de Red y Nodos

```text
               +----------------------------------+
               |        Cloudflare / Edge DNS     |
               +----------------+-----------------+
                                |
               +----------------v-----------------+
               |  Traefik Ingress Controller      |
               +----------------+-----------------+
                                |
     +--------------------------+--------------------------+
     |                                                     |
+----v-----------------------+             +---------------v---------------+
| Node 1 (Control Plane)     |             | Node 2 (Worker Node)          |
|  - fixia-auth-service      |             |  - fixia-order-service        |
|  - fixia-user-service      |             |  - fixia-payment-service      |
+----------------------------+             +-------------------------------+
```

---

## 3. Especificaciones de Despliegue (Kubernetes Manifests)

### Requerimientos Estándar por Deployment:
- **Resource Requests & Limits:** Definir explícitamente CPU y Memoria para evitar starvation.
- **Probes:** Configurar `livenessProbe` y `readinessProbe` apuntando a los endpoints de Actuator/Health.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fixia-order-service
  namespace: fixia-prod
spec:
  replicas: 2
  selector:
    matchLabels:
      app: fixia-order-service
  template:
    metadata:
      labels:
        app: fixia-order-service
    spec:
      containers:
      - name: order-service
        image: fixia/fixia-order-service:1.0.0
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        ports:
        - containerPort: 8083
        livenessProbe:
          httpGet:
            path: /actuator/health/liveness
            port: 8083
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /actuator/health/readiness
            port: 8083
          initialDelaySeconds: 15
          periodSeconds: 5
```
