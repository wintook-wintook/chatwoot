# Crear un Agente IA a partir de un encargo (.md)

Rama: `feat/importar_prompt_md` (desde `develop`). **Solo plan**: nada se programa hasta que el
usuario lo revise.

> **23/09/2026 — el plan se rehízo.** La primera versión (21/09) trataba el `.md` como un prompt que
> había que **repartir y recortar**, y copiaba pedazos del texto original a cada destino. El usuario
> corrigió el enfoque: *"el `.md` es una idea de cómo se quiere el prompt; el motor debe ser capaz
> de crear el prompt para el agente"*. El `.md` es un **encargo**, y el Entrenamiento lo **escribe el
> Asistente**, el mismo que ya está en develop.
>
> Decisiones del usuario (23/09): **(1)** lo que al encargo le falte, el Asistente lo **pregunta en el
> chat**; **(2)** el encargo **se guarda** junto al agente, para poder regenerar; **(3)** se rehace
> el plan en esta rama, y `feat/importador_md` queda como está (F0/F1 del enfoque anterior).

---

## 1. Qué se pide

Alguien escribe en un `.md`, con sus palabras y con el largo que quiera, **cómo quiere que sea su
agente**: quién es, qué vende o atiende, cómo habla, qué nunca debe hacer, cuándo pasa a una persona.
Lo sube al Asistente de Agentes IA y el motor:

1. **entiende** el encargo, aunque sea enorme;
2. **pregunta en el chat** solo lo que el encargo no dice o dice de dos maneras;
3. **escribe** el Entrenamiento en el formato que el motor ejecuta (Definición · Rutas · Secciones);
4. lo **comprueba** con el parser real y lo corrige solo, como hoy;
5. **guarda el encargo** con el agente, para poder regenerar más adelante.

Lo que **no** es: copiar el texto del `.md` al Entrenamiento. Un encargo de ADAM (1,1 MB) y uno de
media página tienen que terminar igual: en un Entrenamiento que el motor cumple bien (≈ 4–6 mil
tokens).

---

## 2. Lo que cambia respecto del plan anterior

```
PLAN DEL 21/09  (feat/importador_md)                 PLAN NUEVO
────────────────────────────────────                 ──────────
.md = el prompt, ya escrito                          .md = el ENCARGO (la idea)
  │                                                    │
  ├─ leer reglas con formato **ID** (gravedad)         ├─ leer CUALQUIER formato, por temas
  ├─ repartir cada regla por su título                 ├─ ENTENDER: sacar qué se pide
  ├─ deduplicar / recortar al presupuesto              │   (la "ficha del encargo")
  └─ Entrenamiento = pedazos del original              ├─ PREGUNTAR en el chat lo que falta
                                                       └─ el Asistente ESCRIBE el Entrenamiento
                                                          (redacción + comprobador de hoy)
Resultado medido: ADAM bien, cualquier otro           Resultado buscado: cualquier encargo,
.md → 0 o 1 unidades (solo leía el formato            largo o corto, con o sin formato
de ADAM)
```

**Qué se aprovecha de `feat/importador_md`:** la lectura por bloques (`PromptImport::Reader`), ampliada
a formatos generales (§4.1), y la **línea base** de ADAM hecha a mano
(`docs/ejemplos/adam_entrenamiento_linea_base.txt`, 14.701 caracteres) como vara para medir.
**Qué se deja:** el reparto por reglas fijas (`Distributor`) y su revisión con IA (`AiReview`).
**Lección que se conserva:** a la IA no se le muestra la respuesta sugerida. Con la sugerencia a la
vista confirmó 80 de 81 y no sirvió de nada.

---

## 3. El flujo completo

