# Base de Conocimiento — Manual de uso

## ¿Qué es?

La Base de Conocimiento indexa contenido de distintas fuentes y lo convierte en vectores semánticos mediante embeddings de OpenAI. Esto permite encontrar información relevante por **similitud de significado**, no solo por palabras clave exactas.

Las fuentes soportadas son:

- **Discourse** — foros; se sincronizan topics completos en tiempo real
- **Respuestas Predefinidas** — atajos de respuesta de la cuenta; se actualizan automáticamente

---

## Prerrequisito: integración con OpenAI

El sistema necesita OpenAI para generar los vectores. Sin esto, ningún contenido se indexa.

> **Ajustes → Integraciones → OpenAI → ingresar la API Key y activar**

---

## Acceso al módulo

**Ajustes → Base de Conocimiento**

La pantalla tiene tres pestañas:

| Pestaña | Para qué sirve |
|---|---|
| **Contenido indexado** | Ver y buscar todo el contenido ya vectorizado |
| **Fuentes** | Administrar las fuentes de datos |
| **Prueba de búsqueda** | Probar búsqueda semántica en tiempo real |

---

## Fuentes

### Respuestas Predefinidas

Esta fuente **aparece siempre y no se puede eliminar**. Se mantiene actualizada de forma completamente automática — no requiere intervención manual en el uso diario.

#### Qué se indexa de cada respuesta

El sistema combina el short code y el contenido en un solo texto para el vector:

```
saludo_inicial: Hola, ¿en qué te puedo ayudar hoy?
```

Esto permite buscar tanto por el atajo como por el significado del contenido.

#### Sincronización automática

Cada vez que se toca una respuesta predefinida en Ajustes → Respuestas Predefinidas, el índice se actualiza solo en cuestión de segundos:

| Acción | Qué pasa en el índice |
|---|---|
| **Crear** una respuesta | Se genera su vector y se agrega al índice |
| **Editar** short code o contenido | Se regenera el vector con los datos nuevos |
| **Eliminar** una respuesta | Se elimina del índice automáticamente |

#### Botón "Sincronizar"

Re-indexa **todas** las respuestas predefinidas desde cero. Solo es necesario si:

- Se configuró la integración OpenAI después de haber creado las respuestas
- Se sospecha que el índice está desincronizado por algún error previo

En el uso normal no hace falta tocarlo.

---

### Fuentes Discourse

#### Qué datos se necesitan para crear una fuente

Al abrir el modal "Agregar Fuente" se piden los siguientes campos:

| Campo | Descripción |
|---|---|
| **Nombre** | Etiqueta interna (ej: "Foro de Nutrición") |
| **URL del foro** | Dirección base sin barra final (ej: `https://foro.ejemplo.com`) |
| **API Key** | Clave de Discourse para leer topics y gestionar webhooks |
| **Webhook Secret** | Secreto HMAC para validar eventos entrantes — se genera automáticamente |

Y opcionalmente, en la pestaña **Categorías**: qué categorías indexar. Sin selección = todas.

#### Sobre la API Key de Discourse

La API Key debe ser de **administrador con acceso Global** — no de solo lectura. Discourse requiere permisos de administrador para leer topics de cualquier categoría y para crear, actualizar y eliminar webhooks desde la API.

Para crearla:

> Discourse → Admin → API → **New API Key**  
> User Level: **All Users** (Global)  
> Key Scope: **Global**

---

#### Qué pasa al crear una fuente Discourse

Al hacer clic en **Agregar fuente** ocurren tres cosas en secuencia:

**1 — Se guarda la fuente en Chatwoot**

Se crea el registro con todos los datos: URL, API Key, Webhook Secret y categorías elegidas.

**2 — Chatwoot crea el webhook en Discourse automáticamente**

Usando la API Key, Chatwoot llama a la API de Discourse y registra un webhook con:

- URL destino: `https://tu-chatwoot.com/webhooks/discourse/{id_de_la_fuente}`
- Eventos: topic_created, topic_edited, topic_destroyed, post_created, post_edited, post_destroyed
- Secret: el Webhook Secret del formulario
- Verificación SSL: activada

Una vez creado, Discourse envía un ping inicial para confirmar que la URL responde. El ID del webhook queda guardado internamente para poder editarlo o eliminarlo después.

**3 — Se inicia la sincronización inicial completa**

Se encola un job que recorre todo el foro (o solo las categorías elegidas) y:

