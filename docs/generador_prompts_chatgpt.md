# Montá un generador de Entrenamientos en ChatGPT / OpenAI

**Paso a paso para que la IA escriba Entrenamientos de Agentes IA que el motor ejecuta de verdad**

| | |
|---|---|
| **Qué vas a montar** | un asistente que entrevista, genera, se audita y entrega un Entrenamiento válido |
| **Tiempo de montaje** | 20 minutos, una sola vez |
| **Requisito** | cuenta de ChatGPT (plan con GPTs) o acceso a la API / Playground |
| **Documentos relacionados** | *Cómo crear el Entrenamiento paso a paso* (para personas) · *Manual del motor* (referencia técnica) |

---

## 1. El circuito completo

No alcanza con "pedirle un prompt a ChatGPT". Lo que hace que esto funcione son **cuatro
estaciones**, y cada una atrapa un tipo de error distinto.

<svg viewBox="0 0 880 300" width="100%" style="max-width:880px;height:auto" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Circuito de cuatro estaciones: entrevista, generación, auditoría y validación mecánica antes de publicar el Entrenamiento">
  <defs>
    <marker id="g1" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#94a3b8"/>
    </marker>
  </defs>
  <rect x="14" y="42" width="196" height="112" rx="10" fill="#ffffff" stroke="#6366f1" stroke-width="1.5"/>
  <rect x="14" y="42" width="196" height="28" rx="10" fill="#eef2ff" stroke="#6366f1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#0f172a" x="112" y="61" text-anchor="middle">1 · Entrevista</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#475569" x="28" y="90">El asistente pregunta lo que</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#475569" x="28" y="104">le falta antes de escribir.</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" font-weight="700" fill="#4338ca" x="28" y="126">Evita:</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="28" y="140">nombres de fuentes inventados</text>
  <line x1="212" y1="98" x2="234" y2="98" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#g1)"/>
  <rect x="238" y="42" width="196" height="112" rx="10" fill="#ffffff" stroke="#22c55e" stroke-width="1.5"/>
  <rect x="238" y="42" width="196" height="28" rx="10" fill="#ecfdf5" stroke="#22c55e" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#0f172a" x="336" y="61" text-anchor="middle">2 · Generación</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#475569" x="252" y="90">Escribe las rutas y la prosa</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#475569" x="252" y="104">siguiendo el contrato cerrado.</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" font-weight="700" fill="#15803d" x="252" y="126">Evita:</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="252" y="140">directivas que no existen</text>
  <line x1="436" y1="98" x2="458" y2="98" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#g1)"/>
  <rect x="462" y="42" width="196" height="112" rx="10" fill="#ffffff" stroke="#f59e0b" stroke-width="1.5"/>
  <rect x="462" y="42" width="196" height="28" rx="10" fill="#fffbeb" stroke="#f59e0b" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#0f172a" x="560" y="61" text-anchor="middle">3 · Auditoría</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#475569" x="476" y="90">Segunda pasada: revisa su</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#475569" x="476" y="104">propia salida y la corrige.</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" font-weight="700" fill="#b45309" x="476" y="126">Evita:</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="476" y="140">descripciones que se pisan</text>
  <line x1="660" y1="98" x2="682" y2="98" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#g1)"/>
  <rect x="686" y="42" width="180" height="112" rx="10" fill="#ffffff" stroke="#0ea5e9" stroke-width="1.5"/>
  <rect x="686" y="42" width="180" height="28" rx="10" fill="#f0f9ff" stroke="#0ea5e9" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#0f172a" x="776" y="61" text-anchor="middle">4 · Validación</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#475569" x="700" y="90">Un script, sin IA, verifica</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#475569" x="700" y="104">la sintaxis exacta.</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" font-weight="700" fill="#0369a1" x="700" y="126">Da:</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="700" y="140">certeza, no probabilidad</text>
  <rect x="14" y="176" width="852" height="52" rx="10" fill="#f8fafc" stroke="#cbd5e1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#0f172a" x="32" y="198">Por qué la estación 4 no es opcional</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#475569" x="32" y="218">Un modelo que revisa su propio trabajo mejora mucho, pero nunca garantiza. El motor no avisa cuando una directiva está mal escrita: la ignora en silencio. El script cierra ese hueco.</text>
  <rect x="14" y="244" width="852" height="44" rx="10" fill="#fef2f2" stroke="#ef4444" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" font-weight="700" fill="#b91c1c" x="32" y="264">Y una advertencia sobre el material que le das</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#475569" x="32" y="280">Cargarle el manual completo del motor EMPEORA la generación: empieza a mezclar detalles internos. Para generar alcanza el contrato de una página del Bloque A.</text>
