# Cómo crear el Entrenamiento de un Agente IA — paso a paso

**Guía práctica para quien configura los agentes. Sin código.**

Al final de esta guía vas a tener un Entrenamiento completo, probado y funcionando. Cada
paso agrega una línea al ejemplo, así que podés seguirlo con tu propio caso al lado.

| | |
|---|---|
| **Dónde se escribe** | Agentes IA → tu agente → campo **Entrenamiento** |
| **Tiempo estimado** | 30–45 min la primera vez |
| **Requisito** | tener cargada la información en Base de Conocimiento (o saber que no la tenés) |

<svg viewBox="0 0 880 118" width="100%" style="max-width:880px;height:auto" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Los siete pasos de la guía: inventario, ramas, fuentes, etiquetas, escalamiento, reglas y prueba">
  <line x1="72" y1="46" x2="808" y2="46" stroke="#cbd5e1" stroke-width="2"/>
  <circle cx="72" cy="46" r="19" fill="#eef2ff" stroke="#6366f1" stroke-width="2"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="13" font-weight="700" fill="#4338ca" x="72" y="51" text-anchor="middle">1</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#475569" x="72" y="86" text-anchor="middle">Inventario</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#94a3b8" x="72" y="100" text-anchor="middle">qué te preguntan</text>
  <circle cx="194" cy="46" r="19" fill="#eef2ff" stroke="#6366f1" stroke-width="2"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="13" font-weight="700" fill="#4338ca" x="194" y="51" text-anchor="middle">2</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#475569" x="194" y="86" text-anchor="middle">Ramas</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#94a3b8" x="194" y="100" text-anchor="middle">una por tema</text>
  <circle cx="316" cy="46" r="19" fill="#ecfdf5" stroke="#22c55e" stroke-width="2"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="13" font-weight="700" fill="#15803d" x="316" y="51" text-anchor="middle">3</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#475569" x="316" y="86" text-anchor="middle">Fuentes</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#94a3b8" x="316" y="100" text-anchor="middle">dónde busca</text>
  <circle cx="440" cy="46" r="19" fill="#f0f9ff" stroke="#0ea5e9" stroke-width="2"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="13" font-weight="700" fill="#0369a1" x="440" y="51" text-anchor="middle">4</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#475569" x="440" y="86" text-anchor="middle">Etiquetas</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#94a3b8" x="440" y="100" text-anchor="middle">para automatizar</text>
  <circle cx="564" cy="46" r="19" fill="#fef2f2" stroke="#ef4444" stroke-width="2"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="13" font-weight="700" fill="#b91c1c" x="564" y="51" text-anchor="middle">5</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#475569" x="564" y="86" text-anchor="middle">Escalamiento</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#94a3b8" x="564" y="100" text-anchor="middle">si no alcanza</text>
  <circle cx="686" cy="46" r="19" fill="#fffbeb" stroke="#f59e0b" stroke-width="2"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="13" font-weight="700" fill="#b45309" x="686" y="51" text-anchor="middle">6</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#475569" x="686" y="86" text-anchor="middle">Reglas</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#94a3b8" x="686" y="100" text-anchor="middle">cómo habla</text>
  <circle cx="808" cy="46" r="19" fill="#f1f5f9" stroke="#64748b" stroke-width="2"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="13" font-weight="700" fill="#334155" x="808" y="51" text-anchor="middle">7</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#475569" x="808" y="86" text-anchor="middle">Prueba</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#94a3b8" x="808" y="100" text-anchor="middle">y ajuste</text>
</svg>

---

## Antes de empezar: cómo piensa el agente

<svg viewBox="0 0 880 258" width="100%" style="max-width:880px;height:auto" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Los cinco momentos de un mensaje: leer, elegir rama, buscar en la fuente, redactar con las reglas y cerrar con la etiqueta">
  <defs>
    <marker id="p1" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#94a3b8"/>
    </marker>
  </defs>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="12" font-weight="700" fill="#0f172a" x="14" y="24">Qué hace el agente con cada mensaje que llega</text>
  <rect x="10" y="40" width="150" height="106" rx="9" fill="#ffffff" stroke="#94a3b8" stroke-width="1.5"/>
  <circle cx="32" cy="62" r="11" fill="#eef2ff"/><text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#4338ca" x="32" y="66" text-anchor="middle">1</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#0f172a" x="50" y="66">Lee</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="24" y="90">El mensaje y los</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="24" y="104">últimos turnos, para</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="24" y="118">no perder el hilo si</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="24" y="132">la frase es corta.</text>
  <line x1="162" y1="93" x2="186" y2="93" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#p1)"/>
  <rect x="190" y="40" width="150" height="106" rx="9" fill="#ffffff" stroke="#6366f1" stroke-width="1.5"/>
  <circle cx="212" cy="62" r="11" fill="#eef2ff"/><text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#4338ca" x="212" y="66" text-anchor="middle">2</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#0f172a" x="230" y="66">Elige la rama</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="204" y="90">Compara el mensaje</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="204" y="104">con las descripciones</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="204" y="118">que vos escribiste.</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#4338ca" x="204" y="132">Elige UNA sola.</text>
  <line x1="342" y1="93" x2="366" y2="93" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#p1)"/>
  <rect x="370" y="40" width="150" height="106" rx="9" fill="#ffffff" stroke="#22c55e" stroke-width="1.5"/>
  <circle cx="392" cy="62" r="11" fill="#ecfdf5"/><text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#15803d" x="392" y="66" text-anchor="middle">3</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#0f172a" x="410" y="66">Busca</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="384" y="90">Solo en la fuente de</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="384" y="104">esa rama. Nunca en</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="384" y="118">dos a la vez, ni pasa</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="384" y="132">a otra si no encuentra.</text>
  <line x1="522" y1="93" x2="546" y2="93" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#p1)"/>
  <rect x="550" y="40" width="150" height="106" rx="9" fill="#ffffff" stroke="#f59e0b" stroke-width="1.5"/>
  <circle cx="572" cy="62" r="11" fill="#fffbeb"/><text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#b45309" x="572" y="66" text-anchor="middle">4</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#0f172a" x="590" y="66">Redacta</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="564" y="90">Con lo que encontró</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="564" y="104">y con tus reglas, pero</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="564" y="118">solo las de la rama</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="564" y="132">que ya se eligió.</text>
  <line x1="702" y1="93" x2="726" y2="93" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#p1)"/>
  <rect x="730" y="40" width="140" height="106" rx="9" fill="#ffffff" stroke="#0ea5e9" stroke-width="1.5"/>
  <circle cx="752" cy="62" r="11" fill="#f0f9ff"/><text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#0369a1" x="752" y="66" text-anchor="middle">5</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#0f172a" x="770" y="66">Cierra</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="744" y="90">Agrega la etiqueta,</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="744" y="104">firma de dónde salió</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="744" y="118">la información</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="744" y="132">y envía.</text>
  <rect x="10" y="162" width="860" height="82" rx="9" fill="#fffbeb" stroke="#f59e0b" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#0f172a" x="28" y="184">¿Y si la fuente no encuentra nada?</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#475569" x="28" y="204">El agente no prueba con otra fuente. Hace lo que vos hayas declarado para esa rama: abrir un ticket, o simplemente responder</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#475569" x="28" y="220">conversando con tus reglas, sin información nueva. Por eso importa tanto elegir bien la fuente de cada rama (Paso 3) y</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#475569" x="28" y="236">decidir qué pasa cuando no alcanza (Paso 5).</text>
