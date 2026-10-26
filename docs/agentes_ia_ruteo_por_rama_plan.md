# Plan — Ruteo de fuentes por rama en Agentes IA (`@ruta`)

**Objetivo**: que un mismo Agente IA use una fuente de conocimiento distinta según la rama
de la conversación, con un número de ramas **libre** (dos, tres o siete) y nombres definidos
por quien configura el agente, sin cablear nada en el código.

| | |
|---|---|
| **Origen** | Análisis del agente #4906 "Atender a los clientes en Soporte, Comercial y Administrativo" |
| **Rama de trabajo** | `fix/test_agentes_ia` |
| **Estado** | Plan — nada implementado |
| **Alcance** | Motor de seguimientos (`ContactTracking`), compartido por todas las cuentas |
| **Fecha** | 25/08/2026 |

---

## 1. El problema en una imagen

<svg viewBox="0 0 860 400" width="100%" style="max-width:860px;height:auto" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Comparación entre el comportamiento actual, con una sola fuente para todas las ramas, y el propuesto, con una fuente por rama">
  <defs>
    <marker id="a1" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#94a3b8"/>
    </marker>
    <marker id="a1g" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#16a34a"/>
    </marker>
  </defs>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="13px" font-weight="700" fill="#b91c1c" x="219" y="30" text-anchor="middle">HOY · una sola fuente para todo</text>
  <rect x="24" y="44" width="390" height="340" rx="12" fill="#ffffff" stroke="#cbd5e1" stroke-width="1.5"/>
  <rect x="48" y="90" width="140" height="30" rx="15" fill="#f1f5f9" stroke="#cbd5e1"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" font-weight="600" fill="#1e293b" x="118" y="110" text-anchor="middle">SOPORTE</text>
  <rect x="48" y="132" width="140" height="30" rx="15" fill="#f1f5f9" stroke="#cbd5e1"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" font-weight="600" fill="#1e293b" x="118" y="152" text-anchor="middle">COMERCIAL</text>
  <rect x="48" y="174" width="140" height="30" rx="15" fill="#f1f5f9" stroke="#cbd5e1"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" font-weight="600" fill="#1e293b" x="118" y="194" text-anchor="middle">ADMINISTRATIVO</text>
  <line x1="192" y1="105" x2="228" y2="136" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#a1)"/>
  <line x1="192" y1="147" x2="228" y2="147" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#a1)"/>
  <line x1="192" y1="189" x2="228" y2="158" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#a1)"/>
  <rect x="232" y="120" width="156" height="54" rx="8" fill="#fef2f2" stroke="#ef4444" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" font-weight="600" fill="#1e293b" x="310" y="142" text-anchor="middle">detect_directive</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="310" y="159" text-anchor="middle">cadena if / elsif</text>
  <line x1="310" y1="174" x2="310" y2="212" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#a1)"/>
  <rect x="225" y="214" width="170" height="52" rx="8" fill="#f1f5f9" stroke="#cbd5e1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" font-weight="600" fill="#1e293b" x="310" y="236" text-anchor="middle">Respuestas Predefinidas</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="310" y="253" text-anchor="middle">16 items · pgvector</text>
  <rect x="48" y="292" width="340" height="64" rx="8" fill="#fef2f2" stroke="#fecaca"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="64" y="314" style="font-weight:700;fill:#b91c1c">El foro Kontrolya nunca se consulta.</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="64" y="332">Gana la primera directiva de la cadena y las tres ramas</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="64" y="348">terminan recibiendo exactamente la misma fuente.</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="13px" font-weight="700" fill="#16a34a" x="641" y="30" text-anchor="middle">CON @ruta · cada rama su fuente</text>
  <rect x="446" y="44" width="390" height="340" rx="12" fill="#ffffff" stroke="#cbd5e1" stroke-width="1.5"/>
  <rect x="470" y="90" width="140" height="30" rx="15" fill="#ecfdf5" stroke="#22c55e"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" font-weight="600" fill="#1e293b" x="540" y="110" text-anchor="middle">SOPORTE</text>
  <rect x="470" y="132" width="140" height="30" rx="15" fill="#ecfdf5" stroke="#22c55e"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" font-weight="600" fill="#1e293b" x="540" y="152" text-anchor="middle">COMERCIAL</text>
  <rect x="470" y="174" width="140" height="30" rx="15" fill="#ecfdf5" stroke="#22c55e"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" font-weight="600" fill="#1e293b" x="540" y="194" text-anchor="middle">ADMINISTRATIVO</text>
  <line x1="614" y1="105" x2="654" y2="105" stroke="#16a34a" stroke-width="1.5" marker-end="url(#a1g)"/>
  <line x1="614" y1="147" x2="654" y2="147" stroke="#16a34a" stroke-width="1.5" marker-end="url(#a1g)"/>
  <line x1="614" y1="189" x2="654" y2="189" stroke="#16a34a" stroke-width="1.5" marker-end="url(#a1g)"/>
  <rect x="658" y="90" width="154" height="30" rx="8" fill="#f8fafc" stroke="#cbd5e1"/>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="11px" fill="#0f172a" x="735" y="110" text-anchor="middle">@discourse</text>
  <rect x="658" y="132" width="154" height="30" rx="8" fill="#f8fafc" stroke="#cbd5e1"/>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="11px" fill="#0f172a" x="735" y="152" text-anchor="middle" style="font-size:10px">@buscar_predefinidas</text>
  <rect x="658" y="174" width="154" height="30" rx="8" fill="#f8fafc" stroke="#cbd5e1"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="735" y="193" text-anchor="middle">sin fuente → humano</text>
  <rect x="470" y="248" width="342" height="108" rx="8" fill="#ecfdf5" stroke="#bbf7d0"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="486" y="270" style="font-weight:700;fill:#15803d">Las ramas no están cableadas en el código.</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="486" y="290">Son las que declare cada agente en su Entrenamiento:</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="486" y="306">tres hoy, siete mañana, o dos con otros nombres.</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="486" y="330">El motor no sabe qué significa “soporte”; solo lee</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="486" y="346">las etiquetas que encuentra declaradas.</text>