</svg>

---

## 2. Elegí dónde montarlo

| Opción | Cómo | Cuándo conviene |
|---|---|---|
| **GPT personalizado** (recomendado) | ChatGPT → Explorar GPTs → Crear → pegás el Bloque A en *Instrucciones* | varias personas lo usan sin pegar nada; queda guardado |
| **Playground / API** | `system` = Bloque A, `user` = el pedido | querés automatizarlo o integrarlo a otra herramienta |
| **Conversación suelta** | pegás el Bloque A como primer mensaje | prueba rápida, un solo uso |

Configuración en todos los casos:

| Ajuste | Valor | Por qué |
|---|---|---|
| Modelo | el más capaz disponible (GPT‑4o o superior) | los modelos chicos se saltean el checklist final |
| Temperatura | **0.2** | esto es sintaxis, no creatividad |
| Capacidades del GPT | navegación y generación de imágenes **apagadas** | no las necesita y agregan ruido |
| Conocimiento (archivos) | opcional: *Cómo crear el Entrenamiento paso a paso* | como consulta; **no** subas el manual del motor |

---

## 3. Paso 1 · Juntá el material exacto

Este paso es el que decide la calidad del resultado. El generador **no puede adivinar** los
nombres propios de tu cuenta, y si lo dejás, los inventa.

Completá esta ficha antes de abrir ChatGPT:

| Dato | Dónde lo sacás | Ejemplo |
|---|---|---|
| Nombre exacto de cada fuente | Base de Conocimiento → listado de fuentes | `Foro Kontrolya`, `Precios 2026` |
| Tipo de cada fuente | misma pantalla | foro / Google Doc / hoja / predefinidas / artículos |
| Prefijos de grupo disponibles | nombres de tus Respuestas predefinidas | `GESTION - …` |
| Tipos de ticket | catálogo de Tipos de caso | `Soporte`, `Comercial`, `Administrativo` |
| Etiquetas en uso | tus automatizaciones | `#soporte1`, `#gestion` |
| Temas que llegan | los últimos 50 chats reales | "no me deja entrar", "cuánto sale" |

> **Regla de oro:** cualquier nombre que no esté en esta ficha, el generador lo tiene que
> dejar como `<PENDIENTE: …>`. El Bloque A ya se lo exige.

---

## 4. Paso 2 · Creá el GPT

1. ChatGPT → **Explorar GPTs** → **Crear** → pestaña **Configurar**.
2. **Nombre:** `Generador de Entrenamientos — Agentes IA`.
3. **Descripción:** `Escribe el campo Entrenamiento de un Agente IA del motor de Seguimientos, con rutas, fuentes y etiquetas válidas.`
4. **Instrucciones:** pegá el **Bloque A** completo (sección 5).
5. **Iniciadores de conversación**, pegá estos cuatro:
   - `Quiero un agente de soporte técnico con foro y escalamiento a ticket`
   - `Necesito un coordinador con soporte, comercial y administración`
   - `Auditá este Entrenamiento y decime qué está mal`
   - `Tengo una hoja de precios y quiero que el agente la consulte`
6. **Capacidades:** desmarcá todo.
7. **Conocimiento:** subí, si querés, el documento *Cómo crear el Entrenamiento paso a paso*.
8. Guardar → **Solo yo** o **Cualquiera con el enlace**, según tu equipo.

---

## 5. Paso 3 · Bloque A — las instrucciones del generador

Este es el corazón del montaje. Cada sección previene una falla concreta.

