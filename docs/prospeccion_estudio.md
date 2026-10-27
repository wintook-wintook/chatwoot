# Estudio · Prospección: cómo se hace y qué tenemos

> Rama: `prospeccion` (desde `develop` 742a66a6) · 26/10/2026 · **Solo estudio, sin código**
> Pantalla revisada: `/app/accounts/2/tracking-dashboard/campaigns` (Campañas de seguimiento)

---

## 0. En una frase

Prospectar es **encontrar a quién venderle, abrir conversación, calificar si vale la pena y
pasárselo a un vendedor en el momento justo**, midiendo cada paso. Ya tenemos la parte de
*abrir conversación y darle seguimiento con IA*. Nos falta casi todo lo de **antes**
(a quién y con qué permiso) y lo de **después** (calificar, puntuar, entregar al vendedor y medir dinero).

---

## 1. La teoría: el proceso de prospección

### 1.1 El embudo estándar

Salesforce lo resume en cuatro pasos: los **leads** (prospectos sin calificar) se **califican** y
pasan a **prospectos**; los prospectos se convierten en **oportunidades** y las oportunidades en
**acuerdos**, que terminan como *cerradas ganadas* o *cerradas perdidas*.

<svg viewBox="0 0 880 400" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Embudo de prospección: mercado, leads, prospectos, oportunidades y acuerdos">
  <g font-family="system-ui, sans-serif">
    <polygon points="40,30 540,30 510,90 70,90" fill="#F1F5F9" stroke="#64748B" stroke-width="1.5"/>
    <text x="290" y="58" font-size="14" font-weight="700" fill="#0F172A" text-anchor="middle">Mercado total</text>
    <text x="290" y="76" font-size="11.5" fill="#334155" text-anchor="middle">todas las empresas o personas posibles</text>

    <polygon points="75,98 505,98 475,158 105,158" fill="#DBEAFE" stroke="#3B82F6" stroke-width="1.5"/>
    <text x="290" y="126" font-size="14" font-weight="700" fill="#1E3A8A" text-anchor="middle">Leads</text>
    <text x="290" y="144" font-size="11.5" fill="#1E40AF" text-anchor="middle">prospectos sin calificar</text>

    <polygon points="110,166 470,166 440,226 140,226" fill="#BFDBFE" stroke="#2563EB" stroke-width="1.5"/>
    <text x="290" y="194" font-size="14" font-weight="700" fill="#1E3A8A" text-anchor="middle">Prospectos</text>
    <text x="290" y="212" font-size="11.5" fill="#1E40AF" text-anchor="middle">calificados: sí encajan</text>

    <polygon points="145,234 435,234 405,294 175,294" fill="#FEF3C7" stroke="#D97706" stroke-width="1.5"/>
    <text x="290" y="262" font-size="14" font-weight="700" fill="#78350F" text-anchor="middle">Oportunidades</text>
    <text x="290" y="280" font-size="11.5" fill="#92400E" text-anchor="middle">hay intención de compra</text>

    <polygon points="180,302 400,302 370,362 210,362" fill="#DCFCE7" stroke="#16A34A" stroke-width="1.5"/>
    <text x="290" y="330" font-size="14" font-weight="700" fill="#14532D" text-anchor="middle">Acuerdos</text>
    <text x="290" y="348" font-size="11.5" fill="#166534" text-anchor="middle">ganada o perdida</text>

    <g stroke="#94A3B8" stroke-dasharray="3 3">
      <line x1="540" y1="60" x2="560" y2="60"/>
      <line x1="505" y1="128" x2="560" y2="128"/>
      <line x1="470" y1="196" x2="560" y2="196"/>
      <line x1="435" y1="264" x2="560" y2="264"/>
      <line x1="400" y1="332" x2="560" y2="332"/>
    </g>
    <g font-size="11.5" fill="#334155">
      <text x="568" y="56" font-weight="700">ICP: a quién sí buscar</text>
      <text x="568" y="72">giro, tamaño, zona, necesidad</text>
      <text x="568" y="124" font-weight="700">Fuente</text>
      <text x="568" y="140">marketing (formularios) o ventas (en frío)</text>
      <text x="568" y="192" font-weight="700">Calificar</text>
      <text x="568" y="208">¿persona, empresa y proyecto correctos?</text>
      <text x="568" y="260" font-weight="700">Conversar y nutrir</text>
      <text x="568" y="276">el interés crece con cada conversación</text>
      <text x="568" y="328" font-weight="700">Cerrar</text>
      <text x="568" y="344">se mide en dinero, no en mensajes</text>
    </g>
    <text x="20" y="390" font-size="11" fill="#64748B">Etapas según Salesforce LATAM. Referencia de terceros: de la lista cruda a oportunidad llega ~2–5 %.</text>
  </g>
</svg>

### 1.2 Las piezas, una por una

| Pieza | Qué es | Cómo se hace en la industria |
|---|---|---|
| **ICP** (perfil de cliente ideal) | A quién vale la pena buscar | Reglas repetibles: giro, tamaño, zona, tecnología. Un ICP claro convierte la calificación en reglas |
| **Fuente de prospectos** | De dónde salen | Bases propias (CRM, clientes viejos), formularios, eventos, bases compradas o enriquecidas (Apollo y similares) |
| **Permiso** (opt-in) | Si se le puede escribir | En WhatsApp es obligatorio (sección 3) |
| **Cadencia / secuencia** | Serie ordenada de toques | 6–12 toques en 2–4 semanas. Cada paso dice canal, mensaje, espera y si es automático o tarea manual |
| **Paro automático** | Dejar de insistir | Al responder o agendar, el contacto sale de la secuencia (HubSpot lo hace por omisión) |
| **Clasificar respuestas** | Qué significa lo que contestó | La IA etiqueta cada respuesta: interesado, pide precio, pide info, no le interesa, no es la persona, fuera de oficina, baja |
| **Calificación** | Si vale la pena para ventas | BANT (presupuesto, autoridad, necesidad, tiempo) para volumen; MEDDIC para ventas grandes. En frío no se pregunta presupuesto en el 1.er toque: se infiere |
| **Puntuación** (lead scoring) | Ordenar a quién atender primero | Encaje con el ICP (Excelente/Bueno/Regular/No encaja) + comportamiento (respondió, abrió, preguntó precio) |
| **Handoff** | Pasarlo a un vendedor | Etapa formal de «Lead aceptado por ventas», con dueño y plazo |
| **Métricas** | Saber si funciona | Respuesta, respuesta positiva, citas, oportunidades y valor. Enviados y abiertos son métricas de vanidad |

Referencia de volumen (un playbook de terceros): de la lista cruda a la oportunidad aceptada pasa
**~2–5 %**. Sirve para dimensionar: 1 000 prospectos ≈ 20–50 oportunidades.

### 1.3 Lead, prospecto, oportunidad (Salesforce)

| Término | Definición de Salesforce | En nuestro sistema |
|---|---|---|
| **Lead** | «Los leads son prospectos no calificados.» Vienen de marketing (un formulario de seminario web) o de ventas (contacto en frío) | Un contacto inscrito en la campaña |
| **Prospecto** | Un lead que ventas califica como adecuado para el producto | No hay marca: falta la categoría (P1) |
| **Oportunidad** | Un prospecto cuyo interés de compra crece con las conversaciones | Un caso / tarjeta del Embudo de contactos |
| **Acuerdo** | Cerrada ganada o cerrada perdida | El caso cerrado (sin valor medido) |

Para Salesforce, **calificar** es contestar tres preguntas:

<svg viewBox="0 0 880 300" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Calificar un prospecto: persona, empresa y proyecto correctos">
  <g font-family="system-ui, sans-serif">
    <rect x="20" y="20" width="273" height="180" rx="8" fill="#DBEAFE" stroke="#3B82F6" stroke-width="1.5"/>
    <text x="36" y="48" font-size="14" font-weight="700" fill="#1E3A8A">¿Es la persona correcta?</text>
    <g font-size="11.5" fill="#1E40AF">
      <text x="36" y="76">• Coincide con el perfil ideal</text>
      <text x="36" y="98">• Ya muestra interés</text>
      <text x="36" y="120">• Decide o influye en la compra</text>
    </g>
    <rect x="36" y="160" width="130" height="24" rx="12" fill="#FFFFFF" stroke="#3B82F6"/>
    <text x="101" y="176" font-size="11" fill="#1E3A8A" text-anchor="middle">BANT: Autoridad</text>

    <rect x="313" y="20" width="273" height="180" rx="8" fill="#DBEAFE" stroke="#3B82F6" stroke-width="1.5"/>
    <text x="329" y="48" font-size="14" font-weight="700" fill="#1E3A8A">¿Es la empresa correcta?</text>
    <g font-size="11.5" fill="#1E40AF">
      <text x="329" y="76">• Está en tu zona</text>
      <text x="329" y="98">• Su giro encaja</text>
      <text x="329" y="120">• Su tamaño o consumo alcanza</text>
    </g>
    <rect x="329" y="160" width="130" height="24" rx="12" fill="#FFFFFF" stroke="#3B82F6"/>
    <text x="394" y="176" font-size="11" fill="#1E3A8A" text-anchor="middle">Encaje con el ICP</text>

    <rect x="606" y="20" width="254" height="180" rx="8" fill="#DBEAFE" stroke="#3B82F6" stroke-width="1.5"/>
    <text x="622" y="48" font-size="14" font-weight="700" fill="#1E3A8A">¿Es el proyecto correcto?</text>
    <g font-size="11.5" fill="#1E40AF">
      <text x="622" y="76">• Hay presupuesto</text>
      <text x="622" y="98">• Es prioridad este año</text>
      <text x="622" y="120">• Lo usarían con impacto real</text>
    </g>
    <rect x="616" y="160" width="236" height="24" rx="12" fill="#FFFFFF" stroke="#3B82F6"/>
    <text x="734" y="176" font-size="11" fill="#1E3A8A" text-anchor="middle">BANT: Presupuesto, Necesidad, Tiempo</text>

    <g stroke="#16A34A" stroke-width="1.5" fill="none">
      <path d="M156 200 L156 222"/><path d="M449 200 L449 222"/><path d="M733 200 L733 222"/>
    </g>
    <rect x="20" y="222" width="840" height="64" rx="8" fill="#DCFCE7" stroke="#16A34A" stroke-width="1.5"/>
    <text x="440" y="248" font-size="13" font-weight="700" fill="#14532D" text-anchor="middle">Las tres en sí → PROSPECTO CALIFICADO → se entrega al vendedor</text>
    <text x="440" y="270" font-size="11.5" fill="#166534" text-anchor="middle">Con alguna en no: se sigue nutriendo o se cierra. Quien no decide igual puede llevarte a quien sí.</text>
  </g>