</svg>

---

## 2. La sintaxis

El mapa de rutas se declara **dentro del propio Entrenamiento**, en líneas parseables:

```
@ruta(soporte: fallas, errores, configuración, integraciones): @discourse
@ruta(comercial: precios, planes, cotización, demo): @buscar_predefinidas
@ruta(administrativo: facturas, RFC, pagos, comprobantes): —
@ruta_por_defecto: comercial
```

### Gramática

| Elemento | Regla |
|---|---|
| Nombre de rama | `[a-z0-9_-]+`, sin espacios, insensible a mayúsculas |
| Descripción | texto libre tras `:`, hasta el `)`. Es lo que lee el clasificador |
| Directiva | cualquiera del catálogo de fuentes, o `—` / `-` / vacío = **sin fuente** |
| Cantidad | una por línea, sin límite de ramas |
| Por defecto | `@ruta_por_defecto: <nombre>` — opcional |
| Ausencia total | sin líneas `@ruta(` el motor se comporta **exactamente como hoy** |

Patrón: `/@ruta\(\s*([a-z0-9_\-]+)\s*(?::\s*([^)]*))?\)\s*:\s*(.*)$/i`

---

## 3. Anatomía del Entrenamiento

<svg viewBox="0 0 860 430" width="100%" style="max-width:860px;height:auto" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="El Entrenamiento se divide en una zona parseable de rutas y una zona de prosa, y cada zona alimenta una parte distinta del motor">
  <defs>
    <marker id="a2" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#94a3b8"/>
    </marker>
  </defs>
  <rect x="30" y="46" width="420" height="344" rx="10" fill="#ffffff" stroke="#94a3b8" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="13px" font-weight="700" fill="#0f172a" x="48" y="72">Entrenamiento del Agente IA</text>
  <line x1="48" y1="82" x2="432" y2="82" stroke="#e2e8f0"/>
  <rect x="48" y="96" width="384" height="106" rx="8" fill="#eef2ff" stroke="#6366f1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" font-weight="700" fill="#475569" letter-spacing=".03em" x="62" y="116">1 · DECLARACIÓN DE RUTAS — parseable</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10.5px" fill="#0f172a" x="62" y="140">@ruta(soporte: fallas, errores): @discourse</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10.5px" fill="#0f172a" x="62" y="160">@ruta(comercial: precios, demo): @buscar_predefinidas</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10.5px" fill="#0f172a" x="62" y="180">@ruta(administrativo: facturas, RFC): —</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="62" y="196">↑ nombre + descripción            ↑ fuente de datos</text>
  <rect x="48" y="216" width="384" height="150" rx="8" fill="#f8fafc" stroke="#cbd5e1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" font-weight="700" fill="#475569" letter-spacing=".03em" x="62" y="236">2 · PROSA — las 374 líneas actuales, sin tocar</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10.5px" fill="#94a3b8" x="62" y="260">[ROL] Eres el Agente Coordinador de Kontrolya…</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10.5px" fill="#94a3b8" x="62" y="280">[1. CONTINUIDAD] Una respuesta corta puede…</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10.5px" fill="#94a3b8" x="62" y="300">[3. GATE DE SUFICIENCIA] Evaluar con todo el…</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10.5px" fill="#94a3b8" x="62" y="320">[10. NO SIMULACIÓN] Nunca afirmar que…</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10.5px" fill="#94a3b8" x="62" y="340">[11. ESTILO] WhatsApp, mensajes breves, 1–2…</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="62" y="358">Se conserva íntegra y vuelve a llegar al modelo</text>
  <path d="M436,132 L484,124" stroke="#94a3b8" stroke-width="1.5" fill="none" marker-end="url(#a2)"/>
  <path d="M436,172 L484,210" stroke="#94a3b8" stroke-width="1.5" fill="none" marker-end="url(#a2)"/>
  <path d="M436,290 L484,296" stroke="#94a3b8" stroke-width="1.5" fill="none" marker-end="url(#a2)"/>
  <rect x="488" y="90" width="340" height="72" rx="8" fill="#ffffff" stroke="#6366f1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="13px" font-weight="700" fill="#0f172a" x="506" y="112" style="font-size:12px">BranchClassifier</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="506" y="130">Recibe los nombres y las descripciones declaradas.</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="506" y="147">Devuelve qué rama corresponde a este turno.</text>
  <rect x="488" y="176" width="340" height="72" rx="8" fill="#ffffff" stroke="#22c55e" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="13px" font-weight="700" fill="#0f172a" x="506" y="198" style="font-size:12px">detect_search_directive</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="506" y="216">Recibe SOLO la directiva de la rama elegida.</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="506" y="233">Con una sola directiva, la precedencia no decide nada.</text>
  <rect x="488" y="262" width="340" height="72" rx="8" fill="#ffffff" stroke="#f59e0b" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="13px" font-weight="700" fill="#0f172a" x="506" y="284" style="font-size:12px">System prompt del modelo</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="506" y="302">Recibe la prosa, ya sin las líneas @ruta.</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="506" y="319">El estilo y las reglas del prompt vuelven a mandar.</text>
