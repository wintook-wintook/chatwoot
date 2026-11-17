---
key: vista_bandeja
title: Vista de bandeja (tus avisos de conversaciones)
areas: [conversations]
keywords: [vista de bandeja, bandeja de entrada, avisos, notificaciones, notificacion, marcar como leido, marcar como no leido, marcar todo como leido, eliminar notificacion, eliminar todo, eliminar todo lo leido, posponer notificacion, mencionado, asignada, mensaje nuevo, mostrar, pospuesto, leido, mas reciente, mas antiguo]
pages: [inbox_view, conversations, conversation]
sources:
  - app/javascript/dashboard/routes/dashboard/inbox/**/*.vue
  - app/javascript/dashboard/routes/dashboard/inbox/routes.js
  - app/javascript/dashboard/composables/commands/useInboxHotKeys.js
  - app/javascript/dashboard/i18n/locale/es/inbox.json
reviewed: 2026-11-14
---
## Para qué sirve
Junta en una sola lista tus avisos de conversaciones: cuando te asignan una, cuando te mencionan, cuando llega un mensaje nuevo en una tuya o en una donde participas, y otros. Al abrir un aviso ves su conversación al lado y la contestas ahí mismo.

## Dónde está
Conversaciones › Vista de bandeja, en el menú de la izquierda. Solo sale si tu empresa la tiene encendida. La pantalla se llama «Bandeja de entrada».

## Cómo se hace
### Ver y abrir tus avisos
1. Entra a Conversaciones › Vista de bandeja.
2. Cada aviso dice qué pasó, por ejemplo «Has sido mencionado en una conversación», «Se te ha asignado una conversación», «Nuevo mensaje en una conversación asignada», «Nuevo mensaje en una conversación en la que participas» o «Nueva conversación creada».
3. Haz clic en un aviso: se marca como leído y a la derecha se abre su conversación, con su caja para responder.
4. Arriba de la conversación, las flechas te pasan al aviso anterior o al siguiente.

### Elegir qué se ve y en qué orden
1. Junto al título pulsa «Mostrar».
2. Prende o apaga «Pospuesto» y «Leído» para ver también esos avisos.
3. En «Ordenar» elige «Más reciente» o «Más antiguo».

### Posponer o eliminar un aviso
1. Con el aviso abierto, arriba pulsa «Posponer notificación» y elige hasta cuándo: dentro de una hora, mañana, la próxima semana, el próximo mes o «Personalizado...».
2. «Eliminar notificación» lo quita de la lista (la conversación no se borra).
3. También con clic derecho sobre un aviso de la lista: «Marcar como leído» o «Marcar como no leído» y «Eliminar».

### Limpiar todos los avisos
1. Pulsa el ícono de bandeja, arriba a la derecha de la lista.
2. Elige «Marcar todo como leído», «Eliminar todo» o «Eliminar todo lo leído».

## Límites
- Aquí solo se manejan avisos: asignar, etiquetar o resolver se hace en la conversación que se abre al lado, igual que en Todas las Conversaciones.
- Eliminar un aviso no borra ni resuelve la conversación.

## Dudas frecuentes
- No veo «Vista de bandeja»: tu empresa no la tiene encendida. Para lo que te mencionan, usa Conversaciones › Menciones.
- La lista dice «Sin notificaciones»: no tienes avisos por ver; revisa en «Mostrar» si los tienes ocultos por estar leídos o pospuestos. Mientras no abras ninguno, a la derecha sale «Notificaciones de todas las bandejas de entrada suscritas».

## Quién puede
Todos los usuarios que entran a Conversaciones. Cada quien ve solo sus propios avisos.