</svg>

### Las dos partes del Entrenamiento

<svg viewBox="0 0 880 330" width="100%" style="max-width:880px;height:auto" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="El Entrenamiento tiene dos partes: las líneas de ruta que lee el sistema y las reglas que lee el agente">
  <rect x="14" y="30" width="500" height="216" rx="10" fill="#ffffff" stroke="#94a3b8" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="12" font-weight="700" fill="#0f172a" x="32" y="54">Campo «Entrenamiento» de tu Agente IA</text>
  <rect x="32" y="66" width="464" height="76" rx="8" fill="#eef2ff" stroke="#6366f1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" font-weight="700" fill="#4338ca" x="46" y="84">ARRIBA · las líneas @ruta</text>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9" fill="#0f172a" x="46" y="102">@ruta(soporte #soporte1: fallas, errores): @discourse</text>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9" fill="#0f172a" x="46" y="117">@ruta(precios #info: cuánto cuesta): @buscar_predefinidas</text>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9" fill="#0f172a" x="46" y="132">@ruta_por_defecto: precios</text>
  <rect x="32" y="152" width="464" height="80" rx="8" fill="#f8fafc" stroke="#cbd5e1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" font-weight="700" fill="#475569" x="46" y="170">ABAJO · tus reglas, en texto normal</text>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9" fill="#94a3b8" x="46" y="188">[ROL] Sos asesor de Kontrolya…</text>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9" fill="#94a3b8" x="46" y="203">[ETIQUETAS] Cerrá siempre con una etiqueta…</text>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9" fill="#94a3b8" x="46" y="218">[ESTILO] Dos párrafos como máximo…</text>
  <path d="M500,104 L556,104" stroke="#6366f1" stroke-width="1.5" fill="none"/>
  <path d="M500,192 L556,192" stroke="#94a3b8" stroke-width="1.5" fill="none"/>
  <rect x="560" y="72" width="306" height="66" rx="9" fill="#eef2ff" stroke="#6366f1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#0f172a" x="578" y="94">Esto lo lee el sistema</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#475569" x="578" y="112">Decide la rama, dónde buscar y qué hacer</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#475569" x="578" y="126">si no alcanza. El agente nunca ve estas líneas.</text>
  <rect x="560" y="160" width="306" height="66" rx="9" fill="#f8fafc" stroke="#94a3b8" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#0f172a" x="578" y="182">Esto lo lee el agente</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#475569" x="578" y="200">Su rol, su tono, sus prohibiciones y cuándo</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#475569" x="578" y="214">usar cada etiqueta. El cliente nunca lo ve.</text>
  <rect x="14" y="258" width="852" height="58" rx="9" fill="#fef2f2" stroke="#ef4444" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#b91c1c" x="32" y="280">La regla que más agentes rompe</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#475569" x="32" y="300">Nunca escribas @buscar_predefinidas, @buscar_articulo, @buscar_foro(...) ni @discourse abajo, entre tus reglas.</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#475569" x="32" y="312">Si aparecen fuera de una línea @ruta, el agente ignora TODO tu Entrenamiento y responde a su criterio.</text>
</svg>

---

## Paso 1 · Hacé el inventario

Antes de escribir nada, contestá tres preguntas por cada tema que llega al canal:

1. **¿De qué te escriben?** — en las palabras del cliente, no en las tuyas.
2. **¿Dónde está la respuesta hoy?** — predefinidas, foro, un doc, una hoja, la cabeza de alguien.
3. **¿Qué querés que pase cuando el agente no puede resolverlo?**

Llená esta ficha (podés hacerlo en papel):

| Tema | Cómo lo dice el cliente | Dónde vive la respuesta | Etiqueta al cerrar | ¿Abre ticket? |
|---|---|---|---|---|
| Soporte técnico | "me da error", "no me deja entrar", "dejó de funcionar" | Foro de la comunidad | `#soporte1` | sí, tipo Soporte |
| Precios | "cuánto sale", "qué incluye el plan", "cotización" | Respuestas predefinidas | `#comercial1` | no |
| Trámites | "quiero dar de alta", "necesito cambiar mis datos" | Respuestas predefinidas (las de trámites) | `#gestion` | sí, tipo Comercial |
| Facturación | "mi factura", "el RFC está mal", "ya pagué" | En ningún lado: lo ve administración | `#admin` | sí, tipo Administrativo |

> **Consejo:** si dos filas se responden con lo mismo y se cierran con la misma etiqueta,
> juntalas en una sola. Menos ramas = menos errores de clasificación.

---