```
 ┌───────────────────┐
 │  encargo.md       │  cualquier largo · cualquier formato
 └─────────┬─────────┘
           │ 1. GUARDAR  (sin IA)
           ▼
 ┌───────────────────────────────────────────┐
 │ tracking_agent_briefs                      │  texto completo + huella (SHA)
 │   si la huella ya existe → se reusa todo   │  (no se vuelve a pagar)
 └─────────┬─────────────────────────────────┘
           │ 2. TROCEAR  (sin IA)  por temas, en pedazos de ≤ 24 K caracteres
           ▼
    ┌──────┬──────┬──────┬─ … ─┬──────┐
    │ T1   │ T2   │ T3   │     │ Tn   │     ADAM ≈ 45 pedazos · media página = 1
    └──┬───┴──┬───┴──┬───┴─ … ─┴──┬───┘
       │ 3. ENTENDER  (IA, 4 a la vez)  cada pedazo → ficha parcial
       ▼      ▼      ▼            ▼
    ┌──────────────────────────────────┐
    │ 4. JUNTAR  (IA, 1–2 llamadas)     │  une repetidos · marca contradicciones
    │    → FICHA DEL ENCARGO            │  · marca lo que falta
    └──────────┬───────────────────────┘
               │ 5. ASISTENTE (la conversación de hoy, arrancando con la ficha)
               ▼
    ┌─────────────────────────────────────────────────────────┐
    │  "Esto entendí"  +  preguntas SOLO de lo que falta/choca  │ ◄─┐
    └──────────┬──────────────────────────────────────────────┘   │ la persona
               │ con todo contestado                               │ contesta
               ▼                                                   │ en el chat
    ┌──────────────────────┐   errores   ┌──────────────────┐      │
    │ redactar             │ ──────────► │ comprobador      │      │
    │ Entrenamiento        │ ◄────────── │ (parser real)    │      │
    └──────────┬───────────┘  máx. 3     └──────────────────┘      │
               │                                                   │
               ▼                                                   │
    ┌──────────────────────────────────┐   algo de la ficha        │
    │ 6. COBERTURA  (sin IA)            │ ── no quedó en ningún ────┘
    │   cada punto de la ficha: ¿está?  │    lado → se avisa / se pregunta
    └──────────┬───────────────────────┘
               ▼
    borrador en el Asistente (versiones, editar a mano, probar)
               │ Guardar (SaveService, como hoy)
               ▼
    Agente IA  ── encargo + ficha + respuestas del chat guardados con él
```

---

## 4. Los pasos, uno por uno

### 4.1 Trocear (sin IA)

El trozo tiene que respetar los temas, no cortar a la mitad de una regla. Se corta en este orden de
preferencia:

| Señal de tema | Ejemplo | De dónde sale |
|---|---|---|
| títulos Markdown, el nivel más alto que haya | `# C7 PROTOCOLO`, `## ROL` | `PromptImport::Reader` |
| secciones entre corchetes | `[ROL]`, `[REGLAS]` | `DraftPieces` (ya mide los 28 prompts de la cuenta 2) |
| títulos decorados | `## ROL ##`, `=== OBJETIVO ===` | nuevo |
| renglón corto en MAYÚSCULAS | `PROHIBICIONES` | nuevo |
| sin ninguna señal | párrafos | respaldo |

Si un tema pasa de **24.000 caracteres**, se parte en sus subtítulos y, si no tiene, por párrafos. Cada
trozo lleva su **ruta de títulos** (`C7 › Clasificación del lead`) para que la IA sepa dónde está.

**Banco de pruebas** (el error del plan anterior fue medir solo con ADAM): ADAM-2.0, DCI V8.12 y los
Entrenamientos reales #8533, #6543 (v6.11), #7466 y #7512. Ninguno puede dar 0 trozos.

### 4.2 Entender (IA, un trozo por llamada)

Cada trozo se lee **completo** (Norma y Texto oficial por igual: aquí no se copia nada, así que leer
de más no ensucia el prompt; solo cuesta, ver §6). La IA devuelve una **ficha parcial** con esta forma
fija:

```
FICHA DEL ENCARGO
├─ identidad         quién es el agente, a nombre de quién habla, para quién trabaja
├─ objetivo          qué tiene que lograr en una conversación
├─ temas             lo que el cliente viene a pedir  → serán las RUTAS
│   └─ por tema: cómo lo dice el cliente · qué hace el agente · de dónde saca la
│                respuesta · qué pasa si no resuelve (ticket, agenda, persona)
├─ reglas siempre    lo que vale en toda la conversación
├─ prohibiciones     lo que nunca hace
├─ tono y formato    cómo escribe (largo, preguntas por mensaje, emojis…)
├─ datos a pedir     qué tiene que averiguar del cliente
├─ conocimiento      lo largo y consultable (catálogo, precios, glosario)
│                    → NO va al prompt: se propone como respuesta predefinida (F6)
├─ fuera             lo que es para quien administra, no para el agente
└─ dudas             lo que este trozo deja abierto
```

