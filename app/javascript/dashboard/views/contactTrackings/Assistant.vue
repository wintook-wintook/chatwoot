<script>
// proyecto@asistente_agentes_ia — F0 · F4
// ============================================================================
// Pantalla del Asistente de Agentes IA: dos paneles.
//
//   IZQUIERDA  la conversación — pregunta qué querés que haga el agente
//   DERECHA    el Entrenamiento escribiéndose, editable a mano
//   ABAJO      lo que el motor va a leer, revalidado en cada cambio
//
// La segunda pestaña muestra el inventario: con qué material trabaja el asistente.
// No es decorativa — ahí se ven las frases de clientes YA enmascaradas, que son
// exactamente las que salen hacia OpenAI. Lo que se ve es lo que se manda.
//
// El panel de abajo es lo que hace distinta a esta pantalla de un editor de
// texto: antes de guardar se ve, en las palabras del motor, qué ramas reconoció
// y en qué fuente va a buscar cada una. Y por eso se revalida al teclear — el
// comprobador es una función pura, así que no cuesta nada.
//
// Guardar queda apagado mientras haya un hallazgo bloqueante: guardar un agente
// que no ejecuta nada es exactamente el problema que este módulo vino a arreglar.
// ============================================================================
import AssistantAPI from 'dashboard/api/assistant';
import EmptyState from 'dashboard/components/widgets/EmptyState.vue';
import Spinner from 'shared/components/Spinner.vue';
import InterviewPanel from './assistant/InterviewPanel.vue';
import ValidationReport from './assistant/ValidationReport.vue';
import SaveModal from './assistant/SaveModal.vue';

// El teclado va más rápido que un request: se espera a que la persona pare.
const VALIDATE_DEBOUNCE_MS = 400;

