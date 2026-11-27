---
tags: [plan, servicio, ordenes, taller, equipos]
fecha: 2026-11-26
estado: propuesta (sin empezar)
---

# Plan — Servicio en taller con tipos de equipo

## Idea
Un taller recibe un equipo del cliente y se lo regresa reparado. El equipo puede ser un auto, un montacargas, una retroexcavadora o una computadora. En todos los casos la dinámica es la misma:

**Recibir → Diagnosticar → Cotizar → Autorizar → (Esperar refacción) → Reparar → Revisar → Entregar**

Lo que cambia entre giros no es el flujo sino **el equipo**:
- cómo se identifica;
- qué medidor de uso tiene;
- qué datos lleva;
- qué se revisa al recibirlo;
- cómo le dice cada giro al equipo y al técnico.

**Propuesta:** no crear un módulo por giro ni cambiar la terminología de toda la plataforma.
- Agregar **Tipos de equipo** configurables en Catálogos.
- Sobre ellos montar un flujo de **taller** encima de Servicio › Órdenes de trabajo, que ya existe.

Así, el siguiente cliente (taller de cómputo, renta de maquinaria) se arma configurando, sin programar.

### Lo que cambia por tipo de equipo (ejemplos)
| | Vehículo | Montacargas / maquinaria | Computadora |
|---|---|---|---|
| Se identifica por | Placas (y VIN) | Serie / número económico | Serie / etiqueta |
| Medidor de uso | Kilómetros | Horas (horómetro) | Ninguno |
| Al recibirlo se revisa | Gasolina, golpes, objetos de valor | Combustible/batería, horómetro, aditamentos, fugas | Cargador, accesorios, contraseña, ¿respaldo? |
| Servicio cada… | Fecha o km | Fecha u horas trabajadas | Fecha |
| Dónde se atiende | Taller | Taller o en campo | Taller |
| Cómo le dicen | Auto · Mecánico | Equipo/Unidad · Técnico | Equipo · Técnico |

### Por qué no una «configuración de terminología» general
- Habría que tocar cientos de textos en toda la plataforma: casos, Dali, guías y reportes, y además mantenerlos.
- Tampoco resuelve lo importante: qué datos lleva el equipo y qué se revisa al recibirlo.
- En su lugar, cada **tipo de equipo** trae sus **pocas palabras clave**: equipo, identificador, medidor y técnico. Esas palabras se usan donde el cliente las ve: la orden, la recepción, los mensajes, el portal y la IA.

## Lo que ya existe y sirve tal cual
| Necesidad | Lo que ya existe |
|---|---|
| Orden con folio, técnico, horas y materiales | Orden de trabajo (responsable, horas real/est., cronómetro, materiales del catálogo, total) |
| Etapas y pasos obligatorios | Etapas por tipo de caso + checklist por etapa |
| Fotos antes/después y bitácora | «Reporte de servicio» |
| Cotizar y que el cliente acepte | Cotizaciones ligadas al caso, aceptar/rechazar por enlace, «Cotizar trabajo adicional» |
| Firma y conformidad al entregar | «Terminé» (quién recibe + firma), «Cerrar orden» |
| Reporte y seguimiento del cliente | «Enviar al cliente» + portal de la orden (en qué va, confirmar, calificar) |
| Equipos del cliente con historial | `customer_assets` (pestaña Equipos del contacto, «Historial (N)») |
| Servicio cada X tiempo | Mantenimientos (crean la orden solos, avisan al cliente) |
| Atender en campo (maquinaria) | Mi ruta en campo, Despacho, técnico externo |
| Catálogo de servicios y refacciones | Catálogos (precio, costo, unidades, impuestos), formatos de cotización con PDF |
| Campos extra en la orden | `case_type_fields` |
| WhatsApp con IA, citas, recordatorios | Agentes listos (prospectos, clientes), campañas Recordar y Reactivar |
| Métricas | Dashboard de Órdenes (horas, retrabajos, a la primera, calificación) |

## Lo que hay que construir (análisis)

### A. Tipos de equipo (base de todo)
Catálogos › Tipos de equipo. Cada tipo tiene:
1. **Nombre y palabras:** singular/plural del equipo («Vehículo», «Montacargas»), nombre del identificador («Placas», «Núm. económico», «Serie») y del técnico («Mecánico», «Técnico»).
2. **Identificador principal:** se busca por él en todo el sistema (crear orden, contactos, barra de búsqueda, Dali). Debe ser único por cuenta.
3. **Medidor de uso:** km, horas, otro (con su unidad) o ninguno.
4. **Campos propios:** texto, número, fecha o lista. Por ejemplo VIN, año y color; capacidad y altura de mástil; procesador y RAM.
5. **Hoja de recepción:** la lista de lo que se revisa al recibirlo. Cada punto es sí/no, nivel, texto o foto, y puede ser obligatorio.
6. **Plantillas listas** para arrancar rápido: Vehículo, Maquinaria y Computadora/Electrónico. El administrador las ajusta.

