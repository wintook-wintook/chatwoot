---
key: usuarios_roles
title: Usuarios y roles
areas: [settings]
keywords: [usuario, usuarios, agregar usuario, dar de alta, invitar, eliminar usuario, borrar usuario, rol, roles, permisos, administrador, supervisor, vendedor, tecnico, consulta, solo lo suyo, no entra, ve todo, reasignar, tomar no asignadas, borrar, exportar, ver montos, restaurar como venia, modificado, habilidades, zona de trabajo, disponibilidad, contacto whatsapp del usuario, verificacion pendiente, restablecer contrasena, contrasena]
pages: [settings, users, roles, profile]
sources: [app/javascript/dashboard/routes/dashboard/settings/agents/*.vue, app/javascript/dashboard/routes/dashboard/settings/accessRoles/*.vue, app/javascript/dashboard/i18n/locale/es/agentMgmt.json, app/models/access_role.rb, app/controllers/api/v1/accounts/access_roles_controller.rb, app/controllers/api/v1/accounts/agents_controller.rb, app/policies/user_policy.rb]
reviewed: 2026-11-14
---
## Para qué sirve
- Ajustes › Usuarios: las personas de tu equipo que entran a la plataforma. Aquí se dan de alta, se les cambia el rol o se eliminan.
- Ajustes › Roles: qué ve y qué puede hacer cada rol. Al cambiar un rol, el cambio aplica a todos los usuarios que lo tienen.

## Dónde está
Ajustes › Usuarios y Ajustes › Roles. Ajustes solo lo ve el Administrador.
- En Usuarios cada renglón muestra la foto y el nombre con su correo, el rol, si está «Verificado» o en «Verificación Pendiente», su contacto de WhatsApp (o «—») y los botones «Editar» y «Eliminar».

## Cómo se hace
### Dar de alta a un usuario
1. Entra a Ajustes › Usuarios y pulsa «Agregar usuario».
2. Escribe el «Nombre del usuario» y la «Dirección de Correo Electrónico».
3. En «Rol» elige «Administrador» o «Supervisor».
4. Pulsa «Agregar usuario». La persona recibe un correo para entrar; mientras no lo confirme, en la lista sale «Verificación Pendiente». Si el correo ya está en uso, sale un aviso y no se agrega.
5. Si debe ser Vendedor, Técnico / Soporte o Consulta, edítalo después (siguiente tarea).

### Cambiar el rol o los datos de un usuario
1. En Ajustes › Usuarios pulsa el botón «Editar» (lápiz) del usuario.
2. En «Rol» elige uno de los cinco: Administrador, Supervisor, Vendedor, Técnico / Soporte o Consulta.
3. Si es técnico de campo, llena «Habilidades (separadas por coma)» (por ejemplo «A/C, Refrigeración, Eléctrico») y «Zona de trabajo» (por ejemplo «Norte, Centro…»); se usan para el despacho.
4. Ajusta la «Disponibilidad» («En línea», «Ocupado» o «Desconectado») si hace falta.
5. En «Contacto WhatsApp del usuario» busca (por nombre o teléfono, mínimo 2 letras) el contacto que es el WhatsApp de esa persona; la X lo quita.
6. Pulsa «Guardar cambios». El correo no se cambia aquí: cada quien lo cambia en su perfil.
7. «Restablecer Contraseña» le manda un correo para crear una nueva.

### Eliminar a un usuario
1. En Ajustes › Usuarios pulsa «Eliminar» en su renglón.
2. Confirma con «Sí, Eliminar …». No se puede eliminar a un Administrador ni a uno mismo (no sale el botón).

### Ajustar lo que ve un rol
1. Entra a Ajustes › Roles y elige el rol en la lista de la izquierda: «Supervisor», «Vendedor», «Técnico / Soporte» o «Consulta» (cada uno dice cuántos usuarios lo tienen). «Administrador» sale, pero no se edita.
2. En «A qué entra y qué ve» elige el nivel de cada área: Conversaciones, Agenda, Ventas, Servicio, Clientes, Campañas, Agentes IA, Informes y Ajustes.
3. En «Qué puede hacer» marca o desmarca las acciones.
4. Cada cambio se guarda solo («Rol guardado»). Si te equivocas, «Restaurar como venía» (sale solo si el rol está cambiado) lo regresa a como venía de fábrica; pide confirmar porque se pierden tus cambios.

## Los niveles y las acciones
- No entra: el área no sale en su menú.
- Solo lo suyo: ve lo que tiene asignado (sus conversaciones, sus casos, sus tareas, sus clientes).
- Ve todo (sin cambiar): mira todo pero no modifica.
- Todo: ve y cambia todo.
- Campañas, Agentes IA e Informes no tienen «Solo lo suyo». Ajustes siempre es «No entra» para los roles (no se puede cambiar): solo el Administrador entra.
- Acciones: «Asignar a otra persona», «Tomar lo que no tiene dueño (ve «No asignadas»)», «Borrar», «Exportar» y «Ver montos».

## Cómo vienen los roles
- Administrador: entra a todo, ve todo y puede hacer todo. No se edita.
- Supervisor: todo menos Ajustes; Campañas y Agentes IA solo para ver («Ve todo (sin cambiar)»). Puede asignar a otra persona, tomar no asignadas, exportar y ver montos; no puede borrar. Es el rol de quien no tiene otro.
- Vendedor: Ventas, sus conversaciones, su agenda y sus clientes, solo lo suyo. Toma no asignadas y ve montos.
- Técnico / Soporte: Servicio, sus conversaciones, su agenda y sus clientes, solo lo suyo. Toma no asignadas; no ve montos.
- Consulta: solo Informes (y Mi negocio) para mirar, con exportar y ver montos. Pensado para un socio o el contador.

## Dudas frecuentes
- ¿Por qué al agregar solo salen Administrador y Supervisor? Así es el alta; los demás roles se ponen al editar el usuario.
- Un usuario sin rol asignado cuenta como Supervisor.
- ¿Puedo crear un rol nuevo? No: hay cinco roles fijos; lo que se ajusta es qué ve y qué hace cada uno.
- Un usuario no ve una opción del menú: su rol no tiene esa área. Cámbiale el rol o el nivel en Ajustes › Roles.
- «Modificado» junto a un rol: ese rol ya no está como venía de fábrica.

## Quién puede
Solo el Administrador da de alta usuarios y cambia roles.
