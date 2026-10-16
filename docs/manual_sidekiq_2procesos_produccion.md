# Manual — Separar Sidekiq en 2 procesos (producción)

Rama: `diag/envios_masivos` · Plan: `docs/envios_masivos_escala_plan.md` (§4.2 P1, §5.1 paso 1)
Probado en dev el 16/10/2026 (ver §8). **No cambia código de la app ni la base de datos.**

## Para qué

Hoy producción tiene **un** Sidekiq con 20 hilos para todo. Cada minuto llegan ráfagas de jobs
que esperan red (IMAP de correo, sync de plantillas de WhatsApp, seguimientos) y ocupan los hilos;
mientras tanto lo urgente (mensajes entrantes, ActionCable, eventos) espera en la fila.

```
 ANTES                                   DESPUÉS
 chatwoot-worker.1 · 20 hilos            chatwoot-worker.1 · URGENTE · 10 hilos
   todas las colas                         critical, high, medium, default,
                                           mailers, action_mailbox_routing
                                         chatwoot-worker.2 · LENTO · 10 hilos
                                           low, scheduled_jobs, async_database_migration,
                                           active_storage_analysis, active_storage_purge,
                                           action_mailbox_incineration
```

Costo: **las mismas conexiones que hoy** (20 hilos de Sidekiq en total, solo repartidos en 2
procesos) y +1–2 GB de RAM (hay ~21 GB disponibles).

> **Regla:** los hilos de cada proceso (`-c`) no pueden pasar de `SIDEKIQ_CONCURRENCY` del `.env`
> (en producción, 20): ese valor es el máximo de conexiones a la base de cada proceso. Si después
> hace falta más capacidad en lo urgente, se puede subir el worker.1 a `-c 15` (≈ +5 conexiones,
> ~45 de 100), repitiendo el Paso 2 con ese número.

> La cola `low_priority` (limpieza diaria de seguimientos, `ContactTrackings::CleanupJob`) **no
> se incluye a propósito**: hoy nadie la atiende y tiene jobs acumulados; activarla podría borrar
> mucho de golpe. Se revisa aparte.

---

## Antes de empezar

| Qué | Valor |
|---|---|
| Ventana | Fuera de 9–11 h CST (pico). Mejor por la tarde-noche |
| Duración | ~10 min, más 15 min de observación |
| Impacto | Sidekiq se reinicia: los jobs en curso tienen hasta 25 s para terminar; los que no, **regresan a su cola** (no se pierden). La web **no** se reinicia |
| Necesitas | `sudo` en el servidor y usuario super admin en `https://app.wintook.com/monitoring/sidekiq` |
| Regla del panel | **No presionar ningún botón** (Retry, Delete, Kill, …). Solo mirar |

---

## Paso 0 — Punto de retorno (respaldo) y lectura

Solo copia y lee; no cambia nada.

```bash
sudo bash <<'EOF'
R=/root/respaldo_sidekiq_$(date +%Y%m%d_%H%M); mkdir -p $R
CW=/home/chatwoot/chatwoot        # ← ajustar si la ruta es otra
cp -a /etc/systemd/system/chatwoot* $R/
cp -a $CW/config/sidekiq.yml $R/
echo "RESPALDO EN: $R"; ls -l $R
echo; grep -n ExecStart /etc/systemd/system/chatwoot-worker.1.service
echo; grep -n Wants /etc/systemd/system/chatwoot.target
echo; awk '/:queues:/,/^$/' $CW/config/sidekiq.yml
EOF
```

**Anota la carpeta `RESPALDO EN:`** — es la que usa el retorno (§7).

Revisa antes de seguir (si algo no cuadra, **detente**):
- [ ] `ExecStart` del worker.1 contiene `sidekiq -C config/sidekiq.yml` **y no** tiene ningún `-q`.
- [ ] `Wants=` del target lista `chatwoot-worker.1.service`.
- [ ] Las colas de `sidekiq.yml` son las de la tabla de arriba (critical … action_mailbox_incineration).

---

## Paso 1 — Crear el worker LENTO (chatwoot-worker.2)

Se copia el worker.1 de producción (así conserva su ruta de Ruby y su entorno) y se le agregan las colas.

```bash
sudo cp /etc/systemd/system/chatwoot-worker.1.service /etc/systemd/system/chatwoot-worker.2.service
sudo sed -i 's#sidekiq -C config/sidekiq.yml#sidekiq -C config/sidekiq.yml -c 10 -q low -q scheduled_jobs -q async_database_migration -q active_storage_analysis -q active_storage_purge -q action_mailbox_incineration#' /etc/systemd/system/chatwoot-worker.2.service
grep -n ExecStart /etc/systemd/system/chatwoot-worker.2.service
```
- [ ] La línea termina en `… -c 10 -q low -q scheduled_jobs … -q action_mailbox_incineration'`.

## Paso 2 — Dejar el worker.1 solo con lo URGENTE

```bash
sudo sed -i 's#sidekiq -C config/sidekiq.yml#sidekiq -C config/sidekiq.yml -c 10 -q critical -q high -q medium -q default -q mailers -q action_mailbox_routing#' /etc/systemd/system/chatwoot-worker.1.service
grep -n ExecStart /etc/systemd/system/chatwoot-worker.1.service
```
- [ ] La línea termina en `… -c 10 -q critical … -q action_mailbox_routing'`.

## Paso 3 — Agregar el worker.2 al grupo `chatwoot.target`

Así arranca con el servidor y `cwctl --restart` lo incluye.

