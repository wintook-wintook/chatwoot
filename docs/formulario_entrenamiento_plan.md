# Plan — Entrenamiento por secciones en la ficha del Agente IA

> Rama base: `feat/motor_agentes_ia` · Estado: **plan para revisar, sin código** · 17/09/2026

---

## 1. Qué se pidió

Armar el prompt de un Agente IA **sección por sección, con un formulario**:

- cada sección (ROL, ESTILO, NO SIMULAR, …) es un bloque con **su propia caja de texto**;
- las secciones se **agregan, borran y reordenan**;
- el prompt queda **guardado en la base con su estructura**;
- vive en la **ficha del Agente IA** (pestaña Entrenamiento);
- el chat del Asistente pasa a ser **secundario**: una ayuda, no la forma principal de armarlo.

Lo que **no** cambia: el motor sigue leyendo el texto (`complementary_prompt`), y cada seguimiento
sigue guardando su propia copia del texto al asignarse.

---

## 2. Lo que se midió antes de diseñar

Sobre el respaldo del 11/09/2026 (`tmp/respaldo_agentes_ia_cuenta2_2026-09-11.json`, 29 agentes de la
cuenta 2) y los 4 agentes que hay hoy en la base.

| Dato | Valor | Qué implica |
|---|---|---|
| Agentes con Entrenamiento | 28 de 29 | — |
| Secciones con `[ROL]` (corchetes) | 7 | el formato del Asistente |
| Secciones con `## PERSONALIDAD` (Markdown) | 7 | **hay que reconocerlo**: si no, se abren como un solo bloque |
| Mezclan los dos formatos | 6 | los dos estilos en el mismo prompt |
| **Sin ninguna sección** (texto corrido) | **8** | tienen que poder abrirse y editarse igual |
| Nombres de sección distintos | **110** | la lista **no puede ser fija**: sugerencias + nombre libre |
| Secciones por agente | mediana 8,5 · máximo 31 | el formulario tiene que manejar muchas sin volverse inusable |
| Largo | mediana 45 líneas · máximo 645 | cajas que crecen, secciones plegables |
| Con ramas `@ruta` | 9 | el bloque de ramas es aparte de las secciones |
| Se separan y rearman **idénticos** (formato `[X]`) | 4 de 4 hoy en la base | `DraftPieces` ya garantiza el ida y vuelta |

Y en el código:

| Hallazgo | Dónde | Qué implica |
|---|---|---|
| Hay un selector que **inserta directivas y adjuntos donde está el cursor** | `EditTemplate.vue` · `insertTokenAtPrompt` | con varias cajas, tiene que insertar en la **sección activa** |
| Renombrar un adjunto **reescribe el prompt con `update_columns`** | `AiAgentAttachments::DirectiveReferenceService` | se saltea los callbacks: la estructura no se puede derivar en un `after_save` |
| El Asistente guarda **texto** | `ContactTrackings::Assistant::SaveService` | tiene que actualizar la estructura también |
| Los seguimientos **copian el texto** al asignarse | `BulkAssignService`, `ActionService`, importación, comando `sigue` | no cambian: siguen copiando texto |
| Nadie en el motor lee los rótulos de sección | verificado en fases anteriores | el formato de cada rótulo se puede **conservar tal cual** |
| `EditTemplate.vue` arrastra **167 errores de lint** previos | memoria del proyecto | el formulario va en un **componente aparte**; la ficha solo lo monta |

---

## 3. El principio: estructura y texto, guardados juntos y siempre iguales

```
                     ┌──────────────── ESCRIBEN ────────────────┐
                     │                                          │
   Formulario  ──────┤ estructura ──► armar ──► texto            │
   (ficha)           │                                          │
                     │                                          ├──►  tracking_templates
   Asistente   ──────┤ texto ──► separar ──► estructura          │       ├ complementary_prompt   ◄── el motor
   (chat)            │                                          │       └ training_structure (jsonb)
                     │                                          │
   Renombrar   ──────┤ texto ──► separar ──► estructura          │
   adjunto / API     └──────────────────────────────────────────┘
                                                                      al asignar ▼
                                                               contact_trackings.complementary_prompt
                                                               (copia de TEXTO, como hoy)
```

