---
key: calendario_google
title: Calendario y Google Calendar
areas: [agenda]
keywords: [calendario, google, google calendar, conectar google, conectar calendario, reconectar, desconectar, sincronizar, evento, eventos, tarea agendada, todo el dia, meet, invitados, disponibilidad, enviar mi agenda, mis calendarios, borde punteado, evento sin tarea, interno, semana, mes, proximos eventos, crear calendario, editar calendario, zona horaria, color, pasar a tarea, sin google]
pages: [calendar, agenda, my_day, tasks]
sources:
  - app/javascript/dashboard/routes/dashboard/settings/googleCalendar/*.vue
  - app/javascript/dashboard/components/GoogleCalendar/*.vue
  - app/controllers/api/v1/accounts/agenda_items_controller.rb
  - app/controllers/api/v1/accounts/google_calendar/*.rb
reviewed: 2026-11-14
---
## Para qué sirve
Agenda › Calendario muestra tus tareas agendadas (las que tienen hora) en una vista de semana, mes o agenda. Si conectas tu cuenta de Google, también ves tus eventos de Google y lo que agendes aquí aparece allá.

## Dónde está
Agenda › Calendario. Solo aparece si tu empresa tiene el calendario activado.
- Arriba: «Nueva tarea agendada» y los botones de Google («Conectar cuenta de Google», o ya conectado «Enviar mi agenda», «Reconectar» y «Desconectar»).
- En medio, el calendario con «Semana», «Mes» y «Agenda» (lista), las flechas y «Hoy». Abre en la semana.
- A la derecha, tres secciones que se abren con un clic: «Próximos eventos», «Mis calendarios» y «Disponibilidad del equipo».

## Cómo se hace
### Conectar tu Google Calendar
1. Entra a Agenda › Calendario.
2. Pulsa «Conectar cuenta de Google». Se abre una ventana de Google.
3. Elige tu cuenta y acepta los permisos (leer y crear eventos, manejar tus calendarios y ver tu disponibilidad).
4. Al terminar, arriba dice «Conectado como» y tu correo. Sin Google, arriba dice «Sin Google conectado: lo que agendes queda solo en Kontrolya.».
5. Si deja de sincronizar, pulsa «Reconectar». Para quitarlo, «Desconectar» (pregunta si estás seguro).
Cada persona conecta su propia cuenta de Google.

### Agendar desde el calendario
1. Pulsa «Nueva tarea agendada», o selecciona un horario en el calendario.
2. Elige el contacto o la organización y, si quieres, uno de sus casos abiertos en «Caso (opcional)».
3. Si tienes varios calendarios de Google donde puedes escribir, elige el «Calendario» («Principal» es el tuyo).
4. Escribe el «Título», «Inicio» y «Fin».
5. Opcional: «Descripción», «Es una visita al cliente» con su «Dirección de la visita» (vacía = la del caso o la organización), e «Invitados» (escribe un correo y da Enter).
6. Pulsa «Crear tarea agendada». Si falta el cliente te dice «Elige el contacto o un caso, o márcalo como interno.».

### Un evento interno (solo en Google)
Con Google conectado, marca «Interno, sin cliente (solo en Google)»: no pide cliente, se crea solo en tu Google Calendar y no queda como tarea. Solo en un evento interno sale «Todo el día».

### Abrir o cambiar una tarea agendada
1. Haz clic en ella en el calendario. Arriba ves su Contacto, Organización y la liga «Abrir caso».
2. Cambia título, inicio, fin o descripción y pulsa «Guardar cambios».
3. «Pasar a tarea (sin hora)» la quita de la agenda y de Google y la deja como tarea con fecha límite ese día (puedes «Avisarle al cliente que se quita la cita»). Solo sale si sigue agendada y no han marcado «voy en camino».

### Convertir un evento de Google en tarea agendada
1. Los eventos de Google que no tienen tarea en la plataforma salen con borde punteado.
2. Haz clic en el evento. Dice «Este evento aún no tiene tarea agendada».
3. Elige el contacto (y su caso, si aplica) para crearla, o marca «Interno, sin cliente (solo en Google)» si no es de un cliente.
4. Guarda. El evento sigue siendo el mismo en Google; sus fechas no cambian y a sus invitados no se les avisa.

### Mover una cita
Arrastra el evento a otro horario en el calendario. Si es una tarea agendada, el cambio llega a Google; si es un evento de Google, se mueve en Google.

## Qué se sincroniza y qué no
- Una tarea agendada (con hora) creada aquí, en el calendario, en la barra de arriba, en un caso o con el asistente, va al Google Calendar de su responsable, si él lo conectó, con su liga de Google Meet.
- Las tareas sin hora no van a Google: se quedan en Agenda › Tareas.
- Un evento creado directo en Google se ve en el calendario, pero no se vuelve tarea hasta que lo abres y le pones contacto.
- Los eventos de todo el día se quedan solo en Google: no se vuelven tareas.
- Si en Google cambias la fecha u hora de una tarea agendada, o la cancelas, el cambio se refleja aquí.
- Sin Google conectado, lo que agendes queda solo en la plataforma.

## Dudas frecuentes
- ¿Puedo ver otro calendario? Sí: en «Mis calendarios», «Agregar otro calendario» tiene «Crear nuevo» (nombre, descripción, zona horaria y color; se crea en tu Google) y «Suscribir existente» (el correo o ID de un calendario compartido contigo). Con la casilla de cada calendario lo muestras u ocultas; el lápiz abre «Editar calendario».
- «Próximos eventos» lista lo que viene, marcado «Hoy» o «Mañana».
- «Disponibilidad del equipo» muestra quién está libre u ocupado (solo de quienes conectaron su calendario).
- «Enviar mi agenda» (con Google conectado) manda tus próximas citas («Hoy», «3 días» o «7 días») a los «Contactos» que elijas por el «Canal de envío»; antes ves la «Vista previa del mensaje».
- Si agregas invitados, Google les manda la invitación.

## Quién puede
Quien entra a la Agenda. Cada quien ve en el calendario sus propias tareas agendadas y conecta solo su cuenta de Google.
