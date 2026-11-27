---
key: tareas_que_se_repiten
title: Tareas que se repiten
areas: [agenda]
keywords: [tarea que se repite, tareas que se repiten, tarea fija, tarea recurrente, recurrente, repetir tarea, se repite, cada lunes, cada semana, cada mes, cada 15 dias, cada cuanto, seguimiento fijo, seguimiento periodico, recordatorio fijo, despues de hacerla, 30 dias despues, pausar tarea, reanudar, terminar tarea que se repite, no se hizo, cumplimiento, a tiempo, tarde, no hechas]
pages: [recurring_tasks, tasks, my_day]
sources:
  - app/javascript/dashboard/views/gestorTickets/recurring/*.vue
  - app/javascript/dashboard/components/recurrence/*.vue
  - app/javascript/dashboard/views/gestorTickets/tasks/QuickTaskModal.vue
  - app/services/task_recurrences/*.rb
  - app/controllers/api/v1/accounts/task_recurrences_controller.rb
reviewed: 2026-11-23
---
## Para qué sirve
Para un seguimiento fijo que hace una persona (no un agente IA): una tarea que das de alta una vez y que Kontrolya vuelve a crear sola cada cierto tiempo. Cada vez sale en el Mi día del responsable como cualquier tarea y se concluye con su reporte de cierre, así queda evidencia de cada seguimiento.

## Dónde está
- Para crearla: «Tarea» (barra de arriba), «Nueva tarea» en Agenda o «Nueva tarea» dentro de un caso, marcando «Se repite».
- Para verlas todas: Agenda › Tareas que se repiten.

## Cómo se hace
### Crear una tarea que se repite
1. Abre «Tarea» y llena el título, el responsable y, si es de un cliente, el contacto u organización (y el caso, si quieres).
2. «Fecha programada» es el día en que empieza. Si le pones «Hora», cada vez sale como tarea agendada (entra al calendario).
3. Marca «Se repite» y elige cómo cuenta el tiempo:
   - Junto a «cada N días/semanas/meses» eliges «En fecha fija» o «Después de hacerla»:
   - «En fecha fija»: toca en su fecha aunque no se haya hecho la anterior. Cada N días, cada N semanas (eliges los días: Lu, Ma, Mi…) o cada N meses (el mismo día del mes; si el mes es más corto, su último día).
   - «Después de hacerla»: N días, semanas o meses contados desde el día que la concluyes. Si te atrasas, la siguiente también se recorre.
4. En «Termina» eliges: Nunca, El día (una fecha) o Después de N veces.
5. Abajo se lee cómo quedó (por ejemplo, «Cada semana: lunes, jueves · 10:30»). Pulsa «Crear tarea».

### Dentro de un caso
En el caso, pestaña de tareas › «Nueva tarea»: llena la tarea como siempre y marca «Se repite» (solo al crearla y si la hace tu equipo, no el cliente). La primera sale el día «Programada para» (o hoy) y las siguientes salen solas, ligadas a ese caso, con su responsable, prioridad y duración. Si el caso se cierra o se cancela, deja de repetirse.

### Qué pasa cada vez que toca
- Ese día sale la tarea en el Mi día del responsable, con la etiqueta «Se repite».
- Si la anterior sigue pendiente, no se le amontona otra: en fecha fija cuenta como «no hecha» y le llega el aviso «No se hizo …» al responsable y a quien la programó; la siguiente sale cuando la concluya y llegue su fecha.

### Ver, pausar, editar o terminar
En Agenda › Tareas que se repiten ves cada una con su responsable, cada cuánto, la próxima fecha y el cumplimiento: cuántas se hicieron a tiempo, tarde y cuántas no se hicieron.
- «Editar»: cambia título, responsable, hora, cuándo empieza, cada cuánto o cuándo termina; la próxima fecha se recalcula.
- «Pausar»: deja de crearse hasta que pulses «Reanudar».
- «Terminar»: ya no se vuelve a crear; las tareas que ya creó se quedan.

## Dudas frecuentes
- ¿En qué se diferencia de un agente IA de seguimiento? Aquí lo hace una persona; el sistema solo le pone la tarea cada vez y mide si la hizo.
- ¿Y de una «Serie» de tareas agendadas? La serie crea de una vez todas las citas de un tiempo fijo; la tarea que se repite se crea una por una cuando toca, puede no tener hora y puede contar desde la última vez.
- ¿Cuándo aparece la del día? Al empezar el día (se revisa cada hora).

## Quién puede
- Cada usuario puede crear las suyas. Con Agenda en «solo lo suyo», el responsable siempre es uno mismo.
- Con Agenda en «Todo» puedes asignarlas a otra persona y ver las de todo el equipo («Todas»).
