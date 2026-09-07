<!--
  @tickets_cases F2 — Alta / edición de una reunión del ticket (plan §6.2).

  F2 trajo la reunión ÚNICA; F4 suma el bloque de SERIE (repetición + vista
  previa de las fechas). El plan prefiere «después de N reuniones» (COUNT) sobre
  «termina el DD/MM» (UNTIL): COUNT es literal y esquiva la trampa de la zona
  horaria (§11.3/§11.5). No se permiten series infinitas.
-->
<script>
export default {
  name: 'MeetingFormModal',
  props: {
    show: { type: Boolean, default: false },
    // Reunión existente (edición) o null (alta).
    meeting: { type: Object, default: null },
    // Tareas del ticket, para colgar la reunión de una (opcional).
    tasks: { type: Array, default: () => [] },
    // Agentes con Google Calendar conectado (los que pueden ser organizadores
    // de verdad cuando F3 encienda el espejo).
    organizers: { type: Array, default: () => [] },
    // Correo del contacto del ticket; vacío en tickets internos.
    contactEmail: { type: String, default: '' },
    // Tarea preseleccionada al abrir desde la fila de una tarea.
    contextTask: { type: Object, default: null },
    isSaving: { type: Boolean, default: false },
  },
  data() {
    return {
      form: {
        title: '',
        description: '',
        starts_at: '',
        ends_at: '',
        location: '',
        case_task_id: '',
        organizer_id: '',
        notify_client: true,
        guests: '',
      },
      // F4 — repetición. `single` = reunión suelta (lo de F2).
      mode: 'single',
      series: {
        freq: 'weekly',
        interval: 1,
        by_day: [],
        end_mode: 'count', // 'count' | 'until'
        count: 4,
        until_at: '',
      },
    };
  },
  computed: {
    isEditing() {
      return !!this.meeting;
    },
    modalTitle() {
      return this.isEditing
        ? this.$t('CASE_TICKETS.MEETINGS.MODAL.EDIT_TITLE')
        : this.$t('CASE_TICKETS.MEETINGS.MODAL.TITLE');
    },
    // Sin correo del contacto no se puede invitar al cliente: la casilla se
    // deshabilita con la razón a la vista, pero la reunión se agenda igual.
    canInviteClient() {
      return !!this.contactEmail;
    },
    hasOrganizers() {
      return this.organizers.length > 0;
    },
    isValid() {
      const base =
        !!this.form.title.trim() &&
        !!this.form.starts_at &&
        !!this.form.ends_at &&
        new Date(this.form.ends_at) > new Date(this.form.starts_at);
      if (!base || !this.isSeries) return base;
      // Serie: siempre finita, y con al menos una ocurrencia.
      const finite =
        this.series.end_mode === 'count'
          ? Number(this.series.count) > 0 && Number(this.series.count) <= 100
          : !!this.series.until_at;
      return finite && this.seriesPreview.length > 0;
    },
    isSeries() {
      return this.mode === 'series';
    },
    weekDays() {
      // Orden de la semana laboral primero, como el mockup del plan.
      return [
        { code: 'MO', label: this.$t('CASE_TICKETS.MEETINGS.MODAL.DAYS.MO') },
        { code: 'TU', label: this.$t('CASE_TICKETS.MEETINGS.MODAL.DAYS.TU') },
        { code: 'WE', label: this.$t('CASE_TICKETS.MEETINGS.MODAL.DAYS.WE') },
        { code: 'TH', label: this.$t('CASE_TICKETS.MEETINGS.MODAL.DAYS.TH') },
        { code: 'FR', label: this.$t('CASE_TICKETS.MEETINGS.MODAL.DAYS.FR') },
        { code: 'SA', label: this.$t('CASE_TICKETS.MEETINGS.MODAL.DAYS.SA') },
        { code: 'SU', label: this.$t('CASE_TICKETS.MEETINGS.MODAL.DAYS.SU') },
      ];
    },
    // Vista previa de las fechas que se van a crear. Es el mismo cálculo que hace
    // el backend en `RRuleBuilder#expand`, para que el agente vea lo que compra
    // antes de confirmar.
    seriesPreview() {
      if (!this.isSeries || !this.form.starts_at) return [];
      const start = new Date(this.form.starts_at);
      if (Number.isNaN(start.getTime())) return [];
      const wanted =
        this.series.end_mode === 'count'
          ? Math.min(Number(this.series.count) || 0, 100)
          : 100;
      const until =
        this.series.end_mode === 'until' && this.series.until_at
          ? new Date(this.series.until_at)
          : null;
      const days = this.series.by_day.length
        ? this.series.by_day
        : [['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'][start.getDay()]];
      const step = Math.max(1, Number(this.series.interval) || 1);
      const out = [];
      const cursor = new Date(start);
      let guard = 0;
      while (out.length < wanted && guard < 500) {
        guard += 1;
        if (until && cursor > until) break;
        const code = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'][
          cursor.getDay()
        ];
        if (this.series.freq !== 'weekly' || days.includes(code)) {
          out.push(new Date(cursor));
        }
        if (this.series.freq === 'daily')
          cursor.setDate(cursor.getDate() + step);
        else if (this.series.freq === 'monthly')
          cursor.setMonth(cursor.getMonth() + step);
        else {
          cursor.setDate(cursor.getDate() + 1);
          if (cursor.getDay() === 0 && step > 1) {
            cursor.setDate(cursor.getDate() + (step - 1) * 7);
          }
        }
      }
      return out;
    },
    previewLabel() {
      const dates = this.seriesPreview
        .slice(0, 6)
        .map(d =>
          d.toLocaleDateString(undefined, { day: '2-digit', month: 'short' })
        );
      const more = this.seriesPreview.length > 6 ? '…' : '';
      return `${dates.join(', ')}${more}`;
    },
    // Aviso de fechas al revés, para no depender solo del 422 del backend.
    dateError() {
      if (!this.form.starts_at || !this.form.ends_at) return '';
      return new Date(this.form.ends_at) > new Date(this.form.starts_at)
        ? ''
        : this.$t('CASE_TICKETS.MEETINGS.MODAL.DATE_ERROR');
    },
  },
  watch: {
    show: {
      immediate: true,
      handler(open) {
        if (open) this.reset();
      },
    },
  },
  methods: {
    reset() {
      const m = this.meeting;
      // Editar siempre es de una reunión concreta: el bloque de serie no aplica.
      this.mode = 'single';
      this.form = {
        title: m?.title || '',
        description: m?.description || '',
        starts_at: this.toLocalInput(m?.starts_at) || this.defaultStart(),
        ends_at: this.toLocalInput(m?.ends_at) || this.defaultEnd(),
        location: m?.location || '',
        case_task_id: m?.case_task?.id || this.contextTask?.id || '',
        organizer_id: m?.organizer?.id || '',
        // Sin correo del contacto la casilla va deshabilitada: dejarla marcada
        // prometía un aviso al cliente que nunca iba a salir.
        notify_client: m ? m.notify_client : !!this.contactEmail,
        guests: (m?.attendee_emails || []).join(', '),
      };
    },
    // Mañana a las 10:00 como valor por defecto: agendar es casi siempre a futuro.
    defaultStart() {
      const d = new Date();
      d.setDate(d.getDate() + 1);
      d.setHours(10, 0, 0, 0);
      return this.toLocalInput(d);
    },
    defaultEnd() {
      const d = new Date();
      d.setDate(d.getDate() + 1);
      d.setHours(11, 0, 0, 0);
      return this.toLocalInput(d);
    },
    // Date/ISO → valor de <input type="datetime-local"> en hora LOCAL del agente
    // (el backend guarda UTC; aquí solo se pinta lo que el agente ve).
    toLocalInput(value) {
      if (!value) return '';
      const d = new Date(value);
      if (Number.isNaN(d.getTime())) return '';
      const pad = n => String(n).padStart(2, '0');
      return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(
        d.getDate()
      )}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
    },
    taskFolio(n) {
      if (!n) return '';
      return `T${String(n).padStart(3, '0')}`;
    },
    taskLabel(task) {
      return `${this.taskFolio(task.sequence)} — ${task.title}`;
    },
    // Correos escritos a mano, separados por coma o espacio.
    parsedGuests() {
      return this.form.guests
        .split(/[,\s]+/)
        .map(e => e.trim())
        .filter(Boolean);
    },
    toggleDay(code) {
      const i = this.series.by_day.indexOf(code);
      if (i === -1) this.series.by_day.push(code);
      else this.series.by_day.splice(i, 1);
    },
    submit() {
      if (!this.isValid || this.isSaving) return;
      if (this.isSeries) {
        this.$emit('submitSeries', this.seriesPayload());
        return;
      }
      const attendees = this.parsedGuests();
      if (this.form.notify_client && this.contactEmail) {
        attendees.unshift(this.contactEmail);
      }
      this.$emit('submit', {
        title: this.form.title.trim(),
        description: this.form.description,
        // El input entrega hora local; se manda en ISO (UTC) para que el
        // backend no tenga que adivinar la zona.
        starts_at: new Date(this.form.starts_at).toISOString(),
        ends_at: new Date(this.form.ends_at).toISOString(),
        location: this.form.location,
        case_task_id: this.form.case_task_id || null,
        organizer_id: this.form.organizer_id || null,
        notify_client: this.form.notify_client,
        attendee_emails: [...new Set(attendees)],
        // Zona horaria del navegador del agente: se guarda para no re-interpretar
        // los históricos si luego cambia (plan §8.6).
        time_zone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      });
    },
    // La serie guarda las piezas del RRULE; el backend arma la cadena y crea las
    // ocurrencias. `until_at` y `count` son excluyentes: nunca van los dos.
    seriesPayload() {
      return {
        title: this.form.title.trim(),
        description: this.form.description,
        starts_at: new Date(this.form.starts_at).toISOString(),
        ends_at: new Date(this.form.ends_at).toISOString(),
        case_task_id: this.form.case_task_id || null,
        organizer_id: this.form.organizer_id || null,
        freq: this.series.freq,
        interval: Number(this.series.interval) || 1,
        by_day: this.series.by_day,
        count:
          this.series.end_mode === 'count' ? Number(this.series.count) : null,
        until_at:
          this.series.end_mode === 'until' && this.series.until_at
            ? new Date(this.series.until_at).toISOString()
            : null,
        time_zone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      };
    },
  },
};
</script>

