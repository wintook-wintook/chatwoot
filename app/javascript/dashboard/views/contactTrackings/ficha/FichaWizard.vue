<script>
// feat/ficha_agente_ia — CREAR UN AGENTE: RECURSOS → FICHA DE AGENTE IA → CREAR
// ============================================================================
// Plan: docs/ficha_agente_ia_plan.md. Pedido del usuario (09/11/2026): «Recursos cuando
// es nuevo, solo ese; enseguida Ficha de Agente IA; cuando das continuar aparece
// Entrenamiento… es como siguiente, siguiente». Dos pasos, uno por pestaña (el espacio
// del agente muestra la segunda al dar Continuar):
//
//  step = 'resources'                                  step = 'profile'
//  ┌ menú ─────────┐┌ tarjetas ────────┐┌ panel ──┐    ┌ datos ─────────────────────┐┌ panel ────────┐
//  │ Fuentes  2/9  ││ buscador · tipos ││ podrá:  │    │ Nombre · Canal · Tono      ││ podrá: …      │
//  │ Agenda   1/2  ││ ☑ Precios ✓  ▾   ││ ☑ …     │    │ Objetivo   [✨ Proponer]   ││ ✓ sin errores │
//  │ Tickets  0/4  ││                  ││[Continuar]   │ Contexto IA [✨ Proponer]   ││[Crear agente] │
//  │ Archivos · Reglas                 │└─────────┘    │ Te conviene agregar: …     │└───────────────┘
//
// El Entrenamiento se escribe SIN IA (Ficha::Generator) y pasa por el comprobador; la
// vista previa se recalcula sola. ✨ es una llamada a OpenAI (Ficha::Suggester), solo al
// hacer clic. Los archivos se suben al crear y quedan marcados en la ficha.
// ============================================================================
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import FichaAPI from 'dashboard/api/fichaAgente';
import AiAgentAttachmentsAPI from 'dashboard/api/aiAgentAttachments';
import FichaCards, { GROUPS } from './FichaCards.vue';
import FichaNav from './FichaNav.vue';
import FichaFiles from './FichaFiles.vue';
import FichaTest from './FichaTest.vue';
import FichaReadiness from './FichaReadiness.vue';
import FichaAgenda from './FichaAgenda.vue';
import FichaLoading from './FichaLoading.vue';
import FichaChannel, {
  channelKind,
  trackingChannels,
} from './FichaChannel.vue';
import KeywordActionsEditor from 'dashboard/components/contacts/ContactTracking/KeywordActionsEditor.vue';

const SECTIONS = [
  'channel',
  'sources',
  'calendar',
  'tickets',
  'files',
  'rules',
];
const SECTION_ICONS = {
  channel: 'settings',
  sources: 'library',
  calendar: 'calendar',
  tickets: 'folder',
  files: 'attach',
  rules: 'flash-on',
};
const TONES = ['cercano', 'profesional'];
const SOURCE_KINDS = GROUPS.find(group => group.id === 'sources').kinds;
const FILE_NAME = /^[a-zA-Z0-9_-]{1,60}$/;
const MAX_CONTEXT = 800;