</svg>

En frío no se pregunta el presupuesto en el primer toque: se infiere de señales (giro, tamaño,
lo que pide). La pregunta directa llega cuando ya hay conversación.

### 1.4 La cadencia en el tiempo

Una cadencia define *cuándo* escribir o llamar, *qué* guion usar y *qué* material mandar
(así la describe Salesforce). En cuanto el prospecto responde, sale de la cadencia y su
respuesta se clasifica.

<svg viewBox="0 0 880 300" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Cadencia de prospección en el tiempo: estándar multicanal contra nuestro seguimiento actual">
  <g font-family="system-ui, sans-serif">
    <text x="20" y="86" font-size="13" font-weight="700" fill="#0F172A">Estándar</text>
    <text x="20" y="102" font-size="11.5" fill="#334155">multicanal</text>
    <line x1="150" y1="95" x2="850" y2="95" stroke="#CBD5E1" stroke-width="2"/>
    <circle cx="150" cy="95" r="9" fill="#3B82F6"/>
    <text x="150" y="72" font-size="11" fill="#1E3A8A" text-anchor="middle">WA plantilla</text>
    <circle cx="250" cy="95" r="9" fill="#3B82F6"/>
    <text x="250" y="72" font-size="11" fill="#1E3A8A" text-anchor="middle">Llamada</text>
    <circle cx="350" cy="95" r="9" fill="#3B82F6"/>
    <text x="350" y="72" font-size="11" fill="#1E3A8A" text-anchor="middle">WA / correo</text>
    <line x1="425" y1="40" x2="425" y2="140" stroke="#DC2626" stroke-width="2" stroke-dasharray="5 4"/>
    <text x="433" y="44" font-size="11.5" font-weight="700" fill="#B91C1C">Responde</text>
    <text x="433" y="60" font-size="11" fill="#B91C1C">sale de la cadencia y se clasifica</text>
    <circle cx="500" cy="95" r="9" fill="#FFFFFF" stroke="#94A3B8" stroke-width="2" stroke-dasharray="3 2"/>
    <text x="500" y="122" font-size="11" fill="#94A3B8" text-anchor="middle">Llamada</text>
    <circle cx="650" cy="95" r="9" fill="#FFFFFF" stroke="#94A3B8" stroke-width="2" stroke-dasharray="3 2"/>
    <text x="650" y="122" font-size="11" fill="#94A3B8" text-anchor="middle">WA con valor</text>
    <circle cx="850" cy="95" r="9" fill="#FFFFFF" stroke="#94A3B8" stroke-width="2" stroke-dasharray="3 2"/>
    <text x="850" y="122" font-size="11" fill="#94A3B8" text-anchor="end">Cierre «¿lo dejo aquí?»</text>

    <text x="20" y="196" font-size="13" font-weight="700" fill="#0F172A">Hoy en</text>
    <text x="20" y="212" font-size="11.5" fill="#334155">Campañas</text>
    <line x1="150" y1="205" x2="450" y2="205" stroke="#CBD5E1" stroke-width="2"/>
    <circle cx="150" cy="205" r="9" fill="#16A34A"/>
    <text x="150" y="182" font-size="11" fill="#14532D" text-anchor="middle">Intento 1 (IA)</text>
    <circle cx="300" cy="205" r="9" fill="#16A34A"/>
    <text x="300" y="182" font-size="11" fill="#14532D" text-anchor="middle">Intento 2 (IA)</text>
    <circle cx="450" cy="205" r="9" fill="#16A34A"/>
    <text x="450" y="182" font-size="11" fill="#14532D" text-anchor="middle">Intento 3 (IA)</text>
    <text x="520" y="196" font-size="11.5" fill="#334155">Solo WhatsApp · intentos e intervalo del seguimiento</text>
    <text x="520" y="214" font-size="11.5" fill="#334155">Al responder, el Entrenamiento toma la conversación</text>

    <line x1="150" y1="250" x2="850" y2="250" stroke="#64748B"/>
    <g font-size="10" fill="#64748B" text-anchor="middle">
      <text x="150" y="266">D1</text><text x="250" y="266">D3</text><text x="350" y="266">D5</text>
      <text x="500" y="266">D8</text><text x="650" y="266">D11</text><text x="850" y="266">D15</text>
    </g>
    <text x="20" y="290" font-size="11" fill="#64748B">Días hábiles. Referencia: 6–12 toques en 2–4 semanas. Los círculos vacíos ya no se mandan porque el prospecto respondió.</text>
  </g>
</svg>

### 1.5 Qué hacer con cada respuesta

Así trabajan Smartlead e Instantly: la IA lee la respuesta, le pone una categoría y cada
categoría dispara una acción.

<svg viewBox="0 0 880 350" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Clasificación de respuestas del prospecto y la acción de cada categoría">
  <g font-family="system-ui, sans-serif">
    <rect x="20" y="146" width="180" height="60" rx="8" fill="#F1F5F9" stroke="#64748B" stroke-width="1.5"/>
    <text x="110" y="172" font-size="13" font-weight="700" fill="#0F172A" text-anchor="middle">Respuesta del</text>
    <text x="110" y="190" font-size="13" font-weight="700" fill="#0F172A" text-anchor="middle">prospecto</text>
    <line x1="200" y1="176" x2="226" y2="176" stroke="#64748B" stroke-width="1.5"/>
    <rect x="230" y="146" width="140" height="60" rx="8" fill="#EDE9FE" stroke="#7C3AED" stroke-width="1.5"/>
    <text x="300" y="172" font-size="13" font-weight="700" fill="#4C1D95" text-anchor="middle">La IA</text>
    <text x="300" y="190" font-size="13" font-weight="700" fill="#4C1D95" text-anchor="middle">clasifica</text>

    <g stroke="#A78BFA" stroke-width="1.2" fill="none">
      <path d="M370 176 L410 38"/><path d="M370 176 L410 84"/><path d="M370 176 L410 130"/>
      <path d="M370 176 L410 176"/><path d="M370 176 L410 222"/><path d="M370 176 L410 268"/>
      <path d="M370 176 L410 314"/>
    </g>
    <g stroke="#94A3B8" stroke-width="1.2">
      <line x1="610" y1="38" x2="640" y2="38"/><line x1="610" y1="84" x2="640" y2="84"/>
      <line x1="610" y1="130" x2="640" y2="130"/><line x1="610" y1="176" x2="640" y2="176"/>
      <line x1="610" y1="222" x2="640" y2="222"/><line x1="610" y1="268" x2="640" y2="268"/>
      <line x1="610" y1="314" x2="640" y2="314"/>
    </g>

    <g font-size="12" font-weight="700">
      <rect x="410" y="20" width="200" height="36" rx="6" fill="#DCFCE7" stroke="#16A34A"/>
      <text x="422" y="43" fill="#14532D">Interesado / pide cita</text>
      <rect x="410" y="66" width="200" height="36" rx="6" fill="#DCFCE7" stroke="#16A34A"/>
      <text x="422" y="89" fill="#14532D">Pide precio o información</text>
      <rect x="410" y="112" width="200" height="36" rx="6" fill="#FEF3C7" stroke="#D97706"/>
      <text x="422" y="135" fill="#78350F">No ahora</text>
      <rect x="410" y="158" width="200" height="36" rx="6" fill="#FEF3C7" stroke="#D97706"/>
      <text x="422" y="181" fill="#78350F">No es la persona</text>
      <rect x="410" y="204" width="200" height="36" rx="6" fill="#F1F5F9" stroke="#64748B"/>
      <text x="422" y="227" fill="#0F172A">No le interesa</text>
      <rect x="410" y="250" width="200" height="36" rx="6" fill="#FEE2E2" stroke="#DC2626"/>
      <text x="422" y="273" fill="#7F1D1D">Baja / «no me escriban»</text>
      <rect x="410" y="296" width="200" height="36" rx="6" fill="#F1F5F9" stroke="#64748B"/>
      <text x="422" y="319" fill="#0F172A">Sin respuesta</text>
    </g>
    <g font-size="11.5">
      <rect x="640" y="20" width="220" height="36" rx="6" fill="#FFFFFF" stroke="#16A34A"/>
      <text x="652" y="43" fill="#14532D">Pasa al vendedor + cita</text>
      <rect x="640" y="66" width="220" height="36" rx="6" fill="#FFFFFF" stroke="#16A34A"/>
      <text x="652" y="89" fill="#14532D">El Agente IA responde y sigue</text>
      <rect x="640" y="112" width="220" height="36" rx="6" fill="#FFFFFF" stroke="#D97706"/>
      <text x="652" y="135" fill="#78350F">Volver a escribir en N días</text>
      <rect x="640" y="158" width="220" height="36" rx="6" fill="#FFFFFF" stroke="#D97706"/>
      <text x="652" y="181" fill="#78350F">Pedir a quién dirigirse</text>
      <rect x="640" y="204" width="220" height="36" rx="6" fill="#FFFFFF" stroke="#64748B"/>
      <text x="652" y="227" fill="#0F172A">Cerrar como perdido</text>
      <rect x="640" y="250" width="220" height="36" rx="6" fill="#FFFFFF" stroke="#DC2626"/>
      <text x="652" y="273" fill="#7F1D1D">Lista de no contactar, siempre</text>
      <rect x="640" y="296" width="220" height="36" rx="6" fill="#FFFFFF" stroke="#64748B"/>
      <text x="652" y="319" fill="#0F172A">Siguiente toque de la cadencia</text>
    </g>
  </g>
