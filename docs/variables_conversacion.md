# Variables que se conservan en la conversación

Rama: `feat/variables_conversacion` · 01/10/2026

## Qué resuelve

Un Entrenamiento puede declarar variables en una sección `[VARIABLES]` y otras secciones
las leen («Si CARRERA=VACÍO…») y las cambian («Marca LIGA_ENTREGADA=SÍ»). Antes nadie
las guardaba: el modelo las adivinaba leyendo el historial, y el historial se recorta.
Una liga entregada hace muchos mensajes volvía a quedar en `NO`.

Ahora el motor las guarda en la conversación.

**Dónde se guardan:** en Postgres, en la columna `additional_attributes` (jsonb) de la
conversación, igual que el historial `kb_history`. No en Redis: Redis en Chatwoot es para
colas y caché que caducan; las variables deben durar lo que dure la conversación y
sobrevivir a un reinicio.

```
 mensaje del cliente
        │
        ▼
 ┌──────────────────────────────┐   conversation.additional_attributes
 │ prompt del agente            │   ['agent_variables'][<id del Agente IA>]
 │ + VARIABLES ACTUALES ◄─────────┼──── { CARRERA: "Psicología",
 │   CARRERA=Psicología         │       LIGA_ENTREGADA: "NO", … }
 │   LIGA_ENTREGADA=NO …        │                 ▲
 └──────────────┬───────────────┘                 │ guarda solo valores
                ▼                                 │ declarados
        respuesta del modelo                      │
   «Aquí está tu liga: https://…                  │
    VARIABLES: LIGA_ENTREGADA=SÍ ───────────────────┘
    #inscrito»
                │  se quita la línea VARIABLES
                ▼
        mensaje que ve el cliente
```

## Cómo funciona

- **Declaración**: en la sección `[VARIABLES]`, una línea por variable con sus valores
  separados por `|`. `valor` (o `texto`, `dato`) significa «lo que diga el cliente».
  La línea `Inicial:` da el valor de arranque (si falta, se usa el primer valor).
- **Cada turno** se agregan al prompt los valores actuales y la instrucción de escribir
  `VARIABLES: NOMBRE=valor; …` cuando algo cambie.
- **Al enviar**: se quita esa línea del mensaje, y se guardan solo los valores que están
  en la lista declarada (`si` se guarda como `SÍ`; un valor que no existe se descarta y
  queda en el log `[Variables]`). También se reconoce la línea suelta `LIGA_ENTREGADA=SÍ`.
- Se guardan **por Agente IA**: si dos agentes atienden la misma conversación, no se
  mezclan sus variables.
- Funciona en los dos caminos: respuesta conversacional y respuesta con fuente
  (hoja, documento, foro, predefinidas).

Código: `app/services/contact_trackings/conversation_variables.rb`, conectado en
`KnowledgeBaseResponseService` (prompt, historial y `send_reply`) y en
`ContactTrackingResponseAnalyzerJob` (prompt conversacional y `send_auto_reply`).

## Prompt de ejemplo

Para pegarlo en el Entrenamiento de un Agente IA de prueba. No usa fuentes externas: las
ligas están en el propio prompt, así que se prueba sin configurar nada más.

