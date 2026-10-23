# Reporte de funciones (no técnico) — Tipos de Caso

> Redactado para enviar por WhatsApp. Resume, en lenguaje sencillo, lo entregado
> en la rama `feat/tickets` sobre Tipos de Caso y el menú del módulo.
> Fecha: 2026-07-31.

---

📋 *Novedades del módulo de Tickets*

Hola 👋 Esto es lo que quedó listo. En esta etapa el trabajo se enfocó en *dejar funcionando* la parte de fondo de los Tipos de Caso (que todo opere bien). La pantalla todavía *no es muy interactiva*, pero ya estamos mejorándola 🛠️.

🗂️ *Columnas del tablero según cada Tipo de Caso*
Ahora cada tipo de caso (soporte, ventas, incidencias…) puede tener *sus propias columnas* en el tablero, en lugar de unas fijas para todos.

🆕 *Se arman solas al crear un tipo de caso:*
Cuando creas un tipo nuevo, el sistema le genera las columnas por defecto automáticamente, y elige el modelo según cómo esté configurada la cuenta:
　• Si tienes activado el modo *ITIL* 👉 le pone el flujo completo (Nuevo · Asignado · Diagnóstico · En proceso · En espera · Resuelto · Cerrado).
　• Si *no* está activado 👉 le pone un flujo *simple* y directo (Nuevo · En proceso · En espera · Resuelto · Cerrado).
Así cada tipo arranca listo para usar, sin tener que armar nada a mano.

✅ Los tipos que ya existían también recibieron sus columnas, sin rehacer nada.
✅ Puedes ajustar nombre, color y qué estados agrupa cada columna.
✅ Arrastras las tarjetas entre columnas y el estado del ticket se actualiza solo.

📚 *Menú lateral de Tickets más ordenado*
🔹 *Arriba, lo del día a día:* Todos los tickets · Tablero · Tareas · Métricas.
🔹 *Abajo, la configuración en 3 cajones que se abren y cierran:*
　📁 Definiciones · 🤖 Automatización e IA · ⚙️ Ajustes
✨ Solo se abre un cajón a la vez 🎯, cada opción con su iconito 🏷️, y al entrar a algo del día a día se cierran solos 🧹.

En resumen: ya quedó *funcionando* lo importante de los Tipos de Caso (incluido el armado automático ITIL/Simple), y ahora seguimos puliendo la parte visual para que sea más cómoda de usar. 🚀
