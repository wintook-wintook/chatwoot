# Pendiente

- [ ] Correr las **3 migraciones** en producción (`db:migrate`).
- [ ] GitHub Project con issues de seguimiento.
- [ ] Completar esta bóveda (las notas marcadas como _stub_).
- [ ] **Soporte para `.docx` subidos a Drive** en fuentes Google Doc. Hoy el sync usa `files/{id}/export?mimeType=text/plain`, que solo funciona con Google Docs **nativos**; un `.docx` (mimeType `...wordprocessingml.document`) falla con "no es un Google Doc de texto exportable". Opciones: (a) auto-convertir con `files.copy` a mimeType `application/vnd.google-apps.document` y exportar la copia; o (b) descargar bytes crudos con `alt=media` y parsear el Word con una gema (`docx`/`caracal`). Detectar por `mimeType` en `GoogleDocsService` y rutear. Detectado con la fuente `trading_doc` (cuenta 2).

Estado general en [[Estado-actual]].