```
[ROL]
Eres Sofía, asesora de admisiones de la Universidad Demo. Hablas de tú, en mensajes cortos
(máximo 4 líneas) y no finges ser una persona si te lo preguntan.

[VARIABLES]
CARRERA=VACÍO|valor
SIGUIENTE_OFERTA=SIN_INSCRIPCION|PRIMERA_BECA|SEGUNDA_BECA|ULTIMA_BECA|AGOTADA
LIGA_ENTREGADA=NO|SÍ
Inicial: CARRERA=VACÍO; SIGUIENTE_OFERTA=SIN_INSCRIPCION; LIGA_ENTREGADA=NO.

[CARRERAS Y LIGAS]
Solo existen estas carreras, con su liga exacta de inscripción:
- Psicología: https://demo.universidad.mx/inscripcion/psicologia
- Derecho: https://demo.universidad.mx/inscripcion/derecho
- Ingeniería en Sistemas: https://demo.universidad.mx/inscripcion/sistemas
Colegiatura mensual de todas: $4,500.

[1. CARRERA]
Cuando el cliente diga qué carrera le interesa y sea una de la lista, marca CARRERA con el
nombre exacto de la lista. Si pide una que no está, dile cuáles hay y deja CARRERA como está.

[2. BECAS]
SIGUIENTE_OFERTA es la beca que toca ofrecer ahora. Si el cliente dice que es caro o
pregunta por descuentos, ofrece SOLO esa beca y avanza la variable un paso:
- SIN_INSCRIPCION o PRIMERA_BECA → ofrece 10% de beca y marca SIGUIENTE_OFERTA=SEGUNDA_BECA.
- SEGUNDA_BECA → ofrece 20% de beca y marca SIGUIENTE_OFERTA=ULTIMA_BECA.
- ULTIMA_BECA → ofrece 30% de beca y marca SIGUIENTE_OFERTA=AGOTADA.
- AGOTADA → ya ofreciste el 30%, que es la beca más alta: no ofrezcas nada nuevo.
Nunca ofrezcas una beca que ya se ofreció ni te saltes una.

[3. INSCRIPCIÓN]
MODO INSCRIPCIÓN inicia con intención explícita de avanzar, registrarse, inscribirse o
pedir/aceptar la liga. Solo esta sección entrega la liga.
Si CARRERA=VACÍO, pregunta únicamente qué carrera desea y DETENTE.
Con CARRERA:
1. Si LIGA_ENTREGADA=SÍ, no la vuelvas a enviar: dile que ya se la compartiste y pregunta
   si tuvo algún problema con ella.
2. Si no, entrega únicamente la liga exacta de CARRERA de la lista de arriba.
3. Marca LIGA_ENTREGADA=SÍ.
4. No pidas segunda confirmación.
Nunca inventes, completes, construyas, modifiques ni sustituyas una URL.

[ETIQUETAS]
#inscripcion_enviada — la respuesta en la que entregaste la liga.
```

## Pila de pruebas

Cada paso es un mensaje del cliente en una conversación nueva con el agente de arriba.
Después de cada paso se revisan dos cosas: que el mensaje del cliente **no** traiga la
línea `VARIABLES:` y que lo guardado sea lo esperado.

| # | Mensaje del cliente | Qué debe responder | Guardado esperado |
|---|---|---|---|
| 1 | Hola, quiero inscribirme | Pregunta solo qué carrera (CARRERA está VACÍO) | sin cambios: `CARRERA=VACÍO` |
| 2 | Medicina | Que no existe, lista las tres | `CARRERA=VACÍO` |
| 3 | Entonces psicología | Confirma Psicología | `CARRERA=Psicología` |
| 4 | Está caro | Ofrece 10% | `SIGUIENTE_OFERTA=SEGUNDA_BECA` |
| 5 | Sigue caro, ¿no hay más? | Ofrece 20% (no repite 10%) | `ULTIMA_BECA` |
| 6 | Ok, mándame la liga | Liga exacta de Psicología + `#inscripcion_enviada` | `LIGA_ENTREGADA=SÍ` |
| 7 | Pásame otra vez la liga | **No** la reenvía; dice que ya la compartió | sigue `SÍ` |
| 8 | ¿Y más descuento? | Ofrece 30% (sigue desde ULTIMA_BECA, no reinicia) | `AGOTADA` |

La prueba de fondo es la 7 y la 8: el modelo ya no depende de encontrar la liga o la beca
en el historial, lee el valor guardado.

**Prueba de memoria larga** (opcional): después del paso 6, mandar 25 mensajes de
relleno («ok», «gracias», «¿a qué hora abren?») y repetir el paso 7. Antes del cambio el
historial ya no tenía la liga y la reenviaba; ahora debe decir que ya se la compartió.

