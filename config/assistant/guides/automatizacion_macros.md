---
key: automatizacion_macros
title: Automatización y macros
areas: [ai_agents, conversations]
keywords: [automatizacion, automatizaciones, regla, reglas, regla de automatizacion, evento, condicion, condiciones, accion, acciones, asignar agente ia, agregar a campana, pausar seguimiento activo, cancelar seguimiento activo, macro, macros, ejecutar macro, crear macro, macro publica, macro privada, clonar regla, activar regla]
pages: [ai_agents, conversation, automation, macros]
---
## Para qué sirve
- Automatización: reglas que hacen algo solas cuando pasa algo en una conversación. Por ejemplo, cuando entra una conversación nueva por cierta bandeja, asignarle un agente IA, ponerle una etiqueta o inscribir al contacto en una campaña.
- Macros: un conjunto de acciones guardadas que tú ejecutas con un clic en una conversación. Por ejemplo, poner una etiqueta, mandar un mensaje y resolver la conversación, todo de una vez.

## Dónde está
- Agentes IA › Automatización: la lista de reglas con Nombre, Descripción, Activo y Creado en.
- Agentes IA › Macros: la lista de macros con Nombre, Creado por, Última actualización por y Visibilidad.
- En la conversación, el panel de la derecha tiene la sección «Macros» para ejecutarlas.

## Cómo se hace
### Crear una regla de automatización
1. Entra a Agentes IA › Automatización y pulsa «Agregar Regla de Automatización».
2. Escribe «Nombre de la Regla» y «Descripción» (los dos son obligatorios).
3. En «Evento» elige cuándo corre: «Conversación creada», «Conversación actualizada», «Mensaje creado» o «Conversación abierta».
4. En «Condiciones» define a qué conversaciones aplica, por ejemplo la «Bandeja». Con «Agregar Condición» sumas más.
5. En «Acciones» elige qué hace. Con «Agregar Acción» sumas más.
6. Pulsa «Crear». La regla queda en la lista y se prende o apaga con su interruptor.
En cada regla también están Editar, Clonar y Eliminar.

### Acciones con agentes IA
- «Asignar Agente IA»: le arranca un seguimiento al contacto con el agente que elijas. La lista muestra los agentes de la bandeja que pusiste en las condiciones. Si el contacto ya tiene un seguimiento activo en esa bandeja, no crea otro.
- «Agregar a campaña»: inscribe al contacto en una campaña de agentes IA.
- «Pausar seguimiento activo» y «Cancelar seguimiento activo»: pausan o cancelan el seguimiento del contacto en la bandeja de las condiciones; sin bandeja en las condiciones, aplican a todos sus seguimientos activos.
- También están «Asignar Caso» (le pone un tipo de caso a la conversación) y «Asignar tablero de conversación». Las demás son las de siempre, como «Asignar a un agente», «Agregar una etiqueta», «Enviar un mensaje» o «Resolver la conversación».

### Crear una macro
1. Entra a Agentes IA › Macros y pulsa «Agregar una nueva macro».
2. Escribe el «Nombre de la macro».
3. Agrega sus acciones con «Agregar nueva acción» (entre «Iniciar flujo» y «Finalizar flujo»). Por ejemplo «Agregar una etiqueta» o «Enviar un mensaje». Se ejecutan en el orden en que están; puedes reordenarlas arrastrándolas.
4. En «Visibilidad de la macro» elige «Pública» (para todos los usuarios de la empresa) o «Privada» (solo para ti).
5. Pulsa «Guardar macro».

### Usar una macro en una conversación
1. Abre la conversación y busca la sección «Macros» en el panel de la derecha.
2. Con el ícono de información ves la «Vista previa de la macro».
3. Pulsa «Ejecutar». Sale el aviso «Macro ejecutada con éxito».

## Dudas frecuentes
- ¿La regla corre sola en conversaciones viejas? No, solo cuando ocurre el evento después de crearla y mientras esté activa.
- ¿Por qué no puedo borrar un agente IA? Si una automatización lo usa, quítalo primero de esa regla.
- Antes, Automatización y Macros estaban en Ajustes; ahora están en Agentes IA.

## Quién puede
Automatización: solo el Administrador. Macros: la pantalla Agentes IA › Macros la abren quienes tienen el área Agentes IA (Administrador y, por omisión, Supervisor). Cada quien edita y borra sus propias macros; las públicas también las edita el Administrador. En la conversación, cada usuario ve las macros públicas y las suyas.
