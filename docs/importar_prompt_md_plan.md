# Importar un prompt (.md) al Asistente de Agentes IA

Rama: `feat/importar_prompt_md` (desde `develop`, 21/09/2026). **Solo plan**: nada se programa hasta
que el usuario lo revise.

---

## 1. Qué se pide

Subir un archivo `.md` con las instrucciones de un agente y que el Asistente arme, **con ayuda del
motor de agentes IA**, su Estructura (Definición · Rutas · Secciones). Tiene que ser **eficiente**:
un documento grande no puede costar una fortuna ni tardar una eternidad, y el resultado tiene que
caber en lo que el motor puede leer en cada mensaje.

Ejemplo real entregado por el usuario: `/tmp/adam/ADAM-2.0-Comportamiento.md`.

---

## 2. Lo que trae el ejemplo (medido)

```
ADAM-2.0-Comportamiento.md
  1,1 MB · 34.834 líneas · 157.834 palabras · ≈ 280.000 tokens · 3.223 títulos

  # C0 CONSTITUCIÓN ........ 110 K caracteres   identidad, principios, reglas, ética
  # C1 CARÁCTER ............  85 K              personalidad, forma de pensar
  # C2 LENGUAJE ............  96 K              diccionario, terminología, glosario
  # C3 CONVERSACIÓN ........ 226 K              escucha, objeciones, persuasión, memoria…
  # C4 PROCEDIMIENTO ....... 167 K              diagnóstico, hipótesis, evidencia
  # C5 LÍMITES .............  97 K              IA consultiva, papel del consultor humano
  # C6 OFERTA .............. 201 K              13 servicios (ADAM, R.A.D.A.R., Branding…)
  # C7 PROTOCOLO COMERCIAL . 135 K              guiones, objeciones, cierre, precios, escalamiento
```

Cada sección (`##`) tiene dos partes:

```
## Clasificación del lead — …
   ### Norma            ← reglas numeradas, ya condensadas       (≈ 400 K caracteres en total)
   ### Texto oficial    ← la explicación larga, con ejemplos     (≈ 600 K caracteres en total)
```

Y cada regla de la Norma tiene **siempre** la misma forma:

```
**C7-06.06** (inviolable) — Verifica la autoridad de decisión con una sola pregunta…
  - Activación:   Cuando falte confirmar quién decide la contratación.
  - Verificación: El mensaje contiene una única pregunta y no encadena urgencia ni presupuesto.
  - Prompt:       Verifica autoridad de decisión con una sola pregunta por mensaje y espera respuesta.
```