export default {
  components: {
    FichaCards,
    FichaNav,
    FichaFiles,
    FichaTest,
    FichaReadiness,
    FichaAgenda,
    FichaChannel,
    FichaLoading,
    KeywordActionsEditor,
  },
  props: {
    // 'resources' | 'profile': la pestaña en la que está (la elige el espacio del agente).
    step: { type: String, default: 'resources' },
  },
  emits: ['created', 'conversation', 'continue', 'back'],
  data() {
    return {
      section: 'channel',
      name: '',
      // Recursos › Canal y seguimiento (antes de las fuentes: WhatsApp pide plantillas).
      follow: {
        inboxId: '',
        retryValue: 1,
        retryUnit: 'days',
        attempts: 3,
        whatsappTemplates: [],
        emailSignature: '',
      },
      // La bienvenida: se manda tal cual en el primer mensaje del cliente.
      welcome: '',
      displayName: '',
      objective: '',
      business: '',
      missing: [],
      tone: 'cercano',
      cards: [],
      items: [],
      files: [],
      // Reglas: palabras clave → acción (las mismas de la Ficha › Reglas).
      keywordActions: [],
      // Frases de cliente agregadas a una ruta desde la prueba: { oferta: [frases] }.
      phrases: {},
      // Recursos › Agenda: duración, zona, presentación y calendarios donde aparta.
      agenda: {
        calendar_event_duration: 30,
        timezone: '',
        slots_presentation: 'detailed',
        booking_calendar_ids: {},
      },
      // Activarlo en su canal al crearlo (crea la automatización).
      activateOnCreate: false,
      skip: [],
      query: '',
      kind: '',
      preview: null,
      loadingCards: false,
      loadingPreview: false,
      suggesting: false,
      creating: false,
      showPrompt: false,
      timer: null,
      tones: TONES,
      maxContext: MAX_CONTEXT,
    };
  },
  computed: {
    ...mapGetters({
      inboxes: 'inboxes/getInboxes',
      appIntegrations: 'integrations/getAppIntegrations',
    }),
    nameOk() {
      return this.name.trim().length >= 2;
    },
    navItems() {
      return SECTIONS.map(id => {
        const base = {
          id,
          icon: SECTION_ICONS[id],
          label: this.t(`NAV_${id.toUpperCase()}`),
        };
        if (id === 'channel')
          return { ...base, state: this.channelOk ? 'ok' : 'todo' };
        if (id === 'files' || id === 'rules') {
          const cuantos =
            id === 'files' ? this.files.length : this.keywordActions.length;
          return { ...base, count: cuantos, total: cuantos };
        }
        const grupo = GROUPS.find(group => group.id === id);
        const tarjetas = this.cards.filter(card =>
          grupo.kinds.includes(card.kind)
        );
        const marcadas = tarjetas.filter(card =>
          this.items.some(item => item.key === card.key)
        );
        return { ...base, count: marcadas.length, total: tarjetas.length };
      });
    },
    nextSection() {
      return SECTIONS[SECTIONS.indexOf(this.section) + 1] || null;
    },
    kindChips() {
      return [
        '',
        ...SOURCE_KINDS.filter(kind =>
          this.cards.some(card => card.kind === kind)
        ),
      ];
    },
    offers() {
      return (this.preview && this.preview.offers) || [];
    },
    routes() {
      return (this.preview && this.preview.routes) || [];
    },
    validation() {
      return (this.preview && this.preview.validation) || {};
    },
    // Las agendas marcadas (calendar:N → N).
    calendarIds() {
      return this.items
        .map(item => (item.key.match(/^calendar:(\d+)$/) || [])[1])
        .filter(Boolean)
        .map(Number);
    },
    readiness() {
      return (this.preview && this.preview.readiness) || [];
    },
    // Lo que se manda a probar: sin «activar» (no cambia el resultado).
    testPayload() {
      const resto = { ...this.payload };
      delete resto.activate;
      return resto;
    },
    warnings() {
      return [
        ...(this.validation.blocking || []),
        ...(this.validation.degrading || []),
      ];
    },
    objectivePlaceholder() {
      return (
        (this.preview && this.preview.objective) || this.t('OBJECTIVE_AUTO')
      );
    },
    hasSomething() {
      return this.items.length > 0 || this.files.length > 0;
    },
    filesOk() {
      return this.files.every(file => FILE_NAME.test(file.name));
    },
    inboxId() {
      return this.follow.inboxId;
    },
    channelKind() {
      return channelKind(
        trackingChannels(this.appIntegrations, this.inboxes).find(
          item => item.id === Number(this.inboxId)
        )
      );
    },
    channelOk() {
      if (!this.inboxId) return false;
      if (this.channelKind !== 'whatsapp') return true;
      return Array.from({ length: this.follow.attempts || 1 }).every(
        (_, i) => !!(this.follow.whatsappTemplates || [])[i]
      );
    },
    // «Con la ruta»: las que contestan (no la de agendar ni la de ticket).
    fileRouteOptions() {
      return this.routes
        .filter(ruta => !['calendar', 'case_type'].includes(ruta.kind))
        .map(ruta => ({ value: ruta.key, label: ruta.label }));
    },
    // «Al levantar un ticket»: los tipos marcados, o cualquiera.
    fileTicketOptions() {
      const tipos = this.cards.filter(
        card =>
          card.kind === 'case_type' &&
          this.items.some(item => item.key === card.key)
      );
      if (!tipos.length) return [];
      return [
        { value: '*', label: this.t('RULE_ANY_TICKET') },
        ...tipos.map(card => ({ value: card.name, label: card.name })),
      ];
    },
    welcomeFiles() {
      return this.files.filter(file => file.welcome);
    },
    canContinue() {
      return (
        this.routes.length > 0 &&
        this.filesOk &&
        this.channelOk &&
        !this.loadingPreview
      );
    },
    canCreate() {
      return (
        this.nameOk &&
        this.canContinue &&
        !!this.validation.valid &&
        !this.creating
      );
    },
    panelHint() {
      if (!this.routes.length) return this.t('NEED_RESOURCE');
      if (this.step === 'resources') return this.t('CONTINUE_HINT');
      if (!this.nameOk) return this.t('NEED_NAME');
      if (!this.validation.valid) return this.t('INVALID');
      return this.t('AFTER_CREATE');
    },
    payload() {
      return {
        name: this.name.trim(),
        inbox_id: this.inboxId || null,
        customer_display_name: this.displayName.trim(),
        items: this.items,
        files: this.files.map(file => ({
          name: file.name,
          ask: file.ask,
          welcome: file.welcome,
          attempts: file.attempts,
          routes: file.routes || [],
          booking: !!file.booking,
          tickets: file.tickets || [],
        })),
        welcome: this.welcome.trim(),
        retry_interval_value: this.follow.retryValue,
        retry_interval_unit: this.follow.retryUnit,
        attempts: this.follow.attempts,
        whatsapp_templates:
          this.channelKind === 'whatsapp'
            ? this.follow.whatsappTemplates.slice(0, this.follow.attempts)
            : [],
        email_signature:
          this.channelKind === 'email' ? this.follow.emailSignature : '',
        keyword_actions: this.keywordActions,
        phrases: this.phrases,
        agenda: this.calendarIds.length ? this.agenda : null,
        activate: this.activateOnCreate && !!this.inboxId,
        skip: this.skip,
        tone: this.tone,
        objective: this.objective.trim(),
        business: this.business.trim(),
      };
    },
  },
  watch: {
    inboxId() {
      this.loadCards();
    },
    payload: {
      deep: true,
      handler() {
        this.schedulePreview();
      },
    },
  },
  mounted() {
    this.loadCards();
  },
  beforeDestroy() {
    clearTimeout(this.timer);
  },
  methods: {
    t(key, args) {
      return this.$t(`TRACKING_TEMPLATES.FICHA.${key}`, args);
    },
    kindLabel(kind) {
      return kind ? this.t(`KIND_${kind.toUpperCase()}`) : this.t('KIND_ALL');
    },
    async loadCards() {
      this.loadingCards = true;
      try {
        const { data } = await FichaAPI.catalog(this.inboxId);
        this.cards = data.cards || [];
        const existen = this.cards.map(card => card.key);
        this.items = this.items.filter(item => existen.includes(item.key));
      } catch (error) {
        useAlert(this.t('LOAD_ERROR'));
      } finally {
        this.loadingCards = false;
      }
    },
    schedulePreview() {
      clearTimeout(this.timer);
      if (!this.hasSomething) {
        this.preview = null;
        return;
      }
      this.timer = setTimeout(() => this.loadPreview(), 350);
    },
    async loadPreview() {
      this.loadingPreview = true;
      try {
        const { data } = await FichaAPI.preview(this.payload);
        this.preview = data;
      } catch (error) {
        useAlert(this.t('PREVIEW_ERROR'));
      } finally {
        this.loadingPreview = false;
      }
    },
    toggleOffer(offer) {
      this.skip = this.skip.includes(offer.key)
        ? this.skip.filter(key => key !== offer.key)
        : [...this.skip, offer.key];
    },
    isSkipped(offer) {
      return this.skip.includes(offer.key);
    },
    addPhrase({ key, phrase }) {
      const actuales = this.phrases[key] || [];
      if (actuales.includes(phrase)) return;
      this.phrases = { ...this.phrases, [key]: [...actuales, phrase] };
      useAlert(this.t('PHRASE_ADDED'));
    },
    onFix(item) {
      if (item.fix === 'context') {
        this.suggest('context');
        return;
      }
      if (item.fix === 'channel') {
        this.section = 'channel';
        this.$emit('back');
      }
    },
    // ✨ Una llamada a OpenAI: objetivo y contexto, o la bienvenida, con lo capturado.
    async suggest(campo) {
      this.suggesting = campo;
      try {
        const { data } = await FichaAPI.suggest({
          ...this.payload,
          field: campo === 'welcome' ? 'welcome' : 'fields',
        });
        if (campo === 'welcome') {
          if (data.welcome) this.welcome = data.welcome;
          return;
        }
        if (campo !== 'context' && data.objective)
          this.objective = data.objective;
        if (campo !== 'objective' && data.ai_context) {
          this.business = data.ai_context;
          this.missing = data.missing || [];
        }
      } catch (error) {
        const datos = error && error.response && error.response.data;
        useAlert((datos && datos.error) || this.t('SUGGEST_ERROR'));
      } finally {
        this.suggesting = false;
      }
    },
    // Agrega el dato que falta como una línea para llenarla.
    addMissing(dato) {
      const texto = this.business.trim();
      this.business = `${texto}${texto ? '\n' : ''}${dato}: `;
      this.missing = this.missing.filter(item => item !== dato);
      this.$nextTick(() => {
        const caja = this.$refs.context;
        if (caja) caja.focus();
      });
    },
    async create() {
      if (!this.canCreate) return;
      this.creating = true;
      try {
        const { data } = await FichaAPI.create(this.payload);
        await this.uploadFiles(data.id);
        // Esperar: el Entrenamiento que se abre enseguida busca el agente en esta lista.
        await this.$store.dispatch('trackingTemplates/get');
        useAlert(this.t('CREATED'));
        this.$emit('created', data.id);
      } catch (error) {
        const datos = error && error.response && error.response.data;
        if (datos && datos.validation) this.preview = datos;
        useAlert(
          (datos && (datos.error || datos.message)) || this.t('CREATE_ERROR')
        );
      } finally {
        this.creating = false;
      }
    },
    // Los archivos van después de crear (necesitan el agente) y quedan marcados en la ficha.
    async uploadFiles(id) {
      if (!this.files.length) return;
      const subidos = [];
      // eslint-disable-next-line no-restricted-syntax
      for (const item of this.files) {
        try {
          // eslint-disable-next-line no-await-in-loop
          const { data } = await AiAgentAttachmentsAPI.upload(id, {
            name: item.name,
            file: item.file,
          });
          subidos.push({ key: `file:${data.id}` });
        } catch (error) {
          useAlert(this.t('FILE_FAILED', { name: item.file.name }));
        }
      }
      if (subidos.length)
        await FichaAPI.save(id, [...this.items, ...subidos], {
          keyword_actions: this.keywordActions,
        });
    },
  },
};
</script>