<svg viewBox="0 0 880 336" width="100%" style="max-width:880px;height:auto" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Las siete secciones del prompt del generador y el error que previene cada una">
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="12" font-weight="700" fill="#0f172a" x="14" y="24">Anatomía del Bloque A — cada sección tapa un agujero</text>
  <rect x="14" y="36" width="250" height="38" rx="7" fill="#eef2ff" stroke="#6366f1"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" font-weight="700" fill="#4338ca" x="28" y="53">1 · Rol y misión</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="28" y="67">«no es un prompt libre»</text>
  <rect x="276" y="36" width="590" height="38" rx="7" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#334155" x="290" y="59">Sin esto escribe un prompt de asistente genérico, bien redactado y sin ninguna directiva.</text>
  <rect x="14" y="80" width="250" height="38" rx="7" fill="#ecfdf5" stroke="#22c55e"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" font-weight="700" fill="#15803d" x="28" y="97">2 · Gramática literal</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="28" y="111">la línea @ruta con sus signos</text>
  <rect x="276" y="80" width="590" height="38" rx="7" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#334155" x="290" y="103">Descrita en prosa, el modelo improvisa la puntuación. Mostrada literal, la copia bien.</text>
  <rect x="14" y="124" width="250" height="38" rx="7" fill="#f0f9ff" stroke="#0ea5e9"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" font-weight="700" fill="#0369a1" x="28" y="141">3 · Catálogo cerrado</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="28" y="155">lista blanca + prohibición</text>
  <rect x="276" y="124" width="590" height="38" rx="7" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#334155" x="290" y="147">Es lo que impide el clásico «@evaluar_evidencia»: directivas verosímiles que el motor ignora.</text>
  <rect x="14" y="168" width="250" height="38" rx="7" fill="#fef2f2" stroke="#ef4444"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" font-weight="700" fill="#b91c1c" x="28" y="185">4 · Ejemplo negativo</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="28" y="199">el error típico, ya corregido</text>
  <rect x="276" y="168" width="590" height="38" rx="7" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#334155" x="290" y="191">Enseña más que el positivo: sin verlo, el modelo escribe la directiva dentro de la prosa.</text>
  <rect x="14" y="212" width="250" height="38" rx="7" fill="#fffbeb" stroke="#f59e0b"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" font-weight="700" fill="#b45309" x="28" y="229">5 · Modo entrevista</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="28" y="243">pregunta antes de escribir</text>
  <rect x="276" y="212" width="590" height="38" rx="7" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#334155" x="290" y="235">Sin esto inventa nombres de fuentes y de tipos de ticket que no existen en tu cuenta.</text>
  <rect x="14" y="256" width="250" height="38" rx="7" fill="#f5f3ff" stroke="#8b5cf6"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" font-weight="700" fill="#6d28d9" x="28" y="273">6 · Procedimiento</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="28" y="287">agrupar temas antes de redactar</text>
  <rect x="276" y="256" width="590" height="38" rx="7" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#334155" x="290" y="279">Sin un orden, produce diez ramas solapadas; el clasificador después no puede distinguirlas.</text>
  <rect x="14" y="300" width="250" height="30" rx="7" fill="#f1f5f9" stroke="#64748b"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" font-weight="700" fill="#334155" x="28" y="320">7 · Autoverificación</text>
  <rect x="276" y="300" width="590" height="30" rx="7" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#334155" x="290" y="320">Recupera buena parte de los errores. No reemplaza al script del Paso 6, lo complementa.</text>
</svg>

### Bloque A · copiar completo

````text
Sos un especialista en configurar Agentes IA del motor de Seguimientos de Wintook. Escribís el
campo "Entrenamiento" de un agente. NO es un prompt libre: parte del texto lo parsea el sistema
con patrones exactos y solo se ejecuta lo que coincide literalmente. Lo que no coincide no
falla: deja de existir, en silencio.

═══ CONTRATO DEL MOTOR (cerrado, no ampliable) ═══

El Entrenamiento tiene dos zonas, en este orden.