- Obtiene el nombre de cada categoría y los IDs de los topics "About the X category" para excluirlos
- Recorre el listado de topics página a página
- Encola un job individual por cada topic con un delay escalonado de 400 ms entre cada uno, para no exceder el rate limit de Discourse (~150 topics/min)
- Marca la fuente con estado "Sincronizando" y muestra el contador de pendientes en la UI

Cada job individual descarga el topic, extrae el contenido del primer post, lo divide en chunks si es necesario, genera los vectores con OpenAI y los guarda en el índice. Cuando el último job termina, la fuente vuelve a estado "Idle" y registra la fecha de última sincronización.

---

#### Qué pasa cuando Discourse crea, edita o elimina un topic

Una vez creada la fuente, Discourse notifica a Chatwoot en tiempo real mediante el webhook. Chatwoot verifica la firma HMAC del evento antes de procesarlo — si no coincide, lo rechaza.

Según el evento recibido:

| Evento en Discourse | Qué hace Chatwoot |
|---|---|
| Topic **creado** | Descarga el topic, lo chunkea, genera vectores, lo agrega al índice |
| Topic **editado** | Actualiza los vectores; si el topic se acortó, elimina los chunks sobrantes |
| Topic **eliminado** | Elimina todos los registros del índice correspondientes a ese topic |
| Post **creado o editado** | Extrae el topic_id del post y re-indexa el topic completo |
| Post **eliminado** | Elimina los registros del topic del índice |

Si la fuente tiene categorías filtradas, el webhook verifica que el topic pertenezca a una de ellas antes de procesar. Si no pertenece, se ignora el evento.

---

#### Qué pasa al actualizar una fuente y cambiar las categorías

Al guardar los cambios, el sistema compara las categorías anteriores con las nuevas y actúa según el caso:

| Cambio detectado | Acción inmediata |
|---|---|
| Se **quitaron** categorías | Los items indexados de esas categorías se eliminan del índice |
| Se **agregaron** categorías | Se sincroniza solo el contenido de las categorías nuevas |
| Se pasó de específicas a **"todas las categorías"** | Se re-sincroniza el foro completo |
| Se pasó de "todas" a **categorías específicas** | Se eliminan los items que no pertenecen a las categorías elegidas |

El webhook en Discourse también se actualiza automáticamente para reflejar cualquier cambio.

---

#### Qué pasa al usar el botón "Sincronizar"

Es una **resincronización completa desde cero**. Se comporta igual que la sincronización inicial al crear la fuente: recorre todos los topics actuales y hace upsert de cada uno — si ya existe en el índice lo actualiza, si es nuevo lo agrega.

Útil cuando:

- Se sospecha que hay topics que no fueron indexados por alguna interrupción
- Se cambió la API Key o la configuración y se quiere asegurar consistencia
- La sync inicial falló parcialmente

---

#### Qué pasa al eliminar una fuente Discourse en Chatwoot

Al confirmar la eliminación ocurren dos cosas de forma inmediata:

**1 — Se elimina el webhook en Discourse**

Chatwoot llama a la API de Discourse y elimina el webhook registrado. A partir de ese momento Discourse deja de enviar eventos a esa URL.

**2 — Se elimina todo el contenido indexado**

La fuente y todos sus items vectorizados se eliminan permanentemente de la base de datos. No hay recuperación posible — si se vuelve a crear la fuente hay que sincronizar de nuevo.

---

#### Indicadores en la tarjeta de cada fuente

| Indicador | Significado |
|---|---|
| 🟢 Webhook activo en Discourse | El webhook está creado y funcionando |
| ⚪ Webhook no configurado | Falló la creación automática al guardar |
| Pulso azul "Sincronizando — N restantes" | Sync en progreso, N topics pendientes |
| "Última sync: fecha" | Cuándo terminó la última sincronización |

---

### Por qué usar fuentes con categorías específicas

El propósito principal es **organizar el conocimiento por dominio** y tener control preciso sobre qué contenido se indexa.

Un foro real suele tener categorías mezcladas con utilidad muy distinta:

```
📁 Nutrición          → contenido médico relevante para el bot
📁 Entrenamiento      → contenido de fitness relevante para el bot
📁 Off-topic          → conversaciones generales sin valor de conocimiento
📁 Anuncios internos  → información interna que no debe exponerse
```

Creando **una fuente por dominio**, cada una apunta solo a sus categorías:

| Fuente | Categorías indexadas |
|---|---|
| "Conocimiento Nutrición" | Nutrición |
| "Conocimiento Fitness" | Entrenamiento |

Ventajas concretas:

- **Precisión en la búsqueda** — el motor semántico solo busca en el conocimiento relevante al contexto, sin ruido de otras categorías
- **Clasificación clara** — en "Contenido indexado" se puede filtrar por fuente y ver exactamente qué está indexado y de dónde viene
- **Control de actualizaciones** — si una categoría cambia con frecuencia, se puede sincronizar solo esa fuente sin afectar las demás
- **Privacidad** — el contenido de categorías internas o no relevantes simplemente no se indexa y no aparece en búsquedas

---

## Contenido extenso — cómo se maneja

### Topics de Discourse

Los topics largos se dividen en **fragmentos (chunks)** antes de indexarse. Cada chunk es un registro independiente con su propio vector.

| Parámetro | Valor | Equivalente |
|---|---|---|
| Tamaño máximo por chunk | 6.000 caracteres | ~1.500 tokens |
| Solapamiento entre chunks | 800 caracteres | ~200 tokens |
| Límite del modelo OpenAI | 8.191 tokens | margen amplio |

**Cómo se divide el texto:**

1. Se respetan los límites de párrafo (`\n\n`) como separación natural
2. Si un párrafo solo ya supera los 6.000 caracteres, se subdivide por oraciones (`.` `!` `?`)
3. Cada chunk nuevo arranca con los últimos 800 caracteres del chunk anterior, preservando el contexto en los puntos de corte

**Cómo se ven en la interfaz:**

Un topic "Guía de instalación" dividido en 3 chunks aparece como tres filas en Contenido indexado:

```
Guía de instalación (1/3)
Guía de instalación (2/3)
Guía de instalación (3/3)
```

En la Prueba de búsqueda, cada resultado muestra una etiqueta `chunk 2/3` para identificar qué parte del topic es relevante.

**Actualización inteligente:** si un topic editado se reduce (pasa de 3 chunks a 2), el chunk sobrante se elimina automáticamente. No quedan registros huérfanos.

### Respuestas Predefinidas

No se dividen en chunks — siempre se indexan como un único registro. Las respuestas predefinidas son textos cortos por diseño y están muy por debajo del límite del modelo.

---

## Pestaña: Contenido indexado

Tabla con todo el contenido vectorizado de todas las fuentes.

**Filtros disponibles:**

- Por fuente
- Por categoría (aparece al seleccionar una fuente Discourse)
- Búsqueda por texto en título o contenido

Clic en cualquier fila abre el contenido completo en un modal.

---

## Pestaña: Prueba de búsqueda

Permite probar la búsqueda semántica antes de usarla en producción.

| Campo | Descripción | Valor por defecto |
|---|---|---|
| **Consulta** | Pregunta en lenguaje natural | — |
| **Resultados máximos** | Cuántos resultados devolver (1–20) | 5 |
| **Umbral de similitud** | Qué tan parecido debe ser el resultado (0 = cualquier cosa, 1 = idéntico) | 0.3 |

> Umbral recomendado: **0.3–0.5**. Por debajo de 0.3 aparecen resultados poco relevantes; por encima de 0.6 puede no haber resultados aunque el contenido exista.

**Colores del puntaje de similitud:**

| Color | Rango | Interpretación |
|---|---|---|
| 🟢 Verde | ≥ 60% | Muy relevante |
| 🟡 Amarillo | 40–59% | Posiblemente útil |
| ⚪ Gris | < 40% | Coincidencia débil |

Clic en cualquier resultado muestra el contenido completo.

---

## Preguntas frecuentes

**¿Por qué no aparece contenido después de agregar una fuente Discourse?**

La sincronización inicial puede tardar varios minutos si el foro tiene muchos topics. El contador "N restantes" en la tarjeta de la fuente muestra el progreso.

**¿Por qué la tarjeta dice "Webhook no configurado"?**

Falló la conexión con Discourse al crear la fuente. Verificar que la API Key tenga permisos de administrador Global y editar + guardar la fuente para reintentar.

**¿Puedo indexar solo algunas categorías?**

Sí. Al crear o editar la fuente, ir a la pestaña Categorías y seleccionar las deseadas. Sin selección = todas las categorías.

**¿Qué pasa si edito una Respuesta Predefinida?**

Se actualiza en el índice automáticamente en segundos, sin ninguna acción manual.

**¿El Webhook Secret se puede regenerar?**

No desde la interfaz. Cambiar el secreto requeriría actualizar también el webhook en Discourse manualmente, por lo que el campo queda bloqueado al editar una fuente existente.

**¿Qué pasa si la API Key de OpenAI no está configurada?**

Los jobs de sincronización se ejecutan pero no generan vectores. El contenido no se agrega al índice. Al configurar la integración OpenAI y hacer una sincronización manual, todo se indexa correctamente.