</svg>

---

## 4. Flujo en tiempo de ejecución

<svg viewBox="0 0 860 660" width="100%" style="max-width:860px;height:auto" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Flujo de decisión de un turno: si no hay rutas declaradas se conserva el camino actual; si las hay, se clasifica la rama y se usa su fuente">
  <defs>
    <marker id="a3" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#94a3b8"/>
    </marker>
  </defs>
  <rect x="230" y="16" width="400" height="44" rx="10" fill="#eef2ff" stroke="#6366f1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12.5px" font-weight="700" fill="#0f172a" x="430" y="43" text-anchor="middle">Mensaje entrante del cliente</text>
  <line x1="430" y1="60" x2="430" y2="76" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#a3)"/>
  <rect x="230" y="78" width="400" height="48" rx="10" fill="#fffbeb" stroke="#f59e0b" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12.5px" font-weight="700" fill="#0f172a" x="430" y="100" text-anchor="middle">¿El Entrenamiento declara rutas?</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="11px" fill="#0f172a" x="430" y="117" text-anchor="middle" style="font-size:10px">busca líneas @ruta(…)</text>
  <line x1="230" y1="102" x2="196" y2="102" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#a3)"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" font-weight="700" fill="#475569" x="212" y="96" text-anchor="middle">NO</text>
  <rect x="20" y="74" width="172" height="76" rx="8" fill="#f1f5f9" stroke="#cbd5e1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12.5px" font-weight="700" fill="#0f172a" x="106" y="98" text-anchor="middle" style="font-size:11.5px">Camino de hoy</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="106" y="116" text-anchor="middle">intacto, byte por byte</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="106" y="132" text-anchor="middle">cubre los 14 seguimientos</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" font-weight="700" fill="#475569" x="446" y="140">SÍ</text>
  <line x1="430" y1="126" x2="430" y2="146" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#a3)"/>
  <rect x="230" y="148" width="400" height="60" rx="10" fill="#ffffff" stroke="#94a3b8" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12.5px" font-weight="700" fill="#0f172a" x="430" y="170" text-anchor="middle">RouteMap.parse</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="430" y="188" text-anchor="middle">{ soporte → @discourse · comercial → @buscar_predefinidas</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="430" y="202" text-anchor="middle">· administrativo → sin fuente }</text>
  <line x1="430" y1="208" x2="430" y2="226" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#a3)"/>
  <rect x="230" y="228" width="400" height="60" rx="10" fill="#ffffff" stroke="#6366f1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12.5px" font-weight="700" fill="#0f172a" x="430" y="250" text-anchor="middle">BranchClassifier</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="430" y="268" text-anchor="middle">1 llamada corta al LLM con los nombres declarados</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="430" y="282" text-anchor="middle">devuelve: «soporte»</text>
  <line x1="430" y1="288" x2="430" y2="306" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#a3)"/>
  <rect x="230" y="308" width="400" height="60" rx="10" fill="#ffffff" stroke="#22c55e" stroke-width="1.5"/>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="11px" fill="#0f172a" x="430" y="332" text-anchor="middle">detect_search_directive("@discourse")</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="430" y="352" text-anchor="middle">recibe una sola directiva — la precedencia deja de estorbar</text>
  <line x1="430" y1="368" x2="430" y2="386" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#a3)"/>
  <rect x="230" y="388" width="400" height="44" rx="10" fill="#fffbeb" stroke="#f59e0b" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12.5px" font-weight="700" fill="#0f172a" x="430" y="415" text-anchor="middle">¿La rama declara fuente?</text>
  <line x1="230" y1="410" x2="196" y2="410" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#a3)"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" font-weight="700" fill="#475569" x="212" y="404" text-anchor="middle">NO</text>
  <rect x="20" y="382" width="172" height="76" rx="8" fill="#f1f5f9" stroke="#cbd5e1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12.5px" font-weight="700" fill="#0f172a" x="106" y="406" text-anchor="middle" style="font-size:11.5px">Rama sin fuente</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="106" y="424" text-anchor="middle">respuesta conversacional</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="106" y="440" text-anchor="middle">con la prosa del prompt</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" font-weight="700" fill="#475569" x="446" y="446">SÍ</text>
  <line x1="430" y1="432" x2="430" y2="450" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#a3)"/>
  <rect x="230" y="452" width="400" height="48" rx="10" fill="#ffffff" stroke="#94a3b8" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12.5px" font-weight="700" fill="#0f172a" x="430" y="474" text-anchor="middle">Búsqueda en la fuente de esa rama</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="430" y="491" text-anchor="middle">pgvector, Discourse, Google Doc/Sheet o ERP, según corresponda</text>
  <line x1="430" y1="500" x2="430" y2="518" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#a3)"/>
  <rect x="230" y="520" width="400" height="44" rx="10" fill="#fffbeb" stroke="#f59e0b" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12.5px" font-weight="700" fill="#0f172a" x="430" y="547" text-anchor="middle">¿Hubo resultados?</text>
  <path d="M430,564 L430,576 M300,576 L560,576" stroke="#94a3b8" stroke-width="1.5" fill="none"/>
  <line x1="300" y1="576" x2="300" y2="594" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#a3)"/>
  <line x1="560" y1="576" x2="560" y2="594" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#a3)"/>
  <rect x="180" y="596" width="240" height="48" rx="10" fill="#ecfdf5" stroke="#22c55e" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12.5px" font-weight="700" fill="#0f172a" x="300" y="618" text-anchor="middle">Sí → responde con la fuente</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="300" y="635" text-anchor="middle">firmada con el nombre de la fuente</text>
  <rect x="440" y="596" width="240" height="48" rx="10" fill="#fffbeb" stroke="#f59e0b" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12.5px" font-weight="700" fill="#0f172a" x="560" y="618" text-anchor="middle">No → conversacional</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="560" y="635" text-anchor="middle">no se intenta otra fuente</text>