## Paso 2 · Convertí cada tema en una rama

Cada fila del inventario se transforma en **una línea** al principio del Entrenamiento.

<svg viewBox="0 0 880 302" width="100%" style="max-width:880px;height:auto" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Partes de una línea de ruta explicadas: nombre, etiqueta, descripción, fuente, separador y escalamiento">
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="12" font-weight="700" fill="#0f172a" x="14" y="24">Las seis partes de una línea @ruta</text>
  <rect x="8" y="36" width="864" height="40" rx="8" fill="#f8fafc" stroke="#cbd5e1"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="12" fill="#0f172a" x="14" y="62">@ruta(soporte #soporte1: fallas, errores, algo que dejó de funcionar): @discourse -&gt; @crear_ticket(tipo=Soporte)</text>
  <path d="M57,78 L57,86 L100,86 L100,78" fill="none" stroke="#6366f1" stroke-width="1.5"/>
  <path d="M78,86 L78,106" stroke="#6366f1" stroke-width="1.5"/>
  <path d="M115,78 L115,94 L172,94 L172,78" fill="none" stroke="#0ea5e9" stroke-width="1.5"/>
  <path d="M143,94 L143,156" stroke="#0ea5e9" stroke-width="1.5"/>
  <path d="M194,78 L194,100 L496,100 L496,78" fill="none" stroke="#8b5cf6" stroke-width="1.5"/>
  <path d="M345,100 L345,206" stroke="#8b5cf6" stroke-width="1.5"/>
  <path d="M525,78 L525,86 L590,86 L590,78" fill="none" stroke="#22c55e" stroke-width="1.5"/>
  <path d="M557,86 L557,106" stroke="#22c55e" stroke-width="1.5"/>
  <path d="M604,78 L604,94 L612,94 L612,78" fill="none" stroke="#f59e0b" stroke-width="1.5"/>
  <path d="M608,94 L608,156" stroke="#f59e0b" stroke-width="1.5"/>
  <path d="M626,78 L626,100 L814,100 L814,78" fill="none" stroke="#ef4444" stroke-width="1.5"/>
  <path d="M720,100 L720,206" stroke="#ef4444" stroke-width="1.5"/>
  <rect x="8" y="108" width="180" height="44" rx="7" fill="#eef2ff" stroke="#6366f1"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" font-weight="700" fill="#0f172a" x="20" y="124">1 · Nombre de la rama</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="20" y="137">Corto, sin espacios ni</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="20" y="148">acentos. Es un apodo interno.</text>
  <rect x="467" y="108" width="180" height="44" rx="7" fill="#ecfdf5" stroke="#22c55e"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" font-weight="700" fill="#0f172a" x="479" y="124">4 · Fuente</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="479" y="137">Dónde busca esta rama.</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="479" y="148">Una sola. Ver Paso 3.</text>
  <rect x="53" y="158" width="180" height="44" rx="7" fill="#f0f9ff" stroke="#0ea5e9"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" font-weight="700" fill="#0f172a" x="65" y="174">2 · Etiqueta de cierre</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="65" y="187">Se agrega al final del mensaje.</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="65" y="198">Es la que ven tus automatizaciones.</text>
  <rect x="518" y="158" width="180" height="44" rx="7" fill="#fffbeb" stroke="#f59e0b"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" font-weight="700" fill="#0f172a" x="530" y="174">5 · La flecha</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="530" y="187">Se lee «y si no alcanza…».</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="530" y="198">Todo lo de la derecha es opcional.</text>
  <rect x="255" y="208" width="180" height="56" rx="7" fill="#f5f3ff" stroke="#8b5cf6"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" font-weight="700" fill="#0f172a" x="267" y="224">3 · Descripción</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="267" y="237">Lo más importante: con esto</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="267" y="248">el sistema decide si el mensaje</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="267" y="259">va a esta rama.</text>
  <rect x="630" y="208" width="180" height="56" rx="7" fill="#fef2f2" stroke="#ef4444"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" font-weight="700" fill="#0f172a" x="642" y="224">6 · Escalamiento</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="642" y="237">Qué hacer si la fuente no</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="642" y="248">resolvió el mensaje. Hoy solo</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="642" y="259">se puede abrir un ticket.</text>
  <rect x="8" y="272" width="864" height="24" rx="7" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#64748b" x="20" y="288">Y al final de todas: @ruta_por_defecto: soporte    ← a qué rama va un mensaje que no encaja en ninguna</text>
</svg>

### Reglas al escribir una rama

| Sí | No |
|---|---|
| `@ruta(` pegado al margen izquierdo | dejar la línea indentada dentro de un párrafo |
| nombres como `soporte`, `comercial_info`, `alta_servicio` | `Soporte Técnico`, `facturación`, `rama 1` |
| descripciones con las palabras del cliente | descripciones con jerga interna ("incidencias N1") |
| descripciones que no se pisan entre ramas | dos ramas que dicen casi lo mismo |
| una línea por rama | dos ramas en la misma línea |

### Cómo escribir la descripción (lo que más impacta)

La descripción es lo único que mira el sistema para decidir la rama. Escribila como una
lista de situaciones, no como un título:

| ❌ Flojo | ✅ Bueno |
|---|---|
| `soporte técnico` | `fallas, errores, algo que ya usa y dejó de funcionar` |
| `ventas` | `precios, planes, licencias, qué incluye, comparativas` |
| `administración` | `facturas, RFC, datos fiscales, comprobantes, ya pagué` |
| `trámites` | `pide que hagamos algo: alta, cambio o baja de un servicio` |

### Ejemplo, primera versión

```text
@ruta(soporte: fallas, errores, algo que ya usa y dejó de funcionar)
@ruta(precios: precios, planes, licencias, qué incluye)
@ruta(gestion: pide que hagamos un trámite, alta, cambio o baja)
@ruta(admin: facturas, RFC, datos fiscales, pagos)
@ruta_por_defecto: precios
```

Todavía le faltan las fuentes: eso es el Paso 3. Tal como está, ninguna rama busca nada.

---

## Paso 3 · Elegí la fuente de cada rama

<svg viewBox="0 0 880 400" width="100%" style="max-width:880px;height:auto" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Árbol de decisión para elegir la fuente de una rama según dónde está escrita la respuesta">
  <defs>
    <marker id="p2" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#94a3b8"/>
    </marker>
  </defs>
  <rect x="245" y="14" width="390" height="44" rx="10" fill="#eef2ff" stroke="#6366f1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="12" font-weight="700" fill="#0f172a" x="440" y="41" text-anchor="middle">¿Dónde está escrita hoy la respuesta de esta rama?</text>
  <path d="M440,58 L440,74 M155,74 L725,74" stroke="#94a3b8" stroke-width="1.5" fill="none"/>
  <line x1="155" y1="74" x2="155" y2="92" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#p2)"/>
  <line x1="440" y1="74" x2="440" y2="92" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#p2)"/>
  <line x1="725" y1="74" x2="725" y2="92" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#p2)"/>
  <rect x="20" y="94" width="270" height="90" rx="9" fill="#ffffff" stroke="#22c55e" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" font-weight="700" fill="#0f172a" x="36" y="114">En las Respuestas predefinidas</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="36" y="130">Las que ya usan los agentes en el chat.</text>
  <rect x="36" y="138" width="238" height="24" rx="6" fill="#ecfdf5" stroke="#bbf7d0"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="46" y="154">@buscar_predefinidas</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="36" y="176">Si dos ramas la comparten, usá grupos ↓</text>
  <rect x="305" y="94" width="270" height="90" rx="9" fill="#ffffff" stroke="#94a3b8" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" font-weight="700" fill="#0f172a" x="321" y="114">En el Centro de Ayuda</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="321" y="130">Los artículos publicados de tu cuenta.</text>
  <rect x="321" y="138" width="238" height="24" rx="6" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="331" y="154">@buscar_articulo</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="321" y="176">Sin grupos: busca en todos los artículos.</text>
  <rect x="590" y="94" width="270" height="90" rx="9" fill="#ffffff" stroke="#94a3b8" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" font-weight="700" fill="#0f172a" x="606" y="114">En el foro o la comunidad</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="606" y="130">Hilos de Discourse, siempre actualizados.</text>
  <rect x="606" y="138" width="238" height="24" rx="6" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="616" y="154">@buscar_foro(Nombre) o @discourse</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="606" y="176">El nombre debe coincidir exactamente.</text>
  <line x1="155" y1="192" x2="155" y2="210" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#p2)"/>
  <line x1="440" y1="192" x2="440" y2="210" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#p2)"/>
  <line x1="725" y1="192" x2="725" y2="210" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#p2)"/>
  <rect x="20" y="212" width="270" height="90" rx="9" fill="#ffffff" stroke="#94a3b8" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" font-weight="700" fill="#0f172a" x="36" y="232">En un documento de Google</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="36" y="248">Un manual, un instructivo, una política.</text>
  <rect x="36" y="256" width="238" height="24" rx="6" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="46" y="272">{{doc:Nombre del documento}}</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="36" y="294">Debe estar conectado en Base de Conocimiento.</text>
  <rect x="305" y="212" width="270" height="90" rx="9" fill="#ffffff" stroke="#94a3b8" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" font-weight="700" fill="#0f172a" x="321" y="232">En una hoja de cálculo</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="321" y="248">Precios, listas, saldos, inventario.</text>
  <rect x="321" y="256" width="238" height="24" rx="6" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="331" y="272">{{hoja:Nombre de la hoja}}</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="321" y="294">En modo Datos los números se calculan exactos.</text>
  <rect x="590" y="212" width="270" height="90" rx="9" fill="#ffffff" stroke="#f59e0b" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" font-weight="700" fill="#0f172a" x="606" y="232">En ningún lado</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="606" y="248">Lo resuelve una persona del equipo.</text>
  <rect x="606" y="256" width="238" height="24" rx="6" fill="#fffbeb" stroke="#fde68a"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="616" y="272">-   (un guion)</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="606" y="294">El agente conversa y toma el pedido.</text>
  <rect x="20" y="316" width="840" height="70" rx="9" fill="#f8fafc" stroke="#cbd5e1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#0f172a" x="38" y="338">Dos reglas que no se negocian</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#475569" x="38" y="358">1 · Una sola fuente por rama. No se puede pedir «buscá en el foro y si no en la hoja»: si querés las dos, hacé dos ramas.</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#475569" x="38" y="376">2 · La fuente tiene que existir, estar activa y tener contenido cargado. Si no, esa rama nunca va a responder con información.</text>
</svg>

### Qué necesitás tener listo para cada fuente

| Fuente | Antes de usarla, verificá |
|---|---|
| `@buscar_predefinidas` | que haya Respuestas predefinidas cargadas en la cuenta |
| `@buscar_articulo` | que haya artículos publicados en el Centro de Ayuda |
| `@buscar_foro(Nombre)` | que la fuente exista en Base de Conocimiento, activa, y que el **nombre sea idéntico** (incluidos espacios) |
| `@discourse` | que la integración de Discourse esté activa **en esa bandeja** |
| `@soporte_contpaq(Nombre)` | que la fuente exista en Base de Conocimiento con sus datos de acceso, activa, y que el **nombre sea idéntico**. Ojo: en esta rama **el tono y las reglas de tu Entrenamiento no se aplican**, porque quien redacta es CONTPAQi |
| `{{doc:Nombre}}` | que el documento esté conectado y sincronizado |
| `{{hoja:Nombre}}` | ídem; y decidir si va en modo FAQ (texto) o Datos (cálculos) |
| `-` | nada: es la rama que no consulta |

### Cuando dos ramas comparten las Respuestas predefinidas

Es el caso más común: precios y trámites viven en la misma lista. Si las dos ramas buscan
en todo, una consulta de precios puede terminar respondida con el guion de un trámite.

La solución es **agrupar por el nombre de la respuesta**:

1. Renombrá tus respuestas predefinidas con un prefijo:
   `GESTION - alta de usuario`, `GESTION - cambio de datos fiscales`.
2. En la rama de trámites poné `@buscar_predefinidas(GESTION)` → busca **solo** en esas.
3. En la rama de información poné `@buscar_predefinidas(!GESTION)` → busca en **todas menos** esas.

> El signo `!` significa "todas menos". No hace falta crear ninguna fuente nueva: alcanza
> con renombrar. Y el grupo se vuelve más exigente: si no hay una instrucción para lo que
> preguntan, prefiere no responder antes que traer algo parecido.

### Ejemplo, segunda versión

```text
@ruta(soporte: fallas, errores, algo que ya usa y dejó de funcionar): @discourse
@ruta(precios: precios, planes, licencias, qué incluye): @buscar_predefinidas(!GESTION)
@ruta(gestion: pide que hagamos un trámite, alta, cambio o baja): @buscar_predefinidas(GESTION)
@ruta(admin: facturas, RFC, datos fiscales, pagos): -
@ruta_por_defecto: precios
```

---

## Paso 4 · Poné la etiqueta de cierre

La etiqueta es la palabra con `#` que queda al final del mensaje. **No es decoración: es lo
que disparan tus automatizaciones.** Si falta, la automatización no corre y nadie se entera.

Se declara pegada al nombre de la rama:

```text
@ruta(soporte #soporte1: fallas, errores, algo que dejó de funcionar): @discourse
```

| Regla | Detalle |
|---|---|
| Formato | minúsculas, sin acentos, mínimo 3 letras: `#soporte1`, `#gestion`, `#admin` |
| Una por rama | si un tema puede cerrar de dos formas, elegí la **más conservadora** para la línea |
| También va en las reglas | el agente elige el grado correcto solo si vos se lo explicás abajo (Paso 6) |
| Cómo funciona | si el agente ya puso una etiqueta, se respeta la suya; si se olvidó, el sistema pone la de la rama |

> **Por qué la más conservadora:** el sistema solo conoce la rama, no el detalle del caso.
> Si en soporte declarás `#soporte2` (requiere técnico), un turno donde el agente se olvidó
> de etiquetar se marca como que necesita revisión — que es el error menos costoso.

### Ejemplo, tercera versión

```text
@ruta(soporte #soporte2: fallas, errores, algo que ya usa y dejó de funcionar): @discourse
@ruta(precios #comercial1: precios, planes, licencias, qué incluye): @buscar_predefinidas(!GESTION)
@ruta(gestion #gestion: pide que hagamos un trámite, alta, cambio o baja): @buscar_predefinidas(GESTION)
@ruta(admin #admin: facturas, RFC, datos fiscales, pagos): -
@ruta_por_defecto: precios
```

---

## Paso 5 · Decidí qué pasa si la fuente no alcanza

Se agrega con una flecha `->` al final de la línea. Se lee: *"consultá esto; y si no
resuelve, hacé esto otro"*.

```text
@ruta(soporte #soporte2: fallas, errores): @discourse -> @crear_ticket(tipo=Soporte, prioridad=alta)
```

| Qué podés poner | Efecto |
|---|---|
| `@crear_ticket` | abre un caso con lo que el agente entendió de la conversación |
| `@crear_ticket(tipo=Soporte)` | fuerza el tipo de caso (usá el nombre exacto de tu catálogo) |
| `@crear_ticket(prioridad=alta)` | fuerza la prioridad: baja, media, alta, urgente |
| nada (sin flecha) | esa rama nunca abre casos: solo conversa |

Detalles que conviene saber:

- Si el cliente **ya tiene un caso abierto**, no se crea otro: se reutiliza y se le avisa.
- Si a la conversación le falta un dato clave del tipo de caso, el agente **lo pide una vez**
  antes de crear.
- Si la conversación no amerita un caso (un saludo, una charla), no crea nada.
- **Importante:** en cuanto **una** rama lleva flecha, las ramas **sin** flecha dejan de abrir
  casos. Es lo esperable, pero conviene tenerlo presente: revisá que cada rama que deba
  escalar tenga la suya.

### Ejemplo, cuarta versión (las rutas ya están terminadas)

```text
@ruta(soporte #soporte2: fallas, errores, algo que ya usa y dejó de funcionar): @discourse -> @crear_ticket(tipo=Soporte, prioridad=alta)
@ruta(precios #comercial1: precios, planes, licencias, qué incluye): @buscar_predefinidas(!GESTION)
@ruta(gestion #gestion: pide que hagamos un trámite, alta, cambio o baja): @buscar_predefinidas(GESTION) -> @crear_ticket(tipo=Comercial)
@ruta(admin #admin: facturas, RFC, datos fiscales, pagos): - -> @crear_ticket(tipo=Administrativo)
@ruta_por_defecto: precios
```

---

## Paso 6 · Escribí las reglas del agente

Debajo de las líneas `@ruta`, en texto normal, va cómo tiene que comportarse. Usá siempre
las mismas seis secciones: son suficientes y evitan que el texto crezca sin control.

<svg viewBox="0 0 880 330" width="100%" style="max-width:880px;height:auto" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Las seis secciones de las reglas y qué controla cada una">
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="12" font-weight="700" fill="#0f172a" x="14" y="24">Las seis secciones, y qué controla cada una</text>
  <rect x="14" y="36" width="240" height="40" rx="7" fill="#eef2ff" stroke="#6366f1"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="11" font-weight="700" fill="#4338ca" x="28" y="53">[ROL]</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#475569" x="28" y="68">Quién es y para qué empresa habla</text>
  <rect x="266" y="36" width="600" height="40" rx="7" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#334155" x="280" y="53">Dos líneas alcanzan. Sirve para fijar el «yo» del agente: de qué empresa es, a quién atiende</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#334155" x="280" y="68">y por qué canal. Todo lo demás cuelga de acá.</text>
  <rect x="14" y="82" width="240" height="52" rx="7" fill="#ecfdf5" stroke="#22c55e"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="11" font-weight="700" fill="#15803d" x="28" y="99">[ALCANCE POR RAMA]</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#475569" x="28" y="114">Qué hace en cada tema</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#16a34a" x="28" y="128">La sección más importante</text>
  <rect x="266" y="82" width="600" height="52" rx="7" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#334155" x="280" y="99">Un párrafo por rama, nombrado con LAS MISMAS PALABRAS que pusiste en su descripción.</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#334155" x="280" y="114">El sistema le dice al agente «este mensaje es de la rama X»; con esas palabras el agente</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#334155" x="280" y="129">encuentra el párrafo que le toca aplicar e ignora los otros.</text>
  <rect x="14" y="140" width="240" height="40" rx="7" fill="#fffbeb" stroke="#f59e0b"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="11" font-weight="700" fill="#b45309" x="28" y="157">[FIDELIDAD]</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#475569" x="28" y="172">Qué hacer si la fuente no cubre</text>
  <rect x="266" y="140" width="600" height="40" rx="7" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#334155" x="280" y="157">La búsqueda trae lo más parecido, que a veces es un tema vecino. Sin esta sección, el agente</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#334155" x="280" y="172">adapta ese contenido y suena convincente aunque esté contestando otra cosa.</text>
  <rect x="14" y="186" width="240" height="40" rx="7" fill="#f0f9ff" stroke="#0ea5e9"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="11" font-weight="700" fill="#0369a1" x="28" y="203">[ETIQUETAS]</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#475569" x="28" y="218">Cuál usar en cada caso</text>
  <rect x="266" y="186" width="600" height="40" rx="7" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#334155" x="280" y="203">Listá cada etiqueta con la situación que la merece, y pedí explícitamente que cierre SIEMPRE</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#334155" x="280" y="218">con una, incluso cuando el mensaje solo pide una aclaración o está reuniendo datos.</text>
  <rect x="14" y="232" width="240" height="40" rx="7" fill="#f5f3ff" stroke="#8b5cf6"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="11" font-weight="700" fill="#6d28d9" x="28" y="249">[ESTILO]</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#475569" x="28" y="264">Largo, tono y formato</text>
  <rect x="266" y="232" width="600" height="40" rx="7" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#334155" x="280" y="249">Pedí mensajes cortos: el sistema corta las respuestas largas a media frase. Nada de listas</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#334155" x="280" y="264">salvo pasos, y nada de links: la fuente la firma el sistema al pie.</text>
  <rect x="14" y="278" width="240" height="40" rx="7" fill="#fef2f2" stroke="#ef4444"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="11" font-weight="700" fill="#b91c1c" x="28" y="295">[PROHIBIDO]</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#475569" x="28" y="310">Lo que nunca debe hacer</text>
  <rect x="266" y="278" width="600" height="40" rx="7" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#334155" x="280" y="295">Inventar precios, plazos o números de caso. Prometer tiempos de respuesta. Y sobre todo:</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#334155" x="280" y="310">volver a decidir de qué tema es el mensaje — de eso ya se encargó el sistema.</text>
</svg>

### El detalle que hace la diferencia

El sistema le avisa al agente en qué rama cayó el mensaje usando **el nombre y la
descripción que vos escribiste**. Por eso los títulos de `[ALCANCE POR RAMA]` tienen que
sonar igual que las descripciones:

| En la línea `@ruta` escribiste… | …entonces el párrafo se titula |
|---|---|
| `precios, planes, licencias, qué incluye` | **PRECIOS Y PLANES** — … |
| `pide que hagamos un trámite, alta, cambio o baja` | **TRÁMITES (alta, cambio o baja)** — … |
| `fallas, errores, algo que dejó de funcionar` | **FALLAS Y ERRORES** — … |

Si el párrafo se llama "Nivel 1" y la descripción dice "fallas y errores", el agente no
los relaciona y termina aplicando las reglas de otra rama.

### Ejemplo de reglas completas

```text
[ROL]
Sos el coordinador de atención de Kontrolya. Atendés por WhatsApp a clientes que ya usan el
sistema y a personas interesadas en contratarlo. Hablás como alguien del equipo.

[ALCANCE POR RAMA]
FALLAS Y ERRORES — explicás el procedimiento con los nombres de menús, permisos y campos tal
como aparecen en la documentación. No opinás sobre la causa si la documentación no la dice.
PRECIOS Y PLANES — das la cifra o el dato directo. No pedís datos del cliente para responder
una consulta de información.
TRÁMITES (alta, cambio o baja) — pedís los datos indispensables, uno o dos por mensaje, y
confirmás lo que ya quedó registrado.
FACTURACIÓN Y DATOS FISCALES — no tenés documentación: tomás el pedido con sus datos y avisás
que lo pasás al área correspondiente.

[FIDELIDAD]
La información que recibís puede tratar de un tema parecido pero distinto al que preguntaron.
Nunca la adaptes para que encaje: si no cubre exactamente el caso, decilo, contá brevemente
qué sí cubre y ofrecé pasarlo con un asesor. Los nombres de menús, permisos y campos se citan
tal cual aparecen.

[ETIQUETAS]
Cerrá SIEMPRE con una sola etiqueta, en la última línea, aunque el mensaje solo pida una
aclaración o esté reuniendo datos:
#soporte1 la documentación resolvió la consulta
#soporte2 hace falta que lo revise un técnico
#comercial1 información entregada
#gestion trámite en curso
#admin derivado a administración

[ESTILO]
Máximo dos párrafos cortos. Sin listas numeradas salvo que sean pasos. Un emoji como mucho,
solo al saludar. No digas que sos un bot ni que consultaste una base de datos, y no pegues
links: el sistema agrega la fuente al final.

[PROHIBIDO]
Inventar precios, plazos, procedimientos o números de caso. Prometer tiempos de respuesta.
Decidir por tu cuenta de qué tema es el mensaje: la rama ya viene resuelta.
```

---

## Paso 7 · Revisá y probá

### Revisión antes de guardar

- [ ] Cada línea `@ruta` arranca pegada al margen izquierdo.
- [ ] No hay ningún `@buscar_...` ni `@discourse` **abajo**, entre las reglas.
- [ ] Cada rama tiene **una sola** fuente.
- [ ] Los nombres de fuentes (`@buscar_foro(...)`, `{{doc:...}}`, `{{hoja:...}}`) coinciden exactos con Base de Conocimiento.
- [ ] Si usás grupos, las respuestas predefinidas ya están renombradas con el prefijo.
- [ ] `@ruta_por_defecto` nombra una rama que existe.
- [ ] Cada rama tiene su `#etiqueta`, y `[ETIQUETAS]` explica cuándo va cada una.
- [ ] Los títulos de `[ALCANCE POR RAMA]` usan las palabras de las descripciones.
- [ ] Las descripciones de las ramas no se pisan entre sí.

### Guion de prueba

Escribile al agente desde el canal real, **tres mensajes por rama**: uno obvio, uno con las
palabras del cliente y uno ambiguo. Anotá qué esperabas y qué pasó.

| Mensaje de prueba | Rama esperada | Qué tiene que pasar |
|---|---|---|
| "no me deja entrar al sistema" | soporte | responde con el procedimiento del foro y cierra con `#soporte1` o `#soporte2` |
| "cuánto sale la licencia para 20 usuarios" | precios | da la cifra, no pide datos, cierra con `#comercial1` |
| "necesito cambiar mis datos fiscales" | gestión | pide los datos del trámite, cierra con `#gestion` |
| "mi factura de marzo está mal" | admin | toma el pedido, avisa que lo deriva, cierra con `#admin` |
| "hola" | la de por defecto | saluda y pregunta en qué puede ayudar |
| "y para 20?" (después de hablar de precios) | precios | sigue el tema anterior, no cambia de rama |

### Qué mirar en cada respuesta

| Señal | Qué significa | Qué ajustar |
|---|---|---|
| Contesta de otro tema | eligió mal la rama | separá mejor las descripciones (Paso 2) |
| Contesta con documentación parecida pero equivocada | la búsqueda trajo un vecino | agrupá las respuestas predefinidas (Paso 3) o reforzá `[FIDELIDAD]` |
| No pone etiqueta | el agente se la olvidó y la rama no la declara | agregá `#etiqueta` en la línea (Paso 4) |
| Abre tickets de más | hay una flecha donde no corresponde | sacá la flecha de esa rama (Paso 5) |
| Nunca abre tickets | ninguna rama declara flecha, o la que corresponde no la tiene | revisá el Paso 5 |
| Responde larguísimo o cortado | falta la regla de largo | reforzá `[ESTILO]` |
| Ignora todas tus reglas | hay una directiva de búsqueda suelta entre las reglas | movela a su línea `@ruta` |

> Después de cada ajuste, repetí el guion completo: cambiar una descripción puede mover
> mensajes de otra rama.

---

## El ejemplo terminado

```text
@ruta(soporte #soporte2: fallas, errores, algo que ya usa y dejó de funcionar): @discourse -> @crear_ticket(tipo=Soporte, prioridad=alta)
@ruta(precios #comercial1: precios, planes, licencias, qué incluye): @buscar_predefinidas(!GESTION)
@ruta(gestion #gestion: pide que hagamos un trámite, alta, cambio o baja): @buscar_predefinidas(GESTION) -> @crear_ticket(tipo=Comercial)
@ruta(admin #admin: facturas, RFC, datos fiscales, pagos): - -> @crear_ticket(tipo=Administrativo)
@ruta_por_defecto: precios

[ROL]
Sos el coordinador de atención de Kontrolya. Atendés por WhatsApp a clientes que ya usan el
sistema y a personas interesadas en contratarlo. Hablás como alguien del equipo.

[ALCANCE POR RAMA]
FALLAS Y ERRORES — explicás el procedimiento con los nombres de menús, permisos y campos tal
como aparecen en la documentación. No opinás sobre la causa si la documentación no la dice.
PRECIOS Y PLANES — das la cifra o el dato directo. No pedís datos del cliente para responder
una consulta de información.
TRÁMITES (alta, cambio o baja) — pedís los datos indispensables, uno o dos por mensaje, y
confirmás lo que ya quedó registrado.
FACTURACIÓN Y DATOS FISCALES — no tenés documentación: tomás el pedido con sus datos y avisás
que lo pasás al área correspondiente.

[FIDELIDAD]
La información que recibís puede tratar de un tema parecido pero distinto al que preguntaron.
Nunca la adaptes para que encaje: si no cubre exactamente el caso, decilo, contá brevemente
qué sí cubre y ofrecé pasarlo con un asesor. Los nombres de menús, permisos y campos se citan
tal cual aparecen.

[ETIQUETAS]
Cerrá SIEMPRE con una sola etiqueta, en la última línea, aunque el mensaje solo pida una
aclaración o esté reuniendo datos:
#soporte1 la documentación resolvió la consulta
#soporte2 hace falta que lo revise un técnico
#comercial1 información entregada
#gestion trámite en curso
#admin derivado a administración

[ESTILO]
Máximo dos párrafos cortos. Sin listas numeradas salvo que sean pasos. Un emoji como mucho,
solo al saludar. No digas que sos un bot ni que consultaste una base de datos, y no pegues
links: el sistema agrega la fuente al final.

[PROHIBIDO]
Inventar precios, plazos, procedimientos o números de caso. Prometer tiempos de respuesta.
Decidir por tu cuenta de qué tema es el mensaje: la rama ya viene resuelta.
```

---

## Fichas rápidas

### Fuentes (van en la línea `@ruta`, una por rama)

| Se escribe | Busca en | Detalle de uso |
|---|---|---|
| `@buscar_predefinidas` | todas las Respuestas predefinidas | el caso más simple |
| `@buscar_predefinidas(GESTION)` | solo las que empiezan con `GESTION` | renombrá las respuestas con ese prefijo |
| `@buscar_predefinidas(!GESTION)` | todas menos esas | la pareja de la anterior |
| `@buscar_articulo` | Centro de Ayuda | no admite grupos |
| `@buscar_foro(Foro Kontrolya)` | esa fuente de Discourse | **los paréntesis son obligatorios** |
| `@discourse` | el foro configurado en esa bandeja | no lleva nombre |
| `{{doc:Manual de instalación}}` | ese Google Doc | el nombre debe existir tal cual |
| `{{hoja:Precios 2026}}` | esa hoja de cálculo | en modo Datos, calcula números exactos |
| `-` | nada | la rama solo conversa |

### Acciones (van en la línea `@ruta` después de la flecha, o sueltas al final)

| Se escribe | Qué hace | Dónde va |
|---|---|---|
| `-> @crear_ticket(tipo=Soporte)` | abre un caso si la fuente no resolvió | al final de la línea de esa rama |
| `@estado_ticket` | responde "¿cómo va mi caso?" con folio y estado | en su propia línea, al final del Entrenamiento |
| `@agendar_calendar` | ofrece horarios, agenda, mueve y cancela citas | en su propia línea, al final |
| `{{nombre_archivo}}` | el agente lo escribe en su respuesta y se envía el archivo | solo en ramas **sin** fuente |

> `@estado_ticket` y `@agendar_calendar` sí pueden ir sueltos: no son búsquedas. Ponelos en
> su propia línea, al final de todo, y solo si esas funciones están configuradas.

---

## Los 8 errores que más rompen un Entrenamiento

| # | Error | Qué se ve | Arreglo |
|---|---|---|---|
| 1 | Poner `@buscar_...` entre las reglas | el agente ignora todo el Entrenamiento | movelo a una línea `@ruta` |
| 2 | `@buscar_foro` sin paréntesis | el foro nunca contesta | `@buscar_foro(Nombre exacto)` |
| 3 | Dos fuentes en la misma rama | usa una sola, y no siempre la que querías | dividí en dos ramas |
| 4 | Descripciones parecidas entre ramas | mezcla temas | hacelas disjuntas, con palabras del cliente |
| 5 | Nombre de fuente que no coincide | esa rama nunca responde con información | copiá el nombre desde Base de Conocimiento |
| 6 | Olvidar la `#etiqueta` | las automatizaciones no corren | agregala en la línea y explicala en `[ETIQUETAS]` |
| 7 | Títulos de reglas que no coinciden con las descripciones | aplica las reglas de otra rama | unificá el vocabulario |
| 8 | Pedir respuestas largas y detalladas | mensajes cortados a mitad | pedí dos párrafos como máximo |

---

## Preguntas frecuentes

**¿Puedo tener una sola rama?**
Sí. Si el agente atiende un solo tema, una línea `@ruta` y listo — o incluso ninguna, aunque
con rutas siempre queda más claro.

**¿Cuántas ramas conviene tener?**
Entre 2 y 6. Con más, las descripciones empiezan a pisarse y la clasificación se degrada.

**¿Puedo pedirle que busque en el foro y, si no encuentra, en la hoja?**
No. Una fuente por rama. Si el mismo tema vive en dos lados, elegí el principal y usá el
escalamiento para lo que quede afuera.

**¿El cliente ve las líneas `@ruta`?**
No. Ni el cliente ni el agente: las lee solo el sistema.

**¿Qué pasa si un mensaje no encaja en ninguna rama?**
Va a la de `@ruta_por_defecto`. Si no la declaraste, el agente responde conversando sin
consultar ninguna fuente.

**¿Puedo cambiar el modelo de IA desde el Entrenamiento?**
No. El modelo se elige en la integración de la bandeja. Para agentes con muchas reglas
conviene el modelo grande: el chico se saltea instrucciones.

**¿Por qué a veces contesta algo parecido pero no exacto?**
Porque la búsqueda es por parecido y el corpus general es permisivo a propósito. Se corrige
agrupando las respuestas predefinidas y reforzando `[FIDELIDAD]`.

**¿Y si quiero que mande un PDF?**
Cargá el archivo en la pestaña Archivos del Agente IA y nombralo sin espacios ni acentos
(`catalogo`). En una rama **sin** fuente, el agente puede escribir `{{catalogo}}` y el
sistema lo reemplaza por el archivo.

---

## Plantilla en blanco

Copiala, reemplazá lo que está entre `< >` y borrá las ramas que no uses.

```text
@ruta(<nombre_rama_1> #<etiqueta1>: <cómo lo dice el cliente, con varias formas>): <fuente> -> @crear_ticket(tipo=<Tipo>)
@ruta(<nombre_rama_2> #<etiqueta2>: <cómo lo dice el cliente>): <fuente>
@ruta(<nombre_rama_3> #<etiqueta3>: <cómo lo dice el cliente>): -
@ruta_por_defecto: <nombre_rama_2>

[ROL]
Sos <rol> de <empresa>. Atendés por <canal> a <quiénes>. Hablás como alguien del equipo.

[ALCANCE POR RAMA]
<TÍTULO IGUAL A LA DESCRIPCIÓN 1> — <qué hace y qué no hace en este tema>.
<TÍTULO IGUAL A LA DESCRIPCIÓN 2> — <...>.
<TÍTULO IGUAL A LA DESCRIPCIÓN 3> — <...>.

[FIDELIDAD]
La información que recibís puede tratar de un tema parecido pero distinto. Nunca la adaptes:
si no cubre el caso, decilo, contá qué sí cubre y ofrecé pasarlo con un asesor.

[ETIQUETAS]
Cerrá SIEMPRE con una sola etiqueta, en la última línea, aunque el mensaje solo pida una
aclaración o esté reuniendo datos:
#<etiqueta1> <cuándo>
#<etiqueta2> <cuándo>
#<etiqueta3> <cuándo>

[ESTILO]
Máximo dos párrafos cortos. Sin listas salvo pasos. No digas que sos un bot ni pegues links.

[PROHIBIDO]
Inventar <precios/plazos/folios>. Prometer tiempos de respuesta. Decidir de qué tema es el
mensaje: la rama ya viene resuelta.
```