`customer_assets` gana `equipment_type_id` y `fields` (jsonb). El historial **sigue al equipo** aunque cambie de dueño (flotillas, autos que se venden).

### B. Lecturas del medidor
- Cada orden pide la lectura al recibir (km u horas) y la guarda en el historial del equipo, con fecha y orden.
- Avisa si la lectura es menor que la anterior (error de captura).
- Sirve para la garantía («5,000 km») y para los mantenimientos por uso (F).

### C. Recepción del equipo
Es la pieza que más distingue a un taller. Se hace en el mostrador, en celular o tableta:
1. Buscar el equipo por su identificador, o darlo de alta: tipo, cliente y campos.
2. Lectura del medidor.
3. La **hoja de recepción del tipo**: niveles, golpes y daños con fotos, accesorios y objetos.
4. **Falla que reporta el cliente**, con sus palabras.
5. **Fecha promesa** de entrega.
6. **Firma del cliente** (ya existe para entregar; se reutiliza).

Al terminar se crea la orden, ligada al equipo, y le llega al cliente «Recibimos tu …» con el folio y el enlace.

### D. Etapas de taller
Las etapas de Orden de hoy están pensadas para visitas en campo. Para el taller:

**Recibido → En diagnóstico → Esperando autorización → Esperando refacción → En reparación → Control de calidad → Listo para entregar → Entregado**

- Las dos «Esperando…» **detienen el reloj**, como «En espera del cliente» en Soporte, y muestran cuántos días llevan.
- La orden en taller («Dónde se atiende: En oficina») no pide visita ni sale en Despacho. Hay que revisar que nada le pida «Programar visita».
- **Fecha promesa** en la lista y en el tablero, con aviso si se pasa.
- Los nombres de las etapas se pueden cambiar por tipo de caso (ya existe).

### E. Diagnóstico, cotización y autorización
- **Mano de obra por horas** en la cotización (horas × tarifa del técnico o del servicio) junto a las refacciones.
- **Autorizar por partes:** el cliente acepta unas líneas y otras no. Hoy la cotización se acepta o rechaza completa.
- Al autorizar (por enlace, portal o WhatsApp) la orden **avanza sola**: a «Esperando refacción» si falta alguna, o a «En reparación». Las líneas aceptadas pasan a materiales.
- **Trabajo adicional** encontrado al reparar: ya existe. Falta mandar la foto del problema junto con la cotización.

### F. Mantenimientos por uso
Hoy Mantenimientos programa solo por fecha («cada 3 meses»). Hay que agregar:
- **«Cada N km / horas»**, o lo que llegue primero entre fecha y uso.
- La orden se crea cuando la última lectura (o la estimada por el uso promedio) se acerca al límite.
- Es lo que más pide la maquinaria (servicio cada 250 horas) y los autos (cada 10,000 km).
- **Captura de lecturas sin orden:** el cliente manda el horómetro por WhatsApp o el portal. Para flotillas y renta de maquinaria.

### G. Refacciones pedidas
- No hay inventario (existencias). Para esta etapa basta con la **refacción pedida a proveedor**:
  - proveedor, costo y fecha estimada, ligada a la orden;
  - la orden muestra «Esperando: balatas (llega jueves)»;
  - al marcarla como llegada, avisa.
- **Margen por orden:** costo contra precio cobrado (el catálogo ya tiene `cost`).
- El **inventario completo** (entradas, salidas, mínimos) es otro proyecto. No entra aquí.

### H. Avisos al cliente y portal
- Mensajes por WhatsApp al cambiar de etapa, usando las palabras del tipo:
  - «Recibimos tu montacargas»;
  - «Diagnóstico y cotización: autoriza aquí»;
  - «Llegó la refacción»;
  - «Tu auto está listo», con el total y las fotos.
- **Plantillas de WhatsApp de taller** ya hechas (fuera de 24 h, Meta las cobra).
- **Portal de la orden:** etapa de taller, fecha promesa, fotos, autorizar y la hoja de recepción firmada.

### I. La IA
- **Atención a prospectos:**
  - agenda la cita;
  - pide los datos del equipo según su tipo (marca, modelo, año y km; o serie y horas);
  - cotiza los servicios de precio fijo del catálogo.
