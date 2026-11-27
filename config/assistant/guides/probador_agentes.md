---
key: probador_agentes
title: Probar agentes (probador)
areas: [ai_agents]
keywords: [probar agentes, en prueba, poner en prueba, modo prueba, probador, probar agente, probar mi agente, prueba del agente, contesta mal, error del agente, por que contesto, pulgar abajo, corregir respuesta, lote de pruebas, lotes, correr pruebas, bitacora, error del prompt, error del contenido, error del modelo, error del motor, reporte, canal de pruebas, motor 1.0, motor 2.0, busqueda nueva, busqueda de siempre, comparar busquedas, importar preguntas, pegar preguntas, pila del agente, empeoraron, mejoraron, cambiar categoria, agregar al inicio, datos inventados, revision, revisar respuestas, que debio responder, pulgar arriba, no es error, otro diagnostico, probar de nuevo, ver diagnostico al momento]
pages: [ai_agents, trackings]
---
## Para qué sirve
Para probar cualquier agente a medida (Motor 1.0 o 2.0) como si fueras el cliente, sin usar WhatsApp. Contesta el motor de verdad, igual que con un cliente, pero en un canal de pruebas: no sale nada a ningún lado. Quien prueba solo marca lo que estuvo mal y qué debió responder; quien entrena el agente revisa después la causa y la corrige.

## Dónde está
Inicio › Probar agentes: lo ve cualquier usuario. Solo salen los agentes que están «En prueba»; si no hay ninguno, dice «No hay agentes en prueba por ahora».
Quien puede cambiar agentes pone un agente en prueba en Agentes IA › Agentes, con el botón «Poner en prueba» de su renglón (sirve para agentes 1.0 y 2.0; en un 2.0 también está arriba en su ficha). Los agentes en prueba llevan la etiqueta «En prueba».
Quien puede cambiar agentes ve además las pestañas Revisión (con cuántas respuestas hay por revisar), Lotes de pruebas y Bitácora.

## Cómo se hace
### Probar un agente
1. En Probar elige el agente (dice si es Motor 1.0 o 2.0). Si quieres, elige la búsqueda de respuestas predefinidas para esa plática: «Búsqueda: la de la cuenta», «Búsqueda nueva» o «Búsqueda de siempre» (solo cambia en la plática de prueba, no en la cuenta). Pulsa «Empezar».
2. Escribe como lo haría un cliente. El agente contesta en unos segundos (el 2.0 espera a que termines de escribir, como en real).
3. Bajo cada respuesta ves qué hizo: la ruta, la fuente y los fragmentos que consultó (1.0) o las fuentes y habilidades (2.0). Si la empresa tiene la búsqueda nueva de respuestas predefinidas, también ves cuántas candidatas juntó, cuáles escogió y por qué, si ninguna contestaba y los datos que se quitaron por no estar en las fuentes.
4. «Plática nueva» empieza de cero, como un cliente nuevo.

### Cuando una respuesta está mal (quien prueba)
1. Pulsa 👎 y escribe «¿Qué debió responder?» (obligatorio). Si quieres, también «¿Qué estuvo mal?». Pulsa «Enviar».
2. Sale «Gracias, quedó para revisión». No tienes que hacer nada más: quien entrena el agente la revisa.
3. Si una respuesta estuvo bien, pulsa 👍: queda guardada como prueba «a cuidar», para saber si después se rompe.

### Revisión (quien entrena)
1. En la pestaña Revisión salen las pláticas con 👎, las que tienen pendientes primero. Filtra por agente o ve «Todas».
2. Abre una plática: se ve completa, mensaje por mensaje, con los 👍 y 👎. Bajo cada 👎: lo que debió responder, lo que estuvo mal (si lo escribieron) y la causa que encontró el entrenador (mientras la busca dice «Revisando la causa…»).
3. Arréglala con los botones de esa causa y pulsa «Corregido · probar de nuevo». Si varios 👎 apuntan a la misma respuesta, «Probar de nuevo los N con la misma respuesta» los prueba juntos.
4. «No es error» la descarta (escribe por qué en la nota) y su prueba ya no se corre. «Otro diagnóstico» vuelve a buscar la causa con lo que escribas en la nota.
5. Si tú pruebas el agente y quieres ver la causa en ese momento, al dar 👎 marca «Ver diagnóstico al momento».