Cada punto lleva **de qué trozo salió** (su ruta de títulos). La cobertura (§4.5) y la pantalla lo usan
para mostrar "esto salió de C7 › Cierre".

### 4.3 Juntar (IA, 1–2 llamadas)

Las fichas parciales se unen en **una** ficha. Esta llamada:

- **une repetidos**: en ADAM, "una sola pregunta por mensaje" aparece en más de 20 reglas y debe
  quedar como un punto;
- **marca contradicciones**, por ejemplo C3 que dice "nunca des precio" frente a C7 que dice "da el
  rango si insiste". No las resuelve: van a las preguntas;
- **marca lo que falta** contra lo que el Asistente necesita para escribir, que son los mismos 4 pasos
  de la entrevista de hoy:

```
  PASO 1  temas y modo (contesta o deriva)   ── ¿la ficha lo dice?  sí → no se pregunta
  PASO 2  cómo lo dice el cliente, por tema  ── ¿hay frases reales?  no → se pregunta
  PASO 3  fuente y qué pasa si no resuelve   ── ¿dice ticket/agenda?
  PASO 4  etiqueta de cada tema              ── casi nunca está en un encargo → se pregunta
                                                (con opciones de las etiquetas de la cuenta)
```

Si la ficha junta pasa de lo que la conversación del Asistente puede cargar (tope propuesto:
**16.000 caracteres**), esta misma llamada la condensa. Condensa la ficha y nunca el encargo, que
queda guardado entero.

### 4.4 El Asistente, arrancando con la ficha

**No se escribe un redactor nuevo.** La conversación de hoy (`InterviewService`: entrevista →
redacción → comprobador → ruteo) recibe la ficha como **primer mensaje** de la persona, con una
instrucción agregada:

> Ya tenés el encargo. No preguntes lo que la ficha contesta. Preguntá solo lo marcado como falta o
> contradicción, con las mismas reglas de siempre: numeradas, con opciones, como mucho 4 con botones
> por turno.

En la pantalla, el primer turno se ve así:

```
┌─ Asistente de Agentes IA ─────────────────────────────┬─ Entrenamiento ──────────────┐
│ 📎 ADAM-2.0-Comportamiento.md · 1,1 MB · leído        │ (en construcción)            │
│                                                       │                              │
│ ▾ Esto entendí                                        │ Objetivo: …                  │
│   Agente consultivo de Sentidos Creativos. Atiende    │                              │
│   6 temas: diagnóstico, servicios, precios,           │ @ruta(precios …): <PENDIENTE:│
│   objeciones, reunión, dirección. Nunca da cifras…    │   etiqueta>                  │
│   [ver la ficha completa]                             │ …                            │
│                                                       │                              │
│ Me faltan 3 cosas:                                    │                              │
│ 1. ¿Con qué etiqueta cierra cada tema?                │                              │
│    [a) una para todos] [b) una por tema] [c) otra]    │                              │
│ 2. C3 dice "nunca des precio" y C7 "da el rango si    │                              │
│    insiste". ¿Cuál manda?                             │                              │
│    [a) nunca] [b) rango si insiste] [c) otra]         │                              │
│ 3. Cuando alguien pregunta por precios, ¿cómo lo      │                              │
│    escribe? (dame 2 o 3 frases reales)                │                              │
│ ───────────────────────────────────────────────────── │                              │
│ [ escribir… ]                               [Enviar]  │                              │
└───────────────────────────────────────────────────────┴──────────────────────────────┘
```

Todo lo demás es igual que hoy: borrador a la vista con `<PENDIENTE:>`, versiones, editar a mano sin
que el Asistente lo pise, probar, guardar.

**Tope de turnos.** Hoy la entrevista tiene 6 turnos (`MAX_INTERVIEW_TURNS`). Con encargo arranca con
casi todo contestado, así que no debería necesitar más. Si hay más dudas que turnos, se aplica la regla
de siempre: redacta y marca lo que falte como `<PENDIENTE:>`.

