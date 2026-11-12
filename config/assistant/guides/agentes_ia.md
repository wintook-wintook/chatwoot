---
key: agentes_ia
title: Agentes IA
areas: [ai_agents]
keywords: [agente ia, agentes ia, nuevo agente, crear agente, entrenamiento, asistente de agentes, ficha del agente, versiones, restaurar version, probar agente, publicar cambios, galeria, prompts publicados, bajar de la galeria, canal del agente, bandeja del agente, bot de seguimientos, rutas, en construccion, contexto ia]
pages: [ai_agents, trackings]
---
## Para qué sirve
Un agente IA es un asistente que le escribe a tus clientes y les contesta en tu nombre. Cada agente tiene un nombre, un objetivo, la bandeja (canal) donde trabaja y su Entrenamiento: las instrucciones que sigue y los temas que atiende, con la fuente de la que saca cada respuesta. Los usan los seguimientos, las campañas de agentes IA y las reglas de automatización.

## Dónde está
Agentes IA › Agentes. La lista muestra Nombre, Objetivo, Canal, Acciones y Actualizado; se busca por nombre y se filtra por canal. Los administradores ven además la columna Revisión y las pestañas «En construcción» (agentes que se están armando y no se han publicado) y «Recursos».
Al abrir un agente entras a su espacio, con tres pestañas: Entrenamiento, Ficha y Versiones.

## Cómo se hace
### Crear un agente
1. En Agentes IA › Agentes pulsa «Nuevo agente».
2. Elige cómo empezar: «Con el Asistente (conversar, pegar o importar)», «Bajar de la Galería» o «Formulario en blanco».
3. Con el Asistente, cuéntale qué quieres que haga el agente; él escribe el Entrenamiento y tú lo puedes editar a mano. También puedes pegar un prompt o usar «Crear desde instrucciones (.md)».
4. Cuando el comprobador ya no marque problemas, pulsa «Crear el Agente IA» y llena nombre, objetivo y bandeja.

### Probarlo antes de publicar
1. En la pestaña Entrenamiento usa «Probar sin enviar nada»: escribe una pregunta como la haría un cliente y ves a qué tema cae, en qué fuente busca y qué encuentra. No se envía ningún mensaje.
2. Con el agente ya creado, «Probar el agente» corre una pila de pruebas con el motor real en el canal de pruebas y deja descargar el informe.
3. «Analizar» revisa el texto contra las reglas del motor, «Optimizar» propone una versión más corta y «Explicar selección» te dice qué hace un fragmento.

### Publicar cambios y volver atrás
1. Edita en la pestaña Entrenamiento y pulsa «Publicar cambios». Queda guardado como una versión nueva.
2. En la pestaña Versiones ves cada cambio, quién lo hizo y desde dónde; «Ver cambios» muestra las diferencias.
3. «Restaurar» regresa el agente a una versión anterior sin borrar nada: vuelve como una versión nueva.

### La Ficha y la bandeja del agente
1. En la pestaña Ficha están el nombre, el objetivo, «Nombre que verá el cliente» y el Contexto IA (datos del negocio que el agente puede citar).
2. En «Agente seguimiento» eliges el «Canal (Inbox)», el número de intentos, el tiempo entre intentos y, en WhatsApp, la plantilla de cada intento. En correo hay además «Firma para correo».
3. Pulsa «Guardar Cambios».
Solo aparecen las bandejas que tienen activo el Bot de Seguimientos en Ajustes › Integraciones.

### Bajar un prompt publicado
1. En la pestaña Entrenamiento pulsa «Prompts publicados» (o «Nuevo agente» › «Bajar de la Galería»).
2. Revisa uno y pulsa «Bajar a mi cuenta». Queda como un agente nuevo tuyo; adáptalo a tu negocio con el Asistente.

## Dudas frecuentes
- ¿Cómo llega un agente a mis clientes? Con un seguimiento («Delegar seguimiento» › «¿Quién le da seguimiento?» › «Un agente a medida»), con una campaña de Campañas › De agentes IA o con la acción «Asignar Agente IA» de una regla en Agentes IA › Automatización.
- ¿Cómo contesta? En la conversación del seguimiento: le escribe al cliente en cada intento y, cuando el cliente responde, contesta según su Entrenamiento y las fuentes de la Base de Conocimiento que usan sus temas.
- ¿Por qué no puedo borrar un agente? Si tiene seguimientos activos, campañas o automatizaciones que lo usan, primero hay que quitarlo de ahí.
- El Asistente necesita la integración de OpenAI de la empresa.
- Publicar un prompt para otras empresas solo lo puede hacer un usuario que el equipo de la plataforma autorizó.

## Quién puede
El área Agentes IA la ve el Administrador y, por omisión, el Supervisor solo para consultar. Crear o cambiar agentes pide el área Agentes IA en «todo»; la pestaña Entrenamiento con el Asistente, la Galería y restaurar versiones son solo para administradores. Vendedor, Técnico y Consulta no entran, salvo que el administrador lo cambie en Ajustes › Roles.
