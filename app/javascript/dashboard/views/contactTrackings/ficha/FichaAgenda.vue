<script>
// feat/ficha_agente_ia — LA AGENDA, EN RECURSOS
// ============================================================================
// Pedido del usuario (09/11/2026): Agenda solo en Recursos. Lo que antes vivía en la
// Ficha › Agendas, debajo de las agendas marcadas:
//   · duración de la cita · zona horaria · cómo se presentan los horarios
//   · en qué calendario de cada agenda se aparta (ninguno = el principal)
// v-model: { calendar_event_duration, timezone, slots_presentation, booking_calendar_ids }
// Mismos textos y mismas opciones que la Ficha (TRACKING_TEMPLATES.CALENDARS).
// 10/11/2026 (pedido del usuario, para ahorrar espacio): duración, zona horaria y
// presentación en un renglón; la presentación es una lista como la zona horaria y debajo
// va solo la vista previa de la elegida. Así queda lugar para los calendarios.
// 10/11/2026 (2): «no me convence, el usuario se confunde». Tres pasos numerados, en el
// orden en que se piensan:
//   ┌ 1. ¿En qué calendario se apartan? ─────┐┌ 3. ¿Cómo le muestra los horarios? ┐
//   │ Agenda de Admin · correo               ││ [Detallado ▾]                     │
//   │ ☑ correo (principal) · por omisión     ││ ┌ Así lo verá el cliente ───────┐ │
//   │ ☐ Consultorio Centro                   ││ │ 1️⃣ jue 25 jun · 09:00 …       │ │
//   │ 2. ¿Cuánto dura cada cita? [30][1h][2h]││ └───────────────────────────────┘ │
//   │ Zona horaria [Usar la del canal ▾]     │└───────────────────────────────────┘
//   └────────────────────────────────────────┘
// Sin calendarios marcados se ve el principal palomeado «por omisión» (es el que usa el
// motor), en vez de un aviso aparte que se leía como error.
// ============================================================================
import TrackingTemplatesAPI from 'dashboard/api/trackingTemplates';
import { timeZoneOptions } from 'dashboard/routes/dashboard/settings/inbox/helpers/businessHour';

const DURATIONS = [30, 60, 120];
const PRESENTATIONS = [
  'detailed',
  'by_agent',
  'by_calendar',
  'by_day',
  'simple',
];
// Cómo le llega el mensaje al cliente con cada opción (las mismas que la Ficha › Agendas).
const PREVIEWS = {
  detailed:
    '1️⃣ jue 25 jun · 09:00 – 10:00 (hora de Monterrey) — Ana\n2️⃣ jue 25 jun · 11:00 – 12:00 (hora de Monterrey) — Luis\n3️⃣ vie 26 jun · 10:00 – 11:00 (hora de Monterrey) — Ana',
  by_agent:
    '👤 Ana (hora de Monterrey)\n   1️⃣ jue 25 jun · 09:00 – 10:00\n   2️⃣ vie 26 jun · 10:00 – 11:00\n👤 Luis\n   3️⃣ jue 25 jun · 11:00 – 12:00',
  by_calendar:
    '📅 Citas Norte (hora de Monterrey)\n   1️⃣ jue 25 jun · 09:00 – 10:00\n   2️⃣ jue 25 jun · 11:00 – 12:00\n📅 Citas Sur\n   3️⃣ vie 26 jun · 10:00 – 11:00',
  by_day: '📅 jue 25 jun\n   1️⃣ 09:00   2️⃣ 11:00\n📅 vie 26 jun\n   3️⃣ 10:00',
  simple:
    '1️⃣ jue 25 jun · 09:00 – 10:00\n2️⃣ jue 25 jun · 11:00 – 12:00\n3️⃣ vie 26 jun · 10:00 – 11:00',
};

