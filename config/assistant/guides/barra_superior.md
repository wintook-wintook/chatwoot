---
key: barra_superior
title: La barra de arriba (preguntar, buscar y accesos rápidos)
areas: []
keywords: [barra de arriba, barra superior, preguntale, buscar, lupa, busqueda, buscar cliente, buscar caso, folio, rfc, tarea rapida, nueva tarea, reportar actividad, reportar avance, guardar avance, actividad interna, nuevo contacto, ayuda, signo de interrogacion, ctrl j, ctrl k, ctrl shift k, barra de comandos, accesos rapidos, abiertos hace poco, doble clic, fecha programada, fecha de vencimiento, visita, evidencia]
pages: [contacts, organizations, cases, tasks, task_reports, my_day, calendar]
sources:
  - app/javascript/dashboard/components/assistant/AssistantTopBar.vue
  - app/javascript/dashboard/views/gestorTickets/tasks/QuickTaskModal.vue
  - app/javascript/dashboard/views/gestorTickets/tasks/QuickSearchModal.vue
  - app/javascript/dashboard/views/gestorTickets/tasks/ActivityReportModal.vue
  - app/javascript/dashboard/views/gestorTickets/tasks/TimeSpentField.vue
  - app/services/global_search.rb
reviewed: 2026-11-14
---
## Para qué sirve
La barra de arriba está en todas las pantallas. Desde ahí le preguntas al asistente, buscas cualquier cliente o caso y haces lo más común (crear una tarea, reportar algo que hiciste o dar de alta un contacto) sin cambiar de pantalla.

## Dónde está
Arriba de todo. A la izquierda la caja «Pregúntale a …» (con el nombre del asistente de tu empresa) y a la derecha los botones Buscar, Tarea, Reportar actividad, Nuevo contacto y el «?» de ayuda. En pantallas angostas los botones solo muestran su ícono; al pasar el mouse sale su nombre. En Mi ruta en campo no aparece esta barra.

## Cómo se hace
### Preguntarle al asistente
1. Escribe en la caja «Pregúntale a …» y da Enter: se abre el panel del asistente con tu pregunta ya enviada.
2. Enter con la caja vacía, o doble clic en la caja, abre el panel sin preguntar nada.
3. También lo abres o cierras con Ctrl + J (Cmd + J en Mac). Esc lo cierra.
4. El texto de la caja cambia según lo que ves: en un caso dice «Pregúntale a … sobre este caso…»; igual en un contacto, una organización o una conversación.

### Buscar
1. Pulsa Buscar (la lupa, «Buscar en contactos, organizaciones y casos (Ctrl + K)») o usa Ctrl + K (Cmd + K en Mac) desde cualquier pantalla.
2. Antes de escribir ves «Abiertos hace poco»: los últimos 6 que abriste desde la lupa en esta computadora («Borrar» los quita).
3. Escribe al menos 3 letras (si no, dice «Escribe al menos 3 letras.»): nombre, folio, RFC, correo, teléfono o algo que esté en la descripción o en las notas. No importan acentos ni mayúsculas.
4. Arriba salen las pestañas Todo, Contactos, Organizaciones y Casos con cuántos hay de cada uno. En «Todo» van hasta 5 por tipo («Ver todos (N)» abre su pestaña); en una pestaña ves la lista completa y «Ver más (N)» trae el resto.
5. Cada resultado trae su ícono y una línea de datos: del contacto, su organización, teléfono y correo; de la organización, su etapa, RFC y responsable; del caso, su tipo, estado o resultado (Ganada, Perdida, Cancelada), el contacto y el responsable («Sin responsable» si no tiene). Si la palabra no está en el nombre, se ve en qué campo apareció, resaltada.
6. Abre con clic o con Enter; también te mueves con las flechas ↑ ↓ y cierras con Esc.
7. Si no aparece («Sin resultados.»), pulsa «¿No lo encuentras? Pregúntale a …» abajo: el asistente recibe «¿Dónde aparece «…»?» y busca la palabra por ti.

### Crear una tarea rápida
1. Pulsa Tarea: se abre «Nueva tarea». Llena «Qué hay que hacer» (es lo único obligatorio).
2. Lo demás es opcional: «Descripción (opcional)», «Responsable» (eres tú si no lo cambias), «Fecha programada» (viene con hoy), «Hora (opcional)» y «Fecha de vencimiento» (vence al final de ese día).
3. Si le pones hora, queda como tarea agendada (dura una hora) y va al calendario y a Google, si está conectado; entonces ya no se pide fecha de vencimiento. Con hora, la fecha programada es obligatoria.
4. Si es una visita, marca «Es una visita al cliente»: pide fecha y hora («Una visita lleva fecha y hora.») y puedes escribir la dirección; si la dejas vacía, se usa la del caso o la organización.
5. Elige «Organización (opcional)» y «Contacto» si es para un cliente; entonces sale «Caso (opcional)» con sus casos abiertos («Sin caso» si no). Sin cliente, la tarea solo se ve en Mi día.
6. Pulsa «Crear tarea». Sale «Tarea creada».

### Reportar algo que ya hiciste
1. Pulsa Reportar actividad (es para algo que ya hiciste; si es de una tarea pendiente, queda como su avance).
2. Escribe el «Título» y «Qué se hizo» (los dos obligatorios); ajusta «Fecha» y «Hora» (vienen con la de ahora), «Resultado», «Tiempo dedicado» y, si quieres, «Evidencia (opcional)» (hasta 5 archivos).
3. Elige «Organización (opcional)» y «Contacto» y, si aplica, «Caso (opcional)». Sin cliente queda como actividad interna: solo se ve en Reportes y en tu Mi día.
4. Si fue trabajo de una tarea pendiente (del caso elegido o, sin caso, del cliente), elígela en «Tarea (opcional)» («— Sin tarea: es una actividad —» si no). Queda como avance de esa tarea y no la completa: el título se quita, arriba dice «Avance de …» y el botón cambia a «Guardar avance».
5. Pulsa «Guardar». Sale «Actividad reportada» (o «Avance reportado»).

### Dar de alta un contacto
Pulsa Nuevo contacto: es la misma ventana de «Nuevo contacto» de Clientes › Contactos (ver la guía de Contactos). Llena sus datos y guarda.

## Dudas frecuentes
- La búsqueda busca en nombre, correo, teléfono, empresa, ciudad e identificador del contacto; en nombre, RFC, sitio web, giro, teléfono, dirección y notas de la organización; en folio, título, descripción, dirección de trabajo, cierre, nota del resultado y compromiso del caso; y en los atributos personalizados de los tres.
- Solo encuentras lo que tu rol te deja ver.
- El «?» («Ayuda») abre la ayuda en otra pestaña del navegador.
- La barra de comandos que antes salía con Ctrl + K ahora se abre con Ctrl + Shift + K (Cmd + Shift + K en Mac).
- Sin Tarea en la barra: tu empresa no usa casos y por eso no hay tareas.

## Quién puede
Todos los usuarios ven la barra. Cada búsqueda y cada registro respeta su rol: con «Solo lo suyo» encuentras solo tus contactos y casos.
