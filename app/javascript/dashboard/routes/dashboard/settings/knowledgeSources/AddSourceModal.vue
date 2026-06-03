<!-- @knowledge_sources -->
<!-- Modal para agregar o editar una fuente de conocimiento. -->
<script>
export default {
  name: 'AddKnowledgeSourceModal',
  props: {
    show:   { type: Boolean, default: false },
    saving: { type: Boolean, default: false },
    source: { type: Object, default: null },
  },
  emits: ['close', 'save'],
  data() {
    return {
      sourceType: 'discourse',
      name: '',
      discourseUrl: '',
      discourseApiKey: '',
      discourseUsername: '',
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
      if (this.saving) return 'Guardando...';
      return this.isEdit ? 'Guardar cambios' : 'Agregar fuente';
    },
    isValid() {
      if (!this.name.trim()) return false;
      if (this.sourceType === 'discourse') {
        if (!this.discourseUrl.trim()) return false;
        if (!this.discourseApiKey.trim()) return false;
      }
      return true;
    },
  },
  watch: {
    sourceType() {
      this.name = '';
    },
    show(val) {
      if (val) this.populate();
      else this.reset();
    },
  },
  methods: {
    populate() {
      if (!this.source) return;
      this.sourceType     = this.source.source_type || 'discourse';
      this.name           = this.source.name || '';
      this.discourseUrl      = this.source.config?.url || '';
      this.discourseApiKey   = this.source.config?.api_key || '';
      this.discourseUsername = this.source.config?.username || '';
    },
    reset() {
      this.sourceType       = 'discourse';
      this.name             = '';
      this.discourseUrl      = '';
      this.discourseApiKey   = '';
      this.discourseUsername = '';
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
        config: this.sourceType === 'discourse'
          ? {
              url:      this.discourseUrl.trim(),
              api_key:  this.discourseApiKey.trim(),
              username: this.discourseUsername.trim() || 'system',
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

      <div class="flex flex-col gap-4">

        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-slate-700">Nombre</label>
          <input
            v-model="name"
            type="text"
            class="input"
            placeholder="Ej: Foro de Soporte"
          />
        </div>

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
            placeholder="API Key de Discourse"
          />
          <p class="text-xs text-slate-400">Admin → API → Keys en tu instancia de Discourse</p>
        </div>

        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-slate-700">
            Usuario API
            <span class="text-slate-400 font-normal">(opcional)</span>
          </label>
          <input
            v-model="discourseUsername"
            type="text"
            class="input"
            placeholder="system"
          />
          <p class="text-xs text-slate-400">Usuario de Discourse para las peticiones. Por defecto: system</p>
        </div>

      </div>

      <div class="flex justify-end gap-2 pt-2">
        <woot-button variant="clear" @click="onClose">Cancelar</woot-button>
        <woot-button :disabled="!isValid || saving" @click="onSave">
          {{ saveLabel }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