### 4.5 Cobertura: que nada del encargo se pierda (sin IA)

Es el mismo principio de `LostRules`: el Optimizer borró prohibiciones llamándolas "redundantes". Cada
punto de **prohibiciones**, **reglas siempre** y **temas** de la ficha se busca en el Entrenamiento por
sus palabras con contenido. Lo que no aparece:

- si es un tema, se avisa como bloqueante suave ("el encargo pide *reunión* y no hay ruta");
- si es una regla o prohibición, se avisa con su origen ("C0 › Ética: *no prometas resultados*");
- la persona decide en el chat: **"agregalo"** (el Asistente edita, no reescribe) o **"dejalo fuera"**
  (queda anotado en el encargo y no vuelve a avisar).

### 4.6 Guardar y regenerar

Se guarda **con el agente**:

| Qué | Para qué |
|---|---|
| el `.md` completo | poder releerlo y regenerar |
| huella (SHA) | si se sube el mismo archivo, no se vuelve a leer ni a pagar |
| la ficha | arrancar un Asistente nuevo sin volver a entender |
| las respuestas del chat | que regenerar no vuelva a preguntar lo ya contestado |
| lo marcado "dejar fuera" | que la cobertura no vuelva a avisar |

**Regenerar**, desde la ficha del Agente IA (enlace "Encargo"):

```
 subir encargo nuevo ──► ¿misma huella? ── sí ──► misma ficha
                              │
                              no ──► trocear + entender solo los TEMAS que cambiaron
                                     (huella por trozo) + juntar
                                              │
                                              ▼
 Asistente abre con: ficha + respuestas guardadas + Entrenamiento actual
   → pregunta solo lo nuevo
   → EDITA el Entrenamiento (fase A de PROMPT STUDIO), no lo reescribe:
     lo editado a mano se respeta (ManualEdits)
   → queda como versión nueva del borrador; guardar es el botón de siempre
```

---

## 5. Dónde vive

```
 navegador                        Rails                                   Sidekiq
 ─────────                        ─────                                   ───────
 Asistente: 📎 Subir encargo ──► AssistantBriefsController ──crea/reusa─► tracking_agent_briefs
   (.md, ≤ 5 MB)                  (tamaño, tipo, huella)                   estado: en_cola
                                                                              │
                                                                              ▼
                                                                  AgentBriefDigestJob
                                                                    ├─ Trocear   (sin IA)
                                                                    ├─ Entender  (4 a la vez)
                                                                    └─ Juntar    (1–2)
 barra "leyendo tema 12 de 45" ◄──GET progress/:turn_id──  TurnProgress (Redis, ya existe)
 tarjeta "Esto entendí" ◄───────────────────────────────── estado: lista + ficha
 conversación de siempre ──────► InterviewService (+ la ficha como primer mensaje)
 Guardar ──────────────────────► SaveService ── además liga el encargo al agente
```

Tabla nueva **`tracking_agent_briefs`**:

| columna | tipo | nota |
|---|---|---|
| `account_id` | bigint | |
| `tracking_template_id` | bigint, nulo | se llena al guardar el agente |
| `tracking_assistant_session_id` | bigint, nulo | la conversación que lo usó |
| `user_id` | bigint | quién lo subió |
| `filename` | string | |
| `content` | text | el `.md` completo (ADAM: 1,1 MB) |
| `sha256` | string, índice | reusar sin volver a pagar |
| `status` | string | `en_cola` · `leyendo` · `lista` · `error` |
| `chunks` | jsonb | huella + ruta de títulos + ficha parcial de cada trozo |
| `digest` | jsonb | la ficha junta |
| `answers` | jsonb | preguntas y respuestas del chat, y lo marcado "dejar fuera" |
| `usage` | jsonb | tokens y tiempo, por paso |

Un agente puede tener varios encargos (el historial). El vigente es el último ligado.

**Confidencial:** ADAM trae una sección "CONFIDENCIAL · USO INTERNO". El encargo se guarda solo dentro
de la cuenta y no se usa como fuente de respuestas: no se vectoriza ni va a respuestas predefinidas sin
que la persona lo confirme fila por fila (F6).

---

