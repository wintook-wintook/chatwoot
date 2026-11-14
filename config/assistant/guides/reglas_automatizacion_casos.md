---
key: reglas_automatizacion_casos
title: Ajustes de casos (reglas, IA y folio)
areas: [settings]
keywords: [reglas de automatizacion, regla, nueva regla, asignar automatico, asignacion automatica, condiciones, acciones, si entonces, continuar si coincide, posicion, escalar automatico, notificar usuario, agregar etiqueta, inteligencia artificial, ia en casos, clasificacion automatica, respuesta sugerida, resumen y causa raiz, deteccion de repetidos, plan de mi dia, analisis de conversaciones, openai, parametros de ventas, moneda por defecto, impuesto, cotizaciones requieren oportunidad, prospectos y clientes automaticos, ajustes del modulo, reabrir automatico, ventana de reapertura, configuracion de folio, plantilla del folio, consecutivo, reinicio del consecutivo, prefijo, resumen del negocio acceso]
pages: [case_rules, case_ai, commercial_settings, business_summary_access, case_module_settings, case_folio, settings, cases]
sources: [app/javascript/dashboard/views/gestorTickets/TicketRules.vue, app/services/cases/rule_engine_service.rb, app/services/cases/rule_side_actions.rb, app/javascript/dashboard/views/gestorTickets/AiConfig.vue, app/models/case_ai_config.rb, app/javascript/dashboard/views/gestorTickets/CommercialConfig.vue, app/javascript/dashboard/views/gestorTickets/commercial/CommercialSettings.vue, app/javascript/dashboard/views/gestorTickets/summary/BusinessSummaryAccess.vue, app/javascript/dashboard/views/gestorTickets/Settings.vue, app/javascript/dashboard/views/gestorTickets/FolioConfig.vue, app/controllers/api/v1/accounts/case_settings_controller.rb]
reviewed: 2026-11-14
---
## Para qué sirve
En Ajustes › Casos y etapas el administrador define cómo se comportan los casos de toda la cuenta: quién los recibe, qué hace la IA, cómo se numeran y cuándo se reabren.

## Dónde está
Ajustes › Casos y etapas, con estas opciones: Reglas de automatización, Inteligencia Artificial, Parámetros de ventas, Resumen del negocio: acceso, Ajustes del módulo y Configuración de folio.

## Cómo se hace
### Crear una regla de automatización
1. Entra a Ajustes › Casos y etapas › Reglas de automatización y pulsa «+ Nueva regla».
2. Escribe «Nombre», «Posición» (la menor se revisa primero) y, si quieres, «Descripción».
3. En «Se cumplen estas condiciones» pulsa «Agregar condición»: Tipo de caso, Origen (WhatsApp, Web, Email, Bot o Manual), Prioridad, Estado, Estado SLA (A tiempo, En riesgo, Vencido), Contenido del mensaje o Tiempo sin respuesta (min). Elige cómo compara («es», «no es», «está en», «no está en»; en texto, «contiene»; en minutos, =, ≥ o ≤) y el valor. Deben cumplirse todas; sin condiciones, la regla aplica a todos los casos.
4. En «Ejecutar estas acciones» pulsa «Agregar acción»: Asignar responsable o Asignar equipo (escribe el nombre), Cambiar prioridad, Cambiar estado, Escalar (si algún tipo maneja ITIL), Cerrar ticket, Notificar usuario (escribe su correo o nombre: le llega un aviso a la campanita con el nombre de la regla), Agregar etiqueta (el nombre de una etiqueta que ya exista: se pone a la conversación del caso) o Activar seguimiento (el nombre de una plantilla de seguimiento: arranca en la conversación del caso si el contacto no tiene ya uno en ese canal). Hace falta al menos una acción.
5. Deja «Activa» marcada. Marca «Continuar si coincide» si después de esta quieres revisar las siguientes; si no, se detiene en la primera que coincide.
6. Pulsa «Crear regla».

### Revisar y cambiar las reglas
1. La lista muestra #, Regla, Si (las condiciones), Entonces (las acciones) y Estado.
2. Pulsa «Activa» o «Inactiva» para prenderla o apagarla.
3. El lápiz la edita («Guardar cambios») y el bote de basura la elimina (no se puede deshacer).

