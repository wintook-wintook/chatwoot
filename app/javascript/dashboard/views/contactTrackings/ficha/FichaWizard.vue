<script>
// feat/ficha_agente_ia — CREAR UN AGENTE EN UNOS CUANTOS CLICS
// ============================================================================
// Plan: docs/ficha_agente_ia_plan.md §4–§7.
//   ① Recursos     nombre, canal y lo que usa (tarjetas con casilla)
//   ② Qué hará     lo que puede hacer con eso (todo prendido), tono y datos del negocio
//   ③ Revisar      las rutas que se arman y el comprobador → [Crear agente]
// El Entrenamiento se escribe SIN IA (ContactTrackings::Ficha::Generator) y pasa por el
// mismo comprobador del editor. Después se afina en el chat o en el editor.
// ============================================================================
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import FichaAPI from 'dashboard/api/fichaAgente';
import FichaCards from './FichaCards.vue';

const STEPS = ['resources', 'offers', 'review'];
const TONES = ['cercano', 'profesional'];

export default {
  components: { FichaCards },
  emits: ['created', 'conversation'],
  data() {
    return {
      step: 'resources',
      name: '',
      inboxId: '',
      cards: [],
      items: [],
      skip: [],
      tone: 'cercano',
      objective: '',
      business: '',
      preview: null,
      loadingCards: false,
      loadingPreview: false,
      creating: false,
      showPrompt: false,
      timer: null,
      steps: STEPS,
      tones: TONES,
    };
  },
  computed: {
    ...mapGetters({ inboxes: 'inboxes/getInboxes' }),
    stepIndex() {
      return STEPS.indexOf(this.step);
    },
    canContinue() {
      if (this.step === 'resources')
        return this.name.trim().length >= 2 && this.items.length > 0;
      if (this.step === 'offers') return this.activeOffers.length > 0;
      return this.isValid && !this.creating;
    },
    offers() {
      return (this.preview && this.preview.offers) || [];
    },
    activeOffers() {
      return this.offers.filter(offer => !this.skip.includes(offer.key));
    },
    routes() {
      return (this.preview && this.preview.routes) || [];
    },
    validation() {
      return (this.preview && this.preview.validation) || {};
    },
    isValid() {
      return !!this.validation.valid;
    },
    warnings() {
      return [
        ...(this.validation.blocking || []),
        ...(this.validation.degrading || []),
      ];
    },
    generatedObjective() {
      return (this.preview && this.preview.objective) || '';
    },
    payload() {
      return {
        name: this.name.trim(),
        inbox_id: this.inboxId || null,
        items: this.items,
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
        if (this.step !== 'resources') this.schedulePreview();
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
    async next() {
      if (!this.canContinue) return;
      if (this.step === 'review') {
        this.create();
        return;
      }
      if (this.step === 'resources') await this.loadPreview();
      this.step = STEPS[this.stepIndex + 1];
    },
    back() {
      if (this.stepIndex > 0) this.step = STEPS[this.stepIndex - 1];
    },
    goTo(step) {
      if (STEPS.indexOf(step) < this.stepIndex) this.step = step;
    },
    async create() {
      this.creating = true;
      try {
        const { data } = await FichaAPI.create(this.payload);
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
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0 gap-4">
    <!-- Pasos -->
    <ol class="flex flex-wrap items-center gap-2 !m-0 !p-0 list-none shrink-0">
      <li
        v-for="(item, position) in steps"
        :key="item"
        class="flex items-center gap-2"
      >
        <button
          type="button"
          class="flex items-center gap-2 px-3 py-1.5 text-sm rounded-full"
          :class="
            step === item
              ? 'bg-woot-500 text-white'
              : position < stepIndex
              ? 'bg-woot-50 text-woot-700 dark:bg-woot-800 dark:text-woot-100'
              : 'bg-slate-100 text-slate-500 dark:bg-slate-800'
          "
          @click="goTo(item)"
        >
          <span class="font-semibold">{{ position + 1 }}</span>
          {{ t(`STEP_${item.toUpperCase()}`) }}
        </button>
        <fluent-icon
          v-if="position < steps.length - 1"
          icon="chevron-right"
          size="14"
          class="text-slate-400"
        />
      </li>
      <li class="flex-1" />
      <li>
        <woot-button
          size="small"
          variant="clear"
          color-scheme="secondary"
          icon="chat-multiple"
          @click="$emit('conversation')"
        >
          {{ t('USE_CONVERSATION') }}
        </woot-button>
      </li>
    </ol>

    <div class="flex-1 min-h-0 pr-1 overflow-auto">
      <!-- ① Recursos -->
      <div v-if="step === 'resources'" class="flex flex-col gap-5">
        <p class="!m-0 text-sm text-slate-600 dark:text-slate-300">
          {{ t('RESOURCES_HINT') }}
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
        </div>
        <p v-if="loadingCards" class="!m-0 text-sm text-slate-500">
          {{ t('LOADING') }}
        </p>
        <FichaCards v-else v-model="items" :cards="cards" show-files-hint />
      </div>

      <!-- ② Qué hará -->
      <div v-else-if="step === 'offers'" class="flex flex-col gap-5">
        <section class="flex flex-col gap-2">
          <h3
            class="!m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
          >
            {{ t('OFFERS_TITLE') }}
          </h3>
          <p class="!m-0 text-xs text-slate-500">{{ t('OFFERS_HINT') }}</p>
          <ul
            class="!m-0 !p-0 list-none border rounded-lg divide-y border-slate-200 dark:border-slate-700 divide-slate-100 dark:divide-slate-700"
          >
            <li
              v-for="offer in offers"
              :key="offer.key"
              class="flex items-start gap-2 px-3 py-2"
            >
              <input
                type="checkbox"
                class="!m-0 mt-1"
                :checked="!skip.includes(offer.key)"
                @change="toggleOffer(offer)"
              />
              <span class="flex flex-col">
                <span class="text-sm text-slate-800 dark:text-slate-100">
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
        </section>

        <section class="grid gap-3 sm:grid-cols-2">
          <label class="!m-0">
            {{ t('OBJECTIVE') }}
            <input
              v-model="objective"
              type="text"
              class="!mb-0"
              :placeholder="generatedObjective"
            />
            <span class="text-xs text-slate-500">{{
              t('OBJECTIVE_HINT')
            }}</span>
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
          <label class="!m-0 sm:col-span-2">
            {{ t('BUSINESS') }}
            <textarea
              v-model="business"
              rows="3"
              class="!mb-0"
              :placeholder="t('BUSINESS_PLACEHOLDER')"
            />
          </label>
        </section>
      </div>

      <!-- ③ Revisar -->
      <div v-else class="flex flex-col gap-4">
        <div
          class="flex items-center gap-2 px-3 py-2 text-sm rounded-lg"
          :class="
            isValid && !warnings.length
              ? 'bg-green-50 text-green-800 dark:bg-green-900/30 dark:text-green-200'
              : 'bg-amber-50 text-amber-800 dark:bg-amber-900/30 dark:text-amber-200'
          "
        >
          <fluent-icon
            :icon="isValid ? 'checkmark-circle' : 'warning'"
            size="16"
          />
          <span v-if="loadingPreview">{{ t('CHECKING') }}</span>
          <span v-else-if="isValid && !warnings.length">
            {{ t('VALID', { count: routes.length }) }}
          </span>
          <span v-else-if="isValid">
            {{ t('VALID_WITH_WARNINGS', { count: warnings.length }) }}
          </span>
          <span v-else>{{ t('INVALID') }}</span>
        </div>
        <ul v-if="warnings.length" class="!m-0 pl-5 text-xs text-amber-800">
          <li v-for="(item, index) in warnings" :key="index">
            {{ item.message }}
          </li>
        </ul>

        <section class="flex flex-col gap-2">
          <h3
            class="!m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
          >
            {{ t('ROUTES_TITLE', { name: name }) }}
          </h3>
          <ul
            class="!m-0 !p-0 list-none border rounded-lg divide-y border-slate-200 dark:border-slate-700 divide-slate-100 dark:divide-slate-700"
          >
            <li
              v-for="route in routes"
              :key="route.name"
              class="flex flex-col px-3 py-2"
            >
              <span class="text-sm text-slate-800 dark:text-slate-100">
                {{ route.label }}
              </span>
              <span class="text-xs text-slate-500">
                {{ t('WHEN', { text: route.description }) }}
              </span>
            </li>
          </ul>
          <p class="!m-0 text-xs text-slate-500">{{ t('AFTER_CREATE') }}</p>
        </section>

        <woot-button
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
          class="p-3 font-mono text-xs whitespace-pre-wrap rounded-lg bg-slate-50 dark:bg-slate-800 text-slate-700 dark:text-slate-200"
        >
          {{ preview.prompt }}
        </div>
      </div>
    </div>

    <!-- Botones -->
    <div
      class="flex items-center justify-between gap-2 pt-3 border-t shrink-0 border-slate-100 dark:border-slate-700"
    >
      <woot-button
        v-if="stepIndex > 0"
        variant="clear"
        color-scheme="secondary"
        icon="chevron-left"
        @click="back"
      >
        {{ t('BACK') }}
      </woot-button>
      <span v-else class="text-xs text-slate-500">
        {{ t('SELECTED', { count: items.length }) }}
      </span>
      <woot-button
        :icon="step === 'review' ? 'checkmark' : 'arrow-right'"
        :is-loading="creating || (step !== 'resources' && loadingPreview)"
        :is-disabled="!canContinue"
        @click="next"
      >
        {{ step === 'review' ? t('CREATE') : t('NEXT') }}
      </woot-button>
    </div>
  </div>
</template>