## 6. Cuánto cuesta y cuánto tarda (estimado; se mide en la F2)

Precios de lista: gpt-4o USD 2,50 / 10 por millón (entrada / salida); gpt-4o-mini USD 0,15 / 0,60.

| Paso | ADAM (1,1 MB, ≈ 45 trozos) | Encargo de 1 página |
|---|---|---|
| Trocear | < 1 s · 0 | < 1 s · 0 |
| Entender con gpt-4o | ≈ 360 K entrada + 70 K salida ≈ **USD 1,60** · ≈ 4 min (4 a la vez) | ≈ USD 0,02 · 10 s |
| Entender con gpt-4o-mini | ≈ **USD 0,10** · ≈ 2 min | ≈ USD 0,001 · 5 s |
| Juntar (gpt-4o) | ≈ 70 K entrada ≈ USD 0,30 · 40 s | (no hace falta: 1 trozo) |
| Asistente (turnos de hoy) | igual que hoy: 40–60 s por turno | igual |
| **Total para tener la ficha** | **USD 0,40 (mini) a 1,90 (4o)** · 3–5 min | **centavos · segundos** |

Se paga **una vez por versión del archivo**. Reabrir, regenerar con el mismo archivo o seguir
conversando no vuelve a leerlo. Si se cambia un solo tema, se relee solo ese.

---

## 7. Qué se reutiliza (ya está en develop)

| Pieza | Para qué |
|---|---|
| `InterviewService` + `Instructions` | la conversación: preguntar, redactar, corregir (con la ficha como primer mensaje) |
| `ValidatorService`, `RouteSelfCheck` | comprobar y reparar lo escrito |
| `PendingMarkers` | lo que quede sin contestar va como `<PENDIENTE:>` |
| `DraftPieces` | trocear por secciones `[X]` y `## X` |
| `LostRules` | la idea (y el cálculo de palabras) de la cobertura |
| `ManualEdits`, `DraftDiff` | regenerar sin pisar lo editado a mano |
| `SessionVersions` | cada regeneración es una versión |
| `TurnProgress` | barra de avance mientras lee |
| `OpenaiChat` + `EngineConfig` | llamadas con la integración OpenAI de la cuenta |
| `SaveService` | guardar el agente (con bloqueantes y versión anterior) |
| `PromptImport::Reader` (rama `feat/importador_md`) | base del troceo por títulos Markdown |

---

## 8. Riesgos y cómo se cubren

| Riesgo | Cobertura |
|---|---|
| El encargo es enorme y la conversación no lo aguanta | el Asistente nunca ve el `.md`: ve la ficha (≤ 16 K caracteres) |
| La ficha pierde algo importante al juntar/condensar | cada punto trae su origen; cobertura contra el Entrenamiento; la ficha completa se puede ver |
| El Asistente pregunta de más (lo que el encargo ya decía) | la ficha marca qué pasos están contestados; en la F7 se cuentan las preguntas redundantes |
| Solo funciona con el formato de un documento (el error del 21/09) | banco de pruebas de 6 textos distintos desde la F1 |
| Contradicciones del encargo resueltas en silencio por la IA | juntar solo las marca; las decide la persona en el chat |
| Regenerar pisa ediciones a mano | edición, no reescritura (fase A) + `ManualEdits` (fase B) |
| Costo al reprocesar | huella por archivo y por trozo |
| Contenido confidencial que termina en una respuesta al cliente | el encargo no es fuente de respuestas; Conocimiento solo con confirmación por fila |

---

## 9. Fases (días hábiles)