### Qué dice cada causa
1. El entrenador dice de quién es el error:
   - ✏️ Prompt: falta indicarle algo. Te da la indicación lista y dónde va. En un agente 2.0 pulsa «Aplicar»; en uno 1.0 cópiala («Copiar») y pégala en su Entrenamiento («Abrir el agente»). Prueba de nuevo.
   - 📚 Contenido: la fuente tenía el dato mal o no lo tenía. Te enseña lo que dice; si es una respuesta predefinida la corriges ahí mismo («Corregirla»); si no, en la fuente. Si el texto corregido pasa de 3,500 caracteres no se guarda: te lo dice y con «Abrirla para partirla con IA» la abres en Respuestas Predefinidas. Prueba de nuevo.
   - 🔎 Búsqueda: la respuesta con el dato existe pero no le llegó al agente. Con la búsqueda nueva te dice si ni siquiera estuvo entre las candidatas (ponle un nombre que diga de qué trata) o si estuvo y no se escogió (revisa su nombre y su categoría). «Agregar al inicio de la respuesta» le pone cómo lo pregunta el cliente; «Abrir la respuesta» la abre para editarla.
   - 🏷️ Categoría: llegó la respuesta de otro producto o una objeción usada como dato: su categoría (General, Ficha u Objeción) está mal. «Cambiar a «Ficha»» la corrige con un clic.
   - 🧭 Dónde busca (agentes 2.0): el dato sí estaba en una de sus fuentes, pero buscó en otra porque lo que dice esa fuente en «¿Qué hay aquí?» no lo deja ver. Te propone cómo debe decir; «Cambiar «¿Qué hay aquí?»» lo guarda en Bases de conocimiento con un clic.
   - 🧠 Modelo: la indicación y el dato estaban y el modelo no los siguió. Te dice dónde subir el modelo. Si la indicación que haría falta ya está escrita en el Entrenamiento, te lo dice en vez de pedirte que la agregues otra vez.
   - Si la respuesta trae un monto, porcentaje o código que no está en ninguna fuente, el entrenador lo trata como dato inventado: la causa es el contenido o la búsqueda, nunca el prompt.
   - 🔧 Motor: algo que el motor no hace o no cumplió. No lo puedes corregir tú: queda registrado y el equipo de Kontrolya lo revisa.
2. Si no está seguro, hace una pregunta: contéstala en la nota y pulsa «Otro diagnóstico» (o «Contestar» si estás viendo el diagnóstico al momento).
3. No hay que guardar nada: cada 👎 queda solo como prueba en el lote del agente y del día («Pruebas · <agente> · 17 nov»), con lo que escribiste en el 👎 como lo esperado, toda la plática del cliente y de qué se hablaba (por ejemplo la carrera o el producto), para que al correrla no se pierda el tema. Ahí caen los de todos los usuarios ese día. Cuando Kontrolya corrige un error del motor, el lote de ese día se vuelve a correr solo.
4. En un agente 1.0, si alguien cambia su Entrenamiento mientras pruebas, la plática abierta sigue con el anterior: el probador te avisa y empiezas una plática nueva. En un 2.0 y en el contenido, la corrección se ve desde el siguiente mensaje (también con clientes reales).

### Lotes de pruebas
1. En Lotes de pruebas crea un lote (por ejemplo «Becas») y agrégale pruebas: lo que escribe el cliente (un mensaje por renglón) y qué se espera.
2. También puedes guardar a mano una plática que quieras cuidar (por ejemplo, una que salió bien): en Probar, «Guardar como prueba (manual)», escribe qué se espera y pulsa «Guardar prueba». Va sola al lote del agente y del día, igual que las de 👎; cada prueba dice si es «de una corrección» o «manual».
3. Filtra por agente para ver sus lotes día por día; «Correr todas las pruebas de este agente» junta las pruebas de todos sus días en una sola corrida.
4. Elige el agente y pulsa «Correr»: cada prueba se corre con el motor real y un juez dice si cumple. El resultado sale en la Bitácora. Una respuesta que trae un monto, porcentaje o código que no está en sus fuentes no pasa.
5. Arriba elige con qué búsqueda de respuestas predefinidas corren («la de la cuenta», «nueva» o «de siempre»). «Comparar búsquedas» corre las mismas pruebas dos veces, una con cada búsqueda, para ver cuál contesta mejor sin cambiar nada en la cuenta.
6. «Importar preguntas» (con un agente elegido): pega filas copiadas de una hoja (Excel o Sheets) con los mensajes del cliente, lo que se espera y, si quieres, de qué se habla («CARRERA=Licenciatura en Derecho»). Varios mensajes en la misma celda van separados por «|». Te dice cuántas entraron y qué filas no. «Traer la pila vieja del agente» convierte las pruebas de «Pruebas y diagrama» del 1.0 en un lote.

### Bitácora
- Corridas: cada lote corrido, con qué agente y con qué búsqueda, cuántas pasaron y, por prueba, qué contestó y por qué cumple o no. Arriba dice cuántas empeoraron (pasaban la vez anterior con el mismo agente) y cuántas mejoraron; cada prueba lleva «antes pasaba» o «antes fallaba».
- Correcciones: cada 👎 con de quién fue el error. Los del motor muestran el estado de su reporte (nuevo, en revisión, corregido). Quien solo prueba ve aquí sus 👎 y cómo van (pendiente, probando, quedó, no es error), sin la causa.

## Dudas frecuentes
- ¿Le llega algo al cliente? No: el probador usa su propio canal de pruebas («Probador de agentes»).
- ¿Contesta igual que en real? Sí: es el mismo motor y, en el 1.0, el mismo modelo de la bandeja del agente.
- ¿El probador cambia mi agente solo? No. Lo de prompt y contenido lo aplicas tú; en el 1.0 el Entrenamiento se edita en su pantalla de siempre.
- El agente dejó de contestar en la plática: alguna palabra clave o «no me escriban» terminó el seguimiento; empieza una plática nueva.

## Quién puede
Probar, dar 👍 o 👎 y guardar pruebas: cualquier usuario (cada quien ve sus propias pláticas y sus 👎, sin la causa). Revisión, ver el diagnóstico al momento y aplicar una corrección, corregir una respuesta predefinida (también cambiarle la categoría o agregarle algo al inicio), poner agentes «En prueba», los lotes, importar preguntas y la bitácora: quien puede crear o cambiar agentes (área Agentes IA en «todo»). Lo que marcan los demás llega solo a Revisión.