</svg>

Hoy el Entrenamiento ya contesta bien los dos primeros casos (verde), pero **no guarda la
categoría**, y los otros cinco no tienen acción propia.

### 1.6 Consejos y errores comunes (Salesforce)

| Errores | Consejos |
|---|---|
| Confundir «calificar» con «decidir si alguien es importante»: quien no decide puede llevarte a quien sí | **Insiste en el próximo paso**: cada conversación termina con una pregunta concreta |
| Repetir lo que ya dice el sitio web de la empresa | **Avanza, pero califica** en cada etapa |
| Gastar demasiado esfuerzo en un acuerdo que no lo compensa | Apóyate en expertos internos (técnicos, marketing): no tienes que saberlo todo |
| Depender del volumen en vez de la personalización | Aprende la industria del prospecto y habla de sus problemas, no en general |

Canales que menciona: llamadas, correo directo, eventos y LinkedIn (seguir al prospecto,
comentar sus publicaciones, InMail). Su consejo es «probar todas las alternativas posibles».
El artículo es de antes de la IA: no menciona agentes IA ni WhatsApp, que es justo lo que
nosotros agregamos.

---

## 2. Cómo lo hacen otras plataformas

| Plataforma | Enfoque | Lo que vale copiar |
|---|---|---|
| **HubSpot Sequences** | Secuencias de correo + tareas | Pasos: correo automático, correo manual, llamada, tarea, LinkedIn. Espera **en días hábiles** (hasta 90). Sale sola al responder o agendar, y opcionalmente **sale toda la empresa**. Puede pausar hasta completar una tarea. Se inscribe a mano o por workflow |
| **Outreach / Salesloft** | Cadencias multicanal para equipos de ventas | Pasos de correo, llamada y LinkedIn como **tareas del vendedor** («qué hacer y cuándo»). Ramas: respuesta positiva → pasa a ventas; fuera de oficina → pausa. Pruebas A/B. Inscripción por evento o señal de intención |
| **Apollo** | Base de datos + IA que prospecta | Busca prospectos que cumplen el ICP y los **puntúa** (Excelente/Bueno/Regular/No encaja). Arma la secuencia con IA y propone **aprobación manual** antes de inscribir. Recomienda medir calidad del pipeline, no actividad |
| **Smartlead / Instantly** | Correo en frío a escala | **Clasifican cada respuesta con IA**: interesado, no le interesa, objeción, fuera de oficina, baja, no es la persona, pide reunión, pide precio. Cada categoría dispara una acción (mandar liga de agenda, actualizar el CRM) |
| **respond.io** (WhatsApp) | Difusión + agentes IA en chat | **Etapas del ciclo de vida** (lead nuevo → calificado → cliente) que mueven los workflows. El agente IA califica tras la respuesta a la campaña, da seguimiento si el cliente deja de contestar y **enruta a un humano** por turno, habilidad, zona o carga |

Patrón común a todas:

```
 SEGMENTO ──▶ SECUENCIA (pasos + esperas + canal) ──▶ RESPUESTA
                    ▲                                   │
                    │ sigue si no contesta              ▼
                    └──────────────  CLASIFICAR (IA) ──┬─ interesado ─▶ HANDOFF a vendedor (tarea + plazo)
                                                       ├─ no ahora   ─▶ re-agendar en N días
                                                       ├─ no es él   ─▶ pedir referido
                                                       └─ baja       ─▶ LISTA DE NO CONTACTAR
```

---

## 3. Reglas que no se pueden saltar

### 3.1 WhatsApp (política de Meta)

Textual de la política de WhatsApp Business:

- Solo se puede escribir a alguien si **te dio su número** y **dio permiso (opt-in)** para recibir mensajes. *«You may only contact people on WhatsApp if: (a) they have given you their mobile phone number…»*. El método del permiso lo eliges tú, pero debe cumplir la ley.
- Hay que **respetar toda petición de baja**, dentro o fuera de WhatsApp. *«You must respect all requests (either on or off WhatsApp) by a person to block, discontinue, or otherwise opt out…»*
- Fuera de la ventana de 24 h solo se escribe con **plantillas aprobadas**.
- No se puede sorprender, engañar ni mandar spam.

Consecuencias técnicas:

- **Calificación de calidad** del número (verde/amarillo/rojo), según bloqueos y reportes de los últimos 7 días. Escribir sin permiso o a listas compradas la baja.
- **Límites de mensajes** por 24 h que suben con buena calidad. El tope inicial varía por cuenta (las fuentes no coinciden): se consulta en WhatsApp Manager.
- Las plantillas de marketing nuevas pueden salir **dosificadas** (pacing).

**Conclusión:** en WhatsApp la prospección es **en frío solo de nombre**. Se le escribe a quien
ya dio su número y permiso: clientes viejos, cotizaciones sin cerrar, formularios, eventos.
Una base comprada daña el número de toda la cuenta.

### 3.2 México

- **LFPDPPP** (nueva, DOF 20/03/2025, autoridad: Secretaría Anticorrupción y Buen Gobierno tras desaparecer el INAI). Consentimiento libre, específico e informado; aviso de privacidad. *Pendiente: revisar con el texto vigente los artículos de finalidades secundarias (mercadotecnia) y el derecho de oposición.*
- **REPEP (Profeco)**: registro de números que no quieren publicidad (telecom, comercio, turismo). Rige llamadas y, según varias fuentes, SMS. No hay fuente oficial que confirme WhatsApp. Lo prudente es tratarlo como lista de exclusión.
- **Oct 2026:** el Senado aprobó multas y un registro nuevo contra el acoso comercial. Falta la Cámara de Diputados. **Vigilar.**

> Esto no es asesoría legal: hay que validarlo con un abogado antes de vender el módulo como «prospección».

---

## 4. Lo que ya tenemos

```
 Contactos (segmento / etiqueta)           Automatizaciones
          │  POR LOTE                              │  CONTINUA («Agregar a campaña»)
          ▼                                        ▼
   ┌──────────────────────── TrackingCampaign ────────────────────────┐
   │ ventana inicio/fin · tope diario · espera entre entradas         │
   │ respetar horario · bandeja fija · Agente IA (Entrenamiento)      │
   │ estados: guardada → programada → en curso ⇄ pausada → terminada  │
   └───────┬──────────────────────────────────────────────────────────┘
           │ TrackingCampaignEntry (inscrito / omitido + motivo)
           ▼
   ContactTracking (1 por contacto+bandeja) ── ContactTrackingJob: el Agente IA escribe
           │   intentos (max_attempts), intervalo, plantillas de WhatsApp
           ▼
   TrackingDelivery: enviado · entregado · leído · fallido (código de Meta) → pausa si es de configuración
           │
           ▼   el cliente responde → el Entrenamiento (rutas) contesta, agenda, crea caso
   interesado (interested_at) · cita (booked_at, calendario) · objetivo cumplido
```

| Capacidad | Dónde vive | Estado |
|---|---|---|
| Campaña con nombre, Agente IA y bandeja fija | `TrackingCampaign` | ✅ |
| Audiencia **por lote** (segmento o etiqueta) y **continua** (automatizaciones) | `Enroll`, acción `add_to_tracking_campaign` | ✅ |
| Ventana, tope diario, espera entre entradas, horario laboral | columnas de la campaña + `WindowJob` | ✅ |
| Registro de cada inscripción, con motivo si se omitió (`already_enrolled`, `daily_cap`, `active_tracking`, `not_contactable`, `campaign_closed`) | `TrackingCampaignEntry`, pestaña «Inscritos» | ✅ |
| Varios toques con IA (intentos, intervalo, plantillas WA) | `ContactTracking` + `ContactTrackingJob` | ✅ un solo canal |
| Entrega real (enviado / entregado / leído / fallido + motivo) | `TrackingDelivery`, `DeliveryStats` | ✅ |
| Pausa automática por error de configuración; pausar / reanudar | `HandleFailure`, `Pause`, `Resume` | ✅ |
| La IA conversa, responde dudas, agenda en calendario y crea casos | Entrenamiento (rutas, `@agendar_calendar`, `@crear_ticket`…) | ✅ |
| Marcas de interés y cita | `interested_at`, `booked_at`, `appointment_*` | ✅ |
| Embudo de contactos con IA que mueve tarjetas y convierte en oportunidad | `Kanban::FunnelAi`, `FunnelConverter` | ✅ **pero aparte**: no está ligado a la campaña |
| **Uso en producción** | — | ⛔ en espera del análisis de capacidad (`diag/envios_masivos`) |

---

## 5. Comparación: estándar vs. nuestro sistema

