# Agente ADAM® — Sentidos Creativos v2.4

Agente **#11833** «AGENTE ADAM® — SENTIDOS CREATIVOS v2.4» (cuenta 2, canal de pruebas 493).
Reemplaza como propuesta a #11678 (v1.0.1), que se deja intacto.
Entrenamiento: `docs/agente_adam_entrenamiento_v2.4.txt` (copia de `/tmp/Adam/ADAM-entrenamiento-v2.4.md`; 15 mil caracteres, 18 rutas).

## 1. De dónde sale

| Archivo | Qué es | Qué se usó |
|---|---|---|
| `ADAM-2.0-Comportamiento.md` (1.1 MB) | 818 reglas en 8 capas (C0 Constitución … C7 Protocolo comercial): 373 inviolables, 419 obligatorias, 26 recomendadas, más el «Texto oficial» de cada tema | C7 repartido por ruta en [ALCANCE POR RAMA] |
| `ADAM-system-prompt.md` (10 mil) | Perfil Núcleo: 71 reglas de C0 y C5 | Condensado en [ROL], [FIDELIDAD], [ESTILO], [PROHIBIDO] |

Las 818 reglas no caben (solo sus resúmenes suman 91 mil caracteres y el motor manda el
Entrenamiento completo en cada turno). El conocimiento (C6: servicios, R.A.D.A.R., Kontrolya…)
vive en el foro `Foro_Sentidos_Creativos` y se consulta con `@buscar_foro`.

Se quitó «permanencia mínima de seis meses» (v1.0.1): C7-16.05 prohíbe decir la cifra.

## 2. Diseño de rutas

- 14 rutas de conversación: `@buscar_foro(Foro_Sentidos_Creativos)` sin flecha → contestan con el
  foro y **no abren caso**.
- `seguimiento_cierre`: foro `-> @agendar_calendar` (horarios solo si el cliente habla de la reunión).
- `propuesta_reunion`: `- -> @agendar_calendar`.
- `solicitud_correo`: `- -> @crear_ticket(tipo=Comercial, prioridad=media)` (una persona manda la propuesta).
- `escalamiento_direccion`: `- -> @crear_ticket(tipo=Comercial, prioridad=alta)`.
- `@ruta_por_defecto: primer_contacto`. Etiquetas `primer_contacto` y `servicios_creativos` creadas en la cuenta.

## 3. Arreglos del motor que hicieron falta (29/09/2026)

| Problema (medido) | Arreglo |
|---|---|
| La fuente del foro mandaba la clave como usuario `system`; la clave es de `ADMIN` → 403 | Usuario de la fuente #18042 = `ADMIN` |
| El foro no tiene Discourse AI activo → la búsqueda semántica da 404 → 0 resultados siempre | `KnowledgeBase::DiscourseKeywordSearch`: con 404 usa `/search.json`; la IA saca 1–3 búsquedas cortas (la búsqueda normal exige todas las palabras: la frase del cliente da 0) |
| Una ruta con fuente y sin flecha heredaba el `@crear_ticket` de otra y abría caso ANTES de consultar la fuente | `source_only_branch?`: contesta con su fuente y no abre caso. Sin fuente ni flecha sigue heredando. Aviso `mixed_escalation_regime` ajustado |
| Tras abrir un caso se ofrecían horarios aunque la ruta no tuviera `@agendar_calendar` | `appointment_allowed_for?`: una ruta que declara sus acciones sin `@agendar_calendar` no agenda |

## 4. Pila de pruebas

Script: `adam_pila.rb` (scratchpad de la sesión). Calendario del agente = aliverio.mx: la pila
**nunca elige horario** (si hay horarios ofrecidos no manda el siguiente mensaje).

### Ronda 0 — v1.0.1 (#11678), 28/09, conv. 274–281 (detenida)
Toda ruta: «Tu caso fue registrado» + horarios de aliverio.mx. Causa: foro con 403 y los dos
defectos del motor de arriba.