| Fase | Entrega | Cómo se verifica | Días |
|---|---|---|---|
| **F0** Encargo guardado | tabla `tracking_agent_briefs`, subir `.md` (≤ 5 MB), huella, reuso | request spec: subir, mismo archivo no se duplica, otra cuenta no lo ve | 1 |
| **F1** Troceo general | títulos Markdown, `[X]`, decorados, MAYÚSCULAS, párrafos; ≤ 24 K por trozo | spec con el banco de 6 textos: ninguno da 0 trozos, ninguno corta una regla | 1 |
| **F2** Entender y juntar | job con avance, 4 a la vez, ficha parcial → ficha junta, faltas y contradicciones; **medir 4o vs mini** | spec con ADAM y DCI: la ficha trae los 6 temas de la línea base; costo y tiempo medidos | 2 |
| **F3** Asistente con encargo | ficha como primer mensaje, "Esto entendí", preguntas solo de lo que falta; respuestas guardadas en el encargo | e2e contra gpt-4o: con un encargo completo no pregunta el paso 1; con uno sin etiquetas pregunta solo el 4 | 2 |
| **F4** Cobertura | cada punto de la ficha buscado en el Entrenamiento; "agregalo" / "dejalo fuera" | spec: una prohibición borrada a propósito aparece como aviso con su origen | 1 |
| **F5** Pantalla | 📎 en el chat, barra de avance, tarjeta "Esto entendí", ficha completa, enlace "Encargo" en la ficha del agente | Vitest + navegador | 2 |
| **F6** Regenerar | subir versión nueva: relee solo temas cambiados, reusa respuestas, edita el Entrenamiento como versión nueva | spec: cambiar un tema cuesta 1 trozo; lo editado a mano sobrevive | 1 |
| **F7** Prueba real | ADAM, DCI V8.12 y un encargo de una página, de punta a punta en develop | criterios de §9.1 | 1 |

**Total: 11 días hábiles.** Aparte y opcional: **Conocimiento sugerido**, que propone respuestas
predefinidas con lo consultable de la ficha (catálogo de servicios, glosario, guiones con "El mensaje es
el prompt"), con confirmación por fila (+1,5 días; ver decisión C).

### 9.1 Criterios de aceptación (F7)

Con ADAM, comparado contra la línea base hecha a mano
(`docs/ejemplos/adam_entrenamiento_linea_base.txt`, en `feat/importador_md`):

1. el Entrenamiento cabe en el presupuesto (≤ 24.000 caracteres) y el comprobador no da bloqueantes;
2. tiene rutas equivalentes a las de la línea base (diagnóstico, servicios, precios, objeciones,
   reunión, dirección);
3. la cobertura no deja prohibiciones del encargo sin decidir;
4. el Asistente no preguntó nada que la ficha ya contestaba, y sí preguntó las contradicciones;
5. en las pruebas sugeridas enruta al menos tan bien como la línea base cargada en el mismo agente.

Con un encargo de una página: ficha en segundos, a lo sumo 2 turnos de preguntas, mismo nivel de
Entrenamiento que la entrevista de hoy.

---

## 10. Decisiones

**Ya tomadas**

| # | Decisión | Fecha |
|---|---|---|
| 1 | Presupuesto del Entrenamiento: 24.000 caracteres | 21/09 (se mantiene) |
| 4 | El motor que escribe usa gpt-4o, sin importar el modelo del inbox | 21/09 (se mantiene) |
| — | Lo que falta se pregunta en el chat | 23/09 |
| — | El encargo se guarda con el agente, para regenerar | 23/09 |
| — | Plan rehecho aquí; `feat/importador_md` queda como está | 23/09 |

Las decisiones 2 ("Texto oficial" fuera), 3 (guiones) y 5 (IDs de regla) del plan anterior **ya no
aplican**: se leía el encargo para copiarlo y ahora se lee para entenderlo.

**Abiertas**

- **A. Modelo para *entender* los trozos.** gpt-4o (≈ USD 1,90 por ADAM) o gpt-4o-mini (≈ USD 0,40).
  Propuesta: medir los dos en la F2 contra la línea base y elegir con datos. Juntar y escribir siguen
  con gpt-4o.
- **B. ¿La persona puede editar la ficha a mano?** Propuesta: **no**. Se corrige conversando ("no,
  también atiende cobranza") y el Entrenamiento sigue siendo lo único editable, así no hay dos fuentes
  de verdad que se contradigan.
- **C. Conocimiento sugerido** (respuestas predefinidas desde la ficha). ¿Entra en esta rama o
  después? Propuesta: después, cuando el flujo principal esté probado.
- **D. ¿En qué cuenta se prueba ADAM?** (sigue abierta la 6 del plan anterior). Importa por las
  etiquetas, el calendario y las respuestas predefinidas: ¿cuenta nueva de Sentidos Creativos o la
  cuenta 2?