<svg viewBox="0 0 880 290" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Lo que tenemos y lo que falta, antes, durante y después de la conversación">
  <g font-family="system-ui, sans-serif">
    <rect x="20" y="16" width="273" height="34" rx="6" fill="#0F172A"/>
    <text x="156" y="38" font-size="12.5" font-weight="700" fill="#FFFFFF" text-anchor="middle">ANTES · a quién y con permiso</text>
    <rect x="303" y="16" width="273" height="34" rx="6" fill="#0F172A"/>
    <text x="439" y="38" font-size="12.5" font-weight="700" fill="#FFFFFF" text-anchor="middle">DURANTE · conversar</text>
    <rect x="586" y="16" width="274" height="34" rx="6" fill="#0F172A"/>
    <text x="723" y="38" font-size="12.5" font-weight="700" fill="#FFFFFF" text-anchor="middle">DESPUÉS · calificar y cerrar</text>

    <g font-size="13" font-weight="700">
      <rect x="20" y="62" width="273" height="56" rx="8" fill="#FEF3C7" stroke="#D97706" stroke-width="1.5"/>
      <text x="32" y="84" fill="#78350F">Perfil de cliente ideal</text>
      <rect x="20" y="126" width="273" height="56" rx="8" fill="#FEE2E2" stroke="#DC2626" stroke-width="1.5"/>
      <text x="32" y="148" fill="#7F1D1D">Permiso (opt-in)</text>
      <rect x="20" y="190" width="273" height="56" rx="8" fill="#FEE2E2" stroke="#DC2626" stroke-width="1.5"/>
      <text x="32" y="212" fill="#7F1D1D">Lista de no contactar</text>

      <rect x="303" y="62" width="273" height="56" rx="8" fill="#DCFCE7" stroke="#16A34A" stroke-width="1.5"/>
      <text x="315" y="84" fill="#14532D">Campaña y audiencia</text>
      <rect x="303" y="126" width="273" height="56" rx="8" fill="#DCFCE7" stroke="#16A34A" stroke-width="1.5"/>
      <text x="315" y="148" fill="#14532D">Toques con Agente IA</text>
      <rect x="303" y="190" width="273" height="56" rx="8" fill="#DCFCE7" stroke="#16A34A" stroke-width="1.5"/>
      <text x="315" y="212" fill="#14532D">Entrega real</text>

      <rect x="586" y="62" width="274" height="56" rx="8" fill="#FEF3C7" stroke="#D97706" stroke-width="1.5"/>
      <text x="598" y="84" fill="#78350F">Clasificar respuesta</text>
      <rect x="586" y="126" width="274" height="56" rx="8" fill="#FEF3C7" stroke="#D97706" stroke-width="1.5"/>
      <text x="598" y="148" fill="#78350F">Entregar al vendedor</text>
      <rect x="586" y="190" width="274" height="56" rx="8" fill="#FEE2E2" stroke="#DC2626" stroke-width="1.5"/>
      <text x="598" y="212" fill="#7F1D1D">Valor / pipeline</text>
    </g>
    <g font-size="11.5">
      <text x="32" y="104" fill="#92400E">Segmentos y etiquetas; sin encaje medido</text>
      <text x="32" y="168" fill="#991B1B">No se registra quién dio permiso</text>
      <text x="32" y="232" fill="#991B1B">«No me escriban» no se guarda</text>
      <text x="315" y="104" fill="#166534">Lote o continua · ventana · tope diario</text>
      <text x="315" y="168" fill="#166534">Intentos e intervalo · solo WhatsApp</text>
      <text x="315" y="232" fill="#166534">Enviado, entregado, leído, fallido</text>
      <text x="598" y="104" fill="#92400E">La IA contesta; no queda categoría</text>
      <text x="598" y="168" fill="#92400E">El embudo existe, pero no está ligado</text>
      <text x="598" y="232" fill="#991B1B">No se mide</text>
    </g>

    <g font-size="11.5" fill="#334155">
      <rect x="20" y="264" width="14" height="14" rx="3" fill="#DCFCE7" stroke="#16A34A"/>
      <text x="40" y="276">Lo tenemos</text>
      <rect x="130" y="264" width="14" height="14" rx="3" fill="#FEF3C7" stroke="#D97706"/>
      <text x="150" y="276">A medias</text>
      <rect x="230" y="264" width="14" height="14" rx="3" fill="#FEE2E2" stroke="#DC2626"/>
      <text x="250" y="276">Falta</text>
    </g>
  </g>
</svg>

Leyenda: ✅ lo tenemos · ◐ a medias · ❌ no existe

| # | Pieza del estándar | Nosotros | Detalle |
|---|---|---|---|
| 1 | ICP / reglas de a quién buscar | ◐ | Segmentos y etiquetas filtran, pero no hay «perfil» ni encaje medido |
| 2 | Fuente / importación de prospectos | ◐ | Importar contactos nativo (CSV). Sin enriquecimiento ni base externa |
| 3 | **Permiso (opt-in) registrado** | ❌ | No se guarda si el contacto dio permiso, ni cuándo ni cómo |
| 4 | **Lista de no contactar / baja** | ❌ | No encontré manejo de «no me escriban». `Enroll` no lo revisa |
| 5 | Secuencia de varios toques | ✅ | Intentos + intervalo + plantillas, con el Agente IA |
| 6 | Multicanal (WA + llamada + correo + tarea) | ❌ | 1 seguimiento por contacto y bandeja; sin pasos de llamada ni tarea al vendedor |
| 7 | Días hábiles / horario | ✅ | `respect_working_hours` + horario de la bandeja |
| 8 | Paro al responder / al agendar | ✅ | El Entrenamiento toma la conversación; la cita se marca |
| 9 | **Clasificación de respuestas** | ◐ | Las rutas del Entrenamiento deciden qué contestar, pero no queda una **categoría** medible por prospecto (interesado / no ahora / no es él / baja). El router de intención está apagado (`TRACKING_DETECT_INTENT=false`) |
| 10 | Re-agendar «no ahora» | ❌ | No hay «vuelve a escribirle en N días» |
| 11 | **Puntuación** (lead scoring) | ❌ | Planeado en `campanas_agente_vendedor_plan.md` (`TrackingCampaignProspect`), no hecho |
| 12 | **Handoff a vendedor** con dueño y plazo | ◐ | Hay casos y embudo, pero no una «cola del vendedor» ni un plazo (SLA) |
| 13 | Embudo ligado a la campaña | ◐ | El Embudo de contactos existe, pero la campaña no alimenta sus columnas |
| 14 | Valor generado / pipeline | ❌ | Planeado, no hecho |
| 15 | Pruebas A/B de mensajes | ❌ | Una plantilla/Entrenamiento por campaña |
| 16 | Aprobación antes de inscribir | ◐ | «Guardada → Poner en curso» aprueba la campaña completa, no prospecto por prospecto |
| 17 | Salud del número (calidad, límites de Meta) | ◐ | Se guardan errores de entrega; no se muestra la calidad ni el tope del número |
| 18 | Métricas de resultado (respuesta positiva, citas, oportunidades) | ◐ | Hay entrega, interés y cita; faltan tasa positiva, oportunidades y valor |

---

## 6. Brechas priorizadas (propuesta)

<svg viewBox="0 0 880 190" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Ruta propuesta de P0 a P4: cumplir, clasificar, entregar, medir y escalar">
  <g font-family="system-ui, sans-serif">
    <polygon points="10,30 160,30 178,75 160,120 10,120" fill="#FEE2E2" stroke="#DC2626" stroke-width="1.5"/>
    <text x="22" y="58" font-size="13" font-weight="700" fill="#7F1D1D">P0 · Cumplir</text>
    <text x="22" y="80" font-size="11" fill="#991B1B">Permiso y</text>
    <text x="22" y="96" font-size="11" fill="#991B1B">lista de baja</text>

    <polygon points="182,30 332,30 350,75 332,120 182,120 200,75" fill="#FEF3C7" stroke="#D97706" stroke-width="1.5"/>
    <text x="206" y="58" font-size="13" font-weight="700" fill="#78350F">P1 · Clasificar</text>
    <text x="206" y="80" font-size="11" fill="#92400E">Categoría por</text>
    <text x="206" y="96" font-size="11" fill="#92400E">respuesta, «no ahora»</text>

    <polygon points="354,30 504,30 522,75 504,120 354,120 372,75" fill="#DBEAFE" stroke="#3B82F6" stroke-width="1.5"/>
    <text x="378" y="58" font-size="13" font-weight="700" fill="#1E3A8A">P2 · Entregar</text>
    <text x="378" y="80" font-size="11" fill="#1E40AF">Embudo ligado y</text>
    <text x="378" y="96" font-size="11" fill="#1E40AF">cola del vendedor</text>

    <polygon points="526,30 676,30 694,75 676,120 526,120 544,75" fill="#DCFCE7" stroke="#16A34A" stroke-width="1.5"/>
    <text x="550" y="58" font-size="13" font-weight="700" fill="#14532D">P3 · Medir</text>
    <text x="550" y="80" font-size="11" fill="#166534">Tasas por etapa</text>
    <text x="550" y="96" font-size="11" fill="#166534">y valor</text>

    <polygon points="698,30 848,30 866,75 848,120 698,120 716,75" fill="#F1F5F9" stroke="#64748B" stroke-width="1.5"/>
    <text x="722" y="58" font-size="13" font-weight="700" fill="#0F172A">P4 · Escalar</text>
    <text x="722" y="80" font-size="11" fill="#334155">A/B, multicanal,</text>
    <text x="722" y="96" font-size="11" fill="#334155">puntuación</text>

    <g font-size="11" fill="#475569">
      <text x="22" y="148">Protege el número y</text><text x="22" y="164">evita riesgo legal</text>
      <text x="206" y="148">Separa «mandar mensajes»</text><text x="206" y="164">de prospectar</text>
      <text x="378" y="148">Ahí se pierde hoy</text><text x="378" y="164">el prospecto</text>
      <text x="550" y="148">Responde «¿dónde</text><text x="550" y="164">está el dinero?»</text>
      <text x="722" y="148">Mejora, pero no</text><text x="722" y="164">habilita</text>
    </g>
  </g>
</svg>

| Prioridad | Qué | Por qué primero |
|---|---|---|
| **P0 · Cumplir** | Guardar el permiso del contacto (fuente, fecha) · **Lista de no contactar**: «baja» / «no me escriban» la detecta la IA y marca el contacto · `Enroll` omite con motivo `opted_out` · texto de baja en la plantilla | Sin esto se arriesga el número de WhatsApp de la cuenta (calidad → límites) y hay riesgo legal |
| **P1 · Clasificar** | Categoría fija por prospecto: interesado · pide precio/info · no ahora · no es la persona · no le interesa · baja · sin respuesta · «No ahora» re-agenda en N días | Es lo que separa «mandar mensajes» de «prospectar». Reusa la llamada de IA del Entrenamiento |
| **P2 · Entregar** | Interesado → tarjeta en el **Embudo de contactos** (ya existe) + asignar vendedor + plazo · «A quién llamar primero» (la cola del plan Agente Vendedor) | Es el paso donde hoy se pierde el prospecto |
| **P3 · Medir** | Tasas por etapa (respuesta, respuesta positiva, cita, oportunidad) y valor (de la cotización o del caso) | Responde «¿dónde está el dinero?» |
| **P4 · Escalar** | A/B de plantillas, pasos de llamada o tarea, puntuación por ICP, aprobación por prospecto, salud del número | Mejora, no habilita |