| Dato | Valor |
|---|---|
| Reglas | **818** — 373 inviolables · 419 obligatorias · 26 recomendadas |
| Por capítulo | C7 211 · C6 142 · C3 133 · C4 102 · C0 79 · C2 59 · C5 56 · C1 36 |
| Todas las líneas `Prompt:` juntas | 79 K caracteres ≈ **20.000 tokens** |
| Solo las de reglas inviolables | 36 K caracteres ≈ 9.000 tokens |
| El Entrenamiento más grande que hoy corre (v6.11, #6543) | 17 K caracteres ≈ 4.300 tokens |

**Conclusión que manda todo el diseño:**

```
  documento entero       ≈ 280.000 tokens   ✗ imposible en un prompt
  solo las Normas        ≈ 100.000 tokens   ✗ imposible
  solo las líneas Prompt ≈  20.000 tokens   ✗ 4–5 veces el agente más grande que funciona
  lo que el motor aguanta bien ≈ 4–6.000   ✓ el objetivo
```

Importar **no es copiar**: es **repartir** cada pedazo a donde el motor lo usa mejor, y **condensar**
lo que va al prompt. Lo bueno: este formato ya viene casi resuelto (cada regla trae su versión
corta, cuándo aplica y cómo se verifica), así que casi todo se puede hacer **sin IA**.

---

## 3. La idea: repartir, no copiar

Cada pedazo del documento tiene un destino natural en el motor:

```
                          ┌─────────────────────────┐
                          │   ADAM-2.0.md (1,1 MB)  │
                          └────────────┬────────────┘
                                       │ 1. LEER (sin IA, milisegundos)
                                       ▼
                    bloques: título · ruta de títulos · tipo · regla · tamaño
                                       │ 2. REPARTIR (reglas fijas; IA solo en lo dudoso)
       ┌──────────────┬───────────────┼────────────────┬──────────────────┬──────────────┐
       ▼              ▼               ▼                ▼                  ▼              ▼
  DEFINICIÓN      SECCIONES        RUTAS          CONOCIMIENTO          PRUEBAS        FUERA
  Objetivo y      reglas que       lo que depende  lo que se consulta   "Verificación" portada,
  Contexto        valen SIEMPRE    de lo que pide  cuando hace falta    y casos de    índices,
  (C0 Identidad)  (C0,C1,C3,C5)    el cliente      (C6 Oferta, C2       "Aplicación    "Origen:",
                                   (C7 protocolo)  Glosario, Textos     práctica"      notas
                                                   oficiales, guiones)                 editoriales
       │              │               │                │                  │
       ▼              ▼               ▼                ▼                  ▼
  Definición     [ROL] [REGLAS]   @ruta(...)       Respuestas         Pruebas sugeridas
  del agente     [ESTILO] …       + ALCANCE        predefinidas       del Asistente
                                  POR RUTA         (con prompt para   (clasificador real)
                                                   los guiones)
```

Por qué así:

- **Secciones** = lo que el modelo lee en **todos** los mensajes. Solo entra lo que vale siempre, en su
  versión corta (la línea `Prompt:`), nunca el "Texto oficial".
- **Rutas + alcance por ruta** = lo que vale **solo** en un tema (precios, objeciones, cierre). El
  motor ya le dice al modelo "RAMA YA DECIDIDA: aplica solo las instrucciones de esta rama"
  (`branch_scope_rule`), así que las reglas de C7 dejan de competir con las demás.
- **Conocimiento** = lo largo y consultable (los 13 servicios de C6, el glosario, los guiones). Va a
  **respuestas predefinidas**, que el motor busca por parecido solo cuando hace falta. Los
  **guiones** ("Guion: páginas web", "Conducción a la reunión") van como respuesta predefinida con
  **"El mensaje es el prompt"** y aprovechan el **guion en curso** (rama `feat/predefinidas_prompt`).
- **Pruebas** = las líneas `Verificación` y los casos de "Aplicación práctica" son exactamente lo que
  el Asistente necesita para probar el agente: se vuelven **pruebas sugeridas**, que el clasificador
  real corre.

---

## 4. Cómo trabaja el importador

### 4.1 Paso 1 — Leer (sin IA)

- Árbol de títulos (`#`…`######`) → bloques con su **ruta** (`C7 › Clasificación del lead › Norma`).
- **Detector de formato**: si encuentra el patrón `**ID** (severidad) — … / Activación / Verificación /
  Prompt`, lee cada regla como registro (ID, severidad, texto, activación, verificación, prompt
  corto). En ADAM, las 818.
- Si el `.md` **no** trae ese formato (un prompt común, escrito a mano), cae al **modo genérico**:
  bloques por título y la IA hace la parte que aquí resuelve el formato (§4.3).
- Tope de archivo: **5 MB** (ADAM pesa 1,1).

### 4.2 Paso 2 — Repartir

Primero **reglas fijas** (gratis, instantáneas), por el título y la ruta del bloque:

| Señal | Destino |
|---|---|
| `### Norma` | reglas (Secciones o alcance de una Ruta, según §4.3) |
| `### Texto oficial` | Conocimiento (nunca al prompt) |
| título con "Guion", "Conducción", "Cierre", "Seguimiento" | Ruta + guion (respuesta predefinida con prompt) |
| "Oferta", "Servicio", nombre con ® | Conocimiento (un servicio = una respuesta predefinida) |
| "Glosario", "Diccionario", "Terminología", "Analogías", "Errores" | Conocimiento |
| "Aplicación práctica", "Caso N", `Verificación:` | Pruebas |
| portada, "Origen:", "Continuación editorial", índice | Fuera |
| "CONFIDENCIAL · USO INTERNO" | Secciones (el prompt no lo ve el cliente) **y nunca** al Conocimiento, que sí puede terminar en una respuesta |

La **IA solo ve lo que las reglas fijas no resolvieron**, y solo **títulos + primeras líneas**, no el
texto completo. En ADAM eso es una llamada chica.

### 4.3 Paso 3 — Armar el prompt dentro de un presupuesto

```
 818 reglas ─► ① deduplicar ─► ② ¿global o de una ruta? ─► ③ ordenar ─► ④ recortar al presupuesto
```

1. **Deduplicar** con embeddings de las líneas `Prompt:` (el mismo `text-embedding-3-small` del motor;
   818 líneas ≈ 20 K tokens ≈ **USD 0,0004**). Reglas casi iguales (parecido ≥ 0,90) se juntan en una,
   con la severidad más alta y todos sus IDs. ADAM repite mucho: "una sola pregunta por mensaje"
   aparece en más de 20 reglas (C0-07.01, C1-01.10, C3-01.02 y 17 de C7).
2. **¿Global o de una ruta?** Por su `Activación`: "en toda la conversación", "en cada respuesta"
   → **Sección**; "cuando el prospecto pide precios", "ante una objeción" → **alcance de esa Ruta**.
3. **Ordenar**: inviolable → obligatoria → recomendada.
4. **Presupuesto** (decisión 1): por defecto **24.000 caracteres ≈ 6.000 tokens** entre Secciones y
   alcances. Si no alcanza, se condensa **por sección** con IA (solo las que se pasan), y lo que no
   entra se **informa**: nunca desaparece en silencio.

**Secciones** con los nombres que la cuenta ya usa (catálogo de secciones del Asistente: `[ROL]`,
`[REGLAS]`, `[ESTILO]`, `[PROHIBICIONES]`…), así el agente se parece a los que ya funcionan.

### 4.4 Paso 4 — Proponer las Rutas (IA, pocas llamadas)

Una llamada con los títulos de C7 y las `Activación` de sus reglas → rutas por **intención del
cliente**, cada una con:

- **nombre** y **#etiqueta** en minúsculas, sin tildes (se valida contra las etiquetas de la cuenta; si
  no existe se avisa, como hace hoy el comprobador);