- **Atención a clientes:** contesta «¿ya está mi carro / mi equipo?» leyendo la etapa de la orden abierta del contacto, o buscándola por el identificador.
- **Campañas:** Recordar «te toca servicio» por fecha o uso, y Reactivar a clientes que no vienen hace meses.
- **Dali:** «¿qué le hicimos al ABC-123?», «¿qué equipos llevan más de 3 días esperando refacción?».

### J. Tablero del taller y garantía
- **Tablero por etapa** (ya existe el Tablero de casos). La tarjeta muestra identificador, técnico, fecha promesa y días en la etapa. Opcional: columnas por técnico o por bahía.
- **Garantía por trabajo** (tiempo y/o uso: 3 meses o 5,000 km). Si regresa por lo mismo, se marca como garantía o retrabajo; el Dashboard ya mide retrabajos.

### Fuera de este plan
- Facturación CFDI (se integra después).
- Inventario completo de almacén.
- Aseguradoras (siniestros, ajustadores).
- Renta de equipos (contratos de renta, entregas y devoluciones). Podría salir después de B y F.

## Fases

| Fase | Qué | Tamaño |
|---|---|---|
| **T0 — Configurar con lo que hay** | Tipo de caso «Servicio en taller» (clase Orden, en oficina), etapas de taller, checklist, campos del tipo de caso (km, fecha promesa, falla), catálogo de servicios y refacciones, formatos de cotización. **Sin código**: probarlo con el cliente real y anotar qué duele. | 1 día |
| **T1 — Tipos de equipo** | Catálogos › Tipos de equipo (palabras, identificador, medidor, campos, hoja de recepción), plantillas Vehículo/Maquinaria/Computadora, equipo con su tipo y campos, búsqueda por identificador en todo el sistema, historial que sigue al equipo. | 4 días |
| **T2 — Recepción y lecturas** | Hoja de recepción en celular/tableta según el tipo, lectura del medidor con historial, firma al recibir, crea la orden y avisa «Recibimos tu …». | 3–4 días |
| **T3 — Etapas y autorización** | Etapas de taller con reloj detenido en las esperas, fecha promesa, mano de obra por horas, autorizar por partes, la orden avanza sola al autorizar, foto en trabajo adicional. | 4 días |
| **T4 — Refacciones pedidas** | Refacción pedida con proveedor y fecha, aviso al llegar, margen por orden. | 2 días |
| **T5 — Avisos y portal** | Plantillas de WhatsApp de taller con las palabras del tipo, portal con etapa, fecha promesa, fotos, autorizar y recepción firmada. | 2 días |
| **T6 — Mantenimientos por uso** | «Cada N km/horas» o lo que llegue primero, estimación por uso promedio, captura de lecturas por WhatsApp/portal. | 3 días |
| **T7 — IA y campañas** | Prospectos pide los datos según el tipo y agenda, clientes contesta el estado de su orden, Recordar por fecha/uso, Dali por identificador. | 3 días |
| **T8 — Tablero y garantía** | Tarjeta de taller en el Tablero (identificador, técnico, fecha promesa, días en etapa), garantía por tiempo/uso y retrabajo. | 2 días |

**Orden recomendado:**
1. **T0 con el cliente real**, para validar el flujo sin programar.
2. **T1 y T2**: es lo que se nota desde el primer día (recibir el equipo y encontrarlo por su identificador).
3. **T3**: es donde el taller pierde más tiempo, esperando a que el cliente conteste.
4. **T6** antes que el resto si el cliente es de maquinaria.

Cada fase actualiza su guía de Dali (`ordenes_trabajo`, `despacho_mantenimientos`, una guía nueva `tipos_equipo`).

## Preguntas para el cliente
1. ¿Qué equipos recibe (autos, maquinaria, electrónicos)? ¿Atiende también en campo?
2. ¿Cuántos técnicos y bahías tiene? ¿Paga comisión por horas?
3. ¿Hoy cómo recibe el equipo (hoja en papel, fotos)? ¿Pide firma?
4. ¿Maneja almacén de refacciones o compra por pedido?
5. ¿Atiende flotillas (empresas con varios equipos)? ¿Lleva el uso (km/horas) de sus equipos?
6. ¿Factura cada orden? ¿Con qué sistema?
7. ¿Qué servicios tienen precio fijo y cuáles van por diagnóstico?

## 🔗 Relacionado
- [[Plan-Clase-Orden-de-Trabajo]] · [[Plan-Trabajo-Campo]] · [[Plan-Catalogo-Cotizaciones]] · [[Plan-Contratos]]
- Guías: `ordenes_trabajo`, `despacho_mantenimientos`, `cotizaciones`, `tipos_caso`, `agentes_atencion_clientes`
