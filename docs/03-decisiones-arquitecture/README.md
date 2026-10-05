# 03. Decisiones de Arquitectura

Este capítulo es el corazón de la wiki: cada tecnología, lenguaje,
herramienta o patrón que aparece en el [Tech Radar](../02-tech-radar/)
tiene aquí una página propia que explica **por qué** se eligió, no solo
cómo se usa.

Toda página de este capítulo sigue la
[plantilla de decisión](../00-inicio/plantilla-decision.md).

## Subcarpetas (alineadas a los cuadrantes del Tech Radar)

| Subcarpeta | Cuadrante del radar | Contenido |
|---|---|---|
| [lenguajes-frameworks/](./lenguajes-frameworks/) | Lenguajes & Frameworks | Node.js, TypeScript, Python, Java, .NET/C#, React, frameworks backend |
| [plataformas-infraestructura/](./plataformas-infraestructura/) | Plataformas & Infrastructure | On-Premise, Docker, K3s/Kubernetes, Terraform, Google Cloud |
| [herramientas/](./herramientas/) | Tools | Git/GitHub, Jira, SonarQube, VS Code, Figma, Slack |
| [tecnicas-metodos/](./tecnicas-metodos/) | Techniques & Methods | Clean Architecture, DDD, CQRS, TDD, Event-Driven, mTLS |

## Cómo se conecta con el resto de la wiki

Este capítulo explica **por qué**. Los capítulos operativos (05 a 12)
explican **cómo se aplica en el día a día**. Por ejemplo:

- *Por qué* elegimos Docker y K3s → `plataformas-infraestructura/docker.md`
- *Cómo* se conteneriza y despliega un microservicio → capítulo
  [09-infraestructura-devops](../09-infraestructura-devops/)

- *Por qué* elegimos GitHub Actions → `herramientas/github-actions.md`
- *Cómo* se configuran los pipelines → capítulo
  [06-cicd-ambientes](../06-cicd-ambientes/)

Si estás por tomar una decisión técnica y no encontrás una página acá,
seguí el proceso de RFC de tecnología en
[CONTRIBUTING.md](../CONTRIBUTING.md) antes de adoptarla directamente en
un microservicio en producción.