- **frases del cliente** (lo que el clasificador lee: la lección de v5.9 es que el clasificador solo
  ve la descripción de la ruta);
- **fuente**: `@buscar_predefinidas` si se importó conocimiento;
- **escalamiento** según el documento: "Escalamiento a dirección" → `@crear_ticket`; "Conducción a la
  reunión" → `@agendar_calendar` (si el agente tiene calendario);
- **alcance por ruta**: las reglas de §4.3-② de esa ruta.

Todo pasa por el **parser real** (`RouteMap`, `TrainingRoutes`) y el **comprobador** antes de mostrarse.

### 4.5 Paso 5 — Revisar y aplicar

Nada se guarda en un agente sin que alguien lo apruebe. La vista previa va en un modal grande del
Asistente, con componentes nativos:

```
┌─ Importar prompt · ADAM-2.0-Comportamiento.md ─────────────────────────────────────┐
│ ████████████████████░░░░  21.300 / 24.000 caracteres del Entrenamiento             │
│ 818 reglas · 402 al prompt · 211 en rutas · 17 unidas por repetidas · 0 perdidas    │
├──────────┬────────────┬──────────────┬─────────┬──────────┬─────────────────────────┤
│ Resumen  │ Estructura │ Conocimiento │ Pruebas │ Fuera    │ Avisos (3)              │
├──────────┴────────────┴──────────────┴─────────┴──────────┴─────────────────────────┤
│ ▾ Definición                                                                        │
│    Objetivo · Contexto                                                              │
│ ▾ Rutas (7)                                                  [☑ todas]              │
│    ☑ precios #precios_sin_cifra  — 22 reglas · "cuánto cuesta", "precio"…           │
│    ☑ objeciones #objecion        — 31 reglas · "está caro", "lo pienso"…            │
│    ☑ reunion #reunion            — 12 reglas · → @agendar_calendar                  │
│ ▾ Secciones (6)                                                                     │
│    ☑ [ROL] ☑ [PRINCIPIOS] ☑ [ESTILO] ☑ [PROHIBICIONES] ☑ [LÍMITES] ☑ [CONVERSACIÓN] │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ Cada regla lleva su ID (C7-06.06): se puede ver de dónde salió.                     │
│                                  [Cancelar]  [Cargar en el Asistente]               │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

- **Cargar en el Asistente** pone la estructura en el **borrador**, no en un agente. Guardar sigue
  siendo el botón de siempre (`SaveService`), que **no deja guardar con bloqueantes** y guarda el
  Entrenamiento anterior para poder volver atrás.
- **Conocimiento** se crea aparte y también con confirmación: lista de respuestas predefinidas a crear
  (nombre, si es guion con prompt), con casilla por fila.
- **Cobertura de inviolables** (pestaña Avisos): cada una de las 373 tiene que terminar en el prompt,
  en una ruta, o **descartada a mano** por la persona. Es el mismo principio de `LostRules`: el v6.11
  enseñó que un "resumen" borra prohibiciones llamándolas redundantes.

### 4.6 Dónde vive

```
 navegador                       Rails                                Sidekiq
 ─────────                       ─────                                ───────
 [Importar .md] ──POST archivo──► AssistantImportsController ──crea──► TrackingPromptImport
                                   (valida tamaño y tipo)              (estado: en_cola)
                                                                           │
                                                                           ▼
                                                              PromptImportJob
                                                                ├─ Leer        (sin IA)
                                                                ├─ Repartir    (reglas + 1 llamada)
                                                                ├─ Deduplicar  (embeddings)
                                                                ├─ Rutas       (1–2 llamadas)
                                                                ├─ Condensar   (solo si se pasa)
                                                                └─ Comprobar   (parser real)
 barra de avance ◄──GET estado/avance (cada 2 s)──────────────  estado: lista + propuesta (JSON)
 vista previa ◄───────────────────────────────────────────────  
 [Cargar en el Asistente] ──► borrador del Asistente (como hoy)
