# Chat prototipo (simulación) — GC-406 / GC-431 / GC-432

Pantalla de **demostración** de cómo sería la comunicación dentro de Fixia.
**No es mensajería real** y no satisface los requisitos RF-038 a RF-043; esa
limitación está documentada como excepción de alcance en GC-415 y debe
declararse en la Sprint Review.

## Qué hace

- Permite escribir mensajes y ver respuestas simuladas, fijas y reproducibles
  (se repiten en ciclo; los textos están en `domain/simulated_replies.dart`).
- Muestra un aviso permanente de **SIMULACIÓN**: lo escrito no se envía a
  ninguna cuenta y nadie lo recibe.
- Explica que no se guarda nada: al salir de la pantalla, reiniciar o recargar
  la página la conversación desaparece.
- No muestra indicadores de «entregado», «leído» ni «guardado».
- No incluye personas, servicios, precios ni conversaciones: solo lo que
  escribe quien usa la demo y respuestas genéricas.

## Qué NO hace

- No llama a ninguna API, no publica eventos ni usa Kafka.
- No guarda nada (ni en el servidor ni en el navegador).
- No lee ni modifica solicitudes, postulaciones, precios, cotizaciones,
  contratación ni estados.

## Dónde está

```
lib/features/chat_prototype/
├── domain/        # SimulatedMessage, SimulatedReplies (textos fijos)
├── application/   # SimulatedChatController (estado en memoria)
└── presentation/  # ChatPrototypePage
```

Sin capa `infrastructure/` a propósito: no hay nada que persistir ni consumir.
La carpeta no importa `http`, `AuthorizedHttp`, `ApiConfig`, la sesión ni
otras funcionalidades; una prueba (`chat_prototype_page_test.dart`, grupo de
aislamiento) lo verifica leyendo los `import`.

## Cómo se llega

Ruta `/demo/chat` (`AppRoutes.chatPrototype`), solo con sesión iniciada:

- Cliente: botón «Abrir chat» de su inicio.
- Técnico: botón «Chat de demostración» de su inicio.

## Pruebas

```bash
flutter test test/features/chat_prototype test/chat_prototype_navigation_test.dart
```
