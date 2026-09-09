<script>
// proyecto@asistente_agentes_ia — F0
// ================================================================================
// Pantalla del Asistente de Agentes IA.
//
// En esta fase la pantalla solo existe y muestra el INVENTARIO de la cuenta (F1):
// qué fuentes hay conectadas con la directiva exacta de cada una, qué grupos de
// respuestas predefinidas, qué tipos de caso, qué etiquetas y cómo escriben los
// clientes. Es a propósito que se vea antes que la conversación: es el material
// con el que el asistente va a trabajar, y verlo primero deja claro por qué no
// puede inventar nombres.
//
// La entrevista (F3) y el comprobador (F2) entran en los paneles marcados abajo.
// ================================================================================
import AssistantAPI from 'dashboard/api/assistant';
import EmptyState from 'dashboard/components/widgets/EmptyState.vue';
import Spinner from 'shared/components/Spinner.vue';

export default {
  components: { EmptyState, Spinner },
  data() {
    return {
      inventory: null,
      isLoading: false,
      error: null,
    };
  },
  computed: {
    // Sin fuentes ni tipos de caso no hay de dónde proponer: el asistente tendría
    // que ofrecer arquetipos en vez de entrevistar sobre una cuenta vacía.
    isEmptyAccount() {
      return this.inventory?.empty;
    },
    // Fuentes guardadas que el asistente no sabe ofrecer. Se muestran en vez de
    // omitirlas: lo que desaparece sin avisar es lo que después nadie encuentra.
    unsupported() {
      return this.inventory?.unsupported || [];
    },
  },
  mounted() {
    this.fetchInventory();
  },
  methods: {
    async fetchInventory() {
      this.isLoading = true;
      this.error = null;
      try {
        const { data } = await AssistantAPI.getInventory();
        this.inventory = data;
      } catch (error) {
        this.error =
          error?.response?.status === 401
            ? this.$t('TRACKING_ASSISTANT_VIEW.ERROR_FORBIDDEN')
            : this.$t('TRACKING_ASSISTANT_VIEW.ERROR_GENERIC');
      } finally {
        this.isLoading = false;
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
        :is-loading="isLoading"
        @click="fetchInventory"
      >
        {{ $t('TRACKING_ASSISTANT_VIEW.REFRESH') }}
      </woot-button>
    </div>

    <div v-if="isLoading" class="flex items-center justify-center flex-1">
      <Spinner size="" />
    </div>

    <EmptyState v-else-if="error" :title="error" />

    <div v-else-if="inventory" class="flex-1 min-h-0 overflow-auto">
      <!-- Cuenta sin nada cargado: el asistente no tiene de dónde proponer. -->
      <EmptyState
        v-if="isEmptyAccount"
        :title="$t('TRACKING_ASSISTANT_VIEW.EMPTY_ACCOUNT_TITLE')"
        :message="$t('TRACKING_ASSISTANT_VIEW.EMPTY_ACCOUNT_HINT')"
      />

      <div v-else class="grid gap-4 md:grid-cols-2">
        <!-- Fuentes: lo más importante del inventario, porque la directiva de cada
             una es texto exacto que el Entrenamiento tiene que escribir igual. -->
        <section
          class="p-4 bg-white rounded-lg dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
        >
          <h2
            class="text-sm font-semibold text-slate-800 dark:text-slate-100 mb-3"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.SOURCES_TITLE') }}
          </h2>
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
              <span class="text-xs text-slate-500 dark:text-slate-400 shrink-0">
                {{ source.name }}
              </span>
            </li>
          </ul>

          <!-- Fuentes guardadas sin directiva conocida. -->
          <div v-if="unsupported.length" class="mt-4">
            <p class="text-xs text-amber-600 dark:text-amber-400">
              {{ $t('TRACKING_ASSISTANT_VIEW.UNSUPPORTED_HINT') }}
            </p>
            <ul class="mt-1">
              <li
                v-for="source in unsupported"
                :key="source.source_type + source.name"
                class="text-xs text-slate-500 dark:text-slate-400"
              >
                {{ source.name }} ({{ source.source_type }})
              </li>
            </ul>
          </div>
        </section>

        <section
          class="p-4 bg-white rounded-lg dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
        >
          <h2
            class="text-sm font-semibold text-slate-800 dark:text-slate-100 mb-3"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.CASE_TYPES_TITLE') }}
          </h2>
          <p class="text-xs text-slate-600 dark:text-slate-400">
            {{ inventory.case_types.join(' · ') }}
          </p>

          <h2
            class="text-sm font-semibold text-slate-800 dark:text-slate-100 mt-4 mb-2"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.LABELS_TITLE') }}
          </h2>
          <p class="text-xs text-slate-600 dark:text-slate-400">
            {{ inventory.labels.join(' · ') || '—' }}
          </p>

          <h2
            class="text-sm font-semibold text-slate-800 dark:text-slate-100 mt-4 mb-2"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.GROUPS_TITLE') }}
          </h2>
          <p class="text-xs text-slate-600 dark:text-slate-400">
            <span v-for="group in inventory.canned_groups" :key="group.prefix">
              {{ group.prefix }} ({{ group.count }})
            </span>
            <span v-if="!inventory.canned_groups.length">—</span>
          </p>
        </section>

        <!-- Las frases textuales importan: la descripción de una rama tiene que
             estar escrita en estas palabras, no en lenguaje de manual. -->
        <section
          class="p-4 bg-white rounded-lg dark:bg-slate-800 border border-slate-100 dark:border-slate-700 md:col-span-2"
        >
          <h2
            class="text-sm font-semibold text-slate-800 dark:text-slate-100 mb-1"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.PHRASES_TITLE') }}
          </h2>
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

        <!-- F2 y F3 entran acá. -->
        <section
          class="p-4 rounded-lg border border-dashed border-slate-200 dark:border-slate-700 md:col-span-2"
        >
          <p class="text-xs text-slate-500 dark:text-slate-400">
            {{ $t('TRACKING_ASSISTANT_VIEW.COMING_SOON') }}
          </p>
        </section>
      </div>
    </div>
  </div>
</template>