**Una sola puerta de entrada** en el modelo: `TrackingTemplate#write_training(text:)` o
`#write_training(structure:)`. Las dos escriben **ambas columnas en el mismo `UPDATE`**. Ningún
escritor toca `complementary_prompt` por su cuenta (se cambian los que hoy lo hacen).

**Invariante que se prueba:** `armar(separar(texto)) == texto`, carácter por carácter. Así abrir un
agente en el formulario y guardarlo sin tocar nada **no cambia ni un espacio** de lo que lee el motor.

> Por qué no "la estructura manda y el texto se genera siempre": hay tres escritores de texto (el
> chat, el editor de texto y los agentes que ya existen). Si la estructura fuera la única verdad,
> cada uno tendría que convertir, y lo que no encaje se perdería. Con las dos columnas sincronizadas
> en la misma escritura, cualquiera de los dos lados puede escribir.

---

## 4. La estructura en la base

Columna nueva: `tracking_templates.training_structure` (jsonb, `default: {}`).

```json
{
  "version": 1,
  "blocks": [
    { "type": "routes",   "raw": "@ruta(agendar_cita #citado: quiero una cita…): - -> @agendar_calendar\n@ruta_por_defecto: agendar_cita\n\n" },
    { "type": "preamble", "raw": "PROMPT – AGENTE DE CITAS\n\n---\n\n" },
    { "type": "section",  "title": "ROL",        "style": "bracket",  "body": "Eres el asistente del consultorio…\n\n" },
    { "type": "section",  "title": "PERSONALIDAD","style": "markdown2", "body": "* Profesional pero cercano\n…\n\n" },
    { "type": "section",  "title": "NO SIMULAR", "style": "bracket",  "body": "Nunca digas que la cita quedó agendada…\n" }
  ]
}
```

| Campo | Para qué |
|---|---|
| `blocks` en orden | el orden del texto es el orden del formulario |
| `type: routes` | las líneas `@ruta` y `@ruta_por_defecto`, juntas (ver §7) |
| `type: preamble` | lo que va antes de la primera sección: título del prompt, texto suelto. En los 8 agentes sin secciones, es **todo** el prompt |
| `title` | el nombre tal como está escrito (110 distintos: libre) |
| `style` | `bracket` → `[ROL]` · `markdown2` → `## ROL` · `markdown3` → `### ROL`. Se conserva el de cada sección; las nuevas usan `bracket` |
| `body` con sus espacios | el texto exacto, incluidos los renglones en blanco del final: es lo que hace posible el ida y vuelta idéntico |

**Qué cuenta como sección en un prompt con Markdown:** el nivel de encabezado **más alto que aparece**
(si hay `##` y `###`, las secciones son los `##` y los `###` quedan dentro del cuerpo). Los `[X]`
cuentan siempre como sección. Así "A. COINCIDENCIA EXACTA" (subtítulo) no se separa de su regla.

---

## 5. Separar y armar: `ContactTrackings::TrainingStructure`

```
texto ──► separar ──► blocks ──► armar ──► texto (idéntico)
            │                      ▲
            │                      └── formulario: cambia title/body de un bloque, agrega, borra, mueve
            └── reusa el corte de DraftPieces, extendido a encabezados Markdown
```

- **Extender `DraftPieces`** para reconocer `##`/`###`: hoy solo entiende `[X]`. El Asistente se
  beneficia también: su diff ("qué cambió") hoy ve un prompt Markdown como un solo bloque.
- **Armar una sección nueva o editada:** `"[TÍTULO]\n" + body` (o `## TÍTULO`, según `style`), con un
  renglón en blanco entre secciones. Las que no se tocaron se arman con su texto original.
