<script>
// feat/ficha_agente_ia — CREAR UN AGENTE DESDE SUS RECURSOS
// ============================================================================
// Plan: docs/ficha_agente_ia_plan.md §4–§7 (rediseño pedido el 09/11/2026: «que inicie
// en Recursos… organizar fuentes, agenda, tickets… más interactivo… la ficha es parte
// de Recursos… los archivos se adjuntan ahí»).
//
//  ┌ menú ──────────────┐┌ sección elegida ─────────────────┐┌ Tu agente podrá ─────────┐
//  │ Datos del agente ✓ ││ (datos / tarjetas con buscador y ││ ☑ Contestar con «Precios»│
//  │ Fuentes de datos 2/9││  filtro por tipo / archivos)     ││ ☑ Agendar citas          │
//  │ Agenda 1/2         ││                                  ││ ✓ 3 rutas, sin errores   │
//  │ Tickets 0/4        ││        [Siguiente: Agenda ›]     ││ [Crear agente]           │
//  │ Archivos 1         │└──────────────────────────────────┘└──────────────────────────┘
//
// El Entrenamiento se escribe SIN IA (ContactTrackings::Ficha::Generator) y pasa por el
// mismo comprobador del editor; la vista previa se recalcula sola. Los archivos se suben
// al crear y quedan marcados en la ficha.
// ============================================================================
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import FichaAPI from 'dashboard/api/fichaAgente';
import AiAgentAttachmentsAPI from 'dashboard/api/aiAgentAttachments';
import FichaCards, { GROUPS } from './FichaCards.vue';
import FichaNav from './FichaNav.vue';
import FichaFiles from './FichaFiles.vue';

const SECTIONS = ['agent', 'sources', 'calendar', 'tickets', 'files'];
const SECTION_ICONS = {
  agent: 'book-contacts',
  sources: 'library',
  calendar: 'calendar',
  tickets: 'folder',
  files: 'attach',
};
const TONES = ['cercano', 'profesional'];
const SOURCE_KINDS = GROUPS.find(group => group.id === 'sources').kinds;
const FILE_NAME = /^[a-zA-Z0-9_-]{1,60}$/;

