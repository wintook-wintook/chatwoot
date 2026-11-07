---
key: reglas_automatizacion_casos
title: Ajustes de casos (reglas, IA y folio)
areas: [settings]
keywords: [reglas de automatizacion, regla, asignar automatico, asignacion automatica, condiciones, acciones, escalar automatico, inteligencia artificial, ia en casos, clasificacion automatica, respuesta sugerida, parametros de ventas, moneda por defecto, impuesto, ajustes del modulo, reabrir automatico, ventana de reapertura, configuracion de folio, consecutivo, prefijo, resumen del negocio acceso]
pages: [settings, cases, case_rules]
---
## Para qué sirve
En Ajustes › Casos y etapas el administrador define cómo se comportan los casos de toda la cuenta: quién los recibe, qué hace la IA, cómo se numeran y cuándo se reabren.

## Dónde está
Ajustes › Casos y etapas, con estas opciones: Reglas de automatización, Inteligencia Artificial, Parámetros de ventas, Resumen del negocio: acceso, Ajustes del módulo y Configuración de folio.

## Cómo se hace
### Crear una regla de automatización
1. Entra a Ajustes › Casos y etapas › Reglas de automatización y pulsa «+ Nueva regla».
2. Escribe «Nombre», «Posición» (la menor se revisa primero) y, si quieres, «Descripción».
3. En «Se cumplen estas condiciones» pulsa «Agregar condición»: Tipo de caso, Origen, Prioridad, Estado, Estado SLA, Contenido del mensaje o Tiempo sin respuesta (min). Deben cumplirse todas; sin condiciones, la regla aplica a todos los casos.
4. En «Ejecutar estas acciones» pulsa «Agregar acción»: Asignar responsable o Asignar equipo (escribe el nombre), Cambiar prioridad, Cambiar estado, Escalar (si algún tipo maneja ITIL), Cerrar ticket, Notificar usuario (escribe su correo o nombre: le llega un aviso a la campanita con el nombre de la regla), Agregar etiqueta (el nombre de una etiqueta que ya exista: se pone a la conversación del caso) o Activar seguimiento (el nombre de una plantilla de seguimiento: arranca en la conversación del caso si el contacto no tiene ya uno en ese canal).
5. Deja «Activa» marcada. Marca «Continuar si coincide» si después de esta quieres revisar las siguientes; si no, se detiene en la primera que coincide.
6. Pulsa «Crear regla».

### Activar la IA en los casos
1. Entra a Ajustes › Casos y etapas › Inteligencia Artificial.
2. Enciende «Activar IA en el Gestor de Casos».
3. Para cada acción elige «Desactivado», «Sugerir» o «Automático»: Clasificación automática, Respuesta sugerida, Resumen y causa raíz, Detección de repetidos, Seguimiento automático, Plan de mi día, Resumen del negocio y Análisis de conversaciones.
4. Pulsa «Guardar». Necesita una integración de OpenAI activa en Integraciones.

### Parámetros de ventas
1. Entra a Ajustes › Casos y etapas › Parámetros de ventas.
2. «Moneda por defecto»: con la que nace cada oportunidad (por ejemplo MXN).
3. En cotizaciones: «Las cotizaciones requieren oportunidad» e «Impuesto por defecto de las partidas (%)».
4. En «Prospectos y clientes automáticos» marca cuándo una organización pasa sola a prospecto o a cliente. Guarda.

### Quién ve el Resumen del negocio
1. Entra a Ajustes › Casos y etapas › Resumen del negocio: acceso.
2. Marca a los usuarios que también pueden verlo (los administradores siempre lo ven) y pulsa «Guardar».

### Reapertura de casos cerrados
1. Entra a Ajustes › Casos y etapas › Ajustes del módulo.
2. En «Ventana de reapertura» escribe los días desde el cierre en los que una respuesta del cliente reabre el caso (0 = sin límite). Pasado el plazo se crea un caso nuevo ligado al anterior.
3. Activa o apaga «Reabrir si el cliente responde» y guarda.

### Configurar el folio
1. Entra a Ajustes › Casos y etapas › Configuración de folio.
2. Deja marcado «Generar folio automático para nuevos casos».
3. Escribe la «Plantilla del folio» con los datos disponibles: {PREFIX} (prefijo del tipo de caso), {SEQ:5} (consecutivo de 5 dígitos), {YYYY} o {YY} (año), {MM} (mes) y {DD} (día). Revisa la «Vista previa».
4. Elige si el consecutivo es independiente por tipo de caso y cuándo se reinicia: Nunca, Diario, Mensual o Anual. Guarda.

## Dudas frecuentes
- ¿Cuándo corren las reglas? Al crear un caso (venga de un mensaje, del portal o hecho a mano) y cuando su SLA se vence.
- Si al crear el caso alguien eligió responsable o equipo a mano, las reglas no lo cambian. Tampoco gana una regla sobre el responsable fijo del contacto o su organización.
- «Agregar etiqueta» y «Activar seguimiento» necesitan que el caso tenga conversación; un caso creado a mano sin conversación no recibe nada.
- ¿Cambiar la plantilla cambia folios viejos? No, solo los de los casos nuevos.
- ¿Las oportunidades se reabren si el cliente responde? No. Una oportunidad Ganada o Perdida se queda cerrada; en su historial queda el aviso de que el cliente escribió y, si hace falta, se reabre a mano. «Reabrir si el cliente responde» y su ventana aplican solo a los casos de servicio.
- Un administrador o supervisor puede reabrir a mano en cualquier momento con «Reabrir».
- El orden de Mi día se ajusta aparte, en Ajustes › Puntaje de tareas.

## Quién puede
Solo el Administrador ve y cambia Ajustes › Casos y etapas.