- **Líneas `@ruta` fuera del bloque de ramas** (en medio de la prosa): se juntan en el bloque de ramas
  **solo si el formulario guarda cambios**; mientras no se toque nada, el texto queda idéntico.

---

## 6. La pantalla

Ficha del Agente IA → pestaña **Entrenamiento**. Arriba, un selector de vista:
**Secciones** (nueva, por defecto) · **Texto** (la caja de hoy, completa).

```
┌─ Entrenamiento ───────────────────────────── [ Secciones | Texto ] ─── ✓ 3 ramas · sin problemas ┐
│                                                                                                   │
│ ▾ RAMAS                                                                                           │
│   ┌──────────────────────────────────────────────────────────────────────────────────────────┐   │
│   │ @ruta(agendar_cita #citado: quiero una cita, necesito agendar): - -> @agendar_calendar     │   │
│   │ @ruta(informacion #citado: cuanto cuesta la consulta, horarios): {{hoja:Info Consultorio}} │   │
│   │ @ruta_por_defecto: informacion                                                            │   │
│   └──────────────────────────────────────────────────────────────────────────────────────────┘   │
│   ⚠ La etiqueta #citado no existe en la cuenta                                                    │
│                                                                                                   │
│ ▾ TEXTO INICIAL   (lo que va antes de la primera sección)                                         │
│   [ PROMPT – AGENTE DE CITAS                                                                  ]   │
│                                                                                                   │
│ ▾ ROL                                                              [↑] [↓] [ⓘ Explicar] [🗑]      │
│   [ Eres el asistente del consultorio del Dr. …                                               ]   │
│   [ …                                                                                         ]   │
│                                                                                                   │
│ ▸ ESTILO  · 2 líneas                                               [↑] [↓] [ⓘ Explicar] [🗑]      │
│ ▸ NO SIMULAR  · 1 línea                                            [↑] [↓] [ⓘ Explicar] [🗑]      │
│                                                                                                   │
│ [ + Agregar sección ▾ ]  ROL · ALCANCE POR RAMA · FIDELIDAD · ETIQUETAS · ESTILO · PROHIBIDO ·    │
│                          NO SIMULAR · (las que ya usa la cuenta) · Otra: [ nombre libre ]         │
│                                                                                                   │
│ [ 🧩 Directiva ] [ 📎 Adjunto ]   ← insertan en la sección donde está el cursor                   │
└───────────────────────────────────────────────────────────────────────────────────────────────────┘
```

| Comportamiento | Detalle |
|---|---|
| Caja por sección | crece con el texto; las secciones se pliegan (con 31 secciones y 645 líneas, plegadas por defecto salvo la que se edita) |
| Nombre de sección | editable en la cabecera; no puede quedar vacío ni repetirse exacto |
| Agregar | menú con las sugeridas + las que ya usa la cuenta + nombre libre. Se agrega al final, o debajo de la sección activa |
| Borrar | pide confirmar si la sección tiene texto |
| Reordenar | flechas ↑↓ (y arrastrar, con el componente nativo de arrastre que ya usa Chatwoot) |
| Directiva / adjunto | los selectores de hoy, pero insertan en **la caja activa** |
| Comprobador | el mismo `ValidatorService`, en vivo. Los avisos de una rama se muestran bajo el bloque de ramas |
| Explicar | por sección, con el `Explainer` de la fase E |
| Vista Texto | la caja completa de hoy. Cambiar de vista no pierde nada: las dos escriben el mismo texto |
| Agentes sin secciones (8 de 28) | se abren con todo en **Texto inicial**; desde ahí se agregan secciones nuevas |
| "Generar / Mejorar con IA" | se mantiene sobre el texto completo; el resultado se vuelve a separar en secciones |

**Componente aparte:** `TrainingSectionsEditor.vue` (con sus hijos `TrainingSectionCard.vue` y
`AddSectionMenu.vue`). `EditTemplate.vue` solo lo monta en la pestaña; sus 167 errores previos de lint
no se tocan (commit con `--no-verify` en ese archivo, como hasta ahora).

