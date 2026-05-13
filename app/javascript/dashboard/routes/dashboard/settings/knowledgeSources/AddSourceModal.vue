<!-- @knowledge_sources -->
<!-- Modal para agregar o editar una fuente de conocimiento. -->
<script>
import KnowledgeBaseAPI from './api';

export default {
  name: 'AddKnowledgeSourceModal',
  props: {
    show:   { type: Boolean, default: false },
    saving: { type: Boolean, default: false },
    source: { type: Object, default: null },   // null = crear, objeto = editar
  },
  emits: ['close', 'save'],
  data() {
    return {
      activeTab: 0,
      sourceType: 'discourse',
      name: '',
      discourseUrl: '',
      discourseApiKey: '',
      discourseWebhookSecret: '',
      showWebhookSecret: false,
      availableCategories: [],
      selectedCategoryIds: [],
      loadingCategories: false,
      categoriesError: '',
      sourceOptions: [
        { value: 'discourse', label: 'Discourse', icon: 'globe' },
      ],
    };
  },
  computed: {
    isEdit() {
      return !!this.source;
    },
    modalTitle() {
      return this.isEdit ? 'Editar Fuente de Conocimiento' : 'Agregar Fuente de Conocimiento';
    },
    saveLabel() {
      if (this.saving) return this.isEdit ? 'Guardando...' : 'Guardando...';
      return this.isEdit ? 'Guardar cambios' : 'Agregar fuente';
    },
    isValid() {
      if (!this.name.trim()) return false;
      if (this.sourceType === 'discourse') {
        if (!this.discourseUrl.trim()) return false;
        if (!this.discourseApiKey.trim()) return false;
        if (!this.discourseWebhookSecret.trim()) return false;
      }
      return true;
    },
    isDiscourse() {
      return this.sourceType === 'discourse';
    },
    canLoadCategories() {
      return this.discourseUrl.trim().length > 0;
    },
    tabs() {
      const base = [{ label: 'Configuración', key: 'config' }];
      if (this.isDiscourse) {
        const badge = this.selectedCategoryIds.length
          ? ` (${this.selectedCategoryIds.length})`
          : '';
        base.push({ label: `Categorías${badge}`, key: 'categories' });
      }
      return base;
    },
  },
  watch: {
    sourceType() {
      this.name = '';
      this.activeTab = 0;
    },
    show(val) {
      if (val) {
        this.populate();
      } else {
        this.reset();
      }
    },
    discourseUrl(newVal, oldVal) {
      if (oldVal === '') return; // skip reset during populate (first assignment)
      this.availableCategories = [];
      this.selectedCategoryIds = [];
      this.categoriesError = '';
    },
  },
  methods: {
    generateSecret() {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
      this.discourseWebhookSecret = Array.from(
        { length: 20 },
        () => chars[Math.floor(Math.random() * chars.length)]
      ).join('');
    },
    populate() {
      if (!this.source) {
        this.generateSecret();
        return;
      }
      this.sourceType = this.source.source_type || 'discourse';
      this.name = this.source.name || '';
      this.discourseUrl = this.source.config?.url || '';
      this.discourseApiKey = this.source.config?.api_key || '';
      this.discourseWebhookSecret = this.source.config?.webhook_secret || '';
      this.selectedCategoryIds = this.source.config?.category_ids || [];
      this.availableCategories = [];
      this.categoriesError = '';
      this.activeTab = 0;
      if (this.source.source_type === 'discourse' && this.discourseUrl) {
        this.$nextTick(() => this.loadCategories());
      }
    },
    reset() {
      this.activeTab = 0;
      this.sourceType = 'discourse';
      this.name = '';
      this.discourseUrl = '';
      this.discourseApiKey = '';
      this.discourseWebhookSecret = '';
      this.showWebhookSecret = false;
      this.availableCategories = [];
      this.selectedCategoryIds = [];
      this.loadingCategories = false;
      this.categoriesError = '';
    },
    onClose() {
      this.reset();
      this.$emit('close');
    },
    async loadCategories() {
      if (!this.canLoadCategories) return;
      this.loadingCategories = true;
      this.categoriesError = '';
      this.availableCategories = [];
      try {
        const accountId = this.$store.getters['getCurrentUser'].account_id;
        const { data } = await KnowledgeBaseAPI.getDiscourseCategories(accountId, {
          url: this.discourseUrl.trim(),
          api_key: this.discourseApiKey.trim(),
        });
        this.availableCategories = data.categories || [];
        // Mantener las categorías ya seleccionadas al recargar
        if (!this.availableCategories.length) {
          this.categoriesError = 'No se encontraron categorías. Verifica la URL y la API Key.';
        }
      } catch (err) {
        this.categoriesError =
          err?.response?.data?.error || 'No se pudo conectar con Discourse. Verifica la URL.';
      } finally {
        this.loadingCategories = false;
      }
    },
    toggleCategory(id) {
      if (this.selectedCategoryIds.includes(id)) {
        this.selectedCategoryIds = this.selectedCategoryIds.filter(c => c !== id);
      } else {
        this.selectedCategoryIds = [...this.selectedCategoryIds, id];
      }
    },
    onSave() {
      if (!this.isValid) return;
      const payload = {
        source_type: this.sourceType,
        name: this.name.trim(),
        config: this.isDiscourse
          ? {
              url: this.discourseUrl.trim(),
              api_key: this.discourseApiKey.trim(),
              api_username: 'system',
              webhook_secret: this.discourseWebhookSecret.trim(),
              category_ids: this.selectedCategoryIds.length ? this.selectedCategoryIds : null,
            }
          : {},
      };
      this.$emit('save', payload);
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="onClose">
    <div class="flex flex-col gap-4 p-6 w-full">
      <woot-modal-header
        :header-title="modalTitle"
        header-content="Configura una nueva fuente para indexar en la base de conocimiento."
      />

      <!-- Tabs -->
      <woot-tabs :index="activeTab" @change="activeTab = $event">
        <woot-tabs-item
          v-for="tab in tabs"
          :key="tab.key"
          :name="tab.label"
          :show-badge="false"
        />
      </woot-tabs>

      <!-- Contenido de tabs — altura fija para que el modal no cambie de tamaño -->
      <div class="h-[420px] overflow-y-auto flex flex-col gap-4">

      <!-- Tab: Configuración -->
      <template v-if="activeTab === 0">
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-slate-700">Nombre</label>
          <input
            v-model="name"
            type="text"
            class="input"
            placeholder="Ej: Foro de Soporte"
          />
        </div>

        <template v-if="isDiscourse">
          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-slate-700">URL del foro</label>
            <input
              v-model="discourseUrl"
              type="url"
              class="input"
              placeholder="https://foro.ejemplo.com"
            />
          </div>

          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-slate-700">API Key</label>
            <input
              v-model="discourseApiKey"
              type="password"
              class="input"
              placeholder="api_key de Discourse"
            />
          </div>

          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-slate-700">Webhook Secret</label>
            <div class="flex items-start gap-1.5">
              <woot-input
                :value="discourseWebhookSecret"
                class="flex-1 [&>input]:!py-1.5 ltr:[&>input]:!pr-9 ltr:[&>input]:!pl-3 rtl:[&>input]:!pl-9 rtl:[&>input]:!pr-3 relative"
                :styles="{ borderRadius: '12px', fontSize: '14px', marginBottom: '2px' }"
                :type="showWebhookSecret ? 'text' : 'password'"
                placeholder="Secreto HMAC"
                @input="discourseWebhookSecret = $event"
              >
                <template #masked>
                  <button
                    type="button"
                    class="absolute top-1.5 ltr:right-0.5 rtl:left-0.5"
                    @click="showWebhookSecret = !showWebhookSecret"
                  >
                    <fluent-icon :icon="showWebhookSecret ? 'eye-show' : 'eye-hide'" size="16" />
                  </button>
                </template>
              </woot-input>
              <button
                type="button"
                :disabled="isEdit"
                v-tooltip="isEdit ? 'No se puede cambiar el secreto de un webhook existente' : 'Generar nuevo secreto'"
                class="flex-shrink-0 flex items-center justify-center w-9 h-9 rounded-lg border border-slate-200 transition-colors mt-0.5"
                :class="isEdit ? 'text-slate-300 cursor-not-allowed' : 'text-slate-500 hover:text-slate-700 hover:bg-slate-50'"
                @click="!isEdit && generateSecret()"
              >
                <fluent-icon icon="arrow-clockwise" size="15" />
              </button>
            </div>
            <p class="text-xs text-slate-400">
              Se configura automáticamente en Discourse al guardar.
            </p>
          </div>
        </template>
      </template>

      <!-- Tab: Categorías -->
      <template v-else-if="activeTab === 1 && isDiscourse">
        <div class="flex flex-col gap-3">
          <div class="flex items-center justify-between">
            <p class="text-sm text-slate-500">
              Selecciona las categorías a indexar.
              <span class="text-slate-400">Vacío = todas.</span>
            </p>
            <woot-button
              size="small"
              variant="smooth"
              color-scheme="secondary"
              :disabled="!canLoadCategories || loadingCategories"
              @click="loadCategories"
            >
              {{ loadingCategories ? 'Cargando...' : availableCategories.length ? 'Recargar' : 'Cargar categorías' }}
            </woot-button>
          </div>

          <!-- Categorías ya seleccionadas (sin haber cargado la lista aún) -->
          <p
            v-if="selectedCategoryIds.length && !availableCategories.length && !loadingCategories && !categoriesError"
            class="text-xs text-woot-600"
          >
            {{ selectedCategoryIds.length }} categoría(s) seleccionada(s) previamente. Carga la lista para modificarlas.
          </p>

          <!-- Error -->
          <p v-if="categoriesError" class="text-xs text-red-500">{{ categoriesError }}</p>

          <!-- Lista -->
          <div
            v-if="availableCategories.length"
            class="border border-slate-200 rounded-lg overflow-hidden"
          >
            <div class="divide-y divide-slate-100">
              <label
                v-for="cat in availableCategories"
                :key="cat.id"
                class="flex items-center gap-3 px-3 py-2 cursor-pointer hover:bg-slate-50 transition-colors"
              >
                <input
                  type="checkbox"
                  :value="cat.id"
                  :checked="selectedCategoryIds.includes(cat.id)"
                  class="rounded"
                  @change="toggleCategory(cat.id)"
                />
                <span class="text-sm text-slate-700 flex-1">{{ cat.name }}</span>
                <span class="text-xs text-slate-400">{{ cat.topic_count }} topics</span>
              </label>
            </div>
            <div
              v-if="selectedCategoryIds.length"
              class="px-3 py-1.5 bg-slate-50 border-t border-slate-200 text-xs text-slate-500"
            >
              {{ selectedCategoryIds.length }} categoría(s) seleccionada(s)
            </div>
          </div>

          <p v-else-if="!loadingCategories && !categoriesError && !selectedCategoryIds.length" class="text-xs text-slate-400">
            Ingresa la URL en "Configuración" y haz clic en "Cargar categorías".
          </p>
        </div>
      </template>

      </div><!-- /tab content -->

      <div class="flex justify-end gap-2 pt-2">
        <woot-button variant="clear" @click="onClose">Cancelar</woot-button>
        <woot-button :disabled="!isValid || saving" @click="onSave">
          {{ saveLabel }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