</svg>

---

## 5. Mapa de cambios en el código

<svg viewBox="0 0 860 400" width="100%" style="max-width:860px;height:auto" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Archivos nuevos, archivos modificados y archivos que no se tocan">
  <rect x="24" y="20" width="252" height="28" rx="14" fill="#dcfce7" stroke="#22c55e"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12px" font-weight="700" letter-spacing=".04em" x="150" y="39" text-anchor="middle" fill="#15803d">ARCHIVOS NUEVOS</text>
  <rect x="24" y="58" width="252" height="60" rx="8" fill="#ffffff" stroke="#bbf7d0"/>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10.5px" fill="#0f172a" x="38" y="78">contact_trackings/route_map.rb</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="38" y="94">Parsea las líneas @ruta( y devuelve</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="38" y="108">el mapa {rama → directiva}.</text>
  <rect x="24" y="126" width="252" height="60" rx="8" fill="#ffffff" stroke="#bbf7d0"/>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10.5px" fill="#0f172a" x="38" y="146">branch_classifier_service.rb</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="38" y="162">Una llamada al LLM: mensaje +</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="38" y="176">ramas declaradas → rama elegida.</text>
  <rect x="24" y="194" width="252" height="60" rx="8" fill="#ffffff" stroke="#bbf7d0"/>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10.5px" fill="#0f172a" x="38" y="214">knowledge_base/directives.rb</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="38" y="230">La cadena de detección, en un</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="38" y="244">único lugar del código.</text>
  <rect x="304" y="20" width="252" height="28" rx="14" fill="#fef3c7" stroke="#f59e0b"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12px" font-weight="700" letter-spacing=".04em" x="430" y="39" text-anchor="middle" fill="#b45309">MODIFICADOS</text>
  <rect x="304" y="58" width="252" height="74" rx="8" fill="#ffffff" stroke="#fde68a"/>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10.5px" fill="#0f172a" x="318" y="78">knowledge_base_response_service</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="318" y="94">detect_directive consulta el mapa;</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="318" y="108">si existe, clasifica y pasa una sola</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="318" y="122">directiva a la cadena.</text>
  <rect x="304" y="140" width="252" height="88" rx="8" fill="#ffffff" stroke="#fde68a"/>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10.5px" fill="#0f172a" x="318" y="160">response_analyzer_job</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="318" y="176">kbase_available? pregunta si alguna</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="318" y="190">rama declarada tiene fuente.</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="318" y="208">job:469 deja de blanquear el prompt:</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="318" y="222">solo quita las líneas @ruta.</text>
  <rect x="584" y="20" width="252" height="28" rx="14" fill="#f1f5f9" stroke="#cbd5e1"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12px" font-weight="700" letter-spacing=".04em" x="710" y="39" text-anchor="middle" fill="#475569">SIN TOCAR</text>
  <rect x="584" y="58" width="252" height="170" rx="8" fill="#ffffff" stroke="#e2e8f0"/>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10.5px" fill="#0f172a" x="598" y="80" style="fill:#94a3b8">router_service.rb</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10.5px" fill="#0f172a" x="598" y="104" style="fill:#94a3b8">ticket_creator_service.rb</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10.5px" fill="#0f172a" x="598" y="128" style="fill:#94a3b8">ticket_status_service.rb</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10.5px" fill="#0f172a" x="598" y="152" style="fill:#94a3b8">@agendar_calendar</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10.5px" fill="#0f172a" x="598" y="176" style="fill:#94a3b8">UI del dashboard</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="598" y="204">El ruteo gobierna solo la fuente de</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="598" y="218">conocimiento, nada más.</text>
  <rect x="24" y="272" width="812" height="106" rx="10" fill="#eff6ff" stroke="#bfdbfe"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12px" font-weight="700" letter-spacing=".04em" x="44" y="296" fill="#1d4ed8">POR QUÉ EL MÓDULO COMPARTIDO NO ES OPCIONAL</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="44" y="320" style="font-size:11px">La cadena de detección de directivas está hoy DUPLICADA: una copia en knowledge_base_response_service.rb:82 y otra en</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="44" y="338" style="font-size:11px">response_analyzer_job.rb:378. Ya se pagó una vez — el bug de @buscar_predeterminadas estaba en los 4 sitios a la vez.</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="44" y="356" style="font-size:11px">Si las dos copias divergen, el motor cree que hay fuente disponible y el servicio no encuentra ninguna, o al revés.</text>