### Cómo ver lo guardado

Por consola (`bundle exec rails c`), con el id de la conversación:

```ruby
Conversation.find(ID).additional_attributes['agent_variables']
# => { "<id del Agente IA>" => { "CARRERA" => "Psicología", "SIGUIENTE_OFERTA" => "ULTIMA_BECA", "LIGA_ENTREGADA" => "SÍ" } }
```

Y en el log aparece cada cambio guardado o descartado:

```
[Variables] 💾 Conversación #123: LIGA_ENTREGADA=SÍ
[Variables] ⚠️ Valor no declarado descartado: SIGUIENTE_OFERTA=CUARTA_BECA
```

Para empezar de cero en la misma conversación:

```ruby
c = Conversation.find(ID); c.update_columns(additional_attributes: c.additional_attributes.except('agent_variables'))
```

## Pendiente / fuera de alcance

- No se ven en la pantalla de la conversación; por ahora solo por consola y log.
- El Asistente de Agentes IA todavía no valida la sección `[VARIABLES]` (por ejemplo, una
  instrucción «Marca X=Y» con un valor que no está declarado).
- Las respuestas fijas de acciones (rechazo, reagendar, cita) no reciben las variables.

## Resultados de la prueba (01/10/2026)

Agente de prueba **#12148** «PRUEBA Variables — Universidad Demo» (cuenta 2, canal 493 de
tipo API, sin envíos reales), modelo gpt-4o.

| Corrida | Conversación | Resultado |
|---|---|---|
| 1 · la línea solo «cuando cambie» | /conversations/360 | 7/8. En el paso 5 ofreció 20% sin escribir la línea: se quedó `PRIMERA_BECA`. |
| 2 · la línea SIEMPRE, con todas | /conversations/361 | 8/8. Ninguna línea `VARIABLES:` llegó al cliente. |
| 3 · variables precargadas, sin historial | /conversations/362 | Leyó `CARRERA=Derecho` y `LIGA_ENTREGADA=SÍ` de lo guardado: no reenvió la liga y ofreció 30%. Pero guardó `AGOTADA` en vez de `ULTIMA_BECA`. |

Por la corrida 1, la regla del motor pide la línea en **todas** las respuestas; el motor
solo guarda lo que cambió. En el paso 3 la liga sale de inmediato porque en el paso 1 el
cliente ya dijo «quiero inscribirme», que es lo que pide la sección de inscripción.

El `AGOTADA` de la corrida 3 venía del ejemplo: el valor significaba «la beca que ya se
ofreció», pero el nombre `SIGUIENTE_OFERTA` dice «la que sigue», y el modelo lee el nombre.
Un primer arreglo (quitar «el máximo» de una línea) no bastó: corridas 363 y 364 volvieron
a saltar. Ahora el valor es literalmente la beca que toca ofrecer.

La corrida 364 mostró además una fuga: el modelo pegó `VARIABLES: …` al final de una frase,
el motor solo la buscaba en línea propia y el cliente la vio. Ahora se quita también pegada
(en mayúsculas, para no tocar un «las variables:» normal).

### Después de los arreglos (01/10/2026)

| Prueba | Conversaciones | Variables guardadas | Fugas | Texto al cliente |
|---|---|---|---|---|
| Precarga sin historial, ×5 | 365, 366, 368, 369, 370 | 5/5 correctas | 0 | Liga: 5/5 no la reenvía. 30%: 3/5 la ofrece bien; 2/5 dice «ya te ofrecí el 30%». |
| Pila completa, ×2 | 367, 371 | 8/8 en ambas | 0 | Paso 8: las dos dicen «ya te ofrecí el 30%». |

Lo que guarda el motor siempre fue correcto. Lo que falla es la redacción del modelo
cuando le toca la última beca: probablemente imita la línea `AGOTADA → ya ofreciste el
30%…` del ejemplo. Aclarar en la regla del motor que los valores son «antes de tu
respuesta» no lo cambió.
