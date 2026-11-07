---
key: base_conocimiento
title: Base de Conocimiento
areas: [ai_agents]
keywords: [base de conocimiento, fuente, fuentes, agregar fuente, sincronizar, contenido indexado, consola de busqueda, respuestas predefinidas, centro de ayuda, discourse, foro, google doc, google sheets, hoja de google, contpaqi, vectorizar, de donde saca la respuesta el agente, conocimiento del agente]
pages: [ai_agents, knowledge_sources, canned_responses]
---
## Para qué sirve
La Base de Conocimiento junta la información de la que tus agentes IA sacan sus respuestas: tus respuestas predefinidas, los artículos del Centro de Ayuda, foros, documentos y hojas de Google. Cuando un cliente pregunta algo, el agente busca aquí por significado y contesta con lo que encuentra, en lugar de inventarlo.

## Dónde está
Agentes IA › Base de Conocimiento. Tiene las pestañas:
- Contenido indexado: todo lo que ya se puede buscar, con filtro por fuente y categoría y un buscador.
- Fuentes: una tarjeta por fuente, con su estado (Activo o Inactivo), la última sincronización y los botones para sincronizar, editar y borrar.
- Consola de Búsqueda (Fuentes): escribe una consulta y ves qué encontraría el agente.
Algunas empresas ven además pestañas de configuración o de conexión con su sistema administrativo, si la plataforma se las activó.

## Cómo se hace
### Saber qué fuentes hay
Hay dos fuentes que ya vienen y no se dan de alta:
- Respuestas predefinidas: las de Catálogos › Respuestas Predefinidas.
- Centro de Ayuda: los artículos de tu Centro de ayuda.
Y estas se agregan a mano: Discourse (un foro), Agente de Servicio CONTPAQi, y, si la empresa tiene activa la integración de Google, Google Doc y Google Sheets.

### Agregar una fuente
1. Pulsa «Agregar Fuente».
2. En «Tipo de fuente» elige Discourse, Agente de Servicio CONTPAQi, Google Doc o Google Sheets.
3. Escribe el «Nombre». Debe ser único: con ese nombre la llama el Entrenamiento del agente.
4. Llena los datos de ese tipo: en Discourse, la URL del foro, la API Key y el usuario; en Google Doc, la URL del documento; en Google Sheets, la URL de la hoja, si es FAQ o Datos, el rango y si se consulta en vivo.
5. Pulsa «Agregar fuente».
6. En la pestaña Fuentes pulsa «Sincronizar» para que se lea su contenido.

### Probar qué encuentra
1. Abre la pestaña «Consola de Búsqueda (Fuentes)».
2. En «Consulta» escribe una pregunta como la haría un cliente y pulsa «Buscar». Verás los textos que el agente usaría.

## Dudas frecuentes
- ¿Qué agentes la usan? Los agentes de Agentes IA › Agentes: cada tema de su Entrenamiento dice de qué fuente saca la respuesta. Seguimiento IA («Delegar seguimiento») solo usa las Respuestas predefinidas, nada más.
- ¿Por qué no sale mi respuesta predefinida? Revisa que la fuente esté activa y sincronizada. Para buscar por significado hace falta la integración de OpenAI de la empresa; sin ella la tarjeta lo avisa.
- Google Doc y Google Sheets usan la conexión de Google de la cuenta, y el documento debe poderse abrir con esa cuenta.
- Discourse no se sincroniza: se consulta en vivo.
- En la fuente CONTPAQi, la respuesta la redacta CONTPAQi y se entrega tal cual, con el enlace a su documentación; el tono del Entrenamiento no se aplica.
- Los datos que cambian seguido (precios, horarios, requisitos) conviene tenerlos en respuestas predefinidas: se editan en un solo lugar y el agente siempre usa lo último.

## Quién puede
La ven quienes tienen el área Agentes IA: el Administrador y, por omisión, el Supervisor solo para consultar. Agregar, editar, sincronizar o borrar fuentes pide el área Agentes IA en «todo» (por omisión, solo el Administrador).