</svg>

---

## 6. Fases

| Fase | Qué | Entregable | Días hábiles |
|---|---|---|---|
| **F0** | Extraer la cadena de detección a `KnowledgeBase::Directives` y usarla desde el servicio y el job | Sin cambio de comportamiento; specs verdes | 0.5 |
| **F1** | `ContactTrackings::RouteMap` — parser del mapa de rutas | Parser + specs de gramática | 0.5 |
| **F2** | `ContactTrackings::BranchClassifierService` — clasificación de rama | Servicio + specs con dobles del LLM | 1 |
| **F3** | Integrar el mapa en `detect_directive` | Ruteo real funcionando | 1 |
| **F4** | `kbase_available?` sensible al mapa | Gate coherente con el servicio | 0.5 |
| **F5** | Sustituir el blanqueo por limpieza selectiva del prompt | La prosa vuelve al modelo | 0.5 |
| **F6** | Migrar el prompt V1.6 al formato `@ruta` y probar el agente #4906 | Ronda de pruebas documentada | 1 |
| **F7** | *(opcional)* Pestaña de rutas en la UI del Agente IA | Editor visual del mapa | 2 |

**Total sin F7: 5 días hábiles.**

F0 es independiente y se puede mergear sola: es una limpieza que reduce riesgo aunque el resto del plan se detenga.