export default {
  components: { FichaCards, FichaNav, FichaFiles },
  emits: ['created', 'conversation'],
  data() {
    return {
      section: 'agent',
      name: '',
      inboxId: '',
      displayName: '',
      objective: '',
      business: '',
      tone: 'cercano',
      cards: [],
      items: [],
      files: [],
      skip: [],
      query: '',
      kind: '',
      preview: null,
      loadingCards: false,
      loadingPreview: false,
      creating: false,
      showPrompt: false,
      timer: null,
      tones: TONES,
    };
  },
  computed: {
    ...mapGetters({ inboxes: 'inboxes/getInboxes' }),
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
        if (id === 'agent')
          return { ...base, state: this.nameOk ? 'ok' : 'todo' };
        if (id === 'files')
          return {
            ...base,
            count: this.files.length,
            total: this.files.length,
          };
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
    sectionIndex() {
      return SECTIONS.indexOf(this.section);
    },
    nextSection() {
      return SECTIONS[this.sectionIndex + 1] || null;
    },
    sourceKinds() {
      return SOURCE_KINDS.filter(kind =>
        this.cards.some(card => card.kind === kind)
      );
    },
    kindChips() {
      return ['', ...this.sourceKinds];
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
    canCreate() {
      return (
        this.nameOk &&
        this.routes.length > 0 &&
        !!this.validation.valid &&
        this.filesOk &&
        !this.loadingPreview &&
        !this.creating
      );
    },
    createHint() {
      if (!this.nameOk) return this.t('NEED_NAME');
      if (!this.routes.length) return this.t('NEED_RESOURCE');
      if (!this.validation.valid) return this.t('INVALID');
      return this.t('AFTER_CREATE');
    },
    payload() {
      return {
        name: this.name.trim(),
        inbox_id: this.inboxId || null,
        customer_display_name: this.displayName.trim(),
        items: this.items,
        files: this.files.map(file => ({ name: file.name })),
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
    async create() {
      if (!this.canCreate) return;
      this.creating = true;
      try {
        const { data } = await FichaAPI.create(this.payload);
        await this.uploadFiles(data.id);
        this.$store.dispatch('trackingTemplates/get');
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
      if (subidos.length) await FichaAPI.save(id, [...this.items, ...subidos]);
    },
  },
};
</script>

<template>
  <div
    class="grid flex-1 min-h-0 gap-4 md:grid-cols-[200px_minmax(0,1fr)] xl:grid-cols-[200px_minmax(0,1fr)_320px]"
  >
    <!-- Menú -->
    <div class="flex flex-col min-h-0 gap-3">
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

    <!-- Sección -->
    <div class="flex flex-col min-h-0 gap-4">
      <div class="flex-1 min-h-0 pr-1 overflow-auto">
        <!-- Datos del agente -->
        <div v-if="section === 'agent'" class="flex flex-col gap-4">
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
              {{ t('INBOX') }}
              <select v-model="inboxId" class="!mb-0">
                <option value="">{{ t('INBOX_LATER') }}</option>
                <option
                  v-for="inbox in inboxes"
                  :key="inbox.id"
                  :value="inbox.id"
                >
                  {{ inbox.name }}
                </option>
              </select>
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
                  <input
                    v-model="tone"
                    type="radio"
                    class="!m-0"
                    :value="item"
                  />
                  {{ t(`TONE_${item.toUpperCase()}`) }}
                </label>
              </div>
            </div>
            <label class="!m-0 sm:col-span-2">
              {{ t('OBJECTIVE') }}
              <input
                v-model="objective"
                type="text"
                class="!mb-0"
                :placeholder="objectivePlaceholder"
              />
            </label>
            <label class="!m-0 sm:col-span-2">
              {{ t('BUSINESS') }}
              <textarea
                v-model="business"
                rows="3"
                class="!mb-0"
                :placeholder="t('BUSINESS_PLACEHOLDER')"
              />
            </label>
          </div>
        </div>

        <!-- Fuentes de datos -->
        <div v-else-if="section === 'sources'" class="flex flex-col gap-3">
          <p class="!m-0 text-sm text-slate-600 dark:text-slate-300">
            {{ t('SOURCES_HINT') }}
          </p>
          <div class="flex flex-wrap items-center gap-2">
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
          <p v-if="loadingCards" class="!m-0 text-sm text-slate-500">
            {{ t('LOADING') }}
          </p>
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

        <!-- Agenda / Tickets -->
        <div v-else-if="section === 'calendar'" class="flex flex-col gap-3">
          <p class="!m-0 text-sm text-slate-600 dark:text-slate-300">
            {{ t('CALENDAR_HINT') }}
          </p>
          <FichaCards
            v-model="items"
            :cards="cards"
            :only="['calendar']"
            :show-headers="false"
          />
        </div>
        <div v-else-if="section === 'tickets'" class="flex flex-col gap-3">
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

        <!-- Archivos -->
        <div v-else class="flex flex-col gap-3">
          <p class="!m-0 text-sm text-slate-600 dark:text-slate-300">
            {{ t('FILES_HINT') }}
          </p>
          <FichaFiles v-model="files" />
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

    <!-- Tu agente podrá -->
    <aside
      class="flex flex-col min-h-0 gap-3 p-4 border rounded-lg md:col-span-2 xl:col-span-1 border-slate-200 dark:border-slate-700 bg-slate-25 dark:bg-slate-800/40"
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

      <div class="flex flex-col gap-1 mt-auto">
        <woot-button
          icon="checkmark"
          :is-loading="creating"
          :is-disabled="!canCreate"
          @click="create"
        >
          {{ t('CREATE') }}
        </woot-button>
        <span class="text-xs text-center text-slate-500">
          {{ createHint }}
        </span>
      </div>
    </aside>
  </div>
</template>
