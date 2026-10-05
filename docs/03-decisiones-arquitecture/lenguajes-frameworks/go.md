# Go

**Estado en el Tech Radar:** 🟡 Probar
**Categoría:** Lenguajes & Frameworks
**Última revisión:** 2026-08-24

## Contexto

Fixia necesita un microservicio de **ingesta y procesamiento de datos**:
recibe datos de forma continua (por ejemplo, eventos de ubicación de
proveedores, actividad de búsqueda, métricas de uso) y debe procesarlos
con alto throughput y baja latencia, muchas veces en paralelo. Este tipo
de carga es distinto a los dos perfiles ya cubiertos por el criterio de
selección del proyecto (ver
[README.md](./README.md#criterio-de-selección-por-tipo-de-carga)):

- No es principalmente I/O-bound de orquestación de APIs (el perfil de
  Node.js/TypeScript).
- No es principalmente cálculo geoespacial/analítico batch (el perfil de
  Python).

Es, específicamente, **procesamiento concurrente de alto volumen**, donde
el costo de una máquina virtual con recolector de basura pesado (Node.js)
o un intérprete (Python) puede ser una limitante real de rendimiento.

## Decisión

Go se adopta, en estado **Probar**, para el microservicio de ingesta y
procesamiento de datos, como un cuarto perfil de carga dentro del criterio
de selección de lenguajes de Fixia.

## Alternativas consideradas

| Opción | Por qué no |
|---|---|
| **Node.js (el default general)** | El modelo de un solo hilo con event loop de Node.js no aprovecha múltiples núcleos de forma nativa para procesamiento paralelo intensivo; escalar este tipo de carga en Node.js implicaría múltiples procesos coordinados externamente, más complejo que la concurrencia nativa de Go. |
| **Python (ya adoptado para geoespacial)** | Aunque Python tiene buen ecosistema de datos, su rendimiento en procesamiento concurrente de alto volumen es sensiblemente menor que Go, y el GIL (Global Interpreter Lock) limita el paralelismo real dentro de un mismo proceso. Válido para análisis geoespacial más pesado en cálculo puntual, no para ingesta continua de alto throughput. |
| **Java (Spring Boot / alternativas JVM)** | Técnicamente capaz de manejar este tipo de carga (buen soporte de concurrencia en la JVM), pero con mayor consumo de memoria, tiempo de arranque más lento, y un ecosistema de build/despliegue más pesado que Go para un servicio que se beneficia de binarios livianos y arranque rápido (relevante si este servicio necesita escalar horizontalmente con frecuencia). |

## Justificación para Fixia

1. **Concurrencia nativa y liviana (goroutines).** El modelo de
   concurrencia de Go está diseñado exactamente para el caso de "recibir
   muchos eventos en paralelo y procesarlos sin bloquear", sin la
   sobrecarga de hilos del sistema operativo ni la complejidad de callbacks
   o async/await para este volumen específico.
2. **Binarios compilados, sin runtime pesado.** Go compila a un binario
   único y liviano, lo que encaja bien con la estrategia de
   contenerización de Fixia (ver
   [plataforma-infraestructura/docker.md](../plataforma-infraestructura/docker.md)):
   imágenes Docker más chicas y arranque más rápido que un contenedor con
   runtime de Node.js o Python, relevante si este microservicio necesita
   escalar horizontalmente ante picos de ingesta.
3. **Rendimiento predecible bajo carga sostenida.** A diferencia de un
   entorno con recolector de basura más agresivo o un intérprete, Go
   ofrece un perfil de rendimiento más consistente para un servicio que
   corre de forma continua procesando flujo de datos, no solo respondiendo
   requests puntuales.
4. **No reemplaza el criterio ya definido, lo completa.** Este microservicio
   no compite con el rol de Node.js (orquestación de APIs) ni con el de
   Python (cálculo geoespacial/analítico); ocupa un cuarto perfil de carga
   que no existía en el catálogo hasta ahora: ingesta/procesamiento de
   datos de alto volumen.

## Por qué está en "Probar" y no en "Adoptar"

Es el primer microservicio en Go del proyecto. Antes de considerarlo
default para todo el perfil de "ingesta y procesamiento de datos de alto
volumen", se espera validar en producción:

- Que el equipo puede mantenerlo de forma sostenida (curva de aprendizaje
  de un lenguaje nuevo en el stack).
- Que el pipeline de CI/CD y el proceso de bootstrap de microservicios
  (pensado originalmente para Node.js/Python) se adapta sin fricción a
  Go.

## Cómo se usa en el proyecto

- Aplica, por ahora, al microservicio de ingesta y procesamiento de datos
  (ver convención de nombres en
  [08-estructura-microservicios](../../08-estructura-microservicios/), ej.
  `fixia-msv-ingesta` o el nombre de dominio que corresponda).
- Sigue la misma estructura de Clean Architecture que el resto de los
  microservicios (`domain/`, `application/`, `infrastructure/`,
  `interfaces/`), adaptada a las convenciones idiomáticas de Go (paquetes
  en vez de carpetas estrictamente anidadas, por ejemplo), sin abandonar
  la regla de dependencia hacia adentro.
- Linter y formateo: `gofmt`/`golangci-lint` como estándar obligatorio,
  equivalente a ESLint/Prettier en Node.js o PEP8 en Python.
- El contrato de API expuesto (si este microservicio expone una API,
  además de consumir eventos) sigue el mismo estándar JSON del resto del
  sistema (ver [07-calidad-arquitectura](../../07-calidad-arquitectura/)).
- Se integra con la infraestructura de eventos ya definida en
  [tecnicas-metodos/event-driven.md](../tecnicas-metodos/event-driven.md)
  si la ingesta de datos se alimenta de eventos de otros microservicios
  (ej. `ubicacion_actualizada`).

## Trade-offs / riesgos

- **Segundo/tercer lenguaje adicional en el stack** (sumado a Node.js y
  Python): más superficie de mantenimiento, otro set de herramientas de
  linting/testing/CI, y menos desarrolladores del equipo con experiencia
  previa en Go que en Node.js.
- Ecosistema de librerías más chico que Node.js o Python para casos de
  uso genéricos (aunque suficiente y maduro para lo que este
  microservicio necesita: I/O concurrente y procesamiento de datos).
- Riesgo de que "un lenguaje por cada necesidad puntual" derive en
  fragmentación del stack si no se es estricto con el criterio del
  [README.md](./README.md); Go se adopta para **este perfil de carga
  específico**, no como opción general adicional.

## Cuándo reconsiderar

- Pasa a **Adoptar** (para el perfil "ingesta/procesamiento de datos de
  alto volumen", no en general) si, tras un ciclo de varios sprints en
  producción, demuestra estabilidad y el equipo confirma capacidad de
  mantenimiento sostenida — mismo camino que siguió Python (ver
  [python-fastapi.md](./python-fastapi.md)).
- Se reconsideraría el uso de Go si aparece un requerimiento de negocio
  que el microservicio actual no puede resolver razonablemente, o si el
  costo de mantener un lenguaje adicional en el equipo supera el
  beneficio de rendimiento obtenido.