export default {
  components: {
    EmptyState,
    Spinner,
    InterviewPanel,
    ValidationReport,
    SaveModal,
  },
  data() {
    return {
      inventory: null,
      isLoadingInventory: false,
      inventoryError: null,
      messages: [],
      isThinking: false,
      draft: '',
      validation: null,
      isChecking: false,
      showSaveModal: false,
      isSaving: false,
      saveError: '',
      validateTimer: null,
      activeTab: 0,
    };
  },
  computed: {
    isEmptyAccount() {
      return this.inventory?.empty;
    },
    unsupported() {
      return this.inventory?.unsupported || [];
    },
    hasBlocking() {
      return Boolean(this.validation?.blocking?.length);
    },
    canSave() {
      return this.draft.trim().length > 0 && !this.hasBlocking;
    },
    inboxes() {
      return this.$store.getters['inboxes/getInboxes'] || [];
    },
    templates() {
      return (
        this.$store.getters['trackingTemplates/getTrackingTemplates'] || []
      );
    },
  },
  mounted() {
    this.fetchInventory();
    this.$store.dispatch('inboxes/get');
    this.$store.dispatch('trackingTemplates/get');
  },
  beforeUnmount() {
    clearTimeout(this.validateTimer);
  },
  methods: {
    async fetchInventory() {
      this.isLoadingInventory = true;
      this.inventoryError = null;
      try {
        const { data } = await AssistantAPI.getInventory();
        this.inventory = data;
      } catch (error) {
        this.inventoryError =
          error?.response?.status === 401
            ? this.$t('TRACKING_ASSISTANT_VIEW.ERROR_FORBIDDEN')
            : this.$t('TRACKING_ASSISTANT_VIEW.ERROR_GENERIC');
      } finally {
        this.isLoadingInventory = false;
      }
    },
    async sendMessage(content) {
      this.messages.push({ role: 'user', content });
      this.isThinking = true;
      try {
        const { data } = await AssistantAPI.interview(this.messages);
        this.messages.push({ role: 'assistant', content: data.reply });
        if (data.draft) {
          this.draft = data.draft;
          this.validation = data.validation;
        }
      } catch (error) {
        const reason =
          error?.response?.data?.error === 'no_api_key'
            ? this.$t('TRACKING_ASSISTANT_VIEW.ERROR_NO_KEY')
            : this.$t('TRACKING_ASSISTANT_VIEW.ERROR_GENERIC');
        this.messages.push({ role: 'assistant', content: reason });
      } finally {
        this.isThinking = false;
      }
    },
    // Se revalida también cuando la persona edita a mano: el borrador del modelo
    // no es más confiable que el suyo, y ninguno de los dos se guarda sin pasar.
    onDraftInput() {
      clearTimeout(this.validateTimer);
      this.validateTimer = setTimeout(this.validateDraft, VALIDATE_DEBOUNCE_MS);
    },
    async validateDraft() {
      if (!this.draft.trim()) {
        this.validation = null;
        return;
      }
      this.isChecking = true;
      try {
        const { data } = await AssistantAPI.validate(this.draft);
        this.validation = data;
      } catch (error) {
        this.validation = null;
      } finally {
        this.isChecking = false;
      }
    },
    async saveDraft(payload) {
      this.isSaving = true;
      this.saveError = '';
      try {
        const { data } = await AssistantAPI.save({
          ...payload,
          draft: this.draft,
        });
        this.showSaveModal = false;
        this.$router.push({
          name: 'contact_trackings_agents',
          query: { template_id: data.tracking_template_id },
        });
      } catch (error) {
        const details = error?.response?.data?.details;
        this.saveError = Array.isArray(details)
          ? details.join(' · ')
          : this.$t('TRACKING_ASSISTANT_VIEW.ERROR_GENERIC');
      } finally {
        this.isSaving = false;
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 w-full h-full min-h-0 overflow-hidden p-4">
    <div class="flex items-start justify-between mb-3 shrink-0">
      <div class="flex items-start gap-2">
        <woot-sidemenu-icon />
        <div>
          <h1 class="text-xl font-bold text-slate-800 dark:text-slate-100">
            {{ $t('TRACKING_ASSISTANT_VIEW.TITLE') }}
          </h1>
          <p class="text-sm text-slate-600 dark:text-slate-400 mt-1">
            {{ $t('TRACKING_ASSISTANT_VIEW.DESCRIPTION') }}
          </p>
        </div>
      </div>
      <woot-button
        variant="clear"
        icon="arrow-clockwise"
        :is-loading="isLoadingInventory"
        @click="fetchInventory"
      >
        {{ $t('TRACKING_ASSISTANT_VIEW.REFRESH') }}
      </woot-button>
    </div>

    <div
      v-if="isLoadingInventory"
      class="flex items-center justify-center flex-1"
    >
      <Spinner size="" />
    </div>

    <EmptyState v-else-if="inventoryError" :title="inventoryError" />

    <div v-else-if="inventory" class="flex-1 min-h-0 flex flex-col">
      <!-- Cuenta sin nada cargado: no hay de dónde proponer. -->
      <EmptyState
        v-if="isEmptyAccount"
        :title="$t('TRACKING_ASSISTANT_VIEW.EMPTY_ACCOUNT_TITLE')"
        :message="$t('TRACKING_ASSISTANT_VIEW.EMPTY_ACCOUNT_HINT')"
      />

      <template v-else>
        <woot-tabs
          :index="activeTab"
          class="mb-4 shrink-0"
          @change="activeTab = $event"
        >
          <woot-tabs-item
            :index="0"
            :name="$t('TRACKING_ASSISTANT_VIEW.TAB_ASSISTANT')"
            :show-badge="false"
          />
          <woot-tabs-item
            :index="1"
            :name="$t('TRACKING_ASSISTANT_VIEW.TAB_INVENTORY')"
            :show-badge="false"
          />
        </woot-tabs>

        <div
          v-show="activeTab === 0"
          class="flex-1 min-h-0 grid gap-4 md:grid-cols-2"
        >
          <section
            class="p-4 bg-white rounded-lg dark:bg-slate-800 border border-slate-100 dark:border-slate-700 flex flex-col min-h-0"
          >
            <InterviewPanel
              :messages="messages"
              :is-thinking="isThinking"
              @send="sendMessage"
            />
          </section>

          <section class="flex flex-col gap-4 min-h-0 overflow-y-auto">
            <div
              class="p-4 bg-white rounded-lg dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
            >
              <h3
                class="text-sm font-semibold text-slate-800 dark:text-slate-100 mb-2"
              >
                {{ $t('TRACKING_ASSISTANT_VIEW.DRAFT_TITLE') }}
              </h3>
              <textarea
                v-model="draft"
                rows="14"
                class="w-full font-mono text-xs"
                :placeholder="$t('TRACKING_ASSISTANT_VIEW.DRAFT_PLACEHOLDER')"
                @input="onDraftInput"
              />
            </div>

            <ValidationReport
              :validation="validation"
              :is-checking="isChecking"
            />

            <!-- Fuentes guardadas que el asistente no sabe ofrecer. -->
            <p
              v-if="unsupported.length"
              class="text-xs text-amber-600 dark:text-amber-400"
            >
              {{ $t('TRACKING_ASSISTANT_VIEW.UNSUPPORTED_HINT') }}
              {{ unsupported.map(s => s.name).join(' · ') }}
            </p>
          </section>
        </div>

        <!-- Con qué material trabaja el asistente. Las frases van enmascaradas:
             son las mismas que salen hacia OpenAI. -->
        <div
          v-show="activeTab === 1"
          class="flex-1 min-h-0 overflow-y-auto grid gap-4 md:grid-cols-2"
        >
          <section
            class="p-4 bg-white rounded-lg dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
          >
            <h3
              class="text-sm font-semibold text-slate-800 dark:text-slate-100 mb-3"
            >
              {{ $t('TRACKING_ASSISTANT_VIEW.SOURCES_TITLE') }}
            </h3>
            <ul class="flex flex-col gap-2">
              <li
                v-for="source in inventory.sources"
                :key="source.directive"
                class="flex items-center justify-between gap-3"
              >
                <code
                  class="text-xs px-2 py-1 rounded bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-slate-100 truncate"
                >
                  {{ source.directive }}
                </code>
                <span
                  class="text-xs text-slate-500 dark:text-slate-400 shrink-0"
                >
                  {{ source.name }}
                </span>
              </li>
            </ul>
          </section>

          <section
            class="p-4 bg-white rounded-lg dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
          >
            <h3
              class="text-sm font-semibold text-slate-800 dark:text-slate-100 mb-2"
            >
              {{ $t('TRACKING_ASSISTANT_VIEW.CASE_TYPES_TITLE') }}
            </h3>
            <p class="text-xs text-slate-600 dark:text-slate-400">
              {{ inventory.case_types.join(' · ') || '—' }}
            </p>

            <h3
              class="text-sm font-semibold text-slate-800 dark:text-slate-100 mt-4 mb-2"
            >
              {{ $t('TRACKING_ASSISTANT_VIEW.LABELS_TITLE') }}
            </h3>
            <p class="text-xs text-slate-600 dark:text-slate-400">
              {{ inventory.labels.join(' · ') || '—' }}
            </p>

            <h3
              class="text-sm font-semibold text-slate-800 dark:text-slate-100 mt-4 mb-2"
            >
              {{ $t('TRACKING_ASSISTANT_VIEW.GROUPS_TITLE') }}
            </h3>
            <p class="text-xs text-slate-600 dark:text-slate-400">
              <span
                v-for="group in inventory.canned_groups"
                :key="group.prefix"
              >
                {{ group.prefix }} ({{ group.count }})
              </span>
              <span v-if="!inventory.canned_groups.length">—</span>
            </p>
          </section>

          <section
            class="p-4 bg-white rounded-lg dark:bg-slate-800 border border-slate-100 dark:border-slate-700 md:col-span-2"
          >
            <h3
              class="text-sm font-semibold text-slate-800 dark:text-slate-100 mb-1"
            >
              {{ $t('TRACKING_ASSISTANT_VIEW.PHRASES_TITLE') }}
            </h3>
            <p class="text-xs text-slate-500 dark:text-slate-400 mb-3">
              {{ $t('TRACKING_ASSISTANT_VIEW.PHRASES_HINT') }}
            </p>
            <ul class="flex flex-col gap-1">
              <li
                v-for="phrase in inventory.customer_phrases"
                :key="phrase"
                class="text-xs text-slate-600 dark:text-slate-400"
              >
                · {{ phrase }}
              </li>
              <li
                v-if="!inventory.customer_phrases.length"
                class="text-xs text-slate-500 dark:text-slate-400"
              >
                {{ $t('TRACKING_ASSISTANT_VIEW.PHRASES_EMPTY') }}
              </li>
            </ul>
          </section>
        </div>

        <div
          v-show="activeTab === 0"
          class="flex justify-end gap-2 pt-4 shrink-0"
        >
          <woot-button :is-disabled="!canSave" @click="showSaveModal = true">
            {{ $t('TRACKING_ASSISTANT_VIEW.SAVE_CTA') }}
          </woot-button>
        </div>
      </template>
    </div>

    <SaveModal
      :show="showSaveModal"
      :templates="templates"
      :inboxes="inboxes"
      :is-saving="isSaving"
      :error="saveError"
      @close="showSaveModal = false"
      @save="saveDraft"
    />
  </div>
</template>