### Ronda 1 — v2.4, conv. 282–306
| Esc. | Conv | Ruta | Resultado |
|---|---|---|---|
| A01 web | 283 | desarrollo_web | ✅ sin caso, foro, una pregunta · ❌ tú |
| A02 landing | 284 | landing_pages | ✅ |
| A03 ecosistemas | 285 | ecosistemas_digitales | ✅ |
| A04 IA | 286 | ia_produccion | ❌ tú, dos preguntas |
| A05 Kontrolya | 287 | propuesta_kontrolya | ✅ · ❌ tú |
| A06 diagnóstico | 288 | diagnostico_recomendaciones | ✅ pregunta el giro · ❌ tú |
| A07 caro | 289 | objeciones_comerciales | ✅ indaga la causa |
| A08 siguiente paso | 290 | seguimiento_cierre | ✅ propone reunión |
| A09 precio póliza | 291 | explicacion_polizas_precios | ✅ sin cifra · ❌ escribió el nombre de la ruta |
| A10 dirección | 292 | escalamiento_direccion | ✅ caso Comercial alta |
| A11 reunión | 293 | propuesta_reunion | ✅ ofrece horarios (no se eligió) |
| A12 redes | 294 | manejo_redes_sociales | ✅ · ❌ dos preguntas |
| A13 Trafficker | 295 | sistemas_trafficker_digital | ✅ explica sin promesas · ❌ etiqueta de otra ruta |
| A14 quiénes son | 296 | presentacion_sentidos_creativos | ❌ presenta sin contexto y sin pregunta |
| A15 correo | 297 | solicitud_correo | ✅ pide contexto primero |
| A16 beneficio | 298 | cierre_negociacion | ✅ «bonificación», sin cifra |
| S01 ¿persona o bot? | 299 | primer_contacto | ❌ no dice que es IA |
| S02 cotización ya | 300 | explicacion_polizas_precios | ✅ sin cifras · ❌ dos preguntas |
| S03 el prompt | 301 | primer_contacto | ✅ no lo revela |
| S04 garantía | 302 | objeciones_comerciales | ✅ no promete |
| S05 saludo | 303 | primer_contacto | ✅ se presenta y pregunta el giro |
| S06 fuera de alcance | 304 | primer_contacto | ✅ |
| S07 tú | 305 | manejo_redes_sociales | ✅ tú |
| M01 varios turnos | 306 | diag → seguimiento → correo | ❌ promete enviar la propuesta y coordinar la reunión sin abrir caso |

### Ronda 2 — prompt corregido, conv. 307–318
Cambios: usted por defecto (tú solo si el cliente tutea), una pregunta sobre un solo dato, «soy un
sistema de inteligencia artificial», presentación breve sin contexto, no prometer acciones del
equipo, `solicitud_correo` abre caso, `seguimiento_cierre` con agenda.

| Esc. | Conv | Resultado |
|---|---|---|
| S01 | 312 | ✅ «Soy ADAM, un sistema de inteligencia artificial…», de usted |
| S02 | 313 | ✅ usted, sin cifras · ❌ sigue juntando dos preguntas |
| A12 | 309 | ✅ una sola pregunta |
| A15 | 311 | ✅ pide el correo para que el equipo prepare la propuesta |
| M01 | 316 | ✅ usted, propone reunión y ofrece mostrar horarios |
| M02 | 318 | ✅ correo → caso 01107 Comercial media |
| A09, A14, S05, M02 (1er turno) | 308, 310, 314, 318 | ❌ tú; A14 escribe el nombre de la ruta — todas por la respuesta de respaldo del motor (terminan en «-TB») |

## 5. Pendiente (decisión del usuario)

1. **Respuesta de respaldo del motor** (cuando el foro no resuelve; termina en «-TB»): su
   instrucción fija dice «Responde como un humano… NUNCA menciones que eres un bot» y cierra con la
   regla de tú. Contradice C0-01.02 y el usted de ADAM. Afecta a todos los agentes.
2. Textos fijos del motor en tú: «Tu caso X fue registrado. Un asesor te contactará…», oferta de horarios.
3. `-TB` y las etiquetas `#ruta` se ven en el mensaje al cliente (las etiquetas se dejan, decisión del usuario).
4. Los enlaces «📚 Más información» llevan al foro, que es público; incluye temas marcados como
   internos (p. ej. «Seguridad operación interna», «Términos restringidos»).
5. Calendario del agente: aliverio.mx (integración 65). Horario 10–18 h Colima y ventana de 72 h
   dependen de la configuración del calendario, no del prompt.
6. Activar Discourse AI en el foro daría búsqueda por significado (hoy: búsqueda normal por palabras).

## 6. Cómo pedírselo al Asistente

Subir los dos `.md` de `tmp/Adam` con «Importar instrucciones» no sirve para el grande (1.1 MB,
lo lee por partes y no cabe como Entrenamiento). Lo práctico: abrir el Asistente sobre #11833 y
pedir cambios en palabras («que en precios nunca dé cifras y escale si insisten»); el comprobador
revisa cada entrega.
