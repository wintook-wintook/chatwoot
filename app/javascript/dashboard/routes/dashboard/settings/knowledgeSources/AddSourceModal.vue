<!-- @knowledge_sources -->
<!-- Modal para agregar o editar una fuente de conocimiento. -->
<script>
export default {
  name: 'AddKnowledgeSourceModal',
  props: {
    show: { type: Boolean, default: false },
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
      docUrl: '',
      sheetUrl: '',
      sheetMode: 'faq',
      sheetRange: '',
      sheetLive: false,
      sheetLiveTtl: 60,
      sourceOptions: [
        { value: 'discourse', label: 'Discourse', icon: 'globe' },
        { value: 'google_doc', label: 'Google Doc', icon: 'document' },
        { value: 'google_sheet', label: 'Google Sheets', icon: 'document' },
      ],
    };
  },
  computed: {
    isEdit() {
      return !!this.source;
    },
    modalTitle() {
      return this.isEdit
        ? 'Editar Fuente de Conocimiento'
        : 'Agregar Fuente de Conocimiento';
    },
    saveLabel() {
      if (this.saving) return 'Guardando...';
      return this.isEdit ? 'Guardar cambios' : 'Agregar fuente';
    },
    // Vista previa de la directiva del bot, p.ej. {{doc:manual_usuario}}.
    // Se arma como string (no en el template) para no anidar mustaches de Vue.
    docDirectiveHint() {
      return `{{doc:${this.name.trim() || 'nombre'}}}`;
    },
    sheetDirectiveHint() {
      return `{{hoja:${this.name.trim() || 'nombre'}}}`;
    },
    isValid() {
      if (!this.name.trim()) return false;
      if (this.sourceType === 'discourse') {
        if (!this.discourseUrl.trim()) return false;
        if (!this.discourseApiKey.trim()) return false;
      }
      if (this.sourceType === 'google_doc' && !this.docUrl.trim()) return false;
      if (this.sourceType === 'google_sheet' && !this.sheetUrl.trim())
        return false;
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
      this.sourceType = this.source.source_type || 'discourse';
      this.name = this.source.name || '';
      this.discourseUrl = this.source.config?.url || '';
      this.discourseApiKey = this.source.config?.api_key || '';
      this.discourseUsername = this.source.config?.username || '';
      this.docUrl = this.source.config?.file_url || '';
      this.sheetUrl = this.source.config?.file_url || '';
      this.sheetMode = this.source.config?.sheet_mode || 'faq';
      this.sheetRange = this.source.config?.sheet_range || '';
      this.sheetLive = this.source.config?.live || false;
      this.sheetLiveTtl = this.source.config?.live_ttl || 60;
    },
    reset() {
      this.sourceType = 'discourse';
      this.name = '';
      this.discourseUrl = '';
      this.discourseApiKey = '';
      this.discourseUsername = '';
      this.docUrl = '';
      this.sheetUrl = '';
      this.sheetMode = 'faq';
      this.sheetRange = '';
      this.sheetLive = false;
      this.sheetLiveTtl = 60;
    },
    onClose() {
      this.reset();
      this.$emit('close');
    },
    onSave() {
      if (!this.isValid) return;
      this.$emit('save', {
        source_type: this.sourceType,
        name: this.name.trim(),
        config: this.buildConfig(),
      });
    },
    buildConfig() {
      if (this.sourceType === 'discourse') {
        return {
          url: this.discourseUrl.trim(),
          api_key: this.discourseApiKey.trim(),
          username: this.discourseUsername.trim() || 'system',
        };
      }
      if (this.sourceType === 'google_doc') {
        return { file_url: this.docUrl.trim() };
      }
      if (this.sourceType === 'google_sheet') {
        return {
          file_url: this.sheetUrl.trim(),
          sheet_mode: this.sheetMode,
          sheet_range: this.sheetRange.trim() || null,
          live: this.sheetMode === 'data' ? this.sheetLive : false,
          live_ttl: Number(this.sheetLiveTtl) || 60,
        };
      }
      return {};
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
          <label class="text-sm font-medium text-slate-700"
            >Tipo de fuente</label
          >
          <select v-model="sourceType" :disabled="isEdit" class="input">
            <option
              v-for="opt in sourceOptions"
              :key="opt.value"
              :value="opt.value"
            >
              {{ opt.label }}
            </option>
          </select>
        </div>

        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-slate-700">Nombre</label>
          <input
            v-model="name"
            type="text"
            class="input"
            :placeholder="
              sourceType === 'google_doc'
                ? 'Ej: manual_usuario'
                : 'Ej: Foro de Soporte'
            "
          />
          <p v-if="sourceType === 'google_doc'" class="text-xs text-slate-400">
            Nombre único. Se usa en el bot como directiva:
            <code>{{ docDirectiveHint }}</code>
          </p>
        </div>

        <!-- Campos Discourse -->
        <template v-if="sourceType === 'discourse'">
          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-slate-700"
              >URL del foro</label
            >
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
            <p class="text-xs text-slate-400">
              Admin → API → Keys en tu instancia de Discourse
            </p>
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
            <p class="text-xs text-slate-400">
              Usuario de Discourse para las peticiones. Por defecto: system
            </p>
          </div>
        </template>

        <!-- Campos Google Doc -->
        <template v-if="sourceType === 'google_doc'">
          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-slate-700"
              >URL del documento</label
            >
            <input
              v-model="docUrl"
              type="url"
              class="input"
              placeholder="https://docs.google.com/document/d/.../edit"
            />
            <p class="text-xs text-slate-400">
              Pega la URL del Google Doc. Requiere tener conectada tu cuenta de
              Google (Calendario) y que el documento sea accesible por esa
              cuenta.
            </p>
          </div>
        </template>

        <!-- Campos Google Sheets -->
        <template v-if="sourceType === 'google_sheet'">
          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-slate-700"
              >URL de la hoja</label
            >
            <input
              v-model="sheetUrl"
              type="url"
              class="input"
              placeholder="https://docs.google.com/spreadsheets/d/.../edit"
            />
            <p class="text-xs text-slate-400">
              Nombre único. Directiva del bot:
              <code>{{ sheetDirectiveHint }}</code>
            </p>
          </div>

          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-slate-700">Modo</label>
            <select v-model="sheetMode" class="input">
              <option value="faq">
                FAQ (texto por fila, búsqueda semántica)
              </option>
              <option value="data">
                Datos (consultas exactas: suma, conteo, filtros)
              </option>
            </select>
            <p class="text-xs text-slate-400">
              Usa «Datos» para sumas, conteos o filtrar por columna. Usa «FAQ»
              si cada fila es texto a recuperar por significado.
            </p>
          </div>

          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-slate-700">
              Rango
              <span class="text-slate-400 font-normal">(opcional)</span>
            </label>
            <input
              v-model="sheetRange"
              type="text"
              class="input"
              placeholder="A1:Z2000"
            />
            <p class="text-xs text-slate-400">
              Rango a leer. La primera fila se toma como encabezados. Por
              defecto: A1:Z2000.
            </p>
          </div>

          <div v-if="sheetMode === 'data'" class="flex flex-col gap-2">
            <label
              class="flex items-center gap-2 text-sm font-medium text-slate-700"
            >
              <input v-model="sheetLive" type="checkbox" />
              Consultar en vivo
            </label>
            <p class="text-xs text-slate-400">
              Mantiene los datos al día sin sincronizar a mano: si la hoja
              cambió, refresca la copia local en la próxima consulta. Solo
              disponible en modo «Datos».
            </p>
            <div v-if="sheetLive" class="flex flex-col gap-1">
              <label class="text-sm font-medium text-slate-700">
                Frecuencia de chequeo
                <span class="text-slate-400 font-normal">(segundos)</span>
              </label>
              <input
                v-model="sheetLiveTtl"
                type="number"
                min="10"
                class="input"
                placeholder="60"
              />
              <p class="text-xs text-slate-400">
                Cada cuánto, como máximo, verifica si la hoja cambió. Por
                defecto: 60 segundos.
              </p>
            </div>
          </div>
        </template>
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
