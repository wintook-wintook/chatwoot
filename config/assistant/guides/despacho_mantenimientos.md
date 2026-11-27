---
key: despacho_mantenimientos
title: Despacho y mantenimientos
areas: [service]
keywords: [despacho, despachar, tecnicos, dia de los tecnicos, asignar tecnico, mover visita, reprogramar visita, por programar, visitas sin tecnico, choques de horario, se encima, zona, habilidades, ruta en maps, mantenimiento, mantenimientos, recurrente, preventivo, equipo, equipos, nuevo equipo, dar de baja, garantia, historial del equipo, generar ya, proxima fecha, dias de anticipacion, incluir pausados]
pages: [dispatch, maintenance, cases, case, contact]
sources: [app/javascript/dashboard/views/gestorTickets/dispatch/Dispatch.vue, app/services/field/dispatch_board.rb, app/controllers/api/v1/accounts/field_dispatch_controller.rb, app/javascript/dashboard/views/gestorTickets/maintenance/*.vue, app/javascript/dashboard/routes/dashboard/contacts/components/ContactAssetsTab.vue, app/controllers/api/v1/accounts/maintenance_plans_controller.rb, app/services/maintenance_plans/generator.rb]
reviewed: 2026-11-14
---
## Para qué sirve
- Despacho es el tablero del día: una columna por técnico (y por vendedor con visitas) para repartir y acomodar el trabajo en campo.
- Mantenimientos junta los servicios que se repiten cada cierto tiempo (por ejemplo, un mantenimiento preventivo cada 3 meses) de todos los clientes. Cada uno crea su orden de trabajo sola antes de la fecha.

## Dónde está
- Servicio › Despacho.
- Servicio › Mantenimientos.
- Los equipos y mantenimientos de un cliente se dan de alta en la página del contacto, pestaña Equipos.

## Cómo se hace
### Repartir el día en Despacho
1. Entra a Servicio › Despacho y elige el día con las flechas.
2. A la izquierda están «Por programar» (órdenes en campo, abiertas y sin visita) y «Visitas sin técnico» (órdenes con visita pero sin responsable).
3. Arrastra una orden «Por programar» a la columna de un técnico: se abre «Agendar visita de … con …». Escribe «Hora» y «Duración (min)» y pulsa «Agendar».
4. Arrastra una «Visita sin técnico» a una columna y queda asignada a ese técnico con su misma hora.
5. Arrastra una visita a otra columna para pasársela a otro técnico: te pide la «Hora» (puedes cambiarla) y «Agendar».
6. Doble clic en una tarjeta abre la orden; con «Volver» regresas al mismo día.

### Ver mejor el día
1. Filtra con «Todos», «Soporte» (los técnicos) o «Ventas» (las tareas agendadas marcadas como visita, por vendedor).
2. Si tus técnicos tienen zona, filtra con «Todas las zonas» o una zona.
3. Cada columna muestra la zona y las habilidades del técnico. «N choques de horario» y «Se encima» avisan de visitas encimadas del mismo técnico.
4. «Ruta en Maps» abre en Google Maps la ruta del técnico con las direcciones de sus visitas.
5. Si el cliente contestó desde su portal, la tarjeta dice «✓ El cliente confirmó» o «El cliente pide otra fecha: …».

### Dar de alta un mantenimiento recurrente
1. Abre el contacto y entra a la pestaña Equipos.
2. Si hace falta, pulsa «Nuevo equipo» y escribe «Nombre», «Marca», «Modelo», «Serie», «Ubicación», «Instalado el», «Garantía hasta» y «Notas».
3. Pulsa «Nuevo mantenimiento» (en el equipo o en la sección Mantenimientos).
4. Escribe el «Nombre», elige el «Equipo» (o «Sin equipo») y el «Tipo de orden», cada cuánto («Cada» y la «Unidad»: Semanas o Meses) y la «Próxima fecha».
5. Elige el «Técnico» (o «Sin técnico (se asigna en Despacho)») y los «Días de anticipación».
6. Marca «Avisar al cliente cuando se genere la orden» si quieres, escribe «Notas» y pulsa «Guardar». Nace activo; al editarlo puedes quitar «Activo» para pausarlo.

### Cuidar los equipos del cliente
1. En la pestaña Equipos, cada equipo dice marca, modelo, serie, ubicación y si está «En garantía».
2. «Historial (N)» muestra sus órdenes; clic en una para abrirla.
3. Para retirarlo, edítalo y pulsa «Dar de baja». «Ver dados de baja» los vuelve a mostrar.

### Revisar los mantenimientos de todos
1. Entra a Servicio › Mantenimientos.
2. Busca en «Buscar cliente, equipo o mantenimiento» y elige «Próximos 30 días», «Próximos 90 días» o «Todos». «Incluir pausados» muestra los inactivos.
3. Cada renglón dice el cliente (clic para abrirlo), el equipo, cada cuánto, el tipo, el técnico, «Próximo: fecha» y las órdenes abiertas.
4. «Generar ya» crea ahora la orden de la próxima fecha y adelanta la siguiente. El lápiz edita y el bote de basura elimina.

## Dudas frecuentes
- ¿Cuándo se crea la orden sola? Una vez al día se revisa y se crea cuando la próxima fecha ya entra en los días de anticipación. Si el mantenimiento ya tiene una orden abierta, no crea otra: solo adelanta la fecha.
- ¿Qué le llega al cliente? Si marcaste el aviso, un mensaje por su conversación más reciente con el folio y el enlace para seguir su servicio.
- Si eliminas un mantenimiento, las órdenes ya generadas se quedan.
- No salen técnicos en Despacho («No hay técnicos…»): ponles el rol Técnico, o habilidades y zona de trabajo al editar el usuario en Ajustes › Usuarios.
- Las órdenes que se atienden en oficina o remoto no salen en Despacho, ni las cerradas o canceladas.

## Quién puede
- Despacho: el Administrador y quien pueda reasignar casos y vea todo (o vea sin cambiar) Servicio o Ventas; por omisión, el Supervisor. A los demás no les aparece en el menú.
- Mantenimientos: los ve quien tenga Servicio o Clientes; los crea, edita, genera y elimina quien tenga Servicio en todo o en solo lo suyo.
- Equipos del cliente: quien tenga Clientes, Servicio o Ventas.