Esto **se cruza** con dos planes existentes. Hay que decidir si los absorbe o los continúa:
- `docs/campanas_agente_vendedor_plan.md` (vault `vault-campanas-vendedor`): scoring, valor, las 7 vistas. Solo plan.
- `docs/automatizacion_campanas_plan.md`: ya hecho (PR #60).
- Además, la **capacidad en producción** (`diag/envios_masivos`) sigue pendiente; sin ella las campañas no salen a prod.

---

## 7. Mejoras rápidas con lo que ya tenemos

Antes de construir la prospección completa (P0–P4), hay mejoras que **reusan piezas que ya
funcionan** y que el usuario nota de inmediato. El esfuerzo es una estimación a partir del
código revisado, no una medición.

<svg viewBox="0 0 880 370" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Matriz de impacto contra esfuerzo de las mejoras rápidas">
  <g font-family="system-ui, sans-serif">
    <rect x="80" y="30" width="240" height="150" fill="#DCFCE7" opacity="0.55"/>
    <rect x="320" y="30" width="240" height="150" fill="#DBEAFE" opacity="0.55"/>
    <rect x="80" y="180" width="240" height="150" fill="#F8FAFC"/>
    <rect x="320" y="180" width="240" height="150" fill="#F1F5F9"/>
    <rect x="80" y="30" width="480" height="300" fill="none" stroke="#94A3B8"/>
    <line x1="320" y1="30" x2="320" y2="330" stroke="#94A3B8" stroke-dasharray="4 4"/>
    <line x1="80" y1="180" x2="560" y2="180" stroke="#94A3B8" stroke-dasharray="4 4"/>
    <text x="312" y="48" font-size="11.5" font-weight="700" fill="#166534" text-anchor="end">HACER YA</text>
    <text x="552" y="48" font-size="11.5" font-weight="700" fill="#1E40AF" text-anchor="end">VALE LA PENA</text>
    <text x="88" y="322" font-size="11" fill="#64748B">si sobra tiempo</text>
    <text x="552" y="322" font-size="11" fill="#64748B" text-anchor="end">pensarlo</text>
    <text x="320" y="356" font-size="12" font-weight="700" fill="#334155" text-anchor="middle">Esfuerzo →</text>
    <text x="50" y="180" font-size="12" font-weight="700" fill="#334155" text-anchor="middle" transform="rotate(-90 50 180)">Impacto →</text>

    <g font-size="12" font-weight="700" fill="#FFFFFF" text-anchor="middle">
      <circle cx="140" cy="80" r="16" fill="#16A34A"/><text x="140" y="84">1</text>
      <circle cx="200" cy="112" r="16" fill="#16A34A"/><text x="200" y="116">2</text>
      <circle cx="150" cy="150" r="16" fill="#16A34A"/><text x="150" y="154">4</text>
      <circle cx="285" cy="88" r="16" fill="#2563EB"/><text x="285" y="92">3</text>
      <circle cx="400" cy="76" r="16" fill="#2563EB"/><text x="400" y="80">5</text>
      <circle cx="430" cy="215" r="16" fill="#64748B"/><text x="430" y="219">6</text>
      <circle cx="370" cy="255" r="16" fill="#64748B"/><text x="370" y="259">7</text>
      <circle cx="105" cy="125" r="16" fill="#D97706"/><text x="105" y="129">C</text>
    </g>

    <g font-size="11.5">
      <text x="590" y="44" font-weight="700" fill="#166534">Paquete 1 · hacer ya</text>
      <text x="590" y="64" fill="#334155">1  Respetar «no me escriban»</text>
      <text x="590" y="82" fill="#334155">2  A quién llamar primero</text>
      <text x="590" y="100" fill="#334155">4  Porcentajes que importan</text>
      <text x="590" y="132" font-weight="700" fill="#1E40AF">Paquete 2</text>
      <text x="590" y="152" fill="#334155">3  Interesado → Embudo de contactos</text>
      <text x="590" y="170" fill="#334155">5  Categoría de cada respuesta</text>
      <text x="590" y="202" font-weight="700" fill="#475569">Después</text>
      <text x="590" y="222" fill="#334155">6  «No ahora» → volver a escribir</text>
      <text x="590" y="240" fill="#334155">7  Aviso de permiso en la audiencia</text>
      <text x="590" y="272" font-weight="700" fill="#B45309">Sin desarrollo</text>
      <text x="590" y="292" fill="#334155">C  Configuración y buenas prácticas</text>
    </g>
  </g>
</svg>

### 7.1 Fáciles y de alto impacto (Paquete 1, más el 3)

| # | Mejora | Qué ve el usuario | Por qué es fácil |
|---|---|---|---|
| 1 | **Respetar «no me escriban»** | Si el prospecto pide la baja, queda marcado y ninguna campaña lo vuelve a inscribir. En «Inscritos» aparece «Pidió no ser contactado» | La inscripción (`Enroll`) ya omite contactos por motivos (`daily_cap`, `not_contactable`…): es un motivo más. La IA ya lee cada respuesta |
| 2 | **«A quién llamar primero»** | En el detalle de la campaña, una vista «Interesados sin atender», ordenada por los que mostraron interés o agendaron | `interested_at` y `booked_at` ya se guardan: falta ordenar y filtrar en pantalla |
| 3 | **Interesado → Embudo de contactos** | Al mostrar interés, el prospecto aparece solo como tarjeta en el embudo y se asigna a un vendedor | El embudo y su IA (`Kanban::FunnelAi`) ya existen: falta conectarlo con la campaña |
| 4 | **Porcentajes que importan** | En los KPIs de la campaña: % que respondió, % interesados, % con cita, además de enviado y entregado | Los datos ya están: es calcular y mostrar |

### 7.2 Medianas, que valen la pena

| # | Mejora | Qué ve el usuario |
|---|---|---|
| 5 | **Categoría de cada respuesta** | Una columna «Respuesta» en la lista de prospectos (interesado, pide precio, no ahora, no es la persona, no le interesa, baja) y un filtro por ella. Se aprovecha la misma llamada de IA que ya contesta |
| 6 | **«No ahora» → volver a escribir** | Si dice «en un mes», se programa solo otro seguimiento en esa fecha |
| 7 | **Aviso de permiso al armar la campaña** | Al elegir la audiencia: «De 300 contactos, 120 no tienen permiso registrado» |

### 7.3 Sin desarrollo (C)

- **Texto de baja en la plantilla de WhatsApp:** «Si no quieres recibir más mensajes, responde BAJA». Lo pide la política de Meta y reduce bloqueos.
- **Audiencias con permiso:** segmentos de clientes, cotizaciones abiertas o formularios; nunca bases compradas.
- **Tope diario bajo al empezar:** el campo ya existe y protege la calificación del número.
- **En el Entrenamiento:** una ruta que reconozca «no me interesa» o «baja» y se despida sin insistir.

### 7.4 Cómo se ve el recorrido del prospecto con las mejoras

<svg viewBox="0 0 880 300" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Recorrido del prospecto en una campaña con cada mejora marcada en su paso">
  <g font-family="system-ui, sans-serif">
    <rect x="20" y="85" width="150" height="60" rx="8" fill="#F1F5F9" stroke="#64748B" stroke-width="1.5"/>
    <text x="32" y="110" font-size="12.5" font-weight="700" fill="#0F172A">Audiencia</text>
    <text x="32" y="130" font-size="11" fill="#334155">segmento o etiqueta</text>
    <line x1="170" y1="115" x2="196" y2="115" stroke="#64748B" stroke-width="1.5"/>

    <rect x="200" y="85" width="170" height="60" rx="8" fill="#F1F5F9" stroke="#64748B" stroke-width="1.5"/>
    <text x="212" y="110" font-size="12.5" font-weight="700" fill="#0F172A">El Agente IA escribe</text>
    <text x="212" y="130" font-size="11" fill="#334155">plantilla con texto de baja</text>
    <line x1="370" y1="115" x2="396" y2="115" stroke="#64748B" stroke-width="1.5"/>

    <rect x="400" y="85" width="150" height="60" rx="8" fill="#EDE9FE" stroke="#7C3AED" stroke-width="1.5"/>
    <text x="412" y="110" font-size="12.5" font-weight="700" fill="#4C1D95">Responde</text>
    <text x="412" y="130" font-size="11" fill="#5B21B6">la IA la clasifica</text>

    <g stroke="#A78BFA" stroke-width="1.5" fill="none">
      <path d="M550 115 L600 45"/><path d="M550 115 L600 120"/><path d="M550 115 L600 195"/>
    </g>

    <rect x="600" y="20" width="260" height="50" rx="8" fill="#DCFCE7" stroke="#16A34A" stroke-width="1.5"/>
    <text x="612" y="41" font-size="12" font-weight="700" fill="#14532D">Interesado</text>
    <text x="612" y="59" font-size="11" fill="#166534">Embudo + cola del vendedor</text>
    <rect x="600" y="95" width="260" height="50" rx="8" fill="#FEF3C7" stroke="#D97706" stroke-width="1.5"/>
    <text x="612" y="116" font-size="12" font-weight="700" fill="#78350F">No ahora</text>
    <text x="612" y="134" font-size="11" fill="#92400E">se vuelve a escribir en N días</text>
    <rect x="600" y="170" width="260" height="50" rx="8" fill="#FEE2E2" stroke="#DC2626" stroke-width="1.5"/>
    <text x="612" y="191" font-size="12" font-weight="700" fill="#7F1D1D">Baja</text>
    <text x="612" y="209" font-size="11" fill="#991B1B">no se le vuelve a inscribir nunca</text>

    <rect x="20" y="245" width="840" height="40" rx="8" fill="#F8FAFC" stroke="#94A3B8" stroke-width="1.5"/>
    <text x="440" y="270" font-size="12" fill="#0F172A" text-anchor="middle"><tspan font-weight="700">KPIs de la campaña:</tspan> % respondió · % interesados · % con cita · enviados y entregados</text>

    <g font-size="11" font-weight="700" fill="#FFFFFF" text-anchor="middle">
      <circle cx="154" cy="85" r="11" fill="#64748B"/><text x="154" y="89">7</text>
      <circle cx="354" cy="85" r="11" fill="#D97706"/><text x="354" y="89">C</text>
      <circle cx="534" cy="85" r="11" fill="#2563EB"/><text x="534" y="89">5</text>
      <circle cx="844" cy="20" r="11" fill="#2563EB"/><text x="844" y="24">3</text>
      <circle cx="818" cy="20" r="11" fill="#16A34A"/><text x="818" y="24">2</text>
      <circle cx="844" cy="95" r="11" fill="#64748B"/><text x="844" y="99">6</text>
      <circle cx="844" cy="170" r="11" fill="#16A34A"/><text x="844" y="174">1</text>
      <circle cx="844" cy="245" r="11" fill="#16A34A"/><text x="844" y="249">4</text>
    </g>
  </g>
</svg>

Cada número es la mejora que actúa en ese paso. Recomendación: empezar por el **Paquete 1
(1 + 2 + 4)**, que es lo más rápido, se nota de inmediato y protege el número de WhatsApp de la
cuenta. Después, el **3 + 5**, que convierten las campañas en prospección de verdad.

> Las campañas siguen sin salir a producción hasta terminar el análisis de capacidad
> (`diag/envios_masivos`); estas mejoras pueden quedar listas mientras tanto.

---

## 8. Arranque: etapas, ponderaciones y fórmulas (versión básica)

> Acordado el 26/10/2026. Solo documento; todavía no se programa.

### 8.1 Las etapas

```
  ┌─────────┐   ┌────────────┐   ┌───────────┐   ┌─────────────┐   ┌──────────────┐
  │ 1 Nuevo │──▶│2 Contactado│──▶│3 Respondió│──▶│4 Interesado │──▶│5 Entregado a │
  │ (lista) │   │ (1er toque)│   │           │   │ (calificado)│   │   vendedor   │
  └─────────┘   └─────┬──────┘   └─────┬─────┘   └─────────────┘   └──────────────┘
                      │                │
                      ▼                ▼
               ┌─────────────┐  ┌─────────────────────────────────────────┐
               │Sin respuesta│  │ No ahora → se vuelve a buscar en N días │
               │tras 3 toques│  │ No le interesa → se cierra              │
               └─────────────┘  │ Baja / «no me escriban» → no contactar  │
                                └─────────────────────────────────────────┘
```

Cinco etapas y tres salidas. Son las mismas categorías de P1 y la propuesta para D3.

### 8.2 Las ponderaciones (puntuación del prospecto, 0 a 100)

```
Puntuación = Σ (peso × criterio)
           = Perfil (¿se parece a mi cliente ideal?)  máx. 50
           + Interés (¿qué hizo?)                     máx. 50
```

| Perfil | pts | Interés | pts |
|---|---|---|---|
| Giro o sector que sí atiendes | +20 | Respondió | +10 |
| Tamaño o zona correctos | +15 | Pidió precio o información | +20 |
| Habla quien decide | +15 | Pidió cita o llamada | +20 |
| | | No responde en 30 días | −10 |
| | | Dijo «no ahora» | −15 |

- **Corte:** con 60 puntos o más pasa a *Interesado* y se entrega a un vendedor.
- Los puntos negativos y el decaimiento evitan que un prospecto frío se quede arriba para siempre.
- Variante sencilla: **BANT** (Presupuesto, Autoridad, Necesidad y Tiempo, 25 puntos cada uno). En frío el presupuesto se infiere; no se pregunta en el primer toque.
- **Los pesos se calibran con datos reales.** Por eso la puntuación va al final del arranque (§8.5), igual que en P4.

### 8.3 Las fórmulas

**a) Tasa por etapa** (dónde se pierde la gente):
```
tasa = los que pasaron a la siguiente etapa ÷ los que entraron a esta
```

