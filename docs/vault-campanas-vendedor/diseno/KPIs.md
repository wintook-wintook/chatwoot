---
titulo: KPIs
tipo: diseno
tags: [campanas-vendedor, kpis, metricas]
---

# KPIs (fórmulas)

```
Tasa de respuesta         = respondieron / asignados
Conversión                = objetivos cumplidos / asignados
Conversión s/ interesados = objetivos cumplidos / respondieron
Autonomía                 = conversaciones resueltas por IA / respondidas
Valor generado            = Σ (cotizaciones + pedidos + oportunidades + ventas)
Score promedio            = promedio del score IA de los prospectos
Tiempo prom. de respuesta = 1er mensaje → 1ª respuesta
```

## Notas de cálculo
- **"Respondieron"**: prospecto cuyo contacto envió ≥1 mensaje incoming en la conversación
  de la campaña.
- **"Objetivo cumplido"**: `result` ∈ objetivo de la campaña (o `outcome` positivo del tracking).
- **"Resuelto por IA" (autonomía)**: conversación con outcome positivo y **sin escalado a humano**.
- **"Valor generado"**: ver decisión abierta en [[Pendiente]] (declarado por vendedor / inferido
  por IA / traído del ERP-cotización).
- Las métricas alimentan las Vistas 2/5/6 ([[Las-7-vistas]]); base de cálculo = `tracking_campaign_prospects`.