<template>
  <woot-modal
    :show="show"
    :on-close="() => $emit('close')"
    :close-on-backdrop-click="false"
    size="medium"
  >
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="modalTitle"
        :header-content="$t('CASE_TICKETS.MEETINGS.MODAL.DESC')"
      />

      <form
        class="flex flex-col self-stretch w-full gap-3 pb-8"
        @submit.prevent="submit"
      >
        <label class="block">
          <span class="text-sm text-slate-700 dark:text-slate-200">{{
            $t('CASE_TICKETS.MEETINGS.MODAL.TITLE_LABEL')
          }}</span>
          <input
            v-model="form.title"
            type="text"
            :placeholder="$t('CASE_TICKETS.MEETINGS.MODAL.TITLE_PLACEHOLDER')"
          />
        </label>

        <div class="flex gap-3">
          <label class="flex-1">
            <span class="text-sm text-slate-700 dark:text-slate-200">{{
              $t('CASE_TICKETS.MEETINGS.MODAL.STARTS_LABEL')
            }}</span>
            <input
              v-model="form.starts_at"
              type="datetime-local"
              class="w-full h-10 p-2 bg-white border rounded-md border-slate-200 dark:border-slate-600 dark:bg-slate-900 text-slate-800 dark:text-slate-100"
            />
          </label>
          <label class="flex-1">
            <span class="text-sm text-slate-700 dark:text-slate-200">{{
              $t('CASE_TICKETS.MEETINGS.MODAL.ENDS_LABEL')
            }}</span>
            <input
              v-model="form.ends_at"
              type="datetime-local"
              class="w-full h-10 p-2 bg-white border rounded-md border-slate-200 dark:border-slate-600 dark:bg-slate-900 text-slate-800 dark:text-slate-100"
            />
          </label>
        </div>
        <p v-if="dateError" class="m-0 text-xs text-red-600 dark:text-red-400">
          {{ dateError }}
        </p>

        <div class="flex gap-3">
          <label class="flex-1">
            <span class="text-sm text-slate-700 dark:text-slate-200">{{
              $t('CASE_TICKETS.MEETINGS.MODAL.TASK_LABEL')
            }}</span>
            <select v-model="form.case_task_id">
              <option value="">
                {{ $t('CASE_TICKETS.MEETINGS.MODAL.TASK_NONE') }}
              </option>
              <option v-for="t in tasks" :key="t.id" :value="t.id">
                {{ taskLabel(t) }}
              </option>
            </select>
          </label>

          <label class="flex-1">
            <span class="text-sm text-slate-700 dark:text-slate-200">{{
              $t('CASE_TICKETS.MEETINGS.MODAL.ORGANIZER_LABEL')
            }}</span>
            <select v-model="form.organizer_id">
              <option value="">
                {{ $t('CASE_TICKETS.MEETINGS.MODAL.ORGANIZER_ME') }}
              </option>
              <option v-for="o in organizers" :key="o.id" :value="o.id">
                {{ o.name }}
              </option>
            </select>
          </label>
        </div>

        <!-- F4 — reunión única o serie. Editar una reunión concreta no muestra
             esto: la repetición se toca en la serie, no en una ocurrencia. -->
        <div v-if="!isEditing" class="flex flex-col gap-2">
          <div class="flex items-center gap-4">
            <label class="flex items-center gap-2 m-0">
              <input v-model="mode" type="radio" value="single" class="m-0" />
              <span class="text-sm text-slate-700 dark:text-slate-200">{{
                $t('CASE_TICKETS.MEETINGS.MODAL.MODE_SINGLE')
              }}</span>
            </label>
            <label class="flex items-center gap-2 m-0">
              <input v-model="mode" type="radio" value="series" class="m-0" />
              <span class="text-sm text-slate-700 dark:text-slate-200">{{
                $t('CASE_TICKETS.MEETINGS.MODAL.MODE_SERIES')
              }}</span>
            </label>
          </div>

          <div
            v-if="isSeries"
            class="flex flex-col gap-3 p-3 border rounded-md border-slate-100 dark:border-slate-600 bg-slate-25 dark:bg-slate-900/40"
          >
            <div class="flex items-end gap-2">
              <label class="m-0">
                <span class="text-sm text-slate-700 dark:text-slate-200">{{
                  $t('CASE_TICKETS.MEETINGS.MODAL.REPEAT_EVERY')
                }}</span>
                <input
                  v-model="series.interval"
                  type="number"
                  min="1"
                  max="52"
                  class="w-20"
                />
              </label>
              <select v-model="series.freq" class="w-40">
                <option value="daily">
                  {{ $t('CASE_TICKETS.MEETINGS.MODAL.FREQ.DAILY') }}
                </option>
                <option value="weekly">
                  {{ $t('CASE_TICKETS.MEETINGS.MODAL.FREQ.WEEKLY') }}
                </option>
                <option value="monthly">
                  {{ $t('CASE_TICKETS.MEETINGS.MODAL.FREQ.MONTHLY') }}
                </option>
              </select>
            </div>

            <div v-if="series.freq === 'weekly'">
              <span class="text-sm text-slate-700 dark:text-slate-200">{{
                $t('CASE_TICKETS.MEETINGS.MODAL.DAYS_LABEL')
              }}</span>
              <div class="flex flex-wrap gap-1 mt-1">
                <button
                  v-for="d in weekDays"
                  :key="d.code"
                  type="button"
                  class="px-2 py-1 text-xs font-medium border rounded"
                  :class="
                    series.by_day.includes(d.code)
                      ? 'bg-woot-500 text-white border-woot-500'
                      : 'border-slate-200 dark:border-slate-600 text-slate-600 dark:text-slate-300'
                  "
                  @click="toggleDay(d.code)"
                >
                  {{ d.label }}
                </button>
              </div>
            </div>

            <div class="flex flex-wrap items-center gap-4">
              <label class="flex items-center gap-2 m-0">
                <input
                  v-model="series.end_mode"
                  type="radio"
                  value="count"
                  class="m-0"
                />
                <span class="text-sm text-slate-700 dark:text-slate-200">{{
                  $t('CASE_TICKETS.MEETINGS.MODAL.END_AFTER')
                }}</span>
                <input
                  v-model="series.count"
                  type="number"
                  min="1"
                  max="100"
                  class="w-20 m-0"
                  :disabled="series.end_mode !== 'count'"
                />
              </label>
              <label class="flex items-center gap-2 m-0">
                <input
                  v-model="series.end_mode"
                  type="radio"
                  value="until"
                  class="m-0"
                />
                <span class="text-sm text-slate-700 dark:text-slate-200">{{
                  $t('CASE_TICKETS.MEETINGS.MODAL.END_ON')
                }}</span>
                <input
                  v-model="series.until_at"
                  type="date"
                  class="m-0"
                  :disabled="series.end_mode !== 'until'"
                />
              </label>
            </div>

            <!-- Vista previa: lo que se va a crear, antes de confirmar. -->
            <p class="m-0 text-xs text-slate-500 dark:text-slate-400">
              {{
                $t('CASE_TICKETS.MEETINGS.MODAL.PREVIEW', {
                  count: seriesPreview.length,
                  dates: previewLabel,
                })
              }}
            </p>
          </div>
        </div>

        <label class="block">
          <span class="text-sm text-slate-700 dark:text-slate-200">{{
            $t('CASE_TICKETS.MEETINGS.MODAL.LOCATION_LABEL')
          }}</span>
          <input
            v-model="form.location"
            type="text"
            :placeholder="
              $t('CASE_TICKETS.MEETINGS.MODAL.LOCATION_PLACEHOLDER')
            "
          />
        </label>

        <label class="block">
          <span class="text-sm text-slate-700 dark:text-slate-200">{{
            $t('CASE_TICKETS.MEETINGS.MODAL.DESCRIPTION_LABEL')
          }}</span>
          <textarea
            v-model="form.description"
            rows="3"
            :placeholder="
              $t('CASE_TICKETS.MEETINGS.MODAL.DESCRIPTION_PLACEHOLDER')
            "
          />
        </label>

        <!-- Invitados: el cliente (si el ticket tiene contacto con correo) y
             quien se agregue a mano. Hoy es un registro de a quién se invitó;
             el correo lo manda Google cuando F3 espeje el evento. -->
        <div class="flex flex-col gap-2">
          <label class="flex items-center gap-2 m-0">
            <input
              v-model="form.notify_client"
              type="checkbox"
              :disabled="!canInviteClient"
              class="m-0"
            />
            <span class="text-sm text-slate-700 dark:text-slate-200">
              {{ $t('CASE_TICKETS.MEETINGS.MODAL.INVITE_CLIENT') }}
            </span>
            <span
              v-if="canInviteClient"
              class="text-sm text-slate-500 dark:text-slate-400"
              >{{ contactEmail }}</span
            >
            <span v-else class="text-xs text-slate-400 dark:text-slate-500">{{
              $t('CASE_TICKETS.MEETINGS.MODAL.NO_CLIENT_EMAIL')
            }}</span>
          </label>

          <label class="block">
            <span class="text-sm text-slate-700 dark:text-slate-200">{{
              $t('CASE_TICKETS.MEETINGS.MODAL.GUESTS_LABEL')
            }}</span>
            <input
              v-model="form.guests"
              type="text"
              :placeholder="
                $t('CASE_TICKETS.MEETINGS.MODAL.GUESTS_PLACEHOLDER')
              "
            />
          </label>
        </div>

        <p
          v-if="!hasOrganizers"
          class="flex items-center gap-1 m-0 text-xs text-amber-700 dark:text-amber-300"
        >
          <fluent-icon icon="info" size="14" />
          {{ $t('CASE_TICKETS.MEETINGS.MODAL.LOCAL_ONLY_HINT') }}
        </p>

        <div class="flex items-center justify-end gap-2">
          <woot-button variant="clear" type="button" @click="$emit('close')">
            {{ $t('CASE_TICKETS.MEETINGS.MODAL.CANCEL') }}
          </woot-button>
          <woot-button
            :is-loading="isSaving"
            :disabled="!isValid"
            type="submit"
          >
            {{
              isEditing
                ? $t('CASE_TICKETS.MEETINGS.MODAL.SAVE')
                : $t('CASE_TICKETS.MEETINGS.MODAL.CREATE')
            }}
          </woot-button>
        </div>
      </form>
    </div>
  </woot-modal>
</template>
