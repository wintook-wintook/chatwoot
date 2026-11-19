---
key: ajustes_catalogos
title: Ajustes y catálogos
areas: [settings]
keywords: [ajustes, configuracion, configuracion de cuenta, nombre de la cuenta, idioma, idioma del sitio, id de la cuenta, logo, marca, color de la empresa, nombre del asistente, modelo de openai, modelos de ia, que modelo usa, resolver automaticamente, facturacion, plan, licencias, catalogo, catalogos, etiquetas, crear etiqueta, atributos personalizados, campo extra, respuestas predefinidas, plantillas de whatsapp, productos y servicios, motivos de cierre, ganada, perdida, pospuesta, cancelada, resultados de tareas, tiempo dedicado, motivos de cancelacion, embudos de contactos, tipos de caso, clasificaciones, politicas sla, tipos de contrato, datos propios, puntaje de tareas, pesos, restaurar de fabrica, casos y etapas, folio]
pages: [settings, catalog, account_settings, users, roles, teams, inboxes, integrations, billing, case_types, close_reasons, task_outcomes, labels, custom_attributes, canned_responses, whatsapp_templates, contact_funnels, contract_types, sla_policies, classifications, case_rules, task_scoring]
sources: [app/javascript/dashboard/components/layout/config/sidebarItems/v2/index.js, app/javascript/dashboard/routes/dashboard/settings/account/*.vue, app/javascript/dashboard/routes/dashboard/settings/billing/**/*.vue, app/javascript/dashboard/routes/dashboard/settings/labels/*.vue, app/javascript/dashboard/routes/dashboard/settings/attributes/*.vue, app/javascript/dashboard/views/gestorTickets/OutcomeReasonsConfig.vue, app/javascript/dashboard/views/gestorTickets/commercial/OutcomeReasons.vue, app/javascript/dashboard/views/gestorTickets/TaskOutcomesConfig.vue, app/javascript/dashboard/views/gestorTickets/TaskPriorityConfig.vue, app/javascript/dashboard/views/contracts/ContractTypes.vue, app/javascript/dashboard/i18n/locale/es/generalSettings.json, app/javascript/dashboard/i18n/locale/es/labelsMgmt.json, app/javascript/dashboard/i18n/locale/es/attributesMgmt.json]
reviewed: 2026-11-14
---
## Para qué sirve
- Ajustes: la configuración de la cuenta y quién entra y cómo trabaja. Es del Administrador.
- Catálogos: las listas que se dan de alta una vez y se usan en todo el sistema para clasificar o llenar datos.

## Dónde está
### Ajustes
- «Configuración de Cuenta»: nombre, idioma, «ID de la cuenta», «Marca de la empresa» y «Asistente» (ver abajo).
- «Usuarios» y «Roles»: quién entra y qué ve cada rol. Detalle en la guía usuarios_roles.
- «Equipos», «Bandejas de Entrada» e «Integraciones»: los canales, quién los atiende y las conexiones con otras herramientas. Detalle en la guía bandejas_integraciones.
- «Facturación»: tu plan y licencias (solo en la versión en la nube).
- «Puntaje de tareas»: cómo se ordena «Mi día».
- «Casos y etapas» (se despliega): Reglas de automatización, Inteligencia Artificial, Parámetros de ventas, Resumen del negocio: acceso, Ajustes del módulo y Configuración de folio. Las reglas se explican en la guía reglas_automatizacion_casos.

### Catálogos
- «Etiquetas» y «Atributos Personalizados»: para clasificar conversaciones y contactos, y los campos extra que quieras guardar.
- «Respuestas Predefinidas» y «Plantillas de WhatsApp»: textos listos para contestar y las plantillas aprobadas para escribir por WhatsApp. Detalle en la guía respuestas_plantillas.
- «Productos y servicios»: lo que vendes, con precio. Detalle en la guía catalogo_productos.
- «Motivos de cierre»: por qué se gana, se pierde, se pospone o se cancela una oportunidad.
- «Resultados de tareas»: las opciones del reporte de cierre de una tarea, si el tiempo dedicado es obligatorio y los «Motivos de cancelación».
- «Embudos de contactos»: los embudos y sus columnas. Detalle en la guía embudo_contactos.
- «Tipos de caso», «Clasificaciones» y «Políticas SLA»: cómo se arman los casos, sus campos, sus etapas y los tiempos de atención. Detalle en la guía tipos_caso.
- «Tipos de contrato»: los servicios recurrentes que se contratan. Detalle en la guía contratos.

## Cómo se hace
### Cambiar el nombre o el idioma de la cuenta
1. Entra a Ajustes › Configuración de Cuenta.
2. En «Configuración general» cambia el «Nombre de la cuenta» o el «Idioma del sitio» («Español (es)», «English (en)», «Português (pt)», «Português Brasileiro (pt-BR)»).
3. Si tu cuenta lo tiene, también ahí está cuántos días sin actividad para resolver solo una conversación (de 1 a 999) y los datos de correo entrante.
4. Pulsa «Actualizar configuración» (arriba). Ese botón guarda solo esta sección.
Más abajo, «ID de la cuenta» muestra el número de tu cuenta, que se usa para conectar otro sistema por la API.

### Poner el logo y el color de la empresa
1. En Ajustes › Configuración de Cuenta baja a «Marca de la empresa».
2. «Subir logo» (o «Cambiar logo»): PNG, JPG, SVG o WebP de hasta 2 MB, mejor cuadrado. «Quitar logo» lo borra.
3. En «Color de la empresa» elige: «Predeterminado», «Cálido», «Bosque», «Índigo», «Sepia», «Alto contraste», «Violeta», «Turquesa», «Rosa» o «Grafito».
Se guarda al momento. El logo sale arriba del menú y el color es el de todo el equipo; cada quien puede elegir otro en su perfil (guía mi_perfil).

### Cambiar el nombre del asistente y ver qué modelos de IA se usan
1. Entra a Ajustes › Configuración de Cuenta.
2. Baja al apartado «Asistente».
3. Escribe el «Nombre del asistente» (hasta 30 letras) o déjalo vacío para que se llame Dali.
4. Pulsa «Guardar» de ese apartado.
5. Abajo está la tabla «Modelos de IA de la plataforma»: qué modelo de OpenAI usa cada parte (Dali, Dali para cifras, agentes que atienden clientes, revisar y entrenar, escoger respuestas predefinidas, hojas de Google, agentes 1.0 y otras funciones). Es solo informativa: los modelos son los mismos para todas las cuentas y Kontrolya los cambia con una actualización cuando conviene; ya no se eligen por cuenta.

### Dar de alta motivos de cierre
1. Entra a Catálogos › Motivos de cierre. Hay cuatro grupos: «Ganada», «Perdida», «Pospuesta» y «Cancelada».
2. En el grupo, escribe en «Nuevo motivo» y pulsa «Agregar».
3. Para cambiar un motivo, edita su texto (se guarda al salir del cuadro). Desmarca «Activo» para dejar de usarlo; es mejor que borrarlo, porque conserva la historia.
Si un resultado tiene motivos activos, al marcar la oportunidad hay que elegir uno. Solo sale si la clase Ventas está activa en tu cuenta.

### Dar de alta resultados y motivos de cancelación de tareas
1. Entra a Catálogos › Resultados de tareas.
2. «Exigir el tiempo dedicado en los reportes» (viene marcado): al concluir una tarea o reportar una actividad hay que decir cuánto tomó. Se guarda al marcarlo.
3. En la lista de resultados escribe en «Nuevo resultado» y pulsa «Agregar». Vienen: Logrado, No contestó, Reprogramar, No se pudo.
4. En «Motivos de cancelación» escribe en «Nuevo motivo…» y pulsa «Agregar». Se piden al cancelar una tarea o tarea agendada; el motivo «Otro» pide escribir el motivo.
5. Edita el texto de cualquiera (se guarda al salir del cuadro) o desmarca «Activo».

### Crear una etiqueta
1. Entra a Catálogos › Etiquetas y pulsa «Agregar etiqueta».
2. Escribe el «Nombre de la etiqueta» (mínimo 2 letras, sin espacios; se guarda en minúsculas), una «Descripción» si quieres y el «Color».
3. Deja «Mostrar etiqueta en la barra lateral» si quieres verla en el menú.
4. Pulsa «Crear». Para cambiarla usa «Editar»; para quitarla, «Eliminar».

### Crear un atributo personalizado
1. Entra a Catálogos › Atributos Personalizados. Las pestañas «Conversación» y «Contacto» separan los de cada uno.
2. Pulsa «Agregar Atributo Personalizado».
3. En «Se Aplica a» elige conversación o contacto. Escribe el «Nombre para Mostrar» (la «Clave» se llena sola, sin espacios) y la «Descripción» (obligatoria).
4. Elige el «Tipo»: texto, número, liga, fecha, lista o casilla. En lista escribe los «Valores de la Lista» (Enter después de cada uno). En texto puedes «Habilitar validación regex».
5. Pulsa «Crear». Al editarlo ya no se cambian la clave ni el tipo. Para borrarlo, «Eliminar» y escribe su nombre para confirmar.

### Dar de alta un tipo de contrato
1. Entra a Catálogos › Tipos de contrato y pulsa «Nuevo tipo».
2. Escribe el «Nombre», el «Color», «Se cobra cada» (número y «días», «semanas», «meses» o «años»), el «Plazo por omisión (meses)» (vacío = sin plazo) y si «Se renueva solo al terminar el plazo».
3. En «Datos propios» pulsa «Agregar dato» para lo que pide este tipo (texto, número o fecha); hasta 20.
4. Deja «Activo (se puede elegir en contratos nuevos)» y pulsa «Guardar». No se borran: se desactivan.

### Ajustar el puntaje de tareas
1. Entra a Ajustes › Puntaje de tareas.
2. Cada situación suma puntos: vencimiento («Tarea vencida (base)», «Por cada día de atraso», «Vence hoy», «Vence mañana»…), prioridad, proyecto, soporte (SLA), orden de trabajo, oportunidad y otros («Caso en espera (cliente / tercero)» resta). Más puntos = más arriba en «Mi día».
3. Los ejemplos A y B de arriba muestran cuál quedaría primero con tus pesos.
4. Pulsa «Guardar». «Restaurar de fábrica» regresa los valores de fábrica (luego guarda). Valores permitidos: de -100 a 200.
5. «Avisar «Nueva urgente» desde este puntaje» decide desde cuántos puntos se avisa una tarea urgente nueva.

### Ver la facturación
Ajustes › Facturación muestra tu «Plan Actual» y licencias. «Ir al portal de facturación» abre tus facturas, datos de pago o la cancelación; «Chatea con nosotros» pide ayuda.

## Límites
- Borrar un motivo de cierre o un resultado de tarea pide confirmación («¿Borrar …?») y lo quita de donde se usaba; mejor desactívalo.
- Si borras todos los motivos o resultados de un grupo, vuelven los de fábrica.
- Renombrar «Otro» en motivos de cancelación hace que ya no pida escribir el motivo.

## Dudas frecuentes
- No veo Ajustes en el menú: solo lo ve el Administrador.
- En Catálogos veo menos listas que otra persona: cada quien ve las que su permiso deja abrir. La mayoría son del Administrador.
- ¿Dónde quedaron Automatización, Macros, Base de Conocimiento y Análisis de sitio? En el menú Agentes IA.
- ¿Dónde quedó Portales del cliente? En el menú Servicio.
- ¿Cambio mi nombre o contraseña aquí? No, en tu perfil (guía mi_perfil).

## Quién puede
Ajustes es solo del Administrador; ningún otro rol entra, aunque se le cambie el nivel. En Catálogos casi todo es del Administrador. Los demás pueden abrir, por ejemplo, Respuestas Predefinidas; Productos y servicios si su rol entra a Ventas o Servicio (para cambiarlo hace falta Ventas en «Todo»); y Tipos de contrato para consultar si entra a Clientes o Ventas (solo el Administrador los da de alta).