### Activar la IA en los casos
1. Entra a Ajustes › Casos y etapas › Inteligencia Artificial.
2. Enciende «Activar IA en el Gestor de Casos». Es el interruptor general: apagado, ninguna acción de IA corre.
3. Para cada acción elige «Desactivado», «Sugerir» o «Automático»:
   - Clasificación automática: al crear un caso deduce tipo, servicio, categoría, impacto y urgencia.
   - Respuesta sugerida: propone una respuesta al cliente con la base de conocimiento.
   - Resumen y causa raíz: resume el caso y sugiere la causa raíz.
   - Detección de repetidos: busca incidentes parecidos y sugiere crear o vincular un Problema.
   - Seguimiento automático: redacta seguimientos al cliente según el estado del caso.
   - Plan de mi día: en «Mi día» explica en qué orden y bloques hacer las tareas (no cambia el orden).
   - Resumen del negocio: «Explícame la semana» en el Resumen del negocio.
   - Análisis de conversaciones: en el Resumen del negocio analiza a pedido una muestra de conversaciones del período (envía su texto a OpenAI).
4. Pulsa «Guardar». Necesita una integración de OpenAI activa en Integraciones; si no la hay, la pantalla lo avisa.

### Parámetros de ventas
1. Entra a Ajustes › Casos y etapas › Parámetros de ventas (si la clase Ventas no está activa, la pantalla lo dice).
2. En Cotizaciones: «Las cotizaciones requieren oportunidad» (si está marcada, cada cotización nueva sin oportunidad crea la suya) e «Impuesto por defecto de las partidas (%)».
3. En «Prospectos y clientes automáticos» marca cuándo una organización pasa sola:
   - a prospecto: «Al crear una oportunidad» o «Al enviar una cotización» (si el contacto no tiene organización, se le crea);
   - a cliente: «Al ganar una oportunidad», «Al dar de alta un contrato» o «Al aceptarse una cotización».
4. «Moneda por defecto»: el código de 3 letras con el que nace cada oportunidad (por ejemplo MXN o USD) y «Guardar». Cada oportunidad puede cambiarla.
Las casillas se guardan solas al marcarlas.

### Quién ve el Resumen del negocio
1. Entra a Ajustes › Casos y etapas › Resumen del negocio: acceso.
2. Marca a los usuarios que también pueden verlo (los administradores siempre lo ven: «Administrador · siempre») y pulsa «Guardar».

### Reapertura de casos cerrados
1. Entra a Ajustes › Casos y etapas › Ajustes del módulo.
2. En «Ventana de reapertura» escribe los días desde el cierre en los que una respuesta del cliente reabre el caso (0 = sin límite) y pulsa «Guardar». Pasado el plazo se crea un caso nuevo ligado al anterior.
3. Prende o apaga «Reabrir si el cliente responde» (se guarda solo).
Ahí mismo, «Ir a Tipos de caso» te lleva a donde se decide si cada tipo maneja ITIL.

### Configurar el folio
1. Entra a Ajustes › Casos y etapas › Configuración de folio.
2. Deja marcado «Generar folio automático para nuevos casos».
3. Escribe la «Plantilla del folio» o pulsa los datos disponibles para agregarlos: {PREFIX} (prefijo del tipo de caso), {SEQ:5} (consecutivo de 5 dígitos), {YYYY} o {YY} (año), {MM} (mes) y {DD} (día). Revisa la «Vista previa».
4. En «Alcance del consecutivo» marca si es independiente por tipo de caso, y en «Reinicio del consecutivo» elige Nunca, Diario, Mensual o Anual. Pulsa «Guardar».

## Dudas frecuentes
- ¿Cuándo corren las reglas? Al crear un caso (venga de un mensaje, del portal, de una llamada perdida o hecho a mano) y cuando su SLA se vence.
- Si al crear el caso alguien eligió responsable o equipo a mano, las reglas no lo cambian. Tampoco gana una regla sobre el responsable fijo del contacto o su organización.
- «Agregar etiqueta» y «Activar seguimiento» necesitan que el caso tenga conversación; un caso creado a mano sin conversación no recibe nada.
- Si ningún tipo de caso maneja ITIL, la acción «Escalar» no sale y en «Estado» solo se ofrecen los estados simples.
- ¿Cambiar la plantilla cambia folios viejos? No, solo los de los casos nuevos.
- ¿Las oportunidades se reabren si el cliente responde? No. Una oportunidad Ganada o Perdida se queda cerrada; en su historial queda el aviso de que el cliente escribió y, si hace falta, se reabre a mano. «Reabrir si el cliente responde» y su ventana aplican solo a los casos de servicio.
- Un administrador o supervisor puede reabrir a mano en cualquier momento con «Reabrir». Al reabrir, el SLA vuelve a contar desde cero.
- Los motivos de cierre y los tipos de caso están en Catálogos; el orden de Mi día se ajusta aparte, en Ajustes › Puntaje de tareas.

## Quién puede
Solo el Administrador ve y cambia Ajustes › Casos y etapas.