---

## 7. Decisiones ya tomadas

| Decisión | Resolución | Razón |
|---|---|---|
| Si la fuente de la rama no devuelve nada | Cae a conversacional; **no** intenta otras fuentes | Comportamiento predecible y depurable en pruebas |
| Si el clasificador no reconoce ninguna rama | Usa `@ruta_por_defecto`; si no está declarada, conversacional | Evita elegir una fuente al azar |
| Prompts sin `@ruta` | Comportamiento idéntico al actual | Compatibilidad total sin condicionales por cuenta |
| Modelo del clasificador | `EngineConfig.model_for_tracking(tracking, :classifier)` | Respeta el modelo configurado en el inbox |
| Ramas con varias fuentes | Fuera de alcance: una fuente por rama | Mantiene la primera versión simple |

---

## 8. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| El código es compartido por todos los Agentes IA de todas las cuentas | El código nuevo solo se activa si el prompt trae `@ruta(`. Hoy **ninguna** plantilla la tiene |
| Una llamada extra al LLM por mensaje (latencia y costo) | Solo para agentes con rutas declaradas; modelo chico vía `EngineConfig` |
| El clasificador elige la rama equivocada | Registrar la rama elegida en el log y exponerla con `TRACKING_DEBUG_TAG=true` durante las pruebas |
| El CI del repo no corre (runner `self-hosted` inexistente) | Ejecutar a mano `spec/jobs/contact_tracking_response_analyzer_job_spec.rb` (841 líneas) y los specs nuevos |
| Devolver la prosa al modelo reactiva el problema original (el LLM simulaba “CONSULTA GENERADA / DEBUG”) | Limpieza selectiva: se quitan las líneas `@ruta` y los tokens de directiva, no solo se pasa el texto crudo |

---

## 9. Criterios de aceptación

1. Un Entrenamiento **sin** `@ruta(` produce la misma respuesta que hoy — verificable contra los 14 seguimientos existentes.
2. En el agente #4906, una consulta técnica llega al **foro Kontrolya** y una consulta de precios llega a **Respuestas Predefinidas**.
3. Una consulta administrativa **no consulta ninguna fuente** y responde con la prosa del prompt.
4. El estilo declarado en el prompt (WhatsApp, mensajes breves, máximo dos preguntas) se observa en las respuestas conversacionales.
5. Un agente con **cinco** ramas declaradas funciona sin tocar código.
6. Las líneas `@ruta` nunca aparecen en un mensaje enviado al cliente.

---

## 10. Fuera de alcance

- `@evaluar_evidencia` y los estados de evidencia (EXACTA / PARCIAL / NO_CONFIRMADA / CONTRADICTORIA). Es un trabajo aparte y el de menor retorno de los identificados en el análisis.
- Ruteo de `@crear_ticket`, `@estado_ticket` y `@agendar_calendar` por rama: esas directivas se evalúan en otro punto del job y siguen siendo globales al agente.
- Encender el `RouterService` (`TRACKING_DETECT_INTENT`), que es una decisión independiente con su propio alcance.
