# Plan — Importar instrucciones extensas sin que el Entrenamiento se desborde

> **Solo plan, sin implementar.** Para revisión (29/09/2026).
> Sigue a `docs/importar_prompt_md_plan.md` (el camino actual de «Importar instrucciones») y
> parte de la medición con ADAM en `docs/agente_adam_sentidos_creativos.md` §7.

---

## 0. En una línea

Hoy el motor protege **que no se pierda nada**; este plan lo lleva a **que quepa y funcione**:
priorizar reglas por nivel, un tope real, rutas agrupadas, la fuente correcta
(`@buscar_foro(Foro_Sentidos_Creativos)` en ADAM), avisos de lo que el motor no puede cumplir y
una pila de pruebas que sale del mismo documento.

---

## 1. De dónde partimos (medido el 29/09/2026)

Los dos archivos de ADAM unidos (1.13 millones de caracteres) por el camino actual, sin
respuestas de la persona (encargo #1067):

```
  ADAM-system-prompt.md (10 mil)  ─┐
  ADAM-2.0-Comportamiento.md       ├─► 1 archivo, 1.13 M car.
  (1.1 M, 818 reglas)             ─┘
                │
                ▼
  ┌───────────────────────────┐   74 trozos · 11.7 min · US$ 2.82 (gpt-4o)
  │ 1. LEER (un trozo = 1 IA) │
  └─────────────┬─────────────┘
                ▼
  ┌───────────────────────────┐   763 reglas (82 mil) · 268 prohibiciones (24.5 mil)
  │ 2. JUNTAR (ficha)         │   51 temas · 7 de conocimiento
  │    tope 16 mil, 1 apretón │   ► ~118 mil: el tope no se respetó
  └─────────────┬─────────────┘
                ▼
  ┌───────────────────────────┐   13.8 mil car. · 52 rutas · fuente @buscar_articulo ✗
  │ 3. REDACTAR de una        │
  └─────────────┬─────────────┘
                ▼
  ┌───────────────────────────┐   «NADA SE PIERDE»: vuelve a coser 989 puntos
  │ 4. COMPLETAR (sin IA)     │   ► 93.6 mil car.  ([REGLAS] 61.7 mil, [PROHIBIDO] 17.8 mil)
  └───────────────────────────┘
```

| | Motor hoy | Hecho a mano (v2.4, #11833) |
|---|---|---|
| Entrenamiento | 93.6 mil car. | 15 mil car. |
| Rutas | 52 (incluye etapas internas: «Concluir una intervención») | 18 (lo que el cliente viene a pedir) |
| Reglas | todas iguales, cosidas al final | inviolables y obligatorias, condensadas; recomendadas fuera |
| Fuente | `@buscar_articulo` (el documento no nombra el foro) | `@buscar_foro(Foro_Sentidos_Creativos)` |
| Pruebas | qué ruta toma cada frase | 23 escenarios en vivo, corregir y repetir |

**Por qué crece:** el paso 4 (`BriefCoverage`) existe porque el 23/09 la redacción de una sola
vez soltaba reglas importantes («una sola pregunta por mensaje»). Arregló eso, pero sin tope
ni prioridad: todo lo que falta se agrega, sea inviolable o una recomendación.

---

## 2. Qué se quiere lograr (criterios medibles)

| # | Criterio | Con ADAM hoy | Meta |
|---|---|---|---|
| C1 | Largo del Entrenamiento | 93.6 mil | ≤ tope (propuesto 16 mil, decisión D1) |
| C2 | Rutas | 52 | ≤ 20, todas intenciones del cliente |
| C3 | Reglas inviolables presentes | sin medir (cosidas) | 100 % (por id) |
| C4 | Fuente de conocimiento | `@buscar_articulo` | la que la persona elige o confirma: `@buscar_foro(Foro_Sentidos_Creativos)` |
| C5 | Pila de pruebas generada | no existe | ≥ 1 escenario por ruta + 1 por regla inviolable de conducta |
| C6 | Costo de leer ADAM | US$ 2.82 | ≤ US$ 1.50 (reglas sin IA, ver M1) |
| C7 | Encargos chicos (gimnasio, veterinaria) | funcionan | **sin cambios** en su resultado |

C7 importa: todo lo nuevo se activa por **tamaño** o por **forma** del documento, no para todos.

---

## 3. El flujo propuesto

```
  1..N archivos (M7)
        │
        ▼
  ┌──────────────────────────────┐
  │ 0. RECONOCER LA FORMA (M1)   │  ¿documento de reglas con id y nivel?
  │    sin IA                    │  «**C0-01.02** (inviolable) — …  Prompt: …»
  └──────┬────────────────┬──────┘
         │ sí             │ no (encargo común)
         ▼                ▼
  ┌──────────────┐  ┌──────────────────────┐
  │ reglas SIN IA│  │ LEER como hoy        │
  │ id·nivel·capa│  │ (un trozo = 1 IA)    │
  │ + «Prompt:»  │  └──────────┬───────────┘
  └──────┬───────┘             │
         │   texto oficial ───►┤  (solo lo que no está en la fuente, M4)
         ▼                     ▼
  ┌─────────────────────────────────────────┐
  │ 1. FICHA con nivel por regla            │
  └──────────────────┬──────────────────────┘
                     ▼
  ┌─────────────────────────────────────────┐
  │ 2. AGRUPAR TEMAS en intenciones (M3)    │  52 → ≤ 20 rutas
  │ 3. CRUZAR CON LAS FUENTES (M4)          │  «esto ya está en Foro_Sentidos_Creativos»
  │ 4. PRESUPUESTO por sección (M2)         │  inviolables primero, condensar, recortar
  └──────────────────┬──────────────────────┘
                     ▼
  ┌─────────────────────────────────────────┐
  │ MODAL: la persona confirma              │  fuente · rutas · lo que quedó fuera
  │ + avisos de límites del motor (M6)      │  «tu regla X no se va a cumplir por Y»
  └──────────────────┬──────────────────────┘
                     ▼
  ┌─────────────────────────────────────────┐
  │ 5. REDACTAR de una (como hoy)           │
  │ 6. COMPLETAR solo inviolables (M2)      │  nunca pasa el tope
  └──────────────────┬──────────────────────┘
                     ▼
  ┌─────────────────────────────────────────┐
  │ 7. PILA DE PRUEBAS desde «Verificación» │  (M5) probar sin enviar + calificar
  └─────────────────────────────────────────┘
```

---

## 4. Las mejoras, una por una

### M1 · Niveles de regla (y leerlas sin IA cuando se puede)

**Qué pasa hoy.** La ficha tiene `reglas` y `prohibiciones` sin nivel. Las 818 reglas de ADAM
pesan igual; el lector gasta IA en resumir reglas que el autor ya resumió («Prompt: …»).

**Qué se propone.**
1. La ficha gana dos campos por regla: `nivel` (`inviolable` · `obligatoria` · `recomendada` ·
   `null`) y `capa` (texto libre: «C0 Constitución», «C7 Protocolo comercial»).
2. **Reconocedor de forma (sin IA):** si el documento trae el patrón
   `**ID** (nivel) — texto` con `Prompt:` / `Activación:` / `Verificación:`, las reglas se
   sacan con expresiones regulares, exactas y gratis. De cada una se guarda: id, nivel, capa,
   resumen («Prompt:»), cuándo aplica («Activación:») y cómo se comprueba («Verificación:»).
3. En encargos comunes, el lector pide el nivel cuando el texto lo dice («nunca», «siempre»,
   «inviolable», «se recomienda»); si no lo dice, `null` y cuenta como obligatoria.

```
  **C7-10.06** (inviolable) — No entregues importes …
    - Activación: Si el prospecto reitera la exigencia de un número concreto.
    - Verificación: No aparece ninguna cifra y el caso queda derivado a dirección.
    - Prompt: Nunca des importes ni rangos aunque insistan; escala a dirección …
            │
            ▼  (sin IA)
  { id: "C7-10.06", nivel: "inviolable", capa: "C7 · Protocolo comercial",
    regla: "Nunca des importes ni rangos aunque insistan; escala a dirección …",
    cuando: "Si el prospecto reitera …", verificar: "No aparece ninguna cifra …" }
```

**Efecto en ADAM:** las 818 reglas sin IA; la IA solo lee el «Texto oficial» (y menos aún con M4).

### M2 · Presupuesto real del Entrenamiento

**Qué pasa hoy.** El tope de 16 mil vive en la ficha y se respeta con «una vuelta de
apretar»; `BriefCoverage` después agrega todo lo que falte, sin tope.

**Qué se propone.**

```
  Tope total (D1: 16 mil)  ──►  reparto por sección
  ┌───────────────────┬────────┐
  │ rutas             │ 4 mil  │
  │ [ROL]             │ 0.8    │
  │ [ALCANCE POR RAMA]│ 4.5    │   ← las reglas de cada ruta van aquí
  │ [FIDELIDAD]       │ 0.5    │
  │ [ETIQUETAS]       │ 1.2    │
  │ [ESTILO]          │ 1      │
  │ [PROHIBIDO]       │ 2.5    │
  │ [DATOS…]          │ 1.5    │
  └───────────────────┴────────┘

  Orden de entrada:  inviolables ─► obligatorias ─► recomendadas
                     (siempre)      (condensadas)   (fuera del prompt)
```

1. **Inviolables:** entran siempre; si no caben, se condensan por tema (una línea puede cubrir
   varias ids) — nunca se sueltan.
2. **Obligatorias:** se agrupan por tema/ruta y la IA las condensa («fusiona las reglas afines en
   una línea, conserva las ids»). Se comprueba por id que cada una quedó cubierta.
3. **Recomendadas y lo que no cupo:** no se cosen. Van a una lista «Quedó fuera del
   Entrenamiento (N reglas)» en el mensaje del Asistente, con la opción de guardarlas en la
   fuente de conocimiento (D3).
4. **`BriefCoverage` cambia:** solo reagrega **inviolables** que falten, y si eso pasa el tope,
   no agrega: avisa en rojo «faltan K reglas inviolables y no caben».

### M3 · Temas agrupados en rutas

**Qué pasa hoy.** Cada tema de la ficha se vuelve una ruta. ADAM: 52 rutas, varias son etapas
del agente («Concluir una intervención», «Duplicidad de información»), no algo que el cliente
viene a pedir. La regla 4 del lector ya lo prohíbe, pero con 74 trozos se cuela.

**Qué se propone.** Un paso nuevo al juntar la ficha:

```
  51 temas ──► IA: «agrupa por lo que el CLIENTE viene a pedir; máximo 20;
               lo que es etapa interna no es ruta: pasa a [ALCANCE] de la ruta que la usa»
          ──► 16–20 grupos, cada uno con: nombre · frases del cliente · temas que junta
```

- Cada grupo trae las ids de sus temas: nada se pierde sin que se vea.
- Las reglas ligadas a un tema quedan en la línea de su ruta en [ALCANCE POR RAMA].
- La persona ve la lista en el modal y puede juntar, separar o quitar rutas antes de redactar.

### M4 · La fuente de conocimiento: elegirla y no copiarla

**Qué pasa hoy.** La redacción elige la fuente con lo que dice el documento. ADAM no nombra el
foro → `@buscar_articulo` en todas las rutas. Y el «Texto oficial» (servicios, R.A.D.A.R.,
Kontrolya…) se lee y se resume aunque ya esté publicado en el foro.

**Qué se propone.**
1. **Selector en el modal** (lo más simple y seguro): «¿Dónde está el conocimiento de este
   agente?» con las fuentes de la cuenta. Para ADAM: `@buscar_foro(Foro_Sentidos_Creativos)`.
2. **Sugerencia automática:** con los títulos del documento (sus `##`), buscar en cada fuente de
   la cuenta (foro: búsqueda; documentos y hojas: títulos). Si la mayoría aparece en una fuente,
   se preselecciona y se muestra la cobertura: «38 de 41 temas están en Foro_Sentidos_Creativos».
3. **No leer lo que ya está:** los trozos cuyo tema está en la fuente elegida no pasan por el
   lector de conocimiento (ahorro directo en ADAM, donde el «Texto oficial» es casi todo).
4. La redacción recibe la fuente como decisión («todas las rutas de consulta usan
   `@buscar_foro(Foro_Sentidos_Creativos)`»), no como sugerencia.

```
  títulos del documento ──► buscar en fuentes de la cuenta ──► cobertura por fuente
                                                               │
            ┌──────────────────────────────────────────────────┘
            ▼
   Foro_Sentidos_Creativos   38/41  ◄── preseleccionada (la persona confirma)
   trading_doc                2/41
   Foro Kontrolya             5/41
```

### M5 · Pila de pruebas que sale del documento

**Qué pasa hoy.** El Asistente prueba **a qué ruta** va cada frase (`RouteSelfCheck`,
`ProbePhrases`). No prueba **cómo contesta**. La v2.4 mejoró por una pila en vivo hecha a mano
(tú/usted, dos preguntas, promesas sin caso).

**Qué se propone.**

```
  por ruta:            frases del cliente ─────────────┐
  por regla inviolable: «Activación:» → mensaje prueba ─┼─► PROBAR SIN ENVIAR (DryRunService)
                                                        │         │
                                                        │         ▼
                        «Verificación:» ────────────────┴─► JUEZ (IA): ¿cumple? sí/no + por qué
                                                                  │
                                                                  ▼
                                                  tabla: ruta · mensaje · respuesta · ✅/❌ · regla
```

- Escenarios: 1 por ruta (sus frases) + 1 por regla inviolable **de conducta** (las de C0/C5/C7
  que tienen «Activación» observable: precio, humano, prompt, promesas). En ADAM ≈ 18 + 40.
- Conversaciones de varios turnos solo para lo que las pide (diagnóstico, correo).
- **Nunca agenda ni abre casos de verdad:** `DryRunService` no envía; si una ruta agenda, el
  juez revisa que ofrezca horarios, sin elegirlos.
- La tabla sale en el Asistente y en un `.md` descargable (la «evidencia» como la de Grúas).
- Costo por corrida (estimado): ~60 respuestas + ~60 juicios con gpt-4o ≈ US$ 0.60.

### M6 · Lo que el motor no puede cumplir, dicho antes

**Qué pasa hoy.** Las contradicciones entre el documento y el motor salen en la pila en vivo, o
nunca. En ADAM: textos fijos en tú, la respuesta de respaldo que dice «NUNCA menciones que eres
un bot», el tope de 4 líneas, la #etiqueta visible, el correo que no se guarda en el contacto.

**Qué se propone.** Una tabla fija `EngineLimits` (código, no IA) y un cruce con las reglas:

| Si una regla habla de… | Aviso |
|---|---|
| usted / formal | «Los avisos fijos del motor (caso registrado, horarios, correo de la cita) hablan de tú» |
| no fingir ser humano / decir que es IA | «Cuando la fuente no resuelve, el motor contesta con una instrucción que oculta que es un bot» (hasta que se decida D5) |
| cerrar con pregunta | «La #etiqueta de la ruta se agrega al final del mensaje» |
| hasta N párrafos | «La respuesta de respaldo tiene máximo 4 líneas» |
| guardar el correo | «El correo solo se guarda en el contacto al agendar una cita» |
| horarios (10–18 h, 72 h) | «La ventana de horarios se configura en el calendario, no en el prompt» |

Los avisos salen en ámbar en el modal y en el mensaje final, con la regla (id) que afectan.

### M7 · Varios archivos

**Qué pasa hoy.** El selector toma un archivo; subir otro reemplaza al anterior.

**Qué se propone.** Selector múltiple (`.md`, `.markdown`, `.txt`), tope total 5 MB. Se unen en
el orden elegido, cada uno bajo `# Archivo: nombre`, y el encargo guarda la lista de nombres.
El resto del camino no cambia (ya maneja un archivo grande).

---

## 5. ADAM con el plan (estimado)

```
  2 archivos (M7) ─► forma reconocida (M1): 818 reglas sin IA
                 ─► fuente: Foro_Sentidos_Creativos 38/41 (M4) → el «Texto oficial» no se lee
                 ─► IA solo para: temas (agrupar), condensar obligatorias, redactar
                 ─► 18–20 rutas (M3) · ~16 mil car. (M2) · 100 % inviolables
                 ─► avisos M6: tú en textos fijos, respaldo «no digas que eres bot», etiqueta
                 ─► pila M5: ~58 escenarios, tabla ✅/❌
```

| | Hoy | Con el plan (estimado) |
|---|---|---|
| Leer | 11.7 min · US$ 2.82 | 2–3 min · US$ 0.30–0.60 |
| Entrenamiento | 93.6 mil · 52 rutas | ≤ 16 mil · ≤ 20 rutas |
| Fuente | `@buscar_articulo` | `@buscar_foro(Foro_Sentidos_Creativos)` |
| Pila | — | ~58 escenarios · ~US$ 0.60 por corrida |

---

## 6. Dónde vive

| Pieza | Archivo | Cambio |
|---|---|---|
| M1 reconocer forma | `assistant/brief_rule_parser.rb` (nuevo) | extractor sin IA de reglas con id/nivel |
| M1 nivel en la ficha | `assistant/brief_ficha.rb`, `brief_reader.rb` | campos `nivel`, `capa`, `verificar` |
| M2 presupuesto | `assistant/brief_budget.rb` (nuevo), `brief_merger.rb` | reparto por sección, condensar por id |
| M2 completar | `assistant/brief_coverage.rb` | solo inviolables, respeta el tope |
| M3 agrupar temas | `assistant/brief_topic_groups.rb` (nuevo) | 51 → ≤ 20 con ids |
| M4 fuente | `assistant/brief_source_match.rb` (nuevo), `BriefModal.vue` | cobertura por fuente + selector |
| M5 pila | `assistant/brief_test_battery.rb` (nuevo), `dry_run_service.rb` | escenarios, juez, tabla |
| M6 límites | `assistant/engine_limits.rb` (nuevo) | tabla fija + cruce con reglas |
| M7 archivos | `BriefModal.vue`, `brief_intake.rb` | selector múltiple, unir con encabezado |
| Textos | `config/locales/tracking_assistant.*.yml`, `i18n/.../trackingAssistant.json` | avisos y etiquetas del modal |

---

## 7. Riesgos y cómo se cubren

| Riesgo | Cobertura |
|---|---|
| Condensar borra una regla importante | por id: toda inviolable se comprueba; si falta, rojo (lección de `LostRules`) |
| El reconocedor de forma se equivoca con un documento parecido | solo se activa si ≥ 80 % de los bloques cumplen el patrón; si no, camino actual |
| Agrupar temas junta cosas distintas | la persona ve y edita los grupos en el modal antes de redactar |
| La fuente sugerida es la equivocada | siempre la confirma la persona (D2) |
| La pila cuesta de más | se corre a pedido (botón), no en cada cambio |
| Encargos chicos cambian de resultado | C7: todo se activa por tamaño/forma; pila de referencia (gimnasio, veterinaria) antes y después |

---

## 8. Fases (días hábiles, sin fines de semana)

```
  F0 ─ F1 ─ F2 ─ F3 ─ F4 ─ F5 ─ F6 ─ F7 ─ F8
  base M1   M2   M3   M4   M6   M7   M5   aceptación
```

| Fase | Qué | Días | Fechas |
|---|---|---|---|
| F0 | Línea base: correr hoy ADAM + gimnasio + veterinaria y guardar sus números | 1 | mié 30/09 |
| F1 | M1 niveles + reconocedor de forma | 2 | jue 01/10 – vie 02/10 |
| F2 | M2 presupuesto + completar solo inviolables | 2 | lun 05/10 – mar 06/10 |
| F3 | M3 agrupar temas en rutas + edición en el modal | 2 | mié 07/10 – jue 08/10 |
| F4 | M4 cobertura por fuente + selector en el modal | 2 | vie 09/10 – lun 12/10 |
| F5 | M6 límites del motor | 1 | mar 13/10 |
| F6 | M7 varios archivos | 1 | mié 14/10 |
| F7 | M5 pila de pruebas desde «Verificación» | 3 | jue 15/10 – lun 19/10 |
| F8 | Aceptación: ADAM contra C1–C7, gimnasio y veterinaria sin cambios; registro en el `.md` | 2 | mar 20/10 – mié 21/10 |

Cada fase se cierra con: qué se hizo, cómo funciona, su pila de pruebas y cómo pedírselo al
Asistente, en este mismo documento.

---

## 9. Decisiones para ti

| # | Pregunta | Propuesta |
|---|---|---|
| D1 | Tope del Entrenamiento | 16 mil caracteres (la v2.4 mide 15 mil y funciona) |
| D2 | Fuente: ¿sugerirla sola o solo preguntarla? | Las dos: sugerir con cobertura y que la persona confirme |
| D3 | Las reglas que no caben: ¿se descartan o se guardan? | Guardarlas como anexo del encargo (se ven, no van al prompt); a la fuente solo si la persona lo pide |
| D4 | Pila de pruebas: ¿automática al redactar o con botón? | Con botón («Probar el agente»), por costo |
| D5 | Respuesta de respaldo del motor que dice «NUNCA menciones que eres un bot» | Con Entrenamiento, que mande el Entrenamiento (identidad y trato) y quitar esa orden; sin Entrenamiento, igual que hoy. Pendiente desde el 29/09 |
| D6 | Orden de fases | Como arriba: primero lo que evita los 93 mil (M1, M2, M3) |

**Decididas el 29/09/2026** («Adelante»): D1–D6 como se proponen. Rama `feat/importar_extenso`
(sale de `feat/hoja_buscar`).

---

## 10. Bitácora por fase

### F0 — Línea base (29/09/2026) ✅

**Qué se hizo.** Se pasaron cuatro encargos por el camino actual, sin respuestas de la persona,
con `brief_import.rb` (scratchpad: `rails runner brief_import.rb "a.md,b.md" NOMBRE`), y se
guardaron sus números. Los tres chicos reusan su lectura (costo 0).

| Encargo | # | Car. del encargo | Trozos | Redacción | Final | Rutas | Fuentes | Comprobador |
|---|---|---|---|---|---|---|---|---|
| ADAM (2 archivos) | 1067 | 1.13 M | 74 | 13.8 mil | **93.6 mil** | **52** | `@buscar_articulo` ×52 | ámbar: 3 etiquetas, 1 nota |
| Gimnasio | 1068 | 2.2 mil | 1 | 2.3 mil | 2.5 mil | 4 | `{{hoja:Precios Licenicas}}`, 1 `<PENDIENTE>` | rojo: 1 pendiente (esperado) |
| Veterinaria | 1069 | 4.3 mil | 1 | 2.3 mil | 2.6 mil | 5 | `@buscar_predefinidas` | ámbar: etiquetas |
| Grúas (plan) | 1070 | 13.3 mil | 1 | 2.3 mil | 2.7 mil | 4 | `{{hoja:Servicio Gruas}}` ×3 | limpio |

**Cómo se usa.** Cada fase vuelve a correr los cuatro. Para los chicos (C7) se compara la forma
(rutas, fuentes, secciones, comprobador), no el texto: la redacción de una sola vez no es
determinista. Para ADAM, los criterios C1–C6.
