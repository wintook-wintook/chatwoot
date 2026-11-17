---
key: probador_agentes
title: Probar agentes (probador)
areas: [ai_agents]
keywords: [probar agentes, en prueba, poner en prueba, modo prueba, probador, probar agente, probar mi agente, prueba del agente, contesta mal, error del agente, por que contesto, pulgar abajo, corregir respuesta, lote de pruebas, lotes, correr pruebas, bitacora, error del prompt, error del contenido, error del modelo, error del motor, reporte, canal de pruebas, motor 1.0, motor 2.0]
pages: [ai_agents, trackings]
---
## Para qué sirve
Para probar cualquier agente a medida (Motor 1.0 o 2.0) como si fueras el cliente, sin usar WhatsApp. Contesta el motor de verdad, igual que con un cliente, pero en un canal de pruebas: no sale nada a ningún lado. Cuando una respuesta está mal, te dice de quién es el error y qué hacer.

## Dónde está
Inicio › Probar agentes: lo ve cualquier usuario. Solo salen los agentes que están «En prueba»; si no hay ninguno, dice «No hay agentes en prueba por ahora».
Quien puede cambiar agentes pone un agente en prueba en Agentes IA › Agentes, con el botón «Poner en prueba» de su renglón (sirve para agentes 1.0 y 2.0; en un 2.0 también está arriba en su ficha). Los agentes en prueba llevan la etiqueta «En prueba».
Quien puede cambiar agentes ve además las pestañas Lotes de pruebas y Bitácora.

## Cómo se hace
### Probar un agente
1. En Probar elige el agente (dice si es Motor 1.0 o 2.0) y pulsa «Empezar».
2. Escribe como lo haría un cliente. El agente contesta en unos segundos (el 2.0 espera a que termines de escribir, como en real).
3. Bajo cada respuesta ves qué hizo: la ruta, la fuente y los fragmentos que consultó (1.0) o las fuentes y habilidades (2.0).
4. «Plática nueva» empieza de cero, como un cliente nuevo.

### Cuando una respuesta está mal
1. Pulsa 👎, escribe qué estuvo mal y cómo debió responder, y pulsa «Revisar».
2. El entrenador te dice de quién es el error:
   - ✏️ Prompt: falta indicarle algo. Te da la indicación lista y dónde va. En un agente 2.0 pulsa «Aplicar»; en uno 1.0 cópiala («Copiar») y pégala en su Entrenamiento («Abrir el agente»). Prueba de nuevo.
   - 📚 Contenido: la fuente tenía el dato mal o no lo tenía. Te enseña lo que dice; si es una respuesta predefinida la corriges ahí mismo («Corregirla»); si no, en la fuente. Prueba de nuevo.
   - 🧠 Modelo: la indicación y el dato estaban y el modelo no los siguió. Te dice dónde subir el modelo.
   - 🔧 Motor: algo que el motor no hace o no cumplió. No lo puedes corregir tú: queda registrado y el equipo de Kontrolya lo revisa.
3. Si no está seguro, te hace una pregunta: pulsa «Contestar».
4. No tienes que guardar nada: cada 👎 revisado queda solo como prueba en el lote del agente y del día («Pruebas · <agente> · 17 nov»), con lo que escribiste en el 👎 como lo esperado. Ahí caen los de todos los usuarios ese día. Cuando Kontrolya corrige un error del motor, el lote de ese día se vuelve a correr solo.
5. En un agente 1.0, si alguien cambia su Entrenamiento mientras pruebas, la plática abierta sigue con el anterior: el probador te avisa y empiezas una plática nueva. En un 2.0 y en el contenido, la corrección se ve desde el siguiente mensaje (también con clientes reales).

### Lotes de pruebas
1. En Lotes de pruebas crea un lote (por ejemplo «Becas») y agrégale pruebas: lo que escribe el cliente (un mensaje por renglón) y qué se espera.
2. También puedes guardar a mano una plática que quieras cuidar (por ejemplo, una que salió bien): en Probar, «Guardar como prueba (manual)», escribe qué se espera y pulsa «Guardar prueba». Va sola al lote del agente y del día, igual que las de 👎; cada prueba dice si es «de una corrección» o «manual».
3. Filtra por agente para ver sus lotes día por día; «Correr todas las pruebas de este agente» junta las pruebas de todos sus días en una sola corrida.
4. Elige el agente y pulsa «Correr»: cada prueba se corre con el motor real y un juez dice si cumple. El resultado sale en la Bitácora.

### Bitácora
- Corridas: cada lote corrido, con qué agente, cuántas pasaron y, por prueba, qué contestó y por qué cumple o no.
- Correcciones: cada 👎 con de quién fue el error. Los del motor muestran el estado de su reporte (nuevo, en revisión, corregido).

## Dudas frecuentes
- ¿Le llega algo al cliente? No: el probador usa su propio canal de pruebas («Probador de agentes»).
- ¿Contesta igual que en real? Sí: es el mismo motor y, en el 1.0, el mismo modelo de la bandeja del agente.
- ¿El probador cambia mi agente solo? No. Lo de prompt y contenido lo aplicas tú; en el 1.0 el Entrenamiento se edita en su pantalla de siempre.
- El agente dejó de contestar en la plática: alguna palabra clave o «no me escriban» terminó el seguimiento; empieza una plática nueva.

## Quién puede
Probar, dar 👎 y guardar pruebas: cualquier usuario (cada quien ve sus propias pláticas). Aplicar una corrección, corregir una respuesta predefinida, poner agentes «En prueba», los lotes y la bitácora: quien puede crear o cambiar agentes (área Agentes IA en «todo»). A los demás el probador les dice «Avísale a quien administra el agente»; su 👎 ya quedó en la bitácora y como prueba.
