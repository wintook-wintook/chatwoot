<script>
// proyecto@publicar_prompts (F4) — LA GALERÍA DE PROMPTS PUBLICADOS
// ============================================================================
// Los prompts que otras cuentas publicaron se ven y se bajan SOLO desde el
// Asistente (decisión del usuario, 05/10/2026): de aquí se parte para adecuarlos a
// la cuenta. Dos vistas en el mismo modal: la lista (buscar, filtrar por categoría)
// y el detalle con el prompt completo en solo lectura.
//
// F5: «Bajar a mi cuenta» está SOLO en el detalle: se elige un prompt y se baja ese
// (pedido del usuario: nada de bajar todos). Emite `installed` con la respuesta de la
// API y la vista del Asistente abre la copia para adecuarla.
// Plan: docs/publicar_prompts_plan.md
// ============================================================================
import { useAlert } from 'dashboard/composables';
import Spinner from 'shared/components/Spinner.vue';
import AssistantAPI from 'dashboard/api/assistant';

const SEARCH_DELAY_MS = 300;

export default {
  components: { Spinner },
  props: {
    show: { type: Boolean, default: false },
  },
  emits: ['close', 'installed'],
  data() {
    return {
      isLoading: false,
      hasError: false,
      prompts: [],
      categories: [],
      query: '',
      category: '',
      selected: null,
      isLoadingDetail: false,
      isInstalling: false,
    };
  },
  watch: {
    show(visible) {
      if (!visible) return;
      this.selected = null;
      this.fetchList();
    },
    query() {
      clearTimeout(this.searchTimer);
      this.searchTimer = setTimeout(this.fetchList, SEARCH_DELAY_MS);
    },
    category() {
      this.fetchList();
    },
  },
  beforeDestroy() {
    clearTimeout(this.searchTimer);
  },
  methods: {
    async fetchList() {
      this.isLoading = true;
      this.hasError = false;
      try {
        const { data } = await AssistantAPI.getPublishedPrompts({
          q: this.query.trim(),
          category: this.category,
        });
        this.prompts = data.published_prompts || [];
        this.categories = data.categories || [];
      } catch (error) {
        this.hasError = true;
      } finally {
        this.isLoading = false;
      }
    },
    async openDetail(prompt) {
      this.selected = { ...prompt };
      this.isLoadingDetail = true;
      try {
        const { data } = await AssistantAPI.getPublishedPrompt(prompt.id);
        this.selected = data;
      } catch (error) {
        // Despublicada entre la lista y el clic: se vuelve a la lista actualizada.
        this.selected = null;
        this.fetchList();
      } finally {
        this.isLoadingDetail = false;
      }
    },
    async install() {
      if (!this.selected || this.isInstalling) return;
      this.isInstalling = true;
      try {
        const { data } = await AssistantAPI.installPublishedPrompt(
          this.selected.id
        );
        this.$emit('installed', data);
      } catch (error) {
        useAlert(this.$t('TRACKING_ASSISTANT_VIEW.GALLERY.INSTALL_ERROR'));
      } finally {
        this.isInstalling = false;
      }
    },
    categoryText(category) {
      if (!category) return '';
      return this.$t(
        `TRACKING_TEMPLATES.PUBLISH.CATEGORIES.${category.toUpperCase()}`
      );
    },
    requirementText(req) {
      const kind = this.$t(
        `TRACKING_TEMPLATES.PUBLISH.REQUIREMENTS.${req.kind.toUpperCase()}`
      );
      return req.name ? `${kind}: ${req.name}` : kind;
    },
    metaText(prompt) {
      return this.$t('TRACKING_ASSISTANT_VIEW.GALLERY.META', {
        author: prompt.author || '—',
        version: prompt.version,
        downloads: prompt.downloads_count,
      });
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="() => $emit('close')" size="medium">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="$t('TRACKING_ASSISTANT_VIEW.GALLERY.TITLE')"
        :header-content="$t('TRACKING_ASSISTANT_VIEW.GALLERY.DESCRIPTION')"
      />

      <!-- LISTA -->
      <div v-if="!selected" class="flex flex-col gap-3 px-8 pb-6">
        <div class="flex items-center gap-2">
          <input
            v-model="query"
            type="search"
            class="!mb-0 flex-1"
            :placeholder="$t('TRACKING_ASSISTANT_VIEW.GALLERY.SEARCH')"
          />
          <select v-model="category" class="!mb-0 !w-48">
            <option value="">
              {{ $t('TRACKING_ASSISTANT_VIEW.GALLERY.ALL_CATEGORIES') }}
            </option>
            <option v-for="cat in categories" :key="cat" :value="cat">
              {{ categoryText(cat) }}
            </option>
          </select>
        </div>

        <div v-if="isLoading" class="flex justify-center py-8">
          <Spinner size="" />
        </div>
        <p
          v-else-if="hasError"
          class="py-6 mb-0 text-sm text-center text-red-600 dark:text-red-400"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.GALLERY.LOAD_ERROR') }}
        </p>
        <p
          v-else-if="!prompts.length"
          class="py-6 mb-0 text-sm text-center text-slate-500 dark:text-slate-400"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.GALLERY.EMPTY') }}
        </p>
        <ul v-else class="flex flex-col gap-2 max-h-[28rem] overflow-y-auto">
          <li v-for="prompt in prompts" :key="prompt.id">
            <button
              type="button"
              class="w-full p-3 text-left bg-white border rounded-md border-slate-100 dark:border-slate-700 dark:bg-slate-900 hover:border-woot-500"
              @click="openDetail(prompt)"
            >
              <span class="flex items-center gap-2">
                <span
                  class="text-sm font-medium truncate text-slate-800 dark:text-slate-100"
                >
                  {{ prompt.title }}
                </span>
                <woot-label
                  v-if="prompt.category"
                  small
                  :title="categoryText(prompt.category)"
                  color-scheme="secondary"
                />
                <woot-label
                  v-if="prompt.own"
                  small
                  :title="$t('TRACKING_ASSISTANT_VIEW.GALLERY.OWN')"
                  color-scheme="primary"
                />
              </span>
              <span
                v-if="prompt.description"
                class="block mt-1 text-xs text-slate-600 dark:text-slate-300 line-clamp-2"
              >
                {{ prompt.description }}
              </span>
              <span
                class="block mt-1 text-xs text-slate-500 dark:text-slate-400"
              >
                {{ metaText(prompt) }}
              </span>
            </button>
          </li>
        </ul>
      </div>

      <!-- DETALLE (solo lectura) -->
      <div v-else class="flex flex-col gap-3 px-8 pb-6">
        <div class="flex items-center justify-between gap-2">
          <woot-button
            variant="clear"
            color-scheme="secondary"
            size="small"
            icon="chevron-left"
            @click="selected = null"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.GALLERY.BACK') }}
          </woot-button>
          <woot-button
            size="small"
            color-scheme="success"
            icon="arrow-download"
            :is-loading="isInstalling"
            :is-disabled="isLoadingDetail"
            @click="install"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.GALLERY.INSTALL') }}
          </woot-button>
        </div>
        <div>
          <h3
            class="mb-1 text-base font-semibold text-slate-800 dark:text-slate-100"
          >
            {{ selected.title }}
          </h3>
          <p class="mb-0 text-xs text-slate-500 dark:text-slate-400">
            {{ metaText(selected) }}
          </p>
          <p
            v-if="selected.description"
            class="mt-2 mb-0 text-sm text-slate-700 dark:text-slate-200"
          >
            {{ selected.description }}
          </p>
        </div>

        <div v-if="isLoadingDetail" class="flex justify-center py-8">
          <Spinner size="" />
        </div>
        <template v-else>
          <div
            class="p-3 text-sm border rounded-md border-slate-100 dark:border-slate-700 bg-slate-25 dark:bg-slate-800 text-slate-700 dark:text-slate-200"
          >
            <p class="mb-1 font-medium">
              {{ $t('TRACKING_ASSISTANT_VIEW.GALLERY.REQUIREMENTS_TITLE') }}
            </p>
            <ul
              v-if="selected.requirements && selected.requirements.length"
              class="mb-0 list-disc ltr:ml-5 rtl:mr-5"
            >
              <li
                v-for="req in selected.requirements"
                :key="req.kind + (req.name || '')"
              >
                {{ requirementText(req) }}
              </li>
            </ul>
            <p v-else class="mb-0">
              {{ $t('TRACKING_ASSISTANT_VIEW.GALLERY.NO_REQUIREMENTS') }}
            </p>
          </div>

          <div v-if="selected.objective">
            <p
              class="mb-1 text-xs font-medium text-slate-600 dark:text-slate-300"
            >
              {{ $t('TRACKING_ASSISTANT_VIEW.GALLERY.OBJECTIVE') }}
            </p>
            <p class="mb-0 text-sm text-slate-800 dark:text-slate-100">
              {{ selected.objective }}
            </p>
          </div>

          <div v-if="selected.ai_context">
            <p
              class="mb-1 text-xs font-medium text-slate-600 dark:text-slate-300"
            >
              {{ $t('TRACKING_ASSISTANT_VIEW.GALLERY.CONTEXT') }}
            </p>
            <p
              class="mb-0 text-sm whitespace-pre-wrap text-slate-800 dark:text-slate-100"
            >
              {{ selected.ai_context }}
            </p>
          </div>

          <div v-if="selected.prompt">
            <p
              class="mb-1 text-xs font-medium text-slate-600 dark:text-slate-300"
            >
              {{ $t('TRACKING_ASSISTANT_VIEW.GALLERY.PROMPT') }}
            </p>
            <!-- Un textarea de solo lectura y no un <pre>: respeta los saltos de
                 línea sin que el formateo de la plantilla le meta espacios. -->
            <textarea
              :value="selected.prompt"
              readonly
              rows="14"
              class="!mb-0 font-mono text-xs"
            />
          </div>
        </template>
      </div>
    </div>
  </woot-modal>
</template>
