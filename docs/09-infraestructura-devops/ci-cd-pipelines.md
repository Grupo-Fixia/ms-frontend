# 🚀 Pipelines de CI/CD (GitHub Actions)

## 1. Objetivo
Automatizar las fases de integración continua (linting, tests, análisis de código) y despliegue continuo en el clúster de K3s de **Fixia**.

---

## 2. Estructura del Pipeline Integrado

```text
[ Git Push / PR ] ➡️ [ Linting & Static Analysis ] ➡️ [ Unit & Integration Tests ]
                                                                 |
[ K3s Deployment ] 🏃 [ Push Docker Registry ] ⬅️ [ Build Docker Image ]
```

---

## 3. Flujo Integrado de CI/CD (`.github/workflows/deploy.yml`)

```yaml
name: CI/CD Pipeline - Fixia Microservices

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  code-quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up JDK 21 / Python 3.12
        uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'
      - name: Run Tests
        run: ./mvnw test  # o pytest para servicios Python

  build-and-push:
    needs: code-quality
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Log in to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}
      - name: Build and Push Docker Image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: fixia/${{ github.event.repository.name }}:${{ github.sha }}

  deploy-k3s:
    needs: build-and-push
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to K3s Cluster
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.K3S_HOST }}
          username: ${{ secrets.K3S_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            kubectl set image deployment/${{ github.event.repository.name }} ${{ github.event.repository.name }}=fixia/${{ github.event.repository.name }}:${{ github.sha }} -n fixia-prod
```
