<!-- @knowledge_sources -->
<!-- Modal para agregar o editar una fuente de conocimiento. -->
<script>
import { mapGetters } from 'vuex';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

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
      contpaqBaseUrl: '',
      contpaqTokenUrl: '',
      contpaqClientId: '',
      contpaqClientSecret: '',
      contpaqScope: '',
    };
  },
  computed: {
    ...mapGetters({
      currentUser: 'getCurrentUser',
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
    }),
    // Las fuentes Google reutilizan la conexión de Google Calendar: solo se
    // ofrecen si la cuenta tiene activada esa feature en el super admin.
    googleEnabled() {
      return this.isFeatureEnabledonAccount(
        this.currentUser.account_id,
        FEATURE_FLAGS.GOOGLE_CALENDAR
      );
    },
    sourceOptions() {
      const options = [
        { value: 'discourse', label: 'Discourse', icon: 'globe' },
        {
          value: 'contpaq_support',
          label: 'Agente de Servicio CONTPAQi',
          icon: 'globe',
        },
      ];
      if (this.googleEnabled) {
        options.push(
          { value: 'google_doc', label: 'Google Doc', icon: 'document' },
          { value: 'google_sheet', label: 'Google Sheets', icon: 'document' }
        );
      }
      return options;
    },
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
    contpaqDirectiveHint() {
      return `@soporte_contpaq(${this.name.trim() || 'nombre'})`;
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
      if (this.sourceType === 'contpaq_support') {
        // Las cinco hacen falta para pedir el token: sin una sola, la fuente queda
        // dada de alta pero no contesta, y el fallo recién se ve en la conversación.
        if (!this.contpaqBaseUrl.trim()) return false;
        if (!this.contpaqTokenUrl.trim()) return false;
        if (!this.contpaqClientId.trim()) return false;
        if (!this.contpaqClientSecret.trim()) return false;
        if (!this.contpaqScope.trim()) return false;
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
      this.contpaqBaseUrl = this.source.config?.base_url || '';
      this.contpaqTokenUrl = this.source.config?.token_url || '';
      this.contpaqClientId = this.source.config?.client_id || '';
      this.contpaqClientSecret = this.source.config?.client_secret || '';
      this.contpaqScope = this.source.config?.scope || '';
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
      this.contpaqBaseUrl = '';
      this.contpaqTokenUrl = '';
      this.contpaqClientId = '';
      this.contpaqClientSecret = '';
      this.contpaqScope = '';
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
      if (this.sourceType === 'contpaq_support') {
        return {
          base_url: this.contpaqBaseUrl.trim(),
          token_url: this.contpaqTokenUrl.trim(),
          client_id: this.contpaqClientId.trim(),
          client_secret: this.contpaqClientSecret.trim(),
          scope: this.contpaqScope.trim(),
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
          <p
            v-if="sourceType === 'contpaq_support'"
            class="text-xs text-slate-400"
          >
            Nombre único. Se usa en el Entrenamiento del agente como directiva:
            <code>{{ contpaqDirectiveHint }}</code>
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

          <div class="grid grid-cols-2 gap-3">
            <div class="flex flex-col gap-1">
              <label class="text-sm font-medium text-slate-700">Modo</label>
              <select v-model="sheetMode" class="input">
                <option value="faq">FAQ (semántica)</option>
                <option value="data">Datos (cálculos)</option>
              </select>
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
            </div>
          </div>
          <p class="text-xs text-slate-400">
            «Datos» = sumas, conteos y filtros exactos · «FAQ» = recuperar texto
            por significado. Rango por defecto: A1:Z2000.
          </p>

          <div v-if="sheetMode === 'data'" class="flex flex-col gap-1">
            <label
              class="flex items-center gap-2 text-sm font-medium text-slate-700"
            >
              <input v-model="sheetLive" type="checkbox" />
              Consultar en vivo
              <template v-if="sheetLive">
                <span class="font-normal text-slate-400">· cada</span>
                <input
                  v-model="sheetLiveTtl"
                  type="number"
                  min="10"
                  class="input !w-20 !py-1"
                  placeholder="60"
                />
                <span class="font-normal text-slate-400">seg</span>
              </template>
            </label>
            <p class="text-xs text-slate-400">
              Mantiene los datos al día sin sincronizar a mano: si la hoja
              cambió, refresca en la próxima consulta.
            </p>
          </div>
        </template>

        <!-- Campos Agente de Servicio CONTPAQi -->
        <template v-if="sourceType === 'contpaq_support'">
          <div
            class="px-3 py-2 text-xs rounded-lg text-slate-500 bg-slate-50 border border-slate-100"
          >
            CONTPAQi redacta la respuesta y nosotros la entregamos tal cual, con
            el enlace a su documentación. Por eso, en esta fuente el tono y las
            reglas que tenga el agente en su Entrenamiento no se aplican.
          </div>

          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-slate-700">
              URL del servicio
            </label>
            <input
              v-model="contpaqBaseUrl"
              type="url"
              class="input"
              placeholder="https://…/agente-servicio/v1"
            />
          </div>

          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-slate-700">
              URL del token
            </label>
            <input
              v-model="contpaqTokenUrl"
              type="url"
              class="input"
              placeholder="https://…/oauth2/v2.0/token"
            />
          </div>

          <div class="grid grid-cols-2 gap-3">
            <div class="flex flex-col gap-1">
              <label class="text-sm font-medium text-slate-700">
                Client ID
              </label>
              <input v-model="contpaqClientId" type="text" class="input" />
            </div>
            <div class="flex flex-col gap-1">
              <label class="text-sm font-medium text-slate-700">
                Client Secret
              </label>
              <input
                v-model="contpaqClientSecret"
                type="password"
                class="input"
              />
            </div>
          </div>

          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-slate-700">Scope</label>
            <input
              v-model="contpaqScope"
              type="text"
              class="input"
              placeholder="api://…/.default"
            />
            <p class="text-xs text-slate-400">
              Tiene que terminar en <code>/.default</code>. Sin ese sufijo, el
              servicio rechaza las credenciales.
            </p>
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
