---
titulo: Importación Excel/CSV — Contact Tracking
tipo: implementacion
tags: [contact-tracking, import, excel, csv]
---

# Importación Excel/CSV

Cargar trackings en lote desde un archivo. Servicio:
`app/services/contact_tracking_import_service.rb`. API:
`POST /api/v1/accounts/:account_id/contact_tracking_imports`
(`contact_tracking_imports_controller.rb`). UI:
`routes/dashboard/settings/trackingTemplates/ImportModal.vue`.

## Características

- **Formatos**: `.xlsx` y `.csv`.
- **Parser nativo XLSX** sin gems extra: `unzip` + Nokogiri sobre el XML interno.
  Maneja fechas Excel como **número serial**.
- **CSV** con encoding UTF-8 y fallback ISO-8859-1.
- **Columnas requeridas**: `template_name`, `scheduled_for`, y (`contact_phone` o
  `contact_name`).
- **Crea contactos** si no existen, con los datos del archivo.
- **Normaliza teléfono** a E.164 (ej. `+521...`).
- **Límite** `MAX_IMPORT_ROWS = 50`: si el archivo trae más filas con datos, rechaza
  todo con un error (`inserted: 0`).
- `DEFAULT_MAX_ATTEMPTS = 3` para filas sin valor explícito.

## Salida

`{ inserted: N, skipped: N, errors: [{ row, message }, ...] }`.

## Relación

Cada fila referencia una `tracking_template` por `template_name`, de la que hereda
objetivo/IA/intervalos igual que en [[Bulk-assign]].
