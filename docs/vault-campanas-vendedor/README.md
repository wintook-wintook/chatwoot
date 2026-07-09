# Bóveda de conocimiento — Campañas con Agente Vendedor IA

Notas atómicas (Markdown + wikilinks `[[ ]]`) del módulo **Campañas con Agente
Vendedor IA (MVP)**: desplegar un Agente Vendedor sobre un segmento de prospectos y
convertir las conversaciones en **oportunidades de venta** (no es envío masivo).
Empieza por **[[00-Indice]]**.

```
vault-campanas-vendedor/
├── 00-Indice.md            ← mapa de contenido (MOC), empieza aquí
├── diseno/                 ← visión, modelo de datos, las 7 vistas, KPIs
└── implementacion/         ← reuso/arquitectura, hallazgos del bulk assign, fases, pendiente
```

> Rama `fix/bulk_tracking` (derivada de `develop`). **Estado: PLAN consolidado, sin
> implementar.** Se apoya fuertemente en el módulo existente **Contact Tracking**
> (`@contact_tracking`) — el "Agente IA / entrenamiento" es un `tracking_template` y la
> selección de prospectos es el **bulk assign**. Plan fuente: `docs/campanas_agente_vendedor_plan.md`.