ZONA 1 — líneas de configuración (las lee el sistema; ni el agente ni el cliente las ven):
  @ruta(<nombre> #<etiqueta>: <descripción>): <fuente> -> <escalamiento>
  @ruta_por_defecto: <nombre de una rama declarada>
  · nombre: [a-z0-9_-]+, sin espacios ni acentos.
  · #etiqueta: [a-z0-9_]+, mínimo 3 letras. Es lo que disparan las automatizaciones. El sistema
    la repone solo si el agente la olvidó, así que declará el grado más conservador.
  · descripción: es LO ÚNICO que el sistema usa para decidir si un mensaje va a esta rama.
    Escribila como lista de situaciones, en las palabras del cliente.
  · fuente: UNA sola del catálogo, o "-" si la rama no consulta nada.
  · -> escalamiento: opcional; solo admite @crear_ticket(...). Corre si la fuente no resolvió.
    OJO: si UNA rama lleva flecha, las ramas sin flecha dejan de abrir casos.

ZONA 2 — la prosa (la lee el agente). Secciones fijas y en este orden:
  [ROL] · [ALCANCE POR RAMA] · [FIDELIDAD] · [ETIQUETAS] · [ESTILO] · [PROHIBIDO]

CATÁLOGO DE FUENTES — una por rama, nada fuera de esta lista:
  @buscar_predefinidas            todas las Respuestas predefinidas
  @buscar_predefinidas(GRUPO)     solo las que empiezan con GRUPO; búsqueda más exigente
  @buscar_predefinidas(!GRUPO)    todas menos esas
  @buscar_articulo                Centro de Ayuda
  @buscar_foro(<nombre exacto>)   foro Discourse — los paréntesis son OBLIGATORIOS
  @discourse                      foro configurado en la bandeja
  {{doc:<nombre exacto>}}         un Google Doc
  {{hoja:<nombre exacto>}}        una hoja de cálculo
  -                               la rama no consulta nada

ACCIONES:
  -> @crear_ticket(tipo=<Tipo>, prioridad=<baja|media|alta|urgente>)  al final de una línea @ruta
  @estado_ticket       en su propia línea al final del Entrenamiento (no es búsqueda)
  @agendar_calendar    ídem
  {{nombre_archivo}}   lo escribe el agente en su respuesta; SOLO en ramas sin fuente

PROHIBIDO ABSOLUTO:
  1. Inventar directivas que no estén en el catálogo.
  2. Escribir @buscar_* o @discourse fuera de una línea @ruta: eso hace que el motor descarte
     TODO el Entrenamiento.
  3. Poner dos fuentes en la misma rama.
  4. Inventar nombres de fuentes, tipos de ticket o etiquetas. Si no los sabés, escribí
     <PENDIENTE: …> y listalo al final.
  5. Usar {{consulta:}} junto con líneas @ruta: son incompatibles.

═══ EJEMPLO CORRECTO ═══
@ruta(soporte #soporte2: fallas, errores, algo que ya usa y dejó de funcionar): @discourse -> @crear_ticket(tipo=Soporte, prioridad=alta)
@ruta(precios #comercial1: precios, planes, licencias, qué incluye): @buscar_predefinidas(!GESTION)
@ruta(gestion #gestion: pide que hagamos un trámite, alta, cambio o baja): @buscar_predefinidas(GESTION) -> @crear_ticket(tipo=Comercial)
@ruta(admin #admin: facturas, RFC, datos fiscales, pagos): - -> @crear_ticket(tipo=Administrativo)
@ruta_por_defecto: precios

[ROL]
Sos el coordinador de atención de Kontrolya. Atendés por WhatsApp a clientes que ya usan el
sistema y a interesados. Hablás como alguien del equipo.

[ALCANCE POR RAMA]
FALLAS Y ERRORES — explicás el procedimiento con los nombres de menús, permisos y campos tal
como aparecen en la documentación. No opinás sobre la causa si la documentación no la dice.
PRECIOS Y PLANES — das la cifra o el dato directo. No pedís datos del cliente para responder
una consulta de información.
TRÁMITES (alta, cambio o baja) — pedís los datos indispensables, uno o dos por mensaje.
FACTURACIÓN Y DATOS FISCALES — no tenés documentación: tomás el pedido y avisás que lo derivás.

[FIDELIDAD]
La información que recibís puede tratar de un tema parecido pero distinto. Nunca la adaptes
para que encaje: si no cubre el caso, decilo, contá qué sí cubre y ofrecé pasarlo con un asesor.

[ETIQUETAS]
Cerrá SIEMPRE con una sola etiqueta en la última línea, aunque el mensaje solo pida una
aclaración o esté reuniendo datos:
#soporte1 la documentación resolvió · #soporte2 requiere un técnico · #comercial1 información
entregada · #gestion trámite en curso · #admin derivado a administración

[ESTILO]
Máximo dos párrafos cortos. Sin listas salvo pasos. No digas que sos un bot ni pegues links.

[PROHIBIDO]
Inventar precios, plazos, procedimientos o números de caso. Decidir por tu cuenta de qué tema
es el mensaje: la rama ya viene resuelta.

═══ ERROR FRECUENTE (no lo repitas) ═══
✗ [ALCANCE] Si preguntan algo técnico, usá @discourse para buscar en el foro.
  → La directiva quedó suelta entre las reglas: el motor descarta el Entrenamiento completo.
✓ La directiva va SIEMPRE dentro de su línea @ruta. En la prosa se describe la conducta,
  nunca la herramienta.

═══ CÓMO TRABAJÁS ═══
PASO 1. Si falta alguno de estos datos, PREGUNTALOS antes de escribir (todos juntos, máximo 6):
  empresa y canal · temas que llegan y cómo los nombra el cliente · nombre EXACTO de cada
  fuente disponible y de qué tipo es · tipos de ticket del catálogo · etiquetas que usan las
  automatizaciones · tono deseado.
PASO 2. Agrupá los temas en 2 a 6 ramas. Si dos se responden con lo mismo y cierran con la
  misma etiqueta, son una sola rama.
PASO 3. Asigná una fuente por rama. Si dos ramas comparten las Respuestas predefinidas, usá
  (GRUPO) en una y (!GRUPO) en la otra, y aclará al final qué prefijo hay que ponerle a cada
  respuesta predefinida.
PASO 4. Escribí la prosa. Los títulos de [ALCANCE POR RAMA] deben usar LAS MISMAS PALABRAS que
  la descripción de su rama: el sistema le anuncia al agente la rama con esa descripción, y así
  la empareja con el párrafo correcto.
PASO 5. Verificá tu salida contra el checklist y corregí antes de entregar.

═══ CHECKLIST OBLIGATORIO ═══
[ ] Cada línea @ruta empieza en la columna 1 y cierra todos sus paréntesis.
[ ] Ninguna @buscar_* ni @discourse aparece fuera de una línea @ruta.
[ ] Cada rama tiene como máximo UNA fuente.
[ ] @buscar_foro lleva paréntesis.
[ ] @ruta_por_defecto nombra una rama declarada.
[ ] Las descripciones de las ramas no se solapan.
[ ] Cada rama tiene #etiqueta y [ETIQUETAS] explica cuándo va cada una.
[ ] Los títulos de [ALCANCE POR RAMA] coinciden con las descripciones.
[ ] No hay ninguna directiva fuera del catálogo.
[ ] No inventé nombres propios: los que no sabía quedaron como <PENDIENTE: …>.

═══ SALIDA ═══
Entregá el Entrenamiento completo en un bloque de código, sin explicaciones previas. Después
del bloque, y solo si aplica: la lista de <PENDIENTE> a completar y las respuestas predefinidas
que hay que renombrar.
````

---

## 6. Paso 4 · Usalo — Bloque B, el pedido

Con el GPT ya creado, cada agente nuevo se pide así. Cuanto más completa la ficha del Paso 1,
menos preguntas te hace y mejor sale a la primera.

```text
Necesito el Entrenamiento de un Agente IA con estos datos:

EMPRESA: Kontrolya · sistema de gestión para empresas
CANAL: WhatsApp
QUIÉNES ESCRIBEN: clientes que ya usan el sistema, y personas evaluando contratarlo

TEMAS QUE LLEGAN (en palabras del cliente):
- "me da error", "no me deja entrar", "dejó de funcionar", "cómo configuro X"
- "cuánto sale", "qué incluye el plan", "necesito cotización para 20 usuarios"
- "quiero dar de alta un usuario", "necesito cambiar mis datos fiscales"
- "mi factura está mal", "ya pagué y no me llegó el comprobante"

FUENTES DISPONIBLES (nombre exacto y tipo):
- "Foro Kontrolya" — foro Discourse, con toda la documentación técnica
- Respuestas predefinidas de la cuenta — incluyen precios y también guiones de trámites

TIPOS DE TICKET: Soporte, Comercial, Administrativo
ETIQUETAS DE LAS AUTOMATIZACIONES: #soporte1, #soporte2, #comercial1, #gestion, #admin
TONO: cercano pero profesional, tuteo, mensajes cortos de WhatsApp

Generá el Entrenamiento.
```

**Qué esperar:** si algo falta, primero te hace hasta 6 preguntas juntas. Si está completo,
devuelve el Entrenamiento en un bloque de código y, debajo, los `<PENDIENTE>` y las respuestas
predefinidas que hay que renombrar con el prefijo del grupo.

---

## 7. Paso 5 · Bloque C, la segunda pasada

Un modelo audita mejor un texto ya escrito que el que está escribiendo. Abrí una conversación
**nueva** con el mismo GPT y pegá esto:

```text
Cambiá de modo: no generes, AUDITÁ.

Revisá el Entrenamiento que sigue contra el contrato del motor y devolvé:

1. Una tabla con: línea | problema | corrección concreta.
   Marcá cada hallazgo como BLOQUEANTE (la funcionalidad no existe), DEGRADA (funciona mal)
   o MENOR (cosmético).
2. Debajo, la versión corregida completa en un bloque de código.
3. Si no encontrás nada, decí exactamente "Sin hallazgos" y no reescribas nada.

Prestá especial atención a:
- directivas de búsqueda fuera de líneas @ruta
- dos fuentes en una misma rama
- @buscar_foro sin paréntesis
- @ruta_por_defecto que no existe
- descripciones de ramas que se solapan
- títulos de [ALCANCE POR RAMA] que no coinciden con las descripciones
- directivas que no están en el catálogo

ENTRENAMIENTO A AUDITAR:
---
<pegá acá el texto>
---
```

> Hacelo siempre en conversación nueva: en la misma, el modelo tiende a defender lo que
> acaba de escribir en lugar de revisarlo.

---

## 8. Paso 6 · Bloque D, la validación sin IA

Esto es lo que te da **certeza**. Guardá el Entrenamiento en un archivo de texto y pasalo por
este script: detecta exactamente lo que el motor ignoraría en silencio.

```bash
python3 validar_entrenamiento.py mi_entrenamiento.txt
```

Salida sobre un archivo con errores típicos:

```text
ERROR  línea 1: Rama "soporte": 2 fuentes en la misma rama, solo se usa una
ERROR  línea 2: Línea @ruta mal formada (revisá paréntesis y los dos puntos finales)
ERROR  línea 3: Rama "gestion": @buscar_foro necesita paréntesis con el nombre exacto
ERROR  línea 3: Rama "gestion": después de la flecha solo se admite @crear_ticket(...)
ERROR  línea 4: Rama "soporte" duplicada: solo se conserva la primera
ERROR  línea 8: Directiva de búsqueda FUERA de una línea @ruta: el motor descarta todo el Entrenamiento
ERROR  línea 5: @ruta_por_defecto apunta a "administrativo", que no es una rama declarada
ERROR  línea -: Directiva inexistente: @evaluar_evidencia — el motor la ignora en silencio
AVISO  línea 3: Rama "gestion" sin #etiqueta: si el agente la olvida, no se dispara la automatización
```

Y sobre uno correcto: `OK — el Entrenamiento cumple el contrato`.

### `validar_entrenamiento.py`

```python
#!/usr/bin/env python3
"""Valida un Entrenamiento de Agente IA contra el contrato del motor.
Uso: python3 validar_entrenamiento.py entrenamiento.txt"""
import re, sys

RUTA_OK   = re.compile(r'^[ \t]*@ruta\([ \t]*([a-z0-9_-]+)[ \t]*(?:#([a-z0-9_]+))?[ \t]*(?::[ \t]*([^)]*))?\)[ \t]*:[ \t]*(.*)$', re.I)
RUTA_ANY  = re.compile(r'@ruta\s*\(', re.I)
DEFAULT   = re.compile(r'^[ \t]*@ruta_por_defecto[ \t]*:[ \t]*([a-z0-9_-]+)[ \t]*$', re.I)
BUSQUEDA  = re.compile(r'@buscar_predefinidas\b|@buscar_art[ií]culo\b|@buscar_foro\b|@discourse\b|\{\{doc:|\{\{hoja:', re.I)
FUENTES   = [re.compile(p, re.I) for p in (
    r'@buscar_predefinidas\b(?:\s*\([^)]*\))?', r'@buscar_art[ií]culo\b',
    r'@buscar_foro\([^)]+\)', r'@discourse\b', r'\{\{doc:[^}]+\}\}', r'\{\{hoja:[^}]+\}\}')]
FORO_MAL  = re.compile(r'@buscar_foro(?!\s*\()', re.I)
CONSULTA  = re.compile(r'\{\{consulta:', re.I)
CONOCIDAS = re.compile(r'@(?:ruta|ruta_por_defecto|buscar_predefinidas|buscar_art[ií]culo|buscar_foro|discourse|crear_ticket|estado_ticket|agendar_calendar)\b', re.I)
CUALQUIER = re.compile(r'@[a-záéíóúñ_][a-z0-9áéíóúñ_]*', re.I)
SIN_FUENTE = {'-', '–', '—', ''}

def validar(texto):
    errores, avisos = [], []
    lineas = texto.splitlines()
    rutas, default_line = {}, None

    for n, linea in enumerate(lineas, 1):
        m = RUTA_OK.match(linea)
        if RUTA_ANY.search(linea) and not m:
            errores.append((n, 'Línea @ruta mal formada (revisá paréntesis y los dos puntos finales)'))
            continue
        if not m:
            d = DEFAULT.match(linea)
            if d:
                default_line = (n, d.group(1).lower())
            elif BUSQUEDA.search(linea):
                errores.append((n, 'Directiva de búsqueda FUERA de una línea @ruta: el motor descarta todo el Entrenamiento'))
            continue

        nombre, tag, desc, cuerpo = m.group(1).lower(), m.group(2), m.group(3), m.group(4).strip()
        if nombre in rutas:
            errores.append((n, f'Rama "{nombre}" duplicada: solo se conserva la primera'))
        rutas[nombre] = True
        fuente, _, escal = cuerpo.partition('->')
        if not _:
            fuente, _, escal = cuerpo.partition('→')
        fuente, escal = fuente.strip(), escal.strip()

        encontradas = sum(1 for f in FUENTES if f.search(fuente))
        if encontradas > 1:
            errores.append((n, f'Rama "{nombre}": {encontradas} fuentes en la misma rama, solo se usa una'))
        if encontradas == 0 and fuente not in SIN_FUENTE:
            errores.append((n, f'Rama "{nombre}": "{fuente}" no es una fuente del catálogo (usá "-" si no consulta nada)'))
        if FORO_MAL.search(fuente):
            errores.append((n, f'Rama "{nombre}": @buscar_foro necesita paréntesis con el nombre exacto'))
        if escal and not re.search(r'@crear_ticket\b', escal, re.I):
            errores.append((n, f'Rama "{nombre}": después de la flecha solo se admite @crear_ticket(...)'))
        if not tag:
            avisos.append((n, f'Rama "{nombre}" sin #etiqueta: si el agente la olvida, no se dispara la automatización'))
        if not desc or not desc.strip():
            avisos.append((n, f'Rama "{nombre}" sin descripción: el clasificador no tiene con qué elegirla'))

    if rutas and CONSULTA.search(texto):
        errores.append((0, '{{consulta:}} no convive con líneas @ruta: el motor enviaría el Entrenamiento completo al cliente'))
    if rutas and not default_line:
        avisos.append((0, 'Falta @ruta_por_defecto: un mensaje que no encaje se queda sin rama'))
    if default_line and default_line[1] not in rutas:
        errores.append((default_line[0], f'@ruta_por_defecto apunta a "{default_line[1]}", que no es una rama declarada'))
    inventadas = {t.lower() for t in CUALQUIER.findall(texto) if not CONOCIDAS.match(t)}
    for t in sorted(inventadas):
        errores.append((0, f'Directiva inexistente: {t} — el motor la ignora en silencio'))
    return errores, avisos

if __name__ == '__main__':
    texto = open(sys.argv[1], encoding='utf-8').read()
    errores, avisos = validar(texto)
    for n, msg in errores: print(f'ERROR  línea {n or "-"}: {msg}')
    for n, msg in avisos:  print(f'AVISO  línea {n or "-"}: {msg}')
    if not errores and not avisos: print('OK — el Entrenamiento cumple el contrato')
    sys.exit(1 if errores else 0)
```

| Qué detecta | Severidad |
|---|---|
| Línea `@ruta` mal formada (paréntesis, espacios en el nombre) | error |
| Directiva de búsqueda fuera de una línea `@ruta` | error |
| Dos fuentes en la misma rama | error |
| Fuente que no está en el catálogo | error |
| `@buscar_foro` sin paréntesis | error |
| Escalamiento que no es `@crear_ticket` | error |
| Rama duplicada | error |
| `@ruta_por_defecto` inexistente | error |
| `{{consulta:}}` mezclado con rutas | error |
| Directiva inventada (`@lo_que_sea`) | error |
| Rama sin `#etiqueta` o sin descripción | aviso |
| Falta `@ruta_por_defecto` | aviso |

> Lo que el script **no** puede verificar: que los nombres de fuentes existan en tu cuenta,
> que las descripciones no se solapen y que los títulos de la prosa coincidan. Eso lo revisa
> el Bloque C y lo confirma la prueba real.

---

## 9. Paso 7 · Probalo en el agente

1. Pegá el Entrenamiento en el Agente IA y guardá.
2. Corré el guion de pruebas del documento *Cómo crear el Entrenamiento paso a paso*: tres
   mensajes por rama — uno obvio, uno en palabras del cliente y uno ambiguo.
3. Verificá tres cosas en cada respuesta: **rama correcta**, **información correcta**,
   **etiqueta presente**.
4. Si algo falla, volvé al Bloque C con el texto y el síntoma; el generador corrige mejor con
   el síntoma delante que con una instrucción abstracta.

---

## 10. Si el generador se equivoca

| Lo que hace mal | Qué agregarle al Bloque A |
|---|---|
| Inventa directivas nuevas | reforzá: *"si necesitás algo que no está en el catálogo, decilo en la respuesta en vez de inventar una directiva"* |
| Escribe la directiva dentro de la prosa | duplicá el ejemplo negativo, esta vez con el caso exacto que produjo |
| Hace 10 ramas | fijá el máximo: *"nunca más de 5 ramas; si sobran temas, agrupalos"* |
| Descripciones en jerga interna | agregá: *"la descripción debe poder leerse como algo que escribiría el cliente"* |
| Inventa nombres de fuentes | subí el modo entrevista: *"NO generes si falta el nombre exacto de alguna fuente"* |
| Devuelve explicaciones largas | reforzá el bloque SALIDA: *"sin preámbulo, empezá por el bloque de código"* |
| Se olvida del checklist | ponelo al final del prompt (los modelos atienden mejor el cierre) y pedí que lo liste marcado |

---

## 11. Variante API (si querés automatizarlo)

```bash
curl https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d @- <<'JSON'
{
  "model": "gpt-4o",
  "temperature": 0.2,
  "messages": [
    {"role": "system", "content": "<Bloque A completo>"},
    {"role": "user",   "content": "<Bloque B con los datos del negocio>"}
  ]
}
JSON
```

Encadenado completo, si lo querés sin intervención: **generar** → **auditar** (segunda llamada
con el Bloque C) → **validar** con el script → si hay errores, tercera llamada pasándole la
salida del script como pedido de corrección. Ese ciclo converge en dos vueltas.

---

## 12. Mantenimiento

El Bloque A es una copia del contrato del motor: si el motor cambia, hay que actualizarlo.
Revisalo cuando pase alguna de estas cosas:

| Cambio en el motor | Qué tocar en el Bloque A |
|---|---|
| Se agrega una directiva nueva | el catálogo y, si aplica, el ejemplo correcto |
| Cambia la sintaxis de `@ruta` | la gramática y los dos ejemplos |
| Aparecen nuevos tipos de fuente | el catálogo |
| Cambian los tipos de ticket de la cuenta | nada del bloque: eso va en el Bloque B, en cada pedido |

> Señal de que quedó desactualizado: el validador marca como error algo que el generador
> produce sistemáticamente. Cuando pase, revisá primero el contrato contra el motor real y
> después actualizá el Bloque A y el script en el mismo movimiento.
