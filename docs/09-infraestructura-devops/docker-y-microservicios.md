# 🐳 Docker y Estrategia de Contenedores

## 1. Objetivo
Establecer las directrices de containerización para los microservicios de **Fixia**, garantizando entornos homogéneos entre desarrollo, staging y producción mediante compilar imágenes ligeras, seguras y optimizadas.

---

## 2. Estándares de Dockerfile (Multi-stage Builds)

Todos los microservicios deben implementar builds de múltiples etapas (*multi-stage*) para minimizar la superficie de ataque y el tamaño final de la imagen.

### A. Plantilla Estándar para Java 21 (Spring Boot)
```dockerfile
# Etapa 1: Build
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /app
COPY .mvn/ .mvn
COPY mvnw pom.xml ./
RUN ./mvnw dependency:go-offline
COPY src ./src
RUN ./mvnw clean package -DskipTests

# Etapa 2: Runtime
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
RUN addgroup -S fixia && adduser -S fixia -G fixia
USER fixia
COPY --from=builder /app/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

### B. Plantilla Estándar para Python 3.12 (FastAPI)
```dockerfile
# Etapa 1: Build
FROM python:3.12-slim AS builder
WORKDIR /app
RUN python -m venv /venv
ENV PATH="/venv/bin:$PATH"
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Etapa 2: Runtime
FROM python:3.12-slim
WORKDIR /app
RUN useradd -m fixiauser
USER fixiauser
COPY --from=builder /venv /venv
COPY app/ ./app
ENV PATH="/venv/bin:$PATH"
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

## 3. Principios de Contenerización
- **Principio de Menor Privilegio:** Ningún contenedor debe ejecutarse como `root`.
- **Manejo de Secretos:** Nunca incluir `.env`, claves de API ni certificados en las imágenes.
- **Etiquetado (Tagging):** Formato `fixia/<servicio>:<commit-hash>` y `fixia/<servicio>:vX.Y.Z` para releases.
