<script>
// feat/ficha_agente_ia — LA AGENDA, EN RECURSOS
// ============================================================================
// Pedido del usuario (09/11/2026): Agenda solo en Recursos. Lo que antes vivía en la
// Ficha › Agendas, debajo de las agendas marcadas:
//   · duración de la cita · zona horaria · cómo se presentan los horarios
//   · en qué calendario de cada agenda se aparta (ninguno = el principal)
// v-model: { calendar_event_duration, timezone, slots_presentation, booking_calendar_ids }
// Mismos textos y mismas opciones que la Ficha (TRACKING_TEMPLATES.CALENDARS).
// ============================================================================
import TrackingTemplatesAPI from 'dashboard/api/trackingTemplates';
import { timeZoneOptions } from 'dashboard/routes/dashboard/settings/inbox/helpers/businessHour';

const DURATIONS = [30, 60, 120];
const PRESENTATIONS = ['detailed', 'by_agent', 'by_calendar', 'simple'];

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
  <div class="flex flex-col gap-4">
    <div class="grid gap-3 sm:grid-cols-2">
      <div class="flex flex-col gap-1">
        <span class="text-sm text-slate-800 dark:text-slate-100">
          {{ cal('EVENT_DURATION') }}
        </span>
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
      </div>
      <label class="!m-0">
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
    </div>

    <div class="flex flex-col gap-1">
      <span class="text-sm text-slate-800 dark:text-slate-100">
        {{ cal('PRESENTATION_LABEL') }}
      </span>
      <div class="flex flex-wrap gap-2">
        <label
          v-for="opcion in presentations"
          :key="opcion"
          class="flex items-center gap-2 !m-0 px-3 py-1.5 text-sm border rounded-lg cursor-pointer"
          :class="
            presentation === opcion
              ? 'border-woot-500 bg-woot-25 dark:bg-woot-900/20'
              : 'border-slate-200 dark:border-slate-700'
          "
        >
          <input
            type="radio"
            class="!m-0"
            :checked="presentation === opcion"
            :disabled="disabled"
            @change="set('slots_presentation', opcion)"
          />
          {{ cal(`PRESENTATION.${opcion.toUpperCase()}`) }}
        </label>
      </div>
    </div>

    <div class="flex flex-col gap-2">
      <span class="text-sm text-slate-800 dark:text-slate-100">
        {{ cal('BOOKING_TARGET_LABEL') }}
      </span>
      <p v-if="loading" class="!m-0 text-xs text-slate-500">
        {{ cal('LOADING') }}
      </p>
      <div
        v-for="integration in selected"
        :key="integration.id"
        class="flex flex-col gap-1 p-2 border rounded-lg border-slate-200 dark:border-slate-700"
      >
        <span class="text-xs font-medium text-slate-700 dark:text-slate-200">
          {{ integration.user_name }} · {{ integration.google_email }}
        </span>
        <p
          v-if="!(integration.calendars || []).length"
          class="!m-0 text-xs text-slate-500"
        >
          {{ cal('BOOKING_TARGET_PRIMARY_FALLBACK') }}
        </p>
        <label
          v-for="calendar in integration.calendars || []"
          :key="calendar.id"
          class="flex items-center gap-2 !m-0 text-sm"
        >
          <input
            type="checkbox"
            class="!m-0"
            :checked="isCalendarOn(integration, calendar)"
            :disabled="disabled"
            @change="toggleCalendar(integration, calendar)"
          />
          {{ calendar.summary }}
          <span v-if="calendar.primary" class="text-xs text-slate-400">
            {{ cal('BOOKING_TARGET_PRIMARY') }}
          </span>
        </label>
        <p
          v-if="
            (integration.calendars || []).length &&
            !calendarsOf(integration).length
          "
          class="!m-0 text-xs text-slate-500"
        >
          {{ cal('BOOKING_TARGET_PRIMARY_FALLBACK') }}
        </p>
      </div>
      <p class="!m-0 text-xs text-slate-500">
        {{ cal('BOOKING_TARGET_HINT') }}
      </p>
    </div>
  </div>
</template>