export default {
  model: { prop: 'value', event: 'input' },
  props: {
    value: { type: Object, default: () => ({}) },
    // Las agendas marcadas (ids de UserCalendarIntegration).
    integrationIds: { type: Array, default: () => [] },
    disabled: { type: Boolean, default: false },
  },
  emits: ['input'],
  data() {
    return {
      integrations: [],
      loading: false,
      durations: DURATIONS,
      presentations: PRESENTATIONS,
      previews: PREVIEWS,
      timeZones: timeZoneOptions(),
    };
  },
  computed: {
    duration() {
      return Number(this.value.calendar_event_duration) || 30;
    },
    presentation() {
      return this.value.slots_presentation || 'detailed';
    },
    selected() {
      const ids = this.integrationIds.map(String);
      return this.integrations.filter(item => ids.includes(String(item.id)));
    },
  },
  mounted() {
    this.loadIntegrations();
  },
  methods: {
    cal(key, args) {
      return this.$t(`TRACKING_TEMPLATES.CALENDARS.${key}`, args);
    },
    async loadIntegrations() {
      this.loading = true;
      try {
        const { data } = await TrackingTemplatesAPI.getCalendarIntegrations();
        this.integrations = data || [];
      } catch (error) {
        this.integrations = [];
      } finally {
        this.loading = false;
      }
    },
    set(campo, valor) {
      if (this.disabled) return;
      this.$emit('input', { ...this.value, [campo]: valor });
    },
    durationLabel(minutos) {
      return minutos < 60
        ? this.$t('TRACKING_TEMPLATES.FICHA.MINUTES', { count: minutos })
        : this.$t('TRACKING_TEMPLATES.FICHA.HOURS', { count: minutos / 60 });
    },
    calendarsOf(integration) {
      return (
        (this.value.booking_calendar_ids || {})[String(integration.id)] || []
      );
    },
    isCalendarOn(integration, calendar) {
      return this.calendarsOf(integration).includes(calendar.id);
    },
    // Ninguno marcado: el motor aparta en el principal (se muestra «por omisión»).
    usesDefault(integration) {
      return !this.calendarsOf(integration).length;
    },
    isDefault(integration, calendar) {
      return !!calendar.primary && this.usesDefault(integration);
    },
    toggleCalendar(integration, calendar) {
      const actuales = this.calendarsOf(integration);
      const lista = actuales.includes(calendar.id)
        ? actuales.filter(id => id !== calendar.id)
        : [...actuales, calendar.id];
      this.set('booking_calendar_ids', {
        ...(this.value.booking_calendar_ids || {}),
        [String(integration.id)]: lista,
      });
    },
  },
};
</script>