```bash
sudo sed -i '/^Wants=/ s/$/ chatwoot-worker.2.service/' /etc/systemd/system/chatwoot.target
grep -n Wants /etc/systemd/system/chatwoot.target
```
- [ ] `Wants=chatwoot-web.1.service chatwoot-worker.1.service chatwoot-worker.2.service`

## Paso 4 — Aplicar

```bash
sudo systemctl daemon-reload
sudo systemctl restart chatwoot-worker.1
sudo systemctl start chatwoot-worker.2
systemctl is-active chatwoot-worker.1 chatwoot-worker.2
```
- [ ] Las dos líneas dicen `active`.

---

## Paso 5 — Verificar (inmediato)

1. Panel `https://app.wintook.com/monitoring/sidekiq` → pestaña **Busy**, sección *Processes*:
   - [ ] Hay **2 procesos**.
   - [ ] Uno con **10 hilos** y colas `critical, high, medium, default, mailers, action_mailbox_routing`.
   - [ ] Otro con **10 hilos** y colas `low, scheduled_jobs, …`.
2. Arranque sin errores:
   ```bash
   journalctl -u chatwoot-worker.1 -n 30 --no-pager
   journalctl -u chatwoot-worker.2 -n 30 --no-pager
   ```
   - [ ] Sin `ERROR` repetidos; se ven líneas `Performed …` en el worker.2 (IMAP, seguimientos) al pasar 1–2 min.
3. Prueba funcional en la web, en una conversación **de prueba**:
   - [ ] Un mensaje entrante aparece en la bandeja.
   - [ ] Un mensaje enviado desde la web sale y cambia a entregado.

## Paso 6 — Observar (15 min y al día siguiente)

- [ ] **Enqueued** baja a 0 después de cada ráfaga (puede subir un momento cada minuto; no debe crecer sin parar).
- [ ] En las ráfagas, el proceso **lento** se llena pero el **urgente sigue con hilos libres**: esa es la mejora.
- [ ] Al día siguiente, en la hora pico (9–11 h), mismo chequeo.

**Regresar (§7) si:** algún servicio no queda `active`; Enqueued crece 10 min seguidos sin bajar;
errores repetidos en el journal; los mensajes no entran o no salen.

---

## Paso 7 — Retorno (si no funciona)

No hay cambios en la base ni en Redis: el regreso es completo y tarda < 1 min. Los jobs encolados
mientras tanto se quedan en Redis y los procesa el worker restaurado.

```bash
R=/root/respaldo_sidekiq_FECHA            # ← la carpeta anotada en el Paso 0
sudo systemctl stop chatwoot-worker.2
sudo rm /etc/systemd/system/chatwoot-worker.2.service
sudo cp -a $R/chatwoot-worker.1.service $R/chatwoot.target /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl restart chatwoot-worker.1
systemctl is-active chatwoot-worker.1
```
- [ ] El panel vuelve a mostrar **1 proceso** con 20 hilos y todas las colas.

---

## Nota — actualizaciones con `cwctl --upgrade`

`cwctl --upgrade` vuelve a copiar `chatwoot-worker.1.service` y `chatwoot.target` desde la carpeta
`deployment/` del repo (`deployment/install.sh`). En esta rama ya están actualizados
(`deployment/chatwoot-worker.1.service`, `deployment/chatwoot-worker.2.service`,
`deployment/chatwoot.target` e `install.sh` copia el worker.2). Mientras ese código **no** llegue a
producción, después de un upgrade hay que **repetir los pasos 2–4** (el worker.2 sigue ahí; el
worker.1 y el target se pisan). Ojo: las plantillas del repo usan la ruta de Ruby estándar
(`ruby-3.3.3` de rvm); si producción usa otra, conservar la de producción.

---

## 8. Prueba en dev (16/10/2026)

En dev Sidekiq corre dentro de `chatwoot-dev.service` (foreman + `Procfile.dev`), así que el
cambio se hizo en `Procfile.dev` con dos líneas (`worker_urgente` y `worker_lento`, **10 hilos
cada uno**; `SIDEKIQ_CONCURRENCY` sin definir en dev = 10, así que cabe justo). Primero se probó con
6 + 4 y luego se dejó en 10 + 10. Punto de retorno: tag `estable-2026-10-16-antes-sidekiq-2procesos`.

| Comprobación | Resultado |
|---|---|
| Procesos tras reiniciar | 2 (`0 of 10`, `0 of 10`) |
| Colas por proceso (`Sidekiq::ProcessSet`) | urgente: critical, high, medium, default, mailers, action_mailbox_routing · lento: low, scheduled_jobs, async_database_migration, active_storage_analysis, active_storage_purge, action_mailbox_incineration |
| Jobs programados en el lento | `ContactTrackingJob` (24), `FetchImapEmailInboxesJob`, `TemplatesSyncSchedulerJob`, `ExecutePendingJob`, `TrackingCampaigns::WindowJob`, … |
| Cron duplicado (los 2 procesos cargan el calendario) | No: cada job del minuto corrió **una** vez |
| Urgente | `ActionCableBroadcastJob` de prueba (sin destinatarios) en `critical` → lo corrió `worker_urgente` |
| Errores | 0 |
| Hallazgo | `low_priority`: **203** jobs de limpieza acumulados que nunca corrieron |

Retorno en dev: `git checkout estable-2026-10-16-antes-sidekiq-2procesos -- Procfile.dev` y
`systemctl restart chatwoot-dev.service`.
