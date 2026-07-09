<template>
  <div class="w-72 border-l border-slate-100 dark:border-slate-700 flex flex-col h-full overflow-hidden">
    <!-- Acordeón: solo una sección abierta a la vez. Por defecto, 'Próximos eventos'. -->

    <!-- Próximos eventos -->
    <section
      class="flex flex-col min-h-0 border-b border-slate-100 dark:border-slate-700"
      :class="{ 'flex-1': openSection === 'upcoming' }"
    >
      <button
        class="w-full flex items-center justify-between px-4 py-3 hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors"
        @click="toggleSection('upcoming')"
      >
        <h3 class="text-sm font-semibold text-slate-700 dark:text-slate-200">
          {{ $t('GOOGLE_CALENDAR.AGENDA.TITLE') }}
        </h3>
        <fluent-icon
          :icon="openSection === 'upcoming' ? 'chevron-up' : 'chevron-down'"
          size="14"
          class="text-slate-400"
        />
      </button>

      <div
        v-if="openSection === 'upcoming'"
        class="flex-1 overflow-y-auto px-3 pb-3 space-y-2"
      >
        <template v-if="upcomingEvents.length">
          <div
            v-for="event in upcomingEvents"
            :key="event.id"
            class="rounded-lg bg-slate-50 dark:bg-slate-800 p-3 border-l-4"
            :style="{ borderColor: calendarColor(event.calendarId) }"
          >
            <p class="text-xs font-semibold text-slate-800 dark:text-slate-100 truncate">
              {{ event.summary || $t('GOOGLE_CALENDAR.EVENTS.ALL_DAY') }}
            </p>
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
              {{ formatEventTime(event) }}
            </p>
          </div>
        </template>
        <p v-else class="text-xs text-slate-400 text-center py-4">
          {{ $t('GOOGLE_CALENDAR.AGENDA.EMPTY') }}
        </p>
      </div>
    </section>

    <!-- Mis calendarios -->
    <section
      v-if="calendars.length"
      class="flex flex-col min-h-0 border-b border-slate-100 dark:border-slate-700"
      :class="{ 'flex-1': openSection === 'calendars' }"
    >
      <button
        class="w-full flex items-center justify-between px-4 py-3 hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors"
        @click="toggleSection('calendars')"
      >
        <h3 class="text-sm font-semibold text-slate-700 dark:text-slate-200">
          {{ $t('GOOGLE_CALENDAR.CALENDARS.TITLE') }}
        </h3>
        <fluent-icon
          :icon="openSection === 'calendars' ? 'chevron-up' : 'chevron-down'"
          size="14"
          class="text-slate-400"
        />
      </button>

      <div
        v-if="openSection === 'calendars'"
        class="flex-1 overflow-y-auto px-3 pb-4 space-y-1"
      >
        <!-- Árbol por cuenta: el primario de cada cuenta con sus secundarios anidados -->
        <div v-for="acct in calendarTree" :key="acct.key" class="select-none">
          <button
            class="w-full flex items-center gap-1 px-1 py-1 rounded-md hover:bg-slate-50 dark:hover:bg-slate-800/60 transition-colors"
            @click="toggleAccount(acct.key)"
          >
            <fluent-icon
              :icon="isAccountOpen(acct.key) ? 'chevron-down' : 'chevron-right'"
              size="12"
              class="text-slate-400 flex-shrink-0"
            />
            <fluent-icon icon="person" size="13" class="text-slate-400 flex-shrink-0" />
            <span class="text-xs font-medium text-slate-600 dark:text-slate-300 truncate">
              {{ acct.label }}
            </span>
            <span
              v-if="acct.kind === 'external'"
              class="text-[10px] text-slate-400 dark:text-slate-500 flex-shrink-0"
            >
              ({{ $t('GOOGLE_CALENDAR.CALENDARS.SUBSCRIBED') }})
            </span>
          </button>

          <div v-if="isAccountOpen(acct.key)" class="pl-5 mt-0.5 space-y-1">
            <div
              v-for="cal in acct.calendars"
              :key="cal.id"
              class="flex items-center gap-2 py-0.5 group/cal"
            >
              <label class="flex items-center gap-2 cursor-pointer flex-1 min-w-0">
                <span
                  class="w-3 h-3 rounded-sm flex-shrink-0 border-2 transition-all"
                  :style="cal.enabled
                    ? { backgroundColor: cal.background_color, borderColor: cal.background_color }
                    : { borderColor: cal.background_color, backgroundColor: 'transparent' }"
                />
                <input
                  type="checkbox"
                  class="sr-only"
                  :checked="cal.enabled"
                  @change="$emit('toggleCalendar', cal.id)"
                />
                <span
                  class="text-xs text-slate-600 dark:text-slate-300 truncate"
                  :class="{ 'line-through opacity-50': !cal.enabled }"
                >
                  {{ cal.summary }}
                </span>
                <span
                  v-if="cal.primary"
                  class="text-[10px] text-woot-500 flex-shrink-0"
                >
                  ({{ $t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.CALENDAR_PRIMARY') }})
                </span>
              </label>
              <button
                v-if="canEditCalendar(cal)"
                type="button"
                class="opacity-0 group-hover/cal:opacity-100 focus:opacity-100 text-slate-400 hover:text-woot-500 transition-opacity flex-shrink-0"
                :title="$t('GOOGLE_CALENDAR.CALENDARS.EDIT_MODAL_TITLE')"
                @click.stop.prevent="openEditModal(cal)"
              >
                <fluent-icon icon="settings" size="13" />
              </button>
            </div>
          </div>
        </div>

        <!-- Agregar otro calendario (abre modal) -->
        <button
          class="flex items-center gap-1 text-xs text-slate-400 hover:text-woot-500 mt-2 pl-1 transition-colors"
          @click="openSubscribeModal"
        >
          <fluent-icon icon="add" size="12" />
          {{ $t('GOOGLE_CALENDAR.CALENDARS.SUBSCRIBE_BUTTON') }}
        </button>
      </div>
    </section>

    <!-- Disponibilidad del equipo -->
    <section
      v-if="agents.length"
      class="flex flex-col min-h-0 border-b border-slate-100 dark:border-slate-700"
      :class="{ 'flex-1': openSection === 'availability' }"
    >
      <button
        class="w-full flex items-center justify-between px-4 py-3 hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors"
        @click="toggleSection('availability')"
      >
        <h3 class="text-sm font-semibold text-slate-700 dark:text-slate-200">
          {{ $t('GOOGLE_CALENDAR.AVAILABILITY.TITLE') }}
        </h3>
        <fluent-icon
          :icon="openSection === 'availability' ? 'chevron-up' : 'chevron-down'"
          size="14"
          class="text-slate-400"
        />
      </button>

      <div
        v-if="openSection === 'availability'"
        class="flex-1 overflow-y-auto px-4 pb-4 space-y-2"
      >
        <div
          v-for="agent in agentsWithStatus"
          :key="agent.id"
          class="flex items-center gap-2"
        >
          <span
            class="w-2 h-2 rounded-full flex-shrink-0"
            :class="{
              'bg-green-400': agent.calendarStatus === 'free',
              'bg-ruby-400': agent.calendarStatus === 'busy',
              'bg-slate-300 dark:bg-slate-600': agent.calendarStatus === 'not_connected',
            }"
          />
          <img
            v-if="agent.thumbnail"
            :src="agent.thumbnail"
            class="w-5 h-5 rounded-full flex-shrink-0 object-cover"
            :alt="agent.name"
          />
          <span class="text-xs text-slate-600 dark:text-slate-300 truncate flex-1">
            {{ agent.name }}
          </span>
          <span
            v-if="agent.calendarStatus === 'not_connected'"
            class="text-xs text-slate-400 dark:text-slate-500 flex-shrink-0"
          >
            {{ $t('GOOGLE_CALENDAR.AVAILABILITY.NOT_CONNECTED') }}
          </span>
          <span
            v-else-if="agent.calendarStatus === 'busy'"
            class="text-xs text-ruby-500 flex-shrink-0"
          >
            {{ $t('GOOGLE_CALENDAR.AVAILABILITY.BUSY') }}
          </span>
        </div>
      </div>
    </section>

    <!-- Modal: agregar / suscribir otro calendario -->
    <woot-modal
      :show="showSubscribeModal"
      :on-close="closeSubscribeModal"
      size="small"
    >
      <woot-modal-header
        :header-title="modalTitle"
        :header-content="subscribeHint"
      />
      <div class="px-8 pb-8 pt-2">
        <!-- Modo (solo al agregar): crear un secundario nuevo o suscribir uno existente -->
        <div
          v-if="!isEditing"
          class="flex gap-1 p-1 bg-slate-100 dark:bg-slate-800 rounded-lg mb-4"
        >
          <button
            type="button"
            class="flex-1 text-xs font-medium py-1.5 rounded-md transition-colors"
            :class="subscribeMode === 'create'
              ? 'bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 shadow-sm'
              : 'text-slate-500 dark:text-slate-400'"
            @click="subscribeMode = 'create'"
          >
            {{ $t('GOOGLE_CALENDAR.CALENDARS.MODE_CREATE') }}
          </button>
          <button
            type="button"
            class="flex-1 text-xs font-medium py-1.5 rounded-md transition-colors"
            :class="subscribeMode === 'subscribe'
              ? 'bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 shadow-sm'
              : 'text-slate-500 dark:text-slate-400'"
            @click="subscribeMode = 'subscribe'"
          >
            {{ $t('GOOGLE_CALENDAR.CALENDARS.MODE_SUBSCRIBE') }}
          </button>
        </div>

        <!-- Suscribir uno existente: solo email / ID -->
        <input
          v-if="!showCalendarForm"
          v-model="subscribeInput"
          type="text"
          class="w-full text-sm px-3 py-2 border border-slate-200 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 outline-none focus:border-woot-400"
          :placeholder="$t('GOOGLE_CALENDAR.CALENDARS.SUBSCRIBE_PLACEHOLDER')"
          @keydown.enter="submitCalendar"
          @keydown.esc="closeSubscribeModal"
        />

        <!-- Crear / editar un calendario propio: nombre, descripción, zona y color -->
        <div v-else class="space-y-3">
          <div>
            <label class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1">
              {{ $t('GOOGLE_CALENDAR.CALENDARS.FIELD_NAME') }}
            </label>
            <input
              v-model="calForm.summary"
              type="text"
              class="w-full text-sm px-3 py-2 border border-slate-200 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 outline-none focus:border-woot-400"
              :placeholder="$t('GOOGLE_CALENDAR.CALENDARS.CREATE_PLACEHOLDER')"
              @keydown.enter="submitCalendar"
            />
          </div>
          <div>
            <label class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1">
              {{ $t('GOOGLE_CALENDAR.CALENDARS.FIELD_DESCRIPTION') }}
            </label>
            <textarea
              v-model="calForm.description"
              rows="2"
              class="w-full text-sm px-3 py-2 border border-slate-200 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 outline-none focus:border-woot-400 resize-none"
              :placeholder="$t('GOOGLE_CALENDAR.CALENDARS.FIELD_DESCRIPTION_PLACEHOLDER')"
            />
          </div>
          <div>
            <label class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1">
              {{ $t('GOOGLE_CALENDAR.CALENDARS.FIELD_TIMEZONE') }}
            </label>
            <select
              v-model="calForm.timeZone"
              class="w-full text-sm px-3 py-2 border border-slate-200 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 outline-none focus:border-woot-400"
            >
              <option value="">
                {{ $t('GOOGLE_CALENDAR.CALENDARS.FIELD_TIMEZONE_DEFAULT') }}
              </option>
              <option v-for="tz in timeZones" :key="tz.value" :value="tz.value">
                {{ tz.label }}
              </option>
            </select>
          </div>
          <div>
            <label class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1.5">
              {{ $t('GOOGLE_CALENDAR.CALENDARS.FIELD_COLOR') }}
            </label>
            <div class="flex flex-wrap gap-2">
              <button
                v-for="c in calendarColors"
                :key="c"
                type="button"
                class="w-6 h-6 rounded-full border-2 transition-transform hover:scale-110"
                :style="{
                  backgroundColor: c,
                  borderColor: calForm.backgroundColor === c ? '#1d1d1d' : c,
                }"
                @click="calForm.backgroundColor = c"
              />
            </div>
          </div>
        </div>

        <p v-if="subscribeError" class="text-xs text-red-500 mt-2">
          {{ subscribeError }}
        </p>
        <div class="flex justify-end gap-2 mt-5">
          <woot-button variant="clear" size="small" @click="closeSubscribeModal">
            {{ $t('GOOGLE_CALENDAR.CREATE_EVENT.CANCEL') }}
          </woot-button>
          <woot-button
            size="small"
            :is-loading="subscribing"
            :disabled="submitDisabled"
            @click="submitCalendar"
          >
            {{ submitLabel }}
          </woot-button>
        </div>
      </div>
    </woot-modal>
  </div>
</template>

<script>
import { format, isToday, isTomorrow, parseISO } from 'date-fns';
import { timeZoneOptions } from 'dashboard/routes/dashboard/settings/inbox/helpers/businessHour';

// Paleta de colores para calendarios (estilo Google). Se envía el hex al backend.
const CALENDAR_COLORS = [
  '#6366f1', '#0ea5e9', '#10b981', '#f59e0b', '#ef4444',
  '#8b5cf6', '#ec4899', '#14b8a6', '#64748b', '#f97316',
];

export default {
  name: 'AgendaWidget',
  props: {
    events: { type: Array, default: () => [] },
    calendars: { type: Array, default: () => [] },
    availability: { type: Array, default: () => [] },
    agents: { type: Array, default: () => [] },
  },
  emits: ['toggleCalendar'],
  data() {
    return {
      // Acordeón del panel lateral: 'upcoming' | 'calendars' | 'availability' | null.
      openSection: 'upcoming',
      // Árbol 'Mis calendarios': { [accountKey]: false } para las cuentas colapsadas
      // (por defecto todas abiertas).
      expandedAccounts: {},
      showSubscribeModal: false,
      // Modo del modal 'Agregar otro calendario': 'create' (secundario nuevo) | 'subscribe'.
      subscribeMode: 'create',
      subscribeInput: '',
      subscribeError: '',
      subscribing: false,
      // Edición: id del calendario que se está editando (null = alta).
      editingCalendarId: null,
      // Formulario de crear/editar un calendario propio.
      calForm: { summary: '', description: '', timeZone: '', backgroundColor: CALENDAR_COLORS[0] },
      calendarColors: CALENDAR_COLORS,
    };
  },
  computed: {
    timeZones() {
      return timeZoneOptions();
    },
    isEditing() {
      return !!this.editingCalendarId;
    },
    // El formulario de crear/editar (nombre, descripción, zona, color) se usa al editar
    // y al crear; el input por email/ID solo al suscribir uno existente.
    showCalendarForm() {
      return this.isEditing || this.subscribeMode === 'create';
    },
    modalTitle() {
      return this.isEditing
        ? this.$t('GOOGLE_CALENDAR.CALENDARS.EDIT_MODAL_TITLE')
        : this.$t('GOOGLE_CALENDAR.CALENDARS.SUBSCRIBE_MODAL_TITLE');
    },
    // Texto de ayuda del modal según el modo (editar / crear / suscribir).
    subscribeHint() {
      if (this.isEditing) return this.$t('GOOGLE_CALENDAR.CALENDARS.EDIT_HINT');
      return this.subscribeMode === 'create'
        ? this.$t('GOOGLE_CALENDAR.CALENDARS.CREATE_HINT')
        : this.$t('GOOGLE_CALENDAR.CALENDARS.SUBSCRIBE_MODAL_SUBTITLE');
    },
    submitLabel() {
      if (this.isEditing) return this.$t('GOOGLE_CALENDAR.CALENDARS.SAVE');
      return this.subscribeMode === 'create'
        ? this.$t('GOOGLE_CALENDAR.CALENDARS.CREATE_ADD')
        : this.$t('GOOGLE_CALENDAR.CALENDARS.SUBSCRIBE_ADD');
    },
    submitDisabled() {
      if (this.subscribing) return true;
      return this.showCalendarForm
        ? !this.calForm.summary.trim()
        : !this.subscribeInput.trim();
    },
    // Agrupa la lista plana de calendarios en un árbol por cuenta (Opción "Por cuenta").
    // Raíz = cuenta conectada (su primario) con sus calendarios propios y suscripciones
    // no-personales (feriados, etc.) anidados. Cada calendario personal ajeno (email
    // distinto, compartido) forma su propia cuenta raíz. La conectada va siempre primero.
    calendarTree() {
      const connected = (this.calendars.find(c => c.primary) || {}).id || null;
      const isPersonalEmail = id =>
        typeof id === 'string' &&
        /^[^@\s]+@[^@\s]+$/.test(id) &&
        !id.includes('group.') &&
        !id.includes('#');

      const accounts = new Map();
      const ensure = (key, label, kind) => {
        if (!accounts.has(key)) accounts.set(key, { key, label, kind, calendars: [] });
        return accounts.get(key);
      };
      if (connected) ensure(connected, connected, 'connected');

      this.calendars.forEach(cal => {
        const owned = cal.access_role === 'owner' || cal.primary;
        let key;
        if (owned || !isPersonalEmail(cal.id) || cal.id === connected) {
          key = connected || 'me';
        } else {
          key = cal.id; // calendario personal ajeno (compartido) → su propia cuenta
        }
        const kind = key === connected ? 'connected' : 'external';
        const label = key === connected ? connected || 'Mi cuenta' : key;
        ensure(key, label, kind).calendars.push(cal);
      });

      const groups = [...accounts.values()].filter(a => a.calendars.length);
      groups.sort((a, b) => {
        if (a.kind !== b.kind) return a.kind === 'connected' ? -1 : 1;
        return a.label.localeCompare(b.label);
      });
      // Dentro de cada cuenta: el primario primero, luego por nombre.
      groups.forEach(a =>
        a.calendars.sort(
          (x, y) =>
            (y.primary ? 1 : 0) - (x.primary ? 1 : 0) ||
            (x.summary || '').localeCompare(y.summary || '')
        )
      );
      return groups;
    },
    upcomingEvents() {
      const now = new Date();
      return this.events
        .filter(e => {
          const start = e.start?.dateTime || e.start?.date;
          return start && new Date(start) >= now;
        })
        .slice(0, 8);
    },
    calendarColorMap() {
      return Object.fromEntries(this.calendars.map(c => [c.id, c.background_color]));
    },
    availabilityMap() {
      return Object.fromEntries(this.availability.map(a => [a.agent_id, a.busy || []]));
    },
    agentsWithStatus() {
      return this.agents.map(agent => {
        const busy = this.availabilityMap[agent.id];
        let calendarStatus;
        if (busy === undefined) calendarStatus = 'not_connected';
        else if (busy.length > 0) calendarStatus = 'busy';
        else calendarStatus = 'free';
        return { ...agent, calendarStatus };
      });
    },
  },
  methods: {
    // Abre la sección indicada y repliega las demás; si ya estaba abierta, la cierra.
    toggleSection(name) {
      this.openSection = this.openSection === name ? null : name;
    },
    // Árbol de cuentas: por defecto abiertas (solo guardamos las cerradas).
    isAccountOpen(key) {
      return this.expandedAccounts[key] !== false;
    },
    toggleAccount(key) {
      // Reasignar el objeto para asegurar reactividad en Vue 2/3.
      this.expandedAccounts = {
        ...this.expandedAccounts,
        [key]: !this.isAccountOpen(key),
      };
    },
    // Solo se pueden editar los calendarios secundarios PROPIOS (owner, no principal).
    canEditCalendar(cal) {
      return cal.access_role === 'owner' && !cal.primary;
    },
    detectedTimeZone() {
      let tz = '';
      try {
        tz = Intl.DateTimeFormat().resolvedOptions().timeZone || '';
      } catch {
        tz = '';
      }
      return this.timeZones.some(o => o.value === tz) ? tz : '';
    },
    openSubscribeModal() {
      this.editingCalendarId = null;
      this.subscribeMode = 'create';
      this.subscribeInput = '';
      this.subscribeError = '';
      this.calForm = {
        summary: '',
        description: '',
        timeZone: this.detectedTimeZone(),
        backgroundColor: CALENDAR_COLORS[0],
      };
      this.showSubscribeModal = true;
    },
    openEditModal(cal) {
      this.editingCalendarId = cal.id;
      this.subscribeError = '';
      this.calForm = {
        summary: cal.summary || '',
        description: cal.description || '',
        timeZone: cal.time_zone || '',
        backgroundColor: cal.background_color || CALENDAR_COLORS[0],
      };
      this.showSubscribeModal = true;
    },
    closeSubscribeModal() {
      this.showSubscribeModal = false;
      this.editingCalendarId = null;
      this.subscribeInput = '';
      this.subscribeError = '';
    },
    // Edita el calendario, crea uno nuevo o suscribe uno existente según el estado.
    async submitCalendar() {
      if (this.submitDisabled) return;
      this.subscribing = true;
      this.subscribeError = '';
      try {
        if (this.isEditing) {
          await this.$store.dispatch('googleCalendar/updateCalendar', {
            calendarId: this.editingCalendarId,
            ...this.calFormPayload(),
          });
        } else if (this.subscribeMode === 'create') {
          await this.$store.dispatch('googleCalendar/createCalendar', this.calFormPayload());
        } else {
          await this.$store.dispatch(
            'googleCalendar/subscribeCalendar',
            this.subscribeInput.trim()
          );
        }
        this.closeSubscribeModal();
      } catch {
        // Suele ser falta de permisos (scope): la cuenta necesita reconectarse.
        this.subscribeError = this.$t('GOOGLE_CALENDAR.CALENDARS.ADD_ERROR');
      } finally {
        this.subscribing = false;
      }
    },
    calFormPayload() {
      return {
        summary: this.calForm.summary.trim(),
        description: this.calForm.description,
        timeZone: this.calForm.timeZone,
        backgroundColor: this.calForm.backgroundColor,
      };
    },
    calendarColor(calendarId) {
      return this.calendarColorMap[calendarId] || '#6366f1';
    },
    formatEventTime(event) {
      const start = event.start?.dateTime || event.start?.date;
      if (!start) return '';
      const date = parseISO(start);
      if (isToday(date)) return `${this.$t('GOOGLE_CALENDAR.AGENDA.TODAY')} ${format(date, 'HH:mm')}`;
      if (isTomorrow(date)) return `${this.$t('GOOGLE_CALENDAR.AGENDA.TOMORROW')} ${format(date, 'HH:mm')}`;
      return format(date, 'dd MMM HH:mm');
    },
  },
};
</script>