<template>
  <div class="grid gap-6 lg:grid-cols-2">
    <!-- Izquierda: dónde y cuánto -->
    <div class="flex flex-col gap-5">
      <section class="flex flex-col gap-2">
        <h4
          class="!m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
        >
          {{ $t('TRACKING_TEMPLATES.FICHA.AGENDA_STEP_CALENDAR') }}
        </h4>
        <p class="!m-0 text-xs text-slate-500">
          {{ $t('TRACKING_TEMPLATES.FICHA.AGENDA_STEP_CALENDAR_HINT') }}
        </p>
        <p v-if="loading" class="!m-0 text-xs text-slate-500">
          {{ cal('LOADING') }}
        </p>
        <div
          v-for="integration in selected"
          :key="integration.id"
          class="flex flex-col gap-1 p-3 border rounded-lg border-slate-200 dark:border-slate-700"
        >
          <span class="flex items-center gap-1.5 mb-1 text-xs text-slate-500">
            <fluent-icon icon="calendar" size="14" />
            {{
              $t('TRACKING_TEMPLATES.FICHA.AGENDA_OF', {
                name: integration.user_name,
              })
            }}
            <span class="truncate">· {{ integration.google_email }}</span>
          </span>
          <p
            v-if="!(integration.calendars || []).length"
            class="!m-0 text-sm text-slate-600 dark:text-slate-300"
          >
            {{ $t('TRACKING_TEMPLATES.FICHA.AGENDA_ONLY_PRIMARY') }}
          </p>
          <label
            v-for="calendar in integration.calendars || []"
            :key="calendar.id"
            class="flex items-center gap-2 !m-0 px-2 py-1.5 text-sm rounded-md cursor-pointer"
            :class="
              isCalendarOn(integration, calendar) ||
              isDefault(integration, calendar)
                ? 'bg-woot-25 dark:bg-woot-900/20'
                : 'hover:bg-slate-50 dark:hover:bg-slate-800'
            "
          >
            <input
              type="checkbox"
              class="!m-0"
              :checked="
                isCalendarOn(integration, calendar) ||
                isDefault(integration, calendar)
              "
              :disabled="disabled"
              @change="toggleCalendar(integration, calendar)"
            />
            <span class="flex-1 min-w-0 truncate">{{ calendar.summary }}</span>
            <span
              v-if="calendar.primary"
              class="px-1.5 py-0.5 text-[11px] rounded bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
            >
              {{ cal('BOOKING_TARGET_PRIMARY') }}
            </span>
            <span
              v-if="isDefault(integration, calendar)"
              class="text-[11px] text-woot-600"
            >
              {{ $t('TRACKING_TEMPLATES.FICHA.AGENDA_DEFAULT') }}
            </span>
          </label>
        </div>
      </section>

      <section class="flex flex-col gap-2">
        <h4
          class="!m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
        >
          {{ $t('TRACKING_TEMPLATES.FICHA.AGENDA_STEP_DURATION') }}
        </h4>
        <div class="flex gap-2">
          <button
            v-for="minutos in durations"
            :key="minutos"
            type="button"
            class="px-3 py-1.5 text-sm border rounded-lg"
            :class="
              duration === minutos
                ? 'border-woot-500 bg-woot-25 text-woot-700 dark:bg-woot-900/20 dark:text-woot-100'
                : 'border-slate-200 text-slate-600 dark:border-slate-700 dark:text-slate-300'
            "
            :disabled="disabled"
            @click="set('calendar_event_duration', minutos)"
          >
            {{ durationLabel(minutos) }}
          </button>
        </div>
        <label class="!m-0 text-sm">
          {{ cal('TIMEZONE') }}
          <select
            class="!mb-0"
            :value="value.timezone || ''"
            :disabled="disabled"
            @change="set('timezone', $event.target.value)"
          >
            <option value="">{{ cal('TIMEZONE_INHERIT') }}</option>
            <option v-for="tz in timeZones" :key="tz.label" :value="tz.value">
              {{ tz.label }}
            </option>
          </select>
        </label>
      </section>
    </div>

    <!-- Derecha: cómo lo ve el cliente -->
    <section class="flex flex-col gap-2">
      <h4 class="!m-0 text-sm font-semibold text-slate-800 dark:text-slate-100">
        {{ $t('TRACKING_TEMPLATES.FICHA.AGENDA_STEP_PRESENTATION') }}
      </h4>
      <select
        class="!mb-0"
        :value="presentation"
        :disabled="disabled"
        @change="set('slots_presentation', $event.target.value)"
      >
        <option v-for="opcion in presentations" :key="opcion" :value="opcion">
          {{ cal(`PRESENTATION.${opcion.toUpperCase()}`) }}
        </option>
      </select>
      <div
        class="flex flex-col gap-1 p-3 rounded-lg bg-slate-50 dark:bg-slate-800/60"
      >
        <span class="text-xs text-slate-500">
          {{ $t('TRACKING_TEMPLATES.FICHA.PRESENTATION_PREVIEW') }}
        </span>
        <span
          class="self-start max-w-full px-3 py-2 font-sans text-xs leading-relaxed whitespace-pre-wrap bg-white rounded-lg rounded-tl-none shadow-sm dark:bg-slate-800 text-slate-700 dark:text-slate-200"
        >
          {{ previews[presentation] }}
        </span>
      </div>
    </section>
  </div>
</template>
