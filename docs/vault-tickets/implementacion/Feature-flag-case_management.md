---
titulo: Feature flag case_management (activable por cuenta)
tipo: implementación
tags: [tickets, feature-flag, super-admin]
---

## Feature flag: módulo activable por cuenta (All features)

El Gestor de Tickets es una **feature toggleable por cuenta** desde el super admin (panel "All features"). Off por defecto; el admin la activa por cuenta.

**Nombre de la feature:** `case_management` (consistente con el backend `case_*`).

**Los 4 puntos de registro (todos necesarios):**
1. **`config/features.yml`** — `- name: case_management` / `enabled: false`, **al final del archivo** (ver trampa #11). Esto la hace aparecer automáticamente en el panel "All features" del super admin, porque ese panel itera `account.all_features` que deriva de `FEATURE_LIST`.
2. **`app/javascript/dashboard/featureFlags.js`** — `CASE_MANAGEMENT: 'case_management'`.
3. **`sidebarItems/primaryMenu.js`** — el item `gestorTickets` lleva `featureFlag: FEATURE_FLAGS.CASE_MANAGEMENT`. `Sidebar.vue` (computed `primaryMenuItems`, ~líneas 180-185) solo muestra el icono si `isFeatureEnabledonAccount(accountId, featureFlag)`. **Editar `primaryMenu.js`, no el `.jsx`** (ver trampa #2).
4. **Recargar** — `ConfigLoader.new.process(reconcile_only_new: true)` actualiza el `InstallationConfig` `ACCOUNT_LEVEL_FEATURE_DEFAULTS` (defaults para cuentas nuevas) + `touch tmp/restart.txt` para que el server vivo reconozca el flag.

**Togglear por cuenta:** super admin → cuenta → "All features" → checkbox `case_management`. O por consola: `Account.find(id).enable_features!('case_management')` / `disable_features!`.

**Verificado:** feature ON → icono Tickets visible en sidebar primario; OFF → oculto (probado en browser ambos sentidos, cuenta 2 quedó ON).

**Nota:** el gating es solo de UI (oculta el icono). Las rutas `gestorTickets_*` y los endpoints `/case_*` siguen accesibles por URL directa — igual que el resto de features de Chatwoot (CRM, kanban). Si se requiere bloqueo backend, añadir un `before_action` que valide `Current.account.feature_enabled?('case_management')` en los controllers `case_*`.



## 🔗 Relacionado
- [[Trampas]] (#11 bitfield, #12 boot) · [[Pruebas-en-browser]]