**b) Embudo inverso** (a cuántos hay que escribirles):
```
Meta: 10 ventas al mes
  ÷ 25 % cierre               = 40 interesados entregados
  ÷ 30 % respuesta→interesado = 134 que respondieron
  ÷ 15 % tasa de respuesta    ≈ 900 contactos a prospectar
```
Los porcentajes son de ejemplo; los reales salen de las primeras semanas.

**c) Embudo ponderado** (cuánto dinero hay en juego):
```
Valor esperado = Σ (valor del trato × probabilidad de su etapa)
  ej.: Interesado 20 % · Cita 50 % · Cotización enviada 70 %
```

### 8.4 Canales: WhatsApp con permiso ya; correo para el frío (D6)

El canal **no lo elige la campaña: lo hereda del Agente IA**. Al crear la campaña se copia la
bandeja del agente (`bulk_assign_service.rb:192`) y todo sale por ahí (`tracking_builder.rb:9`).
Un Agente IA tiene **una sola bandeja**.

```
 FASE 1 (ahora): contactos CON permiso      FASE 2: prospección EN FRÍO
 ┌────────────────────────┐                ┌────────────────────────┐
 │ Agente IA «Prospección │                │ Agente IA «Prospección │
 │   WhatsApp»            │                │   Correo» (copia)      │
 │ bandeja: WhatsApp      │                │ bandeja: Correo        │
 └──────────┬─────────────┘                └──────────┬─────────────┘
            ▼                                         ▼
     Campaña WhatsApp                          Campaña Correo
            └──────────────┬──────────────────────────┘
                           ▼
        mismas etapas · misma puntuación · UNA lista de baja
        tasas y embudo inverso medidos POR CANAL
```

| Canal | ¿Se puede escribir en frío? | Requisito del contacto | En campañas hoy |
|---|---|---|---|
| WhatsApp | **No.** La política de Meta exige que la persona te haya dado su número y su permiso (opt-in); la plantilla aprobada (una por toque, `contact_tracking.rb:228`) **no sustituye** el permiso | Teléfono + permiso | ✅ solo para contactos con permiso |
| Correo | Sí (es el canal de entrada en frío; ver §3.2 para México) | Correo | ✅ acepta el contacto (`eligibility.rb:39`); **nunca probado con agentes de IA** |
| SMS | Sí | Teléfono | ✅ |
| Telegram, Messenger, Instagram, TikTok | No: el cliente escribe primero | Conversación previa | Solo para seguimiento, no para prospectar |

- **WhatsApp no sirve para el primer contacto en frío** (objetivo del estudio: clientes que aún no nos conocen, D2 = bases externas). La fase 1 por WhatsApp prueba etapas, clasificación y medición con contactos que **ya dieron permiso** (clientes, cotizaciones, formularios). El frío entra por **correo** (fase 2) y pasa a WhatsApp solo cuando la persona da su número y su permiso.
- **Baja por contacto, no por canal:** quien dice «no me escriban» por WhatsApp tampoco recibe correo.
- **Tasas por canal:** el correo en frío responde mucho menos que WhatsApp; mezclarlas engaña.
- Cuando exista «agente con varias bandejas», los dos agentes se juntan en uno.

**Requisitos para el correo (fase 2):**
1. Bandeja de correo con su propio SMTP e IMAP (no usa el correo del servidor).
2. Subdominio aparte para correo en frío (ej. `ventas.tuempresa.com`), con SPF, DKIM y DMARC.
3. Calentamiento: empezar con 20–30 correos al día e ir subiendo.
4. Enlace de baja en cada correo (lo exigen Gmail y Yahoo).
5. **Verificar** cómo sale el asunto y el formato cuando escribe el Agente IA (puede salir el asunto genérico de Chatwoot).

**Probar correo en desarrollo:** producción ya tiene bandejas de correo; dev no tiene ninguna.
El correo del sistema en dev falla (`SMTP_ADDRESS` vacío y sin `sendmail`), pero eso no afecta a las
bandejas. La IMAP se revisa cada minuto (`config/schedule.yml:26`).
- **Opción A (recomendada):** Gmail nuevo solo de pruebas, con contraseña de aplicación;
  IMAP `imap.gmail.com:993` SSL, SMTP `smtp.gmail.com:587` STARTTLS. Ida y vuelta real.
- **Opción B:** captura local (Mailpit / `letter_opener`): solo salida, sirve para ver el formato.
- ⚠️ Nunca conectar en dev un buzón que usa producción: los dos lo leerían cada minuto.

### 8.5 Orden de arranque

```
 Paso 1                 Paso 2                      Paso 3
 Etapas + salidas  ──▶  Medir las tasas reales ──▶  Puntuación 0–100
 + lista de baja        (embudo inverso,            con pesos calibrados
 (P0 + P1), WhatsApp    por canal)
 con permiso
 ahora                  después de 2–4 semanas      cuando ya hay datos
```

El correo (prospección en frío) entra como fase 2 en cuanto haya bandeja de correo y se verifique el asunto.

---

## 9. Plan: correo listo para prospectar (F1–F4)

> 27/10/2026 · Solo plan. Sale de la prueba real en dev: bandeja «Develop» (Gmail, IMAP + SMTP),
> agente #12877, campañas #304 y #305. **Ya funciona** la ida y vuelta: la IA escribe, el prospecto
> responde, la IA contesta en el mismo hilo (~9 s). Falta lo que hace que el correo se abra,
> no parezca spam y respete la baja.

```
 Hoy                                              Con F1–F4
 ───────────────────────────────────────────      ───────────────────────────────────────────
 Asunto: [#642] Nuevos mensajes en esta conv.     Asunto: Juan, una idea para tus envíos   (F1)
 Hola Juan, ... ¿te interesa? #IA                 Hola Juan, ... ¿te interesa?
                                                  —
                                                  Ana López · Wintook                      (F2)
                                                  ¿No quieres más correos? Darte de baja   (F3)
 Responde → al día siguiente otro toque           Responde → ya no hay más toques          (F4)
```

### F1 · Asunto propio por campaña

