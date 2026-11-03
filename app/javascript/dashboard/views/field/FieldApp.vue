<!--
  Plan-Trabajo-Campo R2 — portal del técnico: pantalla web para el celular,
  sin el menú de Wintook (se agrega a la pantalla de inicio como una app).
  /app/accounts/:id/campo                 → Mi ruta
  /app/accounts/:id/campo?tab=history     → Mis trabajos (lo ya terminado)
  /app/accounts/:id/campo/visita/:ticketId → la visita
-->
<script>
import { mapGetters } from 'vuex';
import FieldHistory from './FieldHistory.vue';
import FieldRoute from './FieldRoute.vue';
import FieldVisit from './FieldVisit.vue';
import FieldAgendaVisit from './FieldAgendaVisit.vue';

// «Ir a Wintook» regresa a la pantalla desde la que se abrió el portal (p. ej.
// Agenda › Calendario). Se guarda al entrar desde Wintook, no al moverse entre
// Mi ruta / Mis trabajos / la visita; sin origen (enlace de WhatsApp) va a Inicio.
const ORIGIN_KEY = 'wintook_field_origin';
const FIELD_ROUTES = ['field_route', 'field_visit', 'field_agenda_visit'];

const readOrigin = () => {
  try {
    return window.sessionStorage.getItem(ORIGIN_KEY);
  } catch {
    return null;
  }
};

const saveOrigin = path => {
  try {
    if (path) window.sessionStorage.setItem(ORIGIN_KEY, path);
    else window.sessionStorage.removeItem(ORIGIN_KEY);
  } catch {
    // Sin almacenamiento: «Ir a Wintook» va a Inicio.
  }
};

export default {
  name: 'FieldApp',
  components: { FieldHistory, FieldRoute, FieldVisit, FieldAgendaVisit },
  beforeRouteEnter(to, from, next) {
    if (!FIELD_ROUTES.includes(from.name)) {
      saveOrigin(from.name ? from.fullPath : null);
    }
    next();
  },
  computed: {
    ...mapGetters({ currentUser: 'getCurrentUser' }),
    ticketId() {
      return Number(this.$route.params.ticketId) || null;
    },
    meetingId() {
      return Number(this.$route.params.meetingId) || null;
    },
    inVisit() {
      return !!(this.ticketId || this.meetingId);
    },
    // En la visita: a qué pestaña regresa.
    fromHistory() {
      return this.$route.query.from === 'history';
    },
    tab() {
      return this.$route.query.tab === 'history' ? 'history' : 'route';
    },
    backLabel() {
      if (!this.inVisit) return this.$t('FIELD.BACK_TO_APP');
      return this.fromHistory
        ? this.$t('FIELD.TABS.HISTORY')
        : this.$t('FIELD.TITLE');
    },
  },
  methods: {
    back() {
      if (this.inVisit) {
        this.$router.push({
          name: 'field_route',
          params: { accountId: this.$route.params.accountId },
          query: this.fromHistory ? { tab: 'history' } : {},
        });
      } else {
        const origin = readOrigin();
        this.$router.push(
          origin && origin.startsWith('/app/')
            ? origin
            : {
                name: 'home',
                params: { accountId: this.$route.params.accountId },
              }
        );
      }
    },
    setTab(tab) {
      if (tab === this.tab) return;
      this.$router.replace({
        name: 'field_route',
        params: { accountId: this.$route.params.accountId },
        query: tab === 'history' ? { tab } : {},
      });
    },
  },
};
</script>

<template>
  <div class="w-full min-h-screen overflow-y-auto bg-slate-100">
    <header class="sticky top-0 z-20 bg-white border-b border-slate-200">
      <div class="flex items-center justify-between h-14 max-w-xl px-3 mx-auto">
        <button
          type="button"
          class="flex items-center gap-1 p-0 text-sm text-woot-600"
          @click="back"
        >
          <fluent-icon icon="chevron-left" size="16" />
          {{ backLabel }}
        </button>
        <span class="text-sm font-semibold text-slate-700">{{
          currentUser && currentUser.name
        }}</span>
      </div>
    </header>
    <main class="max-w-xl px-3 py-4 mx-auto">
      <FieldVisit v-if="ticketId" :key="ticketId" :ticket-id="ticketId" />
      <FieldAgendaVisit
        v-else-if="meetingId"
        :key="`m-${meetingId}`"
        :meeting-id="meetingId"
      />
      <template v-else>
        <div class="flex mb-4 border-b border-slate-200">
          <button
            v-for="option in ['route', 'history']"
            :key="option"
            type="button"
            class="flex-1 py-2 -mb-px text-sm font-medium border-0 border-b-2 border-solid rounded-none focus:outline-none"
            :class="
              tab === option
                ? 'border-woot-500 text-woot-600'
                : 'border-transparent text-slate-500'
            "
            @click="setTab(option)"
          >
            {{ $t(`FIELD.TABS.${option.toUpperCase()}`) }}
          </button>
        </div>
        <FieldHistory v-if="tab === 'history'" />
        <FieldRoute v-else />
      </template>
    </main>
  </div>
</template>