```

- Tabla nueva **`tracking_prompt_imports`**: cuenta, usuario, nombre del archivo, huella (SHA) del
  contenido, estado, avance, propuesta (jsonb), costo en tokens. Con la huella, **reimportar el mismo
  archivo no vuelve a gastar**: se reusa la propuesta.
- El archivo no se guarda: se lee, se procesa y queda solo la propuesta.
- Llamadas a OpenAI con la integración de la cuenta, como todo el motor (`OpenaiChat`).

---

## 5. Cuánto cuesta y cuánto tarda (estimado para ADAM)

| Paso | IA | Tokens aprox. | Tiempo |
|---|---|---|---|
| Leer y repartir con reglas fijas | no | 0 | < 1 s |
| Repartir lo dudoso (títulos + primeras líneas) | sí | 5–10 K | 5–10 s |
| Deduplicar (embeddings de 818 líneas cortas) | embeddings | 20 K | 3–5 s |
| Proponer rutas | sí | 15–25 K | 15–30 s |
| Condensar secciones que se pasen del presupuesto | sí, solo esas | 10–40 K | 10–40 s |
| Comprobar con el parser real | no | 0 | < 1 s |
| **Total** | | **≈ 50–95 K** | **≈ 1 minuto** |

Con gpt-4o eso es del orden de **USD 0,25 a 0,50 por importación**. Si se mandara el documento
completo al modelo serían ≈ 280 K tokens **solo para leerlo**, y además no cabría en una sola llamada.

---

## 6. Qué se reutiliza (ya existe en develop)

| Pieza | Para qué en el importador |
|---|---|
| `TrainingStructure` / `DraftPieces` | armar el texto del Entrenamiento desde los bloques |
| `TrainingRoutes` + `RouteMap` (parser real) | escribir y validar las líneas `@ruta` |
| `TrainingSectionCatalog` / títulos de sección | nombres de sección como los de la cuenta |
| `ValidatorService` (comprobador) | avisos y bloqueantes antes de mostrar la propuesta |
| `LostRules` | cobertura de reglas inviolables |
| `SuggestedTests` + `DraftClassifier` | pruebas desde `Verificación` y "Aplicación práctica" |
| `Proofreader` | "Mejorar la redacción" sobre lo importado, con deshacer |
| `SaveService` | guardar en el agente, con bloqueantes y versión anterior |
| `OpenaiChat` + `EngineConfig` | llamadas y elección del modelo |
| `KnowledgeItemSyncJob` | vectorizar las respuestas predefinidas que se creen |
| **`feat/predefinidas_prompt`** (sin mergear) | guiones como respuesta con "El mensaje es el prompt" + guion en curso |

---

## 7. Riesgos y cómo se cubren

| Riesgo | Cobertura |
|---|---|
| Se pierden reglas importantes al condensar | cobertura por ID de las 373 inviolables; nada se descarta sin decisión de la persona |
| El prompt queda demasiado largo y el modelo lo cumple mal | presupuesto con medidor; reglas de tema a las rutas (el modelo solo ve las de la ruta del turno) |
| Rutas que el clasificador no distingue | frases del cliente escritas por IA + pruebas sugeridas con el clasificador real antes de guardar |
| Etiquetas con tildes o inexistentes | mismo aviso que el modal de predefinidas y el comprobador |
| Contenido confidencial que termina en una respuesta al cliente | lo marcado "USO INTERNO" nunca va a Conocimiento |
| Un `.md` sin formato de reglas | modo genérico (§4.1): más IA, mismo flujo y mismas garantías |
| Costo al reimportar | huella del archivo: la misma versión no se procesa dos veces |
| Crear muchas respuestas predefinidas de golpe | confirmación por fila; se crean en un job, sin bloquear la pantalla |

---

## 8. Fases (días hábiles)

| Fase | Entrega | Cómo se verifica | Días |
|---|---|---|---|
| **F0** ✅ Lectura (`PromptImport::Reader`, rama `feat/importador_md`) | árbol de bloques + detector de formato de reglas + modo genérico | spec con ADAM: 818 reglas, 8 capítulos; spec con un prompt común | 1 |
| **F1** Reparto | reglas fijas de destino + llamada de IA para lo dudoso | spec: cada capítulo de ADAM cae donde dice §4.2 | 1 |
| **F2** Prompt en presupuesto | dedupe por embeddings, global vs ruta, orden, condensado, secciones con nombres de la cuenta | spec: cabe en el presupuesto y las 373 inviolables están cubiertas | 1,5 |
| **F3** Rutas | propuesta de rutas + alcance + escalamiento, validadas con el parser real | spec: el comprobador no da bloqueantes; frases y etiquetas válidas | 1,5 |
| **F4** Job y API | tabla, job con avance, endpoints, huella para no reprocesar | request spec: subir, avance, propuesta; reimportar no gasta | 1 |
| **F5** Pantalla | botón "Importar .md", modal con pestañas y medidor, "Cargar en el Asistente" | Vitest + navegador | 2 |
| **F6** Conocimiento | crear respuestas predefinidas (servicios, glosario) y guiones con prompt | spec: se crean, se vectorizan, los guiones tienen `content_is_prompt` | 1,5 |
| **F7** Prueba real | importar ADAM, pruebas sugeridas, conversación en "Agents IA Test"; comparar contra la línea base (§8.1) | cumple §8.1 + conversación de punta a punta en develop | 1 |

### 8.1 Línea base: la muestra hecha a mano (criterio de aceptación de la F7)

`docs/ejemplos/adam_entrenamiento_linea_base.txt` es el Entrenamiento de ADAM armado a mano (21/09/2026)
siguiendo las reglas de este plan: **14.701 caracteres** (≈ 3.700 tokens), 6 rutas + por defecto, 6
secciones globales y 6 por ruta. Pasó el comprobador real: 0 bloqueantes; avisos por etiquetas que no
existen en la cuenta, `@crear_ticket` heredado y secciones sugeridas.

Lo que quedó fuera del prompt en la muestra, y a dónde va:

| Parte | Destino |
|---|---|
| C6: 13 servicios (142 reglas) | una respuesta predefinida por servicio; sus reglas como Prompt de Contenido |
| C7: guiones de redes, Trafficker y web | respuestas predefinidas con "El mensaje es el prompt" |
| C2 Glosario, C3 Analogías, C4 Errores | respuestas predefinidas |
| C4 Diagnóstico Ejecutivo y Final | fuera: los hace el consultor en sesión |
| C1 Forma de aprender / registro de datos | fuera: el agente no escribe en la base de conocimiento |
| C5 gestión de prompts | fuera: es para quien administra |
| C3 Comunicación verbal, C7 Seguimiento | fuera: voz, y los reintentos ya los maneja el motor |

**La F7 se da por cumplida si, importando ADAM, el resultado de la función:**
1. cabe en el presupuesto (≤ 24.000 caracteres) y no pasa de ~1,5 veces la línea base;
2. cubre las 373 inviolables (en el prompt, en una ruta o descartadas a mano), cosa que la muestra
   no pudo verificar y la función sí;
3. propone rutas equivalentes (diagnóstico, servicios, precios, objeciones, reunión, dirección) y el
   comprobador no da bloqueantes;
4. manda a Conocimiento o Fuera lo mismo que la tabla de arriba, o explica por qué no;
5. en las pruebas sugeridas enruta al menos tan bien como la línea base cargada en el mismo agente.

Si sale peor en alguno, se ajusta el reparto o la condensación antes de cerrar la F7.

**Total: 10,5 días hábiles.** F6 necesita que `feat/predefinidas_prompt` esté mergeada; si no, las F0–F5
funcionan igual y los guiones quedan como alcance de su ruta.

---

## 9. Decisiones para el usuario

> **21/09/2026:** el usuario aceptó las propuestas de las decisiones 1 a 5. Queda abierta la 6.

1. **Presupuesto del Entrenamiento.** Propuesta: 24.000 caracteres (≈ 6.000 tokens). El agente más
   grande que hoy funciona (v6.11) tiene 17.000.
2. **El "Texto oficial".** Propuesta: no va al prompt; en la F6 solo se importan como Conocimiento los
   servicios (C6), el glosario (C2) y los guiones (C7). El resto (≈ 600 K caracteres de explicación)
   queda fuera en esta versión.
3. **Los guiones.** Propuesta: respuesta predefinida con "El mensaje es el prompt" (usa el guion en
   curso). Alternativa: alcance de su ruta (no necesita la otra rama, pero no sigue el hilo entre
   mensajes).
4. **Modelo para importar.** Propuesta: gpt-4o siempre, sin importar el modelo del inbox (medido: el
   mini no cumple reglas largas; aquí se escribe el prompt de todo el agente).
5. **¿IDs de regla en el prompt?** Propuesta: no (cuestan tokens y el cliente nunca los debe ver); el
   mapa ID → dónde quedó se guarda en la importación y se ve en la vista previa.
6. **¿En qué cuenta vive ADAM?** Para las etiquetas, el calendario y las respuestas predefinidas. Es
   de Sentidos Creativos: ¿cuenta nueva, o se prueba en la cuenta 2?
