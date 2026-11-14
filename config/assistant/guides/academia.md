---
key: academia
title: Mi capacitación (lecciones y ejercicios)
areas: []
keywords: [capacitacion, mi capacitacion, academia, curso, cursos, aprender, aprender a usar, entrenamiento, ejercicio, ejercicios, leccion, lecciones, modulo, modulos, revisar ejercicio, hazlo, mi avance, avance, cliente de practica, practica, practicar, borrar mi practica, no me marca el ejercicio, no me cuenta, configura tu cuenta, configuracion inicial, configurar la cuenta, tu perfil, asi me sirve, indispensable, recomendado, deshacer]
pages: [academy, conversations, contacts, account_settings, users, inboxes, profile]
sources:
  - config/academy/modules.yml
  - app/services/academy/*.rb
  - app/controllers/api/v1/accounts/academy_controller.rb
  - app/javascript/dashboard/views/academy/*.vue
  - app/javascript/dashboard/views/gestorTickets/home/MySummary.vue
reviewed: 2026-11-14
---
## Para qué sirve
Para aprender Kontrolya haciendo. Cada módulo tiene lecciones cortas y ejercicios; la plataforma revisa sola si ya hiciste cada ejercicio, con lo que de verdad hay en la cuenta. No se palomea a mano.

## Dónde está
- Inicio › Mi capacitación. Arriba ves cuántos pasos llevas de todos; abajo, tu Cliente de práctica y los módulos.
- Ves los módulos de las áreas de tu rol: Conversaciones, Contactos y organizaciones, y Casos y seguimiento. El que dice «Sigue con» es el primero que no terminaste.
- Los administradores ven primero «Configura tu cuenta»; todos ven «Tu perfil».
- En Inicio › Mi resumen, el botón «Mi capacitación» con tu avance (por ejemplo «Mi capacitación 5/35») te trae aquí.

## Cómo se hace
### Una lección
1. Abre el módulo y pulsa «Leer». Se abre el texto de la lección y queda como leída.
2. Si quieres verla completa, «Ver en el Centro de ayuda».

### Un ejercicio
1. Pulsa «Hazlo»: te lleva a la pantalla y desde ese momento empieza a contar (no vale lo que hiciste antes).
2. Haz lo que pide el ejercicio.
3. Regresa a Inicio › Mi capacitación y pulsa «Revisar». Si lo encuentra, dice «¡Bien! Ya quedó.»; si no, te dice qué le falta.
4. «¿Cómo?» le pregunta a Dali cómo se hace ese ejercicio.

### Configura tu cuenta (administradores)
Lo que hay que dejar listo para que el equipo trabaje. Cada paso dice si es «Indispensable», «Recomendado» o «Cuando estés listo»:
- Indispensable: el nombre y el logo de la empresa (Ajustes › Configuración de cuenta), conectar WhatsApp, invitar a tu equipo, darle a cada quien su rol (Ajustes › Usuarios), elegir quién atiende cada bandeja y revisar tus tipos de caso y sus etapas.
- Recomendado: motivos de cierre, resultados de las tareas, respuestas predefinidas, plantillas de WhatsApp, horario de atención y productos con sus precios.
- Cuando estés listo: el presupuesto de ventas, subir tus contactos, y las lecciones de Seguimiento IA y Agentes listos.

1. «Hazlo» te lleva a la pantalla donde se configura.
2. Cada paso se marca solo cuando ya está, aunque lo haya hecho otro administrador o lo hayas hecho antes. «Revisar» vuelve a comprobar.
3. Lo que Kontrolya ya trae de fábrica (etapas, motivos, resultados) o lo que no usas tiene un botón para darlo por hecho, por ejemplo «Así me sirven» o «No uso WhatsApp». Vale para toda la cuenta y dice quién lo aceptó; «Deshacer» lo regresa a pendiente.

### Tu perfil (todos)
Tu foto, tu firma, conectar tu Google Calendar, instalar Dali en tu celular y preguntarle algo a Dali. Se marcan solos cuando ya están; la firma, Google y el celular se pueden saltar («No la necesito», «No uso Google», «No lo necesito»).

### El Cliente de práctica
1. En el módulo Contactos y organizaciones, el ejercicio «Crea tu Cliente de práctica» tiene el botón «Crear mi Cliente de práctica».
2. Es un contacto a tu nombre, sin teléfono ni correo: no se le manda nada. Los ejercicios de contactos y casos se hacen sobre él (ligarlo a una organización, dejarle una nota, crearle un caso con su tarea, cambiarlo de etapa y agendarle una llamada).
3. Cuando termines, «Borrar mi práctica» quita el contacto, sus casos con sus tareas y citas, y su organización si solo era de él. Tu avance se queda.

## Límites
- Los ejercicios de Conversaciones son con clientes reales (contestar y mencionar a un compañero en una nota privada): cuentan solo los que haces tú después de pulsar «Hazlo».
- Si pulsas «Revisar» sin haber pulsado «Hazlo», empieza a contar en ese momento: haz el ejercicio y vuelve a revisar.
- Si tienes Google conectado, la llamada que agendes en el caso de práctica también sale en tu Google Calendar.
- El Cliente de práctica y su caso todavía cuentan en los informes mientras existan; bórralos al terminar.

## Dudas frecuentes
- No me marca el ejercicio: revisa que lo hiciste tú, después de pulsar «Hazlo», y en el lugar que dice (por ejemplo en «Nota privada», no en «Responder», para la mención; o en tu Cliente de práctica y no en otro contacto).
- ¿Lo ve mi supervisor? Todavía no: por ahora cada quien ve su avance.
- ¿Es obligatoria? No, es recomendada; puedes usar la plataforma sin terminarla.
- «Dale a cada quien su rol» no se marca: hay compañeros que no son administradores con el rol de por omisión; elige el suyo en Ajustes › Usuarios o pulsa «Así me sirve».
- «Elige quién atiende cada bandeja» no se marca: hay una bandeja sin agentes; agrégalos en la bandeja, pestaña de agentes.
- ¿Dónde quedó «Primeros pasos»? Ahora es esta pantalla: el botón de Inicio dice «Mi capacitación».

## Quién puede
Todos. Cada quien ve los módulos de las áreas de su rol y solo su propio avance. «Configura tu cuenta» solo lo ven los administradores, y su avance es de la cuenta.