**Problema.** Una conversación que abre el agente no tiene `mail_subject`, y el correo sale con
«[#N] Nuevos mensajes en esta conversación» (`conversation_reply_mailer.rb:114`).

**Cómo.**
- Columna nueva `tracking_campaigns.email_subject` (texto, máx. 150), con variables `{{contacto}}` y `{{empresa}}`
  (no `{{nombre}}`: en los agentes ya significa «adjunta el archivo»).
- En `TrackingCampaigns::TrackingBuilder#open_conversation` (`tracking_builder.rb:52`), si la
  bandeja es de correo, guardar el asunto ya armado en `conversation.additional_attributes['mail_subject']`.
- El mailer ya hace el resto: el primer correo va con el asunto y los siguientes con «Re: …»
  (cuenta solo mensajes no privados, `message.rb:118`; la nota privada inicial no estorba).
- Si el contacto **ya tenía hilo** en la bandeja, se conserva el asunto del hilo («Re: …»).
- Pantalla: en el modal de campaña, el campo «Asunto del correo» aparece **solo si la bandeja del agente es de correo**, y es obligatorio.

**Pruebas.** Conversación nueva con asunto · hilo existente conserva su asunto · bandeja WhatsApp sin cambios · variables vacías no dejan `{{…}}`.

> ✅ **HECHA (27/10/2026).**
> - **Qué se hizo:** migración `20261031100000_add_email_subject_to_tracking_campaigns`;
>   `TrackingCampaigns::EmailSubject` (arma `{{contacto}}` = primer nombre y `{{empresa}}` =
>   `company_name`; si falta un dato, la variable desaparece sin dejar «, ,»; máx. 150);
>   `TrackingBuilder#email_subject_attributes` lo pone en `mail_subject` al abrir la conversación
>   **solo si la bandeja es de correo**; viaja por la API de lote (`email_subject`) y la de campaña
>   continua; `CampaignForm.vue` muestra «Asunto del correo» solo si el agente elegido escribe por
>   correo, y sin él no deja confirmar.
> - **Cómo funciona:** el primer correo sale con el asunto armado; los siguientes, «Re: asunto»
>   (lo hace el mailer). Si el contacto ya tenía hilo, se conserva el asunto del hilo.
> - **Pruebas:** `spec/services/tracking_campaigns/email_subject_spec.rb` (5) y 4 casos nuevos en
>   `enroll_spec.rb` (asunto en conversación nueva · hilo conserva el suyo · sin asunto como antes ·
>   fuera de correo no aplica). 47 + 26 en verde.
> - **Cómo usarlo:** Campañas → Nueva campaña → elegir un Agente IA cuya bandeja sea de correo →
>   aparece «Asunto del correo» (ej. «{{contacto}}, una idea para reducir tus costos de envío»).
> - **Prueba en vivo (campaña #308, 27/10/2026):** contacto sin hilo → «Wintook, ¿ya elegiste tu carrera?» ✅.
>   Los que ya tenían hilo salen con el asunto del hilo, como se diseñó.
> - **Ojo al borrar conversaciones de correo:** al borrarlas se borran sus mensajes, y el lector IMAP
>   vuelve a importar los correos recientes del buzón (ya no los reconoce) y crea conversaciones
>   nuevas con los asuntos viejos. Pasó en dev: 3 de 4 contactos quedaron en hilos reimportados.
> - **Ojo al migrar en un servidor vivo:** reiniciar Rails y Sidekiq; si no, PostgreSQL rechaza las
>   consultas preparadas de `tracking_campaigns` («cached plan must not change result type») y los
>   toques fallan (pasó en dev con la campaña #306).

### F2 · Firma en lugar de «#IA» / «-TB»

**Problema.** Se agregan dos marcas al texto: « #IA» al toque (`contact_tracking_job.rb:257`) y
«\n\n-TB» a la respuesta (`contact_tracking_response_analyzer_job.rb:629`). En correo se ven raras y delatan el envío automático.

**Cómo.**
- **Solo en bandejas de correo:** no agregar las marcas y poner la **firma** del agente.
- Firma = campo nuevo del agente (`tracking_templates.email_signature`, texto corto), p. ej. «Ana López · Ventas · Wintook».
- WhatsApp y los demás canales siguen igual (decidir aparte si las marcas se quedan ahí).
- La marca sirve para saber qué escribió la IA: se conserva como dato del mensaje
  (`content_attributes`), no como texto visible.

**Pruebas.** Correo sin marcas y con firma · WhatsApp con marcas como hoy · agente sin firma = sin firma.

### F3 · Baja: enlace + lista de no contactar (P0)

**Problema.** No hay forma de darse de baja ni de recordar quién la pidió. Gmail y Yahoo exigen la
baja con un clic, y la ley en México exige respetarla.

**Cómo.**
```
 Correo ──▶ pie «Darte de baja» + cabeceras List-Unsubscribe / List-Unsubscribe-Post
              │
              ▼
 GET/POST /p/baja/:token  (enlace firmado, sin sesión)  ──▶  contacts.opted_out_at = ahora
              ▲                                              opted_out_source = 'link'
 Respuesta «no me escriban» / «baja» ── IA lo detecta ──────┘  (source = 'reply')
              │
              ▼
 Enroll omite con motivo "opted_out" · seguimientos activos del contacto se cancelan
```
- Columnas nuevas en `contacts`: `opted_out_at`, `opted_out_source`. **No** se usa `contacts.blocked`, porque bloquea también lo que el contacto escribe.
- La baja es **por contacto, en todos los canales** (§8.4).
- Enlace: token firmado (`MessageVerifier`), con página pública mínima «Listo, ya no te escribiremos».
- Cabeceras `List-Unsubscribe` (mailto + URL) y `List-Unsubscribe-Post: List-Unsubscribe=One-Click` en `ConversationReplyMailer`, **solo** en correos de seguimiento/campaña.
- `TrackingCampaigns::Enroll`: nuevo motivo `opted_out` (junto a los de `enroll.rb:10-16`) y en la vista previa.
- Detección por respuesta: frase fija («baja», «no me escriban», «unsubscribe») + la IA cuando el router se encienda; hoy el router está apagado (`TRACKING_DETECT_INTENT=false`).
- Ficha del contacto: indicador «Pidió no ser contactado (fecha, cómo)» y botón para quitarlo.

**Pruebas.** Enlace marca la baja · token alterado = 404 · contacto con baja no se inscribe · respuesta «baja» marca y cancela · cabeceras presentes solo en correos de campaña.

### F4 · Dejar de mandar toques cuando el prospecto responde

**Problema.** En la prueba, el prospecto respondió y el seguimiento siguió `scheduled` con otro toque
al día siguiente. Con el router apagado, la respuesta siempre va a «conversar» y no cambia el estado.

**Cómo.**
- Cuando entra un mensaje del contacto en la conversación del seguimiento, el seguimiento pasa a **«conversando»**:
  se cancelan los toques pendientes (`cancel_existing_jobs`) y la IA sigue contestando.
- Si el prospecto deja de responder N días (propuesta: 3 hábiles), se reanuda **un** toque de recuperación.
- Aplica a todos los canales: en WhatsApp pasa lo mismo.
- Es la base de P1: «Respondió» es la etapa 3 de §8.1.

**Pruebas.** Respuesta cancela el toque programado · la IA sigue contestando · sin respuesta en N días se reanuda un toque · seguimiento cancelado no revive.

### Orden y tamaño

| Pieza | Tamaño | Depende de |
|---|---|---|
| F1 Asunto | Chico | — |
| F2 Firma | Chico | — |
| F4 Toques al responder | Chico–mediano | — |
| F3 Baja | Mediano | — (F4 ayuda a cancelar al pedir baja) |

Orden propuesto: **F1 → F2 → F4 → F3**. Las tres primeras son rápidas y se prueban con la bandeja «Develop»; F3 lleva migración, página pública y cabeceras.

### Decisiones de este plan

| # | Pregunta | Propuesta |
|---|---|---|
| D8 | ¿El asunto vive en la campaña o en el agente? | En la **campaña** (cada campaña, su gancho); el agente puede dar uno por omisión |
| D9 | ¿Las marcas «#IA» / «-TB» se quitan también en WhatsApp? | No en esta fase; solo correo |
| D10 | Al responder: ¿cancelar toques para siempre o reanudar uno a los N días? | Reanudar **uno** a los 3 días hábiles |
| D11 | ¿La baja por enlace aplica a todos los canales? | Sí, por contacto (§8.4) |

---

## 10. Plan Prospección v1.0: un tipo de campaña

> 27/10/2026 · Solo plan. Responde D1: **evolución de Campañas**, no módulo nuevo. Hoy una
> campaña de prospección es una campaña de seguimiento que escribe por correo; nada en la
> pantalla dice «Prospección» ni aplica sus reglas.

### 10.1 Cómo se ve

```
 Campañas                                                    [ + Nueva campaña ]
 ┌───────────────────────────────────────────────────────────────────────────┐
 │ Todas · Seguimiento · Prospección                                          │
 ├───────────────────────────────────────────────────────────────────────────┤
 │ 🎯 Prospección · Grúas Monterrey     Correo   En curso   120 → 18 resp.    │
 │ 🔁 Seguimiento · Cobranza octubre    WhatsApp Terminada  300 → 210 resp.   │
 └───────────────────────────────────────────────────────────────────────────┘

 Nueva campaña →  ¿Para qué es?   ( ) Seguimiento: contactos que ya conoces
                                  (•) Prospección: clientes nuevos, hasta que muestren interés

 Detalle de una campaña de prospección:
 Contactados 120 → Respondieron 18 (15 %) → Interesados 6 (5 %) → Entregados 2
 Salidas:  No ahora 4 · No le interesa 7 · Baja 1 · Sin respuesta 102
 [ Interesados: lista para pasar a un vendedor ]
```

### 10.2 Qué trae el tipo «Prospección»

| Regla | En Seguimiento | En Prospección |
|---|---|---|
| Asunto propio en correo (F1 ✅) | Opcional | Obligatorio |
| Firma real, sin «#IA»/«-TB» (F2) | Solo en correo | Siempre en correo |
| Se detiene al responder (F4) | Sí | Sí |
| Baja con un clic + no contactar (F3) | Respeta la lista | Respeta la lista + enlace obligatorio en correo |
| Tope diario (`daily_cap`) | Opcional | **Obligatorio** (sugerido 30) |
| Solo días hábiles y horario de atención | Opcional | **Siempre** |
| Canal | Cualquiera | Correo para el frío; WhatsApp solo a contactos con permiso |
| Clasificar respuestas (P1) | No | **Sí**: 5 etapas + 3 salidas |

### 10.3 Fases

| Fase | Qué | Dónde | Tamaño |
|---|---|---|---|
| **V0** | Columna `tracking_campaigns.purpose` (`follow_up` / `prospecting`, por omisión `follow_up`); selector «¿Para qué es?» en `CampaignForm.vue`; pestañas y marca 🎯 en `Campaigns.vue` | migración + form + lista | Chico |
| **V1** | F2 · Firma (§9) | `contact_tracking_job.rb:257`, `contact_tracking_response_analyzer_job.rb:629` | Chico |
| **V2** | F4 · Se detiene al responder (§9) | analizador de respuestas | Chico–mediano |
| **V3** | Reglas del tipo: tope diario y días hábiles obligatorios; asunto obligatorio en correo | `BulkAssignService`, `TrackingCampaignContinuousParams`, form | Chico |
| **V4** | F3 · Baja + no contactar (§9) | migración `contacts.opted_out_*`, página pública, cabeceras, `Enroll` | Mediano |
| **V5** | P1 · Clasificar cada respuesta: columna `contact_trackings.prospect_stage` (`contacted` · `replied` · `interested` · `handed_off`) y `prospect_exit` (`not_now` · `not_interested` · `opted_out` · `no_reply`); un clasificador propio (no el router apagado) que corre con cada respuesta del prospecto | servicio nuevo `TrackingCampaigns::ProspectClassifier` | Mediano |
| **V6** | Embudo de prospección en `CampaignDetail.vue`: etapas, salidas y tasas; lista «Interesados» | `funnel_by_campaign` + detalle | Chico–mediano |

> ✅ **V0 HECHA (27/10/2026).**
> - **Qué se hizo:** migración `20261031110000_add_purpose_to_tracking_campaigns` (`purpose`:
>   `follow_up` | `prospecting`, por omisión `follow_up`; índice por cuenta); `TrackingCampaign#prospecting?`;
>   viaja por la API de lote y la de campaña continua (valor desconocido → `follow_up`); el detalle lo devuelve.
> - **Pantalla:** en «Nueva campaña», «¿Para qué es?» con dos fichas (Seguimiento / Prospección);
>   en la lista, pestañas **Todas · Seguimiento · Prospección** (`woot-tabs`) y 🎯 junto al nombre.
>   Se puede cambiar mientras está Guardada (D12).
> - **Pruebas:** 3 nuevas en `tracking_campaigns_controller_spec.rb`; 76 en verde.
> - **Cómo usarlo:** Campañas → Agregar campaña → «¿Para qué es?» → Prospección.
> - Todavía **no cambia ninguna regla**: eso llega con V1–V6.

Orden: **V0 → V1 → V2 → V3 → V4 → V5 → V6**. Con V0–V4 el envío ya es correcto;
con V5–V6 ya es prospección (se sabe quién está interesado y cuánto rinde la campaña).

### 10.4 Notas de lo que ya existe

- **El embudo ya existe** (`tracking_campaigns_controller.rb:139`): respondió, interesado, cita,
  objetivo cumplido. Pero «respondió» se cuenta con `last_intent`, que solo llena el router de
  intención, **apagado** (`TRACKING_DETECT_INTENT=false`). V5 llena sus propias etapas sin depender del router.
- **Tope diario y días hábiles ya existen** en la campaña (`daily_cap`, `respect_working_hours`);
  V3 solo los vuelve obligatorios para Prospección.
- **«Interesados» → vendedor** con plazo y avisos es P2 y queda para v1.1. En v1.0, la lista
  de interesados basta para que alguien los tome a mano.

### 10.5 Fuera de v1.0 (v1.1 en adelante)

- P2 · Entregar al vendedor con plazo y avisos (necesita D4).
- Puntuación 0–100 (cuando haya datos para calibrar los pesos, §8.5).
- A/B de asuntos y mensajes.
- Multicanal en una misma campaña: correo → WhatsApp cuando el prospecto da su permiso (necesita «agente con varias bandejas»).

### 10.6 Cómo v1.0 cumple las buenas prácticas

La lista de una prospección bien hecha (§1) no se pierde: cada punto cae en una fase o es tarea
de la empresa (no código). Se marca conforme avanzan las fases.

| Buena práctica | Dónde queda | Estado |
|---|---|---|
| 1 · A quién: cliente ideal, correos validados | Empresa: definir el cliente ideal · v1.1: validar correos antes de enviar | ⏳ empresa / v1.1 |
| 2 · Mensaje: asunto, firma, prompt real | F1 ✅ · V1 firma · empresa: prompt de prospección | 🟡 |
| 3 · Cadencia: se detiene al responder, días hábiles | V2 + V3 | ⏳ |
| 4 · Cumplir: baja, no contactar, aviso de privacidad | V4 · D7 (legal) | ⏳ |
| 5 · Que llegue: dominio, calentamiento, tope diario | V3 tope · empresa: dominio con SPF/DKIM/DMARC | ⏳ |
| 6 · Calificar respuestas | V5 | ⏳ |
| 7 · Entregar al vendedor | V6 lista «Interesados» · v1.1: P2 con plazo y avisos | ⏳ |
| 8 · Medir | V6 embudo y tasas | ⏳ |

### 10.7 Decisiones de este plan

| # | Pregunta | Propuesta |
|---|---|---|
| D12 | ¿El tipo se puede cambiar después de crear la campaña? | Solo mientras está **Guardada** |
| D13 | Tope diario sugerido para Prospección | 30 por campaña al día (lo puede bajar o subir) |
| D14 | ¿El clasificador de V5 usa qué modelo? | gpt-4o-mini con salida fija (solo elige una etiqueta); si falla, gpt-4o |
| D15 | ¿Un prospecto «No ahora» se vuelve a buscar solo? | Sí, a los 30 días, con un solo toque |

---

## 11. Decisiones abiertas

| # | Pregunta |
|---|---|
| D1 | ~~¿«Prospección» es un módulo nuevo o la evolución de Campañas de seguimiento?~~ **Resuelta 27/10/2026:** evolución; un tipo de campaña «Prospección» (§10) |
| D2 | ¿A quién se le va a escribir? ¿Solo contactos con permiso (clientes, cotizaciones, formularios) o también bases externas? Esto define cuánto pesa P0 |
| D3 | ~~¿Qué categorías de respuesta, exactamente?~~ **Resuelta 26/10/2026:** las 5 etapas + 3 salidas de §8.1 |
| D4 | ¿Quién recibe al interesado: el embudo, un vendedor fijo, reparto por turnos? ¿Con qué plazo? |
| D5 | ¿De dónde sale el «valor»: cotización, caso, lo declara el vendedor? |
| D6 | ~~¿Solo WhatsApp o también llamada / correo como pasos?~~ **Resuelta 26/10/2026:** WhatsApp ya, solo con contactos con permiso; correo en fase 2 para el frío (§8.4); llamada, después |
| D7 | Validación legal (LFPDPPP, REPEP) antes de ofrecerlo a clientes |

---

## 12. Fuentes

Prácticas y plataformas:
- Salesforce LATAM · Cómo realizar la prospección de ventas — https://www.salesforce.com/mx/blog/prospeccion-de-ventas/
- HubSpot · Crear y editar secuencias — https://knowledge.hubspot.com/sequences/create-and-edit-sequences
- HubSpot · API de secuencias — https://developers.hubspot.com/docs/api-reference/2026-09-beta/automation/sequences/guide
- Salesloft cadencias (terceros) — https://leadmagic.io/gtm-skills/salesloft-cadences · https://www.octavehq.com/post/salesloft-cadences-building-effective-sequences
- Outreach secuencias (terceros) — https://leadmagic.io/gtm-skills/outreach-sequences
- Cadencia outbound — https://www.apollo.io/insights/outbound-sales-cadence
- Apollo · IA SDR y seguimiento — https://www.apollo.io/insights/how-do-ai-sdrs-handle-follow-up-sequences-without-human-intervention · https://www.apollo.io/insights/what-features-separate-a-great-ai-sdr-platform-from-a-basic-automation-tool
- Clasificación de respuestas — https://smartlead.ai/blog/ai-email-response-generator · https://instantly.ai/blog/ai-reply-management-playbook-cold-email/ · https://help.quickmail.com/replies-and-opportunities/categorizing-replies-with-ai/
- Calificación outbound — https://setsmart.io/blog/outbound-lead-qualification · https://www.gartner.com/peer-community/post/how-outbound-b2b-sales-teams-effectively-qualify-leads-how-maximize-success
- respond.io · WhatsApp y seguimiento de leads — https://respond.io/faqs/what-is-best-whatsapp-marketing-tool-for-campaigns-and-lead-follow-up · https://respond.io/lp/whatsapp-broadcast

WhatsApp / Meta:
- Política de WhatsApp Business — https://whatsappbusiness.com/policy/
- Límites de mensajes (Meta) — https://developers.facebook.com/documentation/business-messaging/whatsapp/messaging-limits
- Calidad y límites (Braze) — https://braze.com/docs/user_guide/channels/whatsapp/message_processing/quality_rating_and_messaging_limits/

México:
- LFPDPPP (texto vigente) — https://www.diputados.gob.mx/LeyesBiblio/pdf/LFPDPPP.pdf
- Resumen nueva LFPDPPP (EY) — https://www.ey.com/content/dam/ey-unified-site/ey-com/es-mx/technical/tax/documents/ey-law-flash-nueva-lfpdppp.pdf
- REPEP (Profeco) — https://www.adn40.mx/tramites/2025-11-06/como-darse-alta-repep-de-profeco-para-evitar-llamadas-no-deseadas
- Senado, multas contra acoso comercial (oct 2026) — https://www.publimetro.com.mx/nacional/2026/10/08/te-llaman-a-cada-rato-para-venderte-algo-senado-aprueba-multas/

> Nota: varias fuentes de plataformas son blogs del propio proveedor o de terceros. Las cifras
> (toques por cadencia, 2–5 % de paso) son de referencia, no garantías.
