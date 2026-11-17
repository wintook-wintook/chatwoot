---
key: tareas_cliente
title: Tareas con el cliente y su portal
areas: [sales, service]
keywords: [tareas con el cliente, tarea del cliente, portal del cliente, enlace del portal, crear enlace, renovar enlace, desactivar portal, visible al cliente, quien la hace, implementacion, proyecto, que le falta al cliente, regresar tarea, responder al cliente, el cliente completo, subir archivo, documentos del cliente, aprobar, probar, estudiar, quien eres, recordatorios, cliente]
pages: [case, cases, organization, contact]
sources: [app/javascript/dashboard/components/clientPortal/*.vue, app/javascript/dashboard/components/contacts/CaseTicket/TicketTasks.vue, app/controllers/public/client_portals_controller.rb, app/views/public/client_portals/*.erb, app/controllers/api/v1/accounts/client_portal_links_controller.rb, app/services/client_tasks/*.rb]
reviewed: 2026-11-14
---
## Para qué sirve
Llevar en el caso o proyecto las tareas que le tocan al cliente (probar, estudiar, enviar documentos, aprobar…) y las nuestras que él debe ver. El cliente las ve y las trabaja en su portal, sin usuario ni contraseña: las empieza, comenta, sube archivos y las marca como hechas; todo queda en el caso.

## Dónde está
- En el caso › Pendientes › Tareas: al crear o editar una tarea, «¿Quién la hace?».
- El enlace del portal: arriba de la lista de tareas del caso («Portal del cliente»), en la ficha de la organización y en la del contacto.
- El portal del cliente se abre con su enlace: la dirección de la plataforma con /cliente/ y un código.

## Cómo se hace
### Asignarle una tarea al cliente
1. En el caso, Pendientes › «Nueva tarea».
2. En «¿Quién la hace?» elige entre «Nosotros (interna)», «Nosotros, visible al cliente» y «El cliente». Para el cliente, elige «El cliente» y escribe qué tiene que hacer, instrucciones y la fecha.
3. Si debe subir algo (constancia, evidencia), marca «Pide que el cliente suba un archivo».
4. Deja marcado «Avisarle al cliente con el enlace de su portal»: le llega un mensaje por la conversación del caso con el enlace. Si no se pudo (sin conversación o con la ventana de 24 h de WhatsApp cerrada), te avisa para que se lo mandes con «Copiar enlace». Si el caso no tiene contacto ni organización, no hay portal al cual mandarlo.
5. Las nuestras que el cliente debe ver (p. ej. «Configurar series») van con «Nosotros, visible al cliente»: ve su avance pero no las mueve. «Nosotros (interna)» es como siempre: no la ve.

### Lo que ve y hace el cliente en su portal
1. Abre el enlace y en «¿Quién eres?» elige su nombre (de los contactos de su organización) y «Continuar»; queda registrado quién hace cada cosa. Con «Cambiar» elige otro.
2. «Lo que necesitamos de ti»: sus tareas pendientes, la más urgente primero, con «Para el …» o «Vencida desde el …».
3. En cada una: «Empezar» (queda En proceso), «Comentar», «Subir archivo» y «Marcar como hecha» (con un comentario opcional). Si pide archivo, no deja marcarla hasta subirlo.
4. Abajo, en «Tus casos y proyectos», ve sus casos abiertos: en los proyectos, el avance, las «Fases» (la actual marcada), los «Hitos» y los «Casos del proyecto»; en cada caso, «Lo que estamos haciendo» (lo nuestro visible, Pendiente o Terminada) y «Lo que ya hiciste».

### Revisar lo que hizo el cliente
1. En la lista de tareas, la del cliente dice «Del cliente · En proceso» o «Hecha por …» y cuántas entradas tiene (💬).
2. Ábrela: «En el portal del cliente» muestra lo que hizo (La empezó, Comentó, Subió un archivo, La marcó como hecha), con sus archivos. Escribe en «Respóndele al cliente…» y pulsa «Responder».
3. Si algo no quedó, «Regresar al cliente» con el porqué (lo verá el cliente) y «Regresar»: vuelve a pendiente y se le avisa.
4. Todo queda en la Actividad del caso («El cliente avanzó una tarea») y al responsable del caso le llega un aviso cuando el cliente comenta, sube un archivo o la completa.

### El enlace del portal
1. Es uno por organización (todas sus personas usan el mismo) o, si el cliente no tiene organización, uno por contacto. No caduca.
2. Si aún no tiene, pulsa «Crear enlace». Después tienes «Copiar enlace» y «Abrir», y ves su «Último uso» (o «Aún no lo han abierto»).
3. «Renovar» crea uno nuevo y el anterior deja de servir (si se compartió por error). «Desactivar» lo apaga.

### Pedírselo a Dali
- «¿Qué le falta a Acme?» o «¿qué clientes tienen tareas vencidas?».
- «Asígnale a Acme probar la facturación para el viernes»: Dali arma la tarjeta «Tarea del cliente» (puedes cambiar el título, la fecha, si pide archivo y si se le avisa) y al confirmar la crea.

## Dudas frecuentes
- ¿Le llegan recordatorios al cliente? Sí: un día antes de que venza y al día siguiente de vencida, por su conversación (si la ventana lo permite). El responsable del caso también recibe el aviso.
- ¿Ve las tareas internas o las oportunidades de venta? No: solo las marcadas como del cliente o visibles, y sus casos y proyectos (sin oportunidades).
- ¿Y si no tiene nombre en la lista? Agrega a esa persona como contacto de la organización.
- La tarea del cliente no lleva responsable interno: la sigue el responsable del caso.

## Quién puede
Quien puede editar tareas del caso asigna, responde y regresa tareas del cliente. El enlace del portal lo crea, renueva o desactiva quien puede editar en Clientes.