<template>
  <div
    class="grid flex-1 min-h-0 gap-4"
    :class="
      step === 'resources'
        ? 'md:grid-cols-[200px_minmax(0,1fr)] xl:grid-cols-[200px_minmax(0,1fr)_320px] xl:grid-rows-[minmax(0,1fr)]'
        : 'xl:grid-cols-[minmax(0,1fr)_320px] xl:grid-rows-[minmax(0,1fr)]'
    "
  >
    <!-- ① Recursos: menú -->
    <div v-if="step === 'resources'" class="flex flex-col min-h-0 gap-3">
      <FichaNav v-model="section" :items="navItems" />
      <woot-button
        size="small"
        variant="clear"
        color-scheme="secondary"
        icon="chat-multiple"
        @click="$emit('conversation')"
      >
        {{ t('USE_CONVERSATION') }}
      </woot-button>
    </div>

    <!-- ① Recursos: sección -->
    <div v-if="step === 'resources'" class="flex flex-col min-h-0 gap-4">
      <div class="flex flex-col flex-1 min-h-0">
        <!-- Fuentes: el texto, el buscador y los tipos fijos; solo las tarjetas hacen scroll. -->
        <div
          v-if="section === 'channel'"
          class="flex flex-col flex-1 min-h-0 pr-1 overflow-auto"
        >
          <FichaChannel v-model="follow" />
        </div>
        <div
          v-else-if="section === 'sources'"
          class="flex flex-col flex-1 min-h-0 gap-3"
        >
          <p class="!m-0 text-sm text-slate-600 dark:text-slate-300 shrink-0">
            {{ t('SOURCES_HINT') }}
          </p>
          <div class="flex flex-wrap items-center gap-2 shrink-0">
            <div class="relative flex-1 min-w-[12rem]">
              <fluent-icon
                icon="search"
                size="14"
                class="absolute -translate-y-1/2 left-2.5 top-1/2 text-slate-400"
              />
              <input
                v-model="query"
                type="search"
                class="!mb-0 !pl-8 !h-9 text-sm"
                :placeholder="t('SEARCH')"
              />
            </div>
            <div class="flex flex-wrap gap-1">
              <button
                v-for="item in kindChips"
                :key="item || 'all'"
                type="button"
                class="px-2.5 py-1 text-xs border rounded-full"
                :class="
                  kind === item
                    ? 'border-woot-500 bg-woot-500 text-white'
                    : 'border-slate-200 text-slate-600 dark:border-slate-700 dark:text-slate-300'
                "
                @click="kind = item"
              >
                {{ kindLabel(item) }}
              </button>
            </div>
          </div>
          <div class="flex-1 min-h-0 pr-1 overflow-auto">
            <FichaLoading v-if="loadingCards" />
            <FichaCards
              v-else
              v-model="items"
              :cards="cards"
              :only="['sources']"
              :query="query"
              :kind="kind"
              :show-headers="false"
            />
          </div>
        </div>
        <div
          v-else-if="section === 'calendar'"
          class="flex flex-col flex-1 min-h-0 gap-3 pr-1 overflow-auto"
        >
          <p class="!m-0 text-sm text-slate-600 dark:text-slate-300">
            {{ t('CALENDAR_HINT') }}
          </p>
          <FichaCards
            v-model="items"
            :cards="cards"
            :only="['calendar']"
            :show-headers="false"
          />
          <FichaAgenda
            v-if="calendarIds.length"
            v-model="agenda"
            class="pt-3 border-t border-slate-100 dark:border-slate-700"
            :integration-ids="calendarIds"
          />
        </div>
        <div
          v-else-if="section === 'tickets'"
          class="flex flex-col flex-1 min-h-0 gap-3 pr-1 overflow-auto"
        >
          <p class="!m-0 text-sm text-slate-600 dark:text-slate-300">
            {{ t('TICKETS_HINT') }}
          </p>
          <FichaCards
            v-model="items"
            :cards="cards"
            :only="['tickets']"
            :show-headers="false"
          />
        </div>
        <div
          v-else-if="section === 'files'"
          class="flex flex-col flex-1 min-h-0 gap-3 pr-1 overflow-auto"
        >
          <p class="!m-0 text-sm text-slate-600 dark:text-slate-300">
            {{ t('FILES_HINT') }}
          </p>
          <FichaFiles
            v-model="files"
            :attempts="follow.attempts"
            :route-options="fileRouteOptions"
            :ticket-options="fileTicketOptions"
            :show-booking="calendarIds.length > 0"
          />
        </div>
        <div
          v-else
          class="flex flex-col flex-1 min-h-0 gap-3 pr-1 overflow-auto"
        >
          <p class="!m-0 text-sm text-slate-600 dark:text-slate-300">
            {{ t('RULES_HINT') }}
          </p>
          <KeywordActionsEditor v-model="keywordActions" />
        </div>
      </div>

      <div
        v-if="nextSection"
        class="flex justify-end pt-3 border-t shrink-0 border-slate-100 dark:border-slate-700"
      >
        <woot-button
          variant="smooth"
          icon="arrow-right"
          @click="section = nextSection"
        >
          {{
            t('NEXT_SECTION', { name: t(`NAV_${nextSection.toUpperCase()}`) })
          }}
        </woot-button>
      </div>
    </div>

    <!-- ② Ficha de Agente IA -->
    <div v-else class="flex flex-col min-h-0 gap-4 pr-1 overflow-auto">
      <p class="!m-0 text-sm text-slate-600 dark:text-slate-300">
        {{ t('AGENT_HINT') }}
      </p>
      <div class="grid gap-3 sm:grid-cols-2">
        <label class="!m-0">
          {{ t('NAME') }}
          <input
            v-model="name"
            type="text"
            class="!mb-0"
            :placeholder="t('NAME_PLACEHOLDER')"
          />
        </label>
        <label class="!m-0">
          {{ t('DISPLAY_NAME') }}
          <input
            v-model="displayName"
            type="text"
            maxlength="30"
            class="!mb-0"
            :placeholder="t('DISPLAY_NAME_PLACEHOLDER')"
          />
        </label>
        <div class="flex flex-col gap-1">
          <span class="text-sm text-slate-800 dark:text-slate-100">
            {{ t('TONE') }}
          </span>
          <div class="flex gap-2">
            <label
              v-for="item in tones"
              :key="item"
              class="flex items-center gap-2 !m-0 px-3 py-2 text-sm border rounded-lg cursor-pointer"
              :class="
                tone === item
                  ? 'border-woot-500 bg-woot-25 dark:bg-woot-900/20'
                  : 'border-slate-200 dark:border-slate-700'
              "
            >
              <input v-model="tone" type="radio" class="!m-0" :value="item" />
              {{ t(`TONE_${item.toUpperCase()}`) }}
            </label>
          </div>
        </div>

        <div class="flex flex-col gap-1 sm:col-span-2">
          <div class="flex items-center justify-between gap-2">
            <span class="text-sm text-slate-800 dark:text-slate-100">
              {{ t('OBJECTIVE') }}
            </span>
            <woot-button
              size="tiny"
              variant="smooth"
              icon="wand"
              :is-loading="suggesting === 'objective'"
              :is-disabled="!!suggesting || !routes.length"
              @click="suggest('objective')"
            >
              {{ t('SUGGEST') }}
            </woot-button>
          </div>
          <input
            v-model="objective"
            type="text"
            maxlength="500"
            class="!mb-0"
            :placeholder="objectivePlaceholder"
          />
        </div>

        <div class="flex flex-col gap-1 sm:col-span-2">
          <div class="flex items-center justify-between gap-2">
            <span class="text-sm text-slate-800 dark:text-slate-100">
              {{ t('CONTEXT') }}
            </span>
            <woot-button
              size="tiny"
              variant="smooth"
              icon="wand"
              :is-loading="suggesting === 'context'"
              :is-disabled="!!suggesting || !routes.length"
              @click="suggest('context')"
            >
              {{ t('SUGGEST') }}
            </woot-button>
          </div>
          <textarea
            ref="context"
            v-model="business"
            rows="6"
            :maxlength="maxContext"
            class="!mb-0"
            :placeholder="t('BUSINESS_PLACEHOLDER')"
          />
          <div class="flex items-center justify-between gap-2 text-xs">
            <span class="text-slate-500">{{ t('CONTEXT_HINT') }}</span>
            <span class="text-slate-400 shrink-0">
              {{ business.length }}/{{ maxContext }}
            </span>
          </div>
          <div
            v-if="missing.length"
            class="flex flex-wrap items-center gap-1 text-xs"
          >
            <span class="text-amber-800">{{ t('MISSING') }}</span>
            <button
              v-for="dato in missing"
              :key="dato"
              type="button"
              class="px-2 py-0.5 border rounded-full border-amber-300 text-amber-800 hover:bg-amber-50"
              @click="addMissing(dato)"
            >
              + {{ dato }}
            </button>
          </div>
          <p class="!m-0 text-xs text-slate-400">{{ t('SUGGEST_COST') }}</p>
        </div>

        <!-- Mensaje de bienvenida: el motor lo manda TAL CUAL en el primer mensaje. -->
        <div class="flex flex-col gap-1 sm:col-span-2">
          <div class="flex items-center justify-between gap-2">
            <span class="text-sm text-slate-800 dark:text-slate-100">
              {{ t('WELCOME') }}
            </span>
            <woot-button
              size="tiny"
              variant="smooth"
              icon="wand"
              :is-loading="suggesting === 'welcome'"
              :is-disabled="!!suggesting"
              @click="suggest('welcome')"
            >
              {{ welcome.trim() ? t('WELCOME_IMPROVE') : t('SUGGEST') }}
            </woot-button>
          </div>
          <textarea
            v-model="welcome"
            rows="3"
            maxlength="600"
            class="!mb-0"
            :placeholder="t('WELCOME_PLACEHOLDER')"
          />
          <span class="text-xs text-slate-500">{{ t('WELCOME_HINT') }}</span>
          <div class="flex flex-wrap items-center gap-1 text-xs">
            <span class="text-slate-600 dark:text-slate-300">
              {{ t('WELCOME_FILES') }}
            </span>
            <span
              v-for="file in welcomeFiles"
              :key="file.key"
              class="flex items-center gap-1 px-2 py-0.5 rounded-full bg-slate-100 dark:bg-slate-700"
            >
              <fluent-icon icon="attach" size="12" />
              {{ file.name }}
            </span>
            <span v-if="!welcomeFiles.length" class="text-slate-400">
              {{ t('WELCOME_FILES_NONE') }}
            </span>
          </div>
        </div>
      </div>
    </div>

    <!-- Panel: Tu agente podrá -->
    <aside
      class="flex flex-col min-h-0 gap-3 p-4 overflow-auto border rounded-lg border-slate-200 dark:border-slate-700 bg-slate-25 dark:bg-slate-800/40"
      :class="{ 'md:col-span-2 xl:col-span-1': step === 'resources' }"
    >
      <h3 class="!m-0 text-sm font-semibold text-slate-800 dark:text-slate-100">
        {{ t('PANEL_TITLE') }}
      </h3>
      <p v-if="!hasSomething" class="!m-0 text-xs text-slate-500">
        {{ t('PANEL_EMPTY') }}
      </p>
      <ul
        v-else
        class="!m-0 !p-0 list-none flex flex-col gap-1.5 overflow-auto min-h-0"
      >
        <li
          v-for="offer in offers"
          :key="offer.key"
          class="flex items-start gap-2"
        >
          <input
            type="checkbox"
            class="!m-0 mt-0.5"
            :checked="!isSkipped(offer)"
            @change="toggleOffer(offer)"
          />
          <span class="flex flex-col">
            <span
              class="text-sm"
              :class="
                isSkipped(offer)
                  ? 'text-slate-400 line-through'
                  : 'text-slate-700 dark:text-slate-200'
              "
            >
              {{ offer.label }}
            </span>
            <span
              v-if="offer.warning"
              class="flex items-center gap-1 text-xs text-amber-700"
            >
              <fluent-icon icon="warning" size="12" />
              {{ offer.warning }}
            </span>
          </span>
        </li>
      </ul>

      <div
        v-if="hasSomething"
        class="flex items-center gap-2 px-3 py-2 text-xs rounded-lg"
        :class="
          validation.valid && !warnings.length
            ? 'bg-green-50 text-green-800 dark:bg-green-900/30 dark:text-green-200'
            : 'bg-amber-50 text-amber-800 dark:bg-amber-900/30 dark:text-amber-200'
        "
      >
        <fluent-icon
          :icon="validation.valid ? 'checkmark-circle' : 'warning'"
          size="14"
        />
        <span v-if="loadingPreview">{{ t('CHECKING') }}</span>
        <span v-else-if="validation.valid && !warnings.length">
          {{ t('VALID', { count: routes.length }) }}
        </span>
        <span v-else-if="validation.valid">
          {{ t('VALID_WITH_WARNINGS', { count: warnings.length }) }}
        </span>
        <span v-else>{{ t('INVALID') }}</span>
      </div>
      <ul v-if="warnings.length" class="!m-0 pl-4 text-xs text-amber-800">
        <li v-for="(item, index) in warnings" :key="index">
          {{ item.message }}
        </li>
      </ul>

      <woot-button
        v-if="preview"
        size="small"
        variant="clear"
        color-scheme="secondary"
        :icon="showPrompt ? 'chevron-up' : 'chevron-down'"
        class="self-start"
        @click="showPrompt = !showPrompt"
      >
        {{ showPrompt ? t('HIDE_PROMPT') : t('SHOW_PROMPT') }}
      </woot-button>
      <div
        v-if="showPrompt && preview"
        class="p-2 overflow-auto font-mono text-xs whitespace-pre-wrap bg-white rounded max-h-64 dark:bg-slate-900 text-slate-700 dark:text-slate-200"
      >
        {{ preview.prompt }}
      </div>

      <template v-if="step === 'profile' && hasSomething">
        <FichaTest
          class="pt-3 border-t border-slate-200 dark:border-slate-700"
          :payload="testPayload"
          :routes="routes"
          @addPhrase="addPhrase"
        />
        <FichaReadiness
          class="pt-3 border-t border-slate-200 dark:border-slate-700"
          :items="readiness"
          is-new
          :activate-on-create.sync="activateOnCreate"
          :can-activate="!!inboxId"
          @fix="onFix"
        />
      </template>

      <div class="flex flex-col gap-1 mt-auto">
        <woot-button
          v-if="step === 'resources'"
          icon="arrow-right"
          :is-disabled="!canContinue"
          @click="$emit('continue')"
        >
          {{ t('CONTINUE') }}
        </woot-button>
        <template v-else>
          <woot-button
            icon="checkmark"
            :is-loading="creating"
            :is-disabled="!canCreate"
            @click="create"
          >
            {{ t('CREATE') }}
          </woot-button>
          <woot-button
            size="small"
            variant="clear"
            color-scheme="secondary"
            icon="chevron-left"
            @click="$emit('back')"
          >
            {{ t('BACK_RESOURCES') }}
          </woot-button>
        </template>
        <span class="text-xs text-center text-slate-500">
          {{ panelHint }}
        </span>
      </div>
    </aside>
  </div>
</template>
