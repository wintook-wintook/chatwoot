<!-- @knowledge_sources -->
<!-- Modal para agregar una nueva fuente de conocimiento. -->
<script>
export default {
  name: 'AddKnowledgeSourceModal',
  props: {
    show: { type: Boolean, default: false },
    saving: { type: Boolean, default: false },
  },
  emits: ['close', 'save'],
  data() {
    return {
      sourceType: 'discourse',
      name: '',
      discourseUrl: '',
      discourseApiKey: '',
      discourseApiUsername: 'system',
      discourseWebhookSecret: '',
      discourseCategoryId: '',
      sourceOptions: [
        { value: 'discourse', label: 'Discourse', icon: 'globe' },
      ],
    };
  },
  computed: {
    isValid() {
      if (!this.name.trim()) return false;
      if (this.sourceType === 'discourse' && !this.discourseUrl.trim()) return false;
      return true;
    },
    isDiscourse() {
      return this.sourceType === 'discourse';
    },
  },
  watch: {
    sourceType() {
      this.name = '';
    },
    show(val) {
      if (!val) this.reset();
    },
  },
  methods: {
    reset() {
      this.sourceType = 'discourse';
      this.name = '';
      this.discourseUrl = '';
      this.discourseApiKey = '';
      this.discourseApiUsername = 'system';
      this.discourseWebhookSecret = '';
      this.discourseCategoryId = '';
    },
    onClose() {
      this.reset();
      this.$emit('close');
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
              api_username: this.discourseApiUsername.trim() || 'system',
              webhook_secret: this.discourseWebhookSecret.trim(),
              category_id: this.discourseCategoryId ? Number(this.discourseCategoryId) : null,
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
        header-title="Agregar Fuente de Conocimiento"
        header-content="Configura una nueva fuente para indexar en la base de conocimiento."
      />

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
          <label class="text-sm font-medium text-slate-700">
            ID de categoría <span class="text-slate-400 font-normal">(opcional — vacío sincroniza todo)</span>
          </label>
          <input
            v-model="discourseCategoryId"
            type="number"
            min="1"
            class="input"
            placeholder="Ej: 5"
          />
          <p class="text-xs text-slate-400">
            Encuéntralo en Discourse → Admin → Categorías → editar categoría → la URL termina en <code>/N</code>.
          </p>
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-slate-700">
            API Key <span class="text-slate-400 font-normal">(opcional)</span>
          </label>
          <input
            v-model="discourseApiKey"
            type="password"
            class="input"
            placeholder="api_key de Discourse"
          />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-slate-700">
            API Username <span class="text-slate-400 font-normal">(por defecto: system)</span>
          </label>
          <input
            v-model="discourseApiUsername"
            type="text"
            class="input"
            placeholder="system"
          />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-slate-700">
            Webhook Secret <span class="text-slate-400 font-normal">(opcional)</span>
          </label>
          <input
            v-model="discourseWebhookSecret"
            type="password"
            class="input"
            placeholder="Secreto para verificar la firma HMAC"
          />
          <p class="text-xs text-slate-400">
            Configura el mismo valor en Discourse → Admin → Webhooks.
          </p>
        </div>
      </template>

      <div class="flex justify-end gap-2 pt-2">
        <woot-button variant="clear" @click="onClose">Cancelar</woot-button>
        <woot-button :disabled="!isValid || saving" @click="onSave">
          {{ saving ? 'Guardando...' : 'Agregar fuente' }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
