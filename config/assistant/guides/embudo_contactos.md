---
key: embudo_contactos
title: Embudo de contactos
areas: [sales]
keywords: [embudo, contacto nuevo, primera conversacion, cliente que vuelve a escribir, por que no entra, salir del embudo, sale del embudo, embudo de contactos, prospecto, prospectos, tablero de conversaciones, kanban, columna, tarjeta, mover tarjeta, convertir, convertido, descartar, descartado, frio, sin respuesta, dias sin respuesta, ia mueve, movimiento automatico, bandejas, criterio, metricas del embudo, interesado, cita, embudo por defecto, etapa por defecto, posicion, tipo de columna, agregar columna, eliminar embudo, mas antiguas, quitar del embudo, meter al embudo]
pages: [contact_funnel, conversation, opportunities, contact_funnels]
sources: [app/javascript/dashboard/views/kanbanBoard.vue, app/javascript/dashboard/components/kanban/**/*.vue, app/javascript/dashboard/components/settings/KanbanProcesses/*.vue, app/javascript/dashboard/components/settings/KanbanTypeProcesses/*.vue, app/javascript/dashboard/routes/dashboard/settings/kanban/*.vue, app/javascript/dashboard/routes/dashboard/conversation/ConversationAction.vue, app/services/kanban/*.rb, app/jobs/kanban/*.rb, app/models/concerns/kanban_funnel_trackable.rb]
reviewed: 2026-11-14
---
## Para qué sirve
El Embudo de contactos es la antesala de la oportunidad: muestra las conversaciones con prospectos como tarjetas en columnas, desde que llegan hasta que se convierten en oportunidad o se descartan. La propia conversación mueve su tarjeta según lo que pasa (reglas e inteligencia artificial).

## Dónde está
- Ventas › Embudo de contactos: el tablero. Arriba eliges qué embudo ver en «Embudo», cuántos días ver en «Convertidas y descartadas:» y tienes «Actualizar» y «Métricas». Al abrir, se muestra el embudo marcado como por defecto.
- Catálogos › Embudos de contactos: crear y configurar los embudos y sus columnas (administrador).
- En la conversación, en «Acciones de la conversación» › «Embudo de contactos»: meter o sacar esa conversación de un embudo a mano.

## Cómo se hace
### Usar el tablero
1. Abre Ventas › Embudo de contactos y elige el embudo en «Embudo».
2. Cada columna dice cuántas «Conversaciones» tiene. Cada tarjeta es una conversación: muestra su estado, los mensajes sin leer, el contacto, el último mensaje, sus etiquetas, la bandeja, el responsable y hace cuánto fue la última actividad.
3. La tarjeta dice quién la movió («Movida sola», «Movida por la IA», «Movida por automatización», «Movida por …» o «Movida a mano»); pasa el mouse para ver por qué.
4. Pulsa la tarjeta para abrir la conversación.
5. Arrastra una tarjeta a otra columna para moverla a mano. Mover a mano siempre gana: las reglas y la IA nunca la regresan.
6. La marca «❄ Frío» sale cuando el cliente lleva los días configurados sin responder.
7. Si la conversación ya tiene caso, la tarjeta muestra su folio (→ folio): púlsalo para abrir el caso.
8. Si una columna se queda vieja, usa «Actualizar conversaciones» al pie de la columna o «Actualizar» arriba.

### Cómo se mueven solas (columnas que trae un embudo nuevo)
1. Nuevo: llega un contacto nuevo (su primera conversación) por una de las bandejas del embudo. Si el contacto ya había escrito antes (un cliente o alguien conocido), su conversación nueva no entra al embudo.
2. En contacto: se le contesta por primera vez (agente o IA).
3. Interesado: se le pone la etiqueta «interesado» (la etiqueta se crea sola con el embudo).
4. Cita: se agenda una cita.
5. Convertido: se crea un caso de Ventas.
6. Descartado: se resuelve la conversación sin caso, o pasan los días sin respuesta configurados.
Las tarjetas solo avanzan, nunca regresan solas. Si el embudo tiene «La IA mueve tarjetas», cuando el cliente deja de escribir (unos 2 minutos después de su último mensaje) la IA lee la conversación y la adelanta a la columna cuyo criterio se cumple, con una nota privada del porqué; si no está segura, solo deja la sugerencia en la nota. La IA nunca la pasa a Convertido: eso lo hace una persona o la regla de caso creado.

### Convertir en oportunidad
1. Arrastra la tarjeta a la columna Convertido.
2. Si esa columna tiene un tipo en «Al soltar una tarjeta aquí, crear la oportunidad de tipo», se crea la oportunidad ligada a la conversación. Si la conversación ya tiene una oportunidad abierta, no se crea otra.
3. También se convierte sola cuando creas un caso de Ventas desde la conversación.

### Descartar
1. Arrástrala a Descartado, o déjala: pasa sola tras los días sin respuesta configurados.
2. Si el cliente vuelve a escribir, la tarjeta regresa a la columna de entrada.

### Meter o sacar una conversación a mano
1. Abre la conversación y, en «Acciones de la conversación», busca «Embudo de contactos».
2. Elige el embudo: la tarjeta entra en su columna marcada como etapa por defecto.
3. Para sacarla del embudo, vuelve a elegir el mismo embudo (se quita la selección).

### Crear un embudo (administrador)
1. Entra a Catálogos › Embudos de contactos y, en «Embudos de contactos», pulsa «Agregar».
2. Escribe el «Nombre del embudo» y, en «Bandejas que entran solas», marca por qué bandejas entran los contactos nuevos. Si no eliges ninguna, sale el aviso «Elige al menos una bandeja para que las conversaciones nuevas entren solas.».
3. Si quieres que sea el que se abre en el tablero, marca «Establecer como embudo por defecto» (solo puede haber uno).
4. Pulsa «Crear». El embudo nace con sus columnas, reglas y criterios de IA listos y con «Movimiento automático» encendido.

### Configurar un embudo (administrador)
1. En la lista «Embudos de contactos» pulsa el lápiz («Editar») del embudo. La lista marca con ⚡ los que tienen «Movimiento automático» y con 🤖 los que tienen «La IA mueve tarjetas».
2. Marca o quita «Movimiento automático» y «La IA mueve tarjetas», y ajusta «Bandejas que entran solas».
3. Llena «Marcar «Frío» tras estos días sin respuesta del cliente» y «Descartar tras estos días sin respuesta del cliente» (vacío = nunca).
4. Si pusiste días para descartar, aparece «Al descartar por días sin respuesta, resolver la conversación»: se resuelve sin avisarle al cliente (sin encuesta ni mensajes). En los embudos nuevos ya viene marcada.
5. Pulsa «Actualizar». Para borrar un embudo usa el botón «Eliminar» de su fila y confirma con «Sí, eliminar».

### Configurar las columnas (administrador)
1. Abajo, en «Columnas del embudo», elige el embudo en «Seleccionar embudo». La tabla muestra Nombre, Posición y un resumen de cada columna (tipo, qué crea, «Reglas» y 🤖 «IA»).
2. Pulsa «Agregar nueva etapa», o el lápiz («Editar») de una columna.
3. Llena «Nombre de la etapa» y «Posición» (el orden en el tablero; es obligatoria).
4. En «Tipo de columna» elige «Normal», «Convertido (ya es oportunidad)» o «Descartado».
5. En «Entra aquí cuando…» marca qué la mueve: «Llega una conversación nueva (columna de entrada)», «Se le contesta por primera vez (agente o IA)», «Se le pone una etiqueta» (y eliges cuáles en «Etiquetas que la mueven»), «Se agenda una cita», «Se crea un caso» (con «De la clase»: Cualquiera, Ventas, Soporte, Orden de trabajo o Proyecto) o «Se resuelve la conversación sin caso». Solo aplica si el embudo tiene «Movimiento automático».
6. Escribe el «Criterio para la IA»: en palabras, cuándo una conversación debe entrar ahí.
7. En una columna «Convertido (ya es oportunidad)» elige «Al soltar una tarjeta aquí, crear la oportunidad de tipo» (o «No crear nada»).
8. Si quieres, marca «Establecer como etapa por defecto» y pulsa «Crear» o «Actualizar». Para quitar una columna usa «Eliminar».

## Límites
- Solo entran solos los contactos nuevos (su primera conversación) y solo en embudos con «Movimiento automático». Si una bandeja está en varios embudos, el contacto entra al más antiguo.
- Una tarjeta convertida ya no se mueve sola; a mano sí se puede arrastrar.
- Una descartada solo sale sola si se crea su caso o si el cliente vuelve a escribir.
- El descarte por días sin respuesta solo toca las columnas normales.
- La etapa por defecto de una columna no se puede desmarcar al editarla («No se puede modificar el estado por defecto de esta etapa de oportunidad.»).

## Dudas frecuentes
- ¿Por qué no entró una conversación? Solo entran contactos nuevos: si esa persona ya tenía conversaciones antes, no entra sola. Si quieres que esté, en la conversación abre «Acciones de la conversación» y elige el embudo en «Embudo de contactos».
- ¿Cuándo deja de estar en el embudo? La tarjeta se queda hasta llegar a Convertido (se crea un caso de Ventas o la arrastras ahí) o a Descartado (se resuelve la conversación sin caso, pasan los días sin respuesta configurados o la arrastras ahí). Esas dos columnas solo muestran los días que eliges en «Convertidas y descartadas:»; después ya no se ven en el tablero, pero no se borran.
- «Convertidas y descartadas:» (Últimos 7, 30 o 90 días, o Todas) solo oculta las viejas para que esas columnas no crezcan sin fin; no se borra nada y las métricas cuentan todo. Al pie de la columna, «+ N más antiguas · ver» las muestra y «Ver solo los últimos … días» las vuelve a ocultar. Cada quien ve su propia elección.
- Un embudo nuevo nace con sus columnas, reglas y criterios de IA listos; solo eliges las bandejas. Los que ya existían no cambian solos.
- «Métricas» muestra, por 7, 30 o 90 días: Entraron, Convertidas, Días para convertir, Aciertos de la IA, Hasta dónde llegaron, Por qué se descartan y Quién movió las tarjetas (Personas, Reglas, IA, Automatizaciones). Cuenta desde que se activó el Embudo de contactos.
- Cada movimiento deja una nota en la conversación con la columna y el motivo.
- La IA solo funciona si tu empresa tiene la inteligencia artificial conectada; sin ella las reglas siguen trabajando.
- Ya convertida, la venta sigue en Ventas › Oportunidades. Ver la guía Oportunidades de venta.

## Quién puede
Usar el tablero: quien tiene acceso a Ventas en su rol. Crear, editar y eliminar embudos y columnas en Catálogos › Embudos de contactos: solo el Administrador.