---

## 7. Las ramas

El pedido es sobre las secciones de instrucciones. Las ramas van en dos pasos:

| Fase | Cómo se editan |
|---|---|
| **1** (este plan) | un bloque **Ramas** con una caja para las líneas `@ruta` y la rama por defecto, con el comprobador en vivo debajo |
| **2** (siguiente) | **tarjetas por rama**: frases del cliente, etiqueta, fuente, escalamiento y acción de calendario, con **listas** que salen del inventario (no se puede elegir una fuente, etiqueta o calendario que no exista) |

La fase 2 es la que evitaría errores como el "cuesta 15" (fuente equivocada) o el calendario borrado
del 15/09; queda fuera de este plan para no mezclar alcances.

---

## 8. Quién escribe, antes y después

| Escritor | Hoy | Después |
|---|---|---|
| Ficha del agente (formulario) | `form.complementary_prompt` | `training_structure` → el backend arma el texto |
| Ficha del agente (vista Texto) | `form.complementary_prompt` | texto → el backend separa la estructura |
| Asistente, "Guardar en un Agente IA" | `SaveService`: texto | `write_training(text:)` |
| Renombrar un adjunto | `update_columns(complementary_prompt:)` | `write_training(text:)` dentro del mismo servicio |
| API / importación de plantillas | texto | `write_training(text:)` |
| Seguimientos al asignarse | copian el texto | **sin cambios** |

Agentes que ya existen: una **tarea de migración** separa su texto y llena `training_structure`, y
**verifica el invariante** en cada uno (si alguno no rearma idéntico, se reporta y se deja sin estructura:
se abre en vista Texto, como hoy).

---

## 9. Fases

| Fase | Entrega | Cómo se verifica | Días hábiles |
|---|---|---|---|
| **F0** Separar y armar | `TrainingStructure` + `DraftPieces` con Markdown | ida y vuelta idéntico sobre los 28 prompts del respaldo (script local, **sin copiarlos al repo**: tienen datos del negocio) + specs sintéticos | 1,5 |
| **F1** Columna y puerta única | migración `training_structure`, `write_training`, escritores de §8, tarea de migración | specs de cada escritor: después de escribir, las dos columnas coinciden | 1,5 |
| **F2** API | la ficha recibe y manda `training_structure`; validación del título | request specs | 1 |
| **F3** Formulario de secciones | `TrainingSectionsEditor` en la pestaña: cajas, agregar, borrar, reordenar, plegar, vista Texto | Vitest del armado en el cliente + prueba en el navegador | 3 |
| **F4** Ayudas por sección | selectores de directiva/adjunto en la caja activa, comprobador en vivo, Explicar por sección | prueba en el navegador | 1,5 |
| **F5** Ramas en tarjetas | ver §7 fase 2 | — | *plan aparte* |

Total F0–F4: **8,5 días hábiles**.

---

## 10. Decisiones abiertas

1. **Nivel de encabezado Markdown:** la regla propuesta es "el más alto que aparece = sección". En un
   prompt con un solo `#` de título y `##` de secciones, el `#` quedaría como única sección. Propuesta:
   **un `#` único al principio cuenta como Texto inicial**, no como sección.
2. **Los separadores `---`:** quedan dentro del cuerpo de la sección anterior (así el ida y vuelta es
   idéntico). ¿Se ocultan en el formulario o se muestran?
3. **Sugerencias de "Agregar sección":** ¿solo las del contrato del Asistente, o también las que ya usa
   la cuenta (hoy serían 110)? Propuesta: las del contrato + las 10 más usadas en la cuenta.
4. **Seguimientos en curso:** hoy editar un agente **no** cambia los seguimientos ya asignados (tienen
   su copia). ¿Se mantiene, o al guardar se ofrece "aplicar a los N seguimientos activos"?
5. **Chat del Asistente:** ¿también muestra el formulario de secciones en su panel derecho (reusando el
   mismo componente), o queda solo con la vista de texto? Propuesta: fase posterior.
