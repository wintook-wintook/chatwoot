<!--
  ================================================================================
  proyecto@tracking_templates
  ================================================================================
  Componente: EditTemplate.vue
  Descripción: Formulario inline para crear/editar plantillas de seguimiento.
               Campos: nombre, objetivo, contexto IA (tabs), prompt complementario,
               selector de inbox (tracking_bot), plantillas WhatsApp por intento.
  ================================================================================
-->

<script>
import { mapGetters } from 'vuex';
import { extractTemplateBody } from 'dashboard/helper/trackingHelpers';
import KeywordActionsEditor from 'dashboard/components/contacts/ContactTracking/KeywordActionsEditor.vue';
import { debounce } from '@chatwoot/utils';
import { useAlert } from 'dashboard/composables';
import TrackingTemplatesAPI from 'dashboard/api/trackingTemplates';
// proyecto@ai_agent_assistant: semáforo del linter
import AiAgentAssistantAPI from 'dashboard/api/aiAgentAssistant';
import LintBadges from 'dashboard/components/contactTrackings/assistant/LintBadges.vue';
import SandboxDrawer from 'dashboard/components/contactTrackings/assistant/SandboxDrawer.vue';
import VersionsDrawer from 'dashboard/components/contactTrackings/assistant/VersionsDrawer.vue';
import PatternLibraryDrawer from 'dashboard/components/contactTrackings/assistant/PatternLibraryDrawer.vue';
// proyecto@ai_agent_attachments
import AiAgentAttachmentsAPI from 'dashboard/api/aiAgentAttachments';
// @knowledge_sources: fuentes Discourse para la directiva @buscar_foro
// proyecto@bot_seguimiento_calendar: lista de zonas horarias (reutiliza Horario laboral)
import { timeZoneOptions } from 'dashboard/routes/dashboard/settings/inbox/helpers/businessHour';

// proyecto@contact_tracking: grupos del picker de directivas (orden + etiqueta del chip).
// A qué chip del filtro pertenece cada capacidad del Registry.
const DIRECTIVE_GROUP_BY_KEY = {
  buscar_predefinidas: 'kb',
  buscar_articulo: 'kb',
  buscar_foro: 'discourse',
  discourse: 'discourse',
  doc: 'google',
  hoja: 'google',
  consulta: 'erp',
  agendar_calendar: 'actions',
  crear_ticket: 'actions',
  estado_ticket: 'actions',
  adjunto: 'actions',
};

const DIRECTIVE_GROUPS = [
  { key: 'kb', label: 'Conocimiento' },
  { key: 'discourse', label: 'Discourse' },
  { key: 'google', label: 'Google' },
  { key: 'erp', label: 'Consulta ERP' },
  { key: 'actions', label: 'Acciones' },
];

export default {
  components: {
    KeywordActionsEditor,
    LintBadges,
    SandboxDrawer,
    VersionsDrawer,
    PatternLibraryDrawer,
  },

  props: {
    templateData: {
      type: Object,
      default: () => ({}),
    },
    mode: {
      type: String,
      default: 'edit',
      validator: val => ['create', 'edit'].includes(val),
    },
  },
  emits: ['save', 'cancel', 'restored'],
  data() {
    return {
      // proyecto@ai_agent_assistant
      lintFindings: [],
      isLinting: false,
      showSandbox: false,
      showVersions: false, // F4: historial en sitio
      showPatterns: false, // F6: biblioteca de bloques
      showDuplicate: false, // ramificar: otro canal o un caso vecino
      duplicateName: '',
      isDuplicating: false,
      versionNote: '',
      form: {
        id: null,
        name: '',
        objective: '',
        ai_context: '',
        complementary_prompt: '',
        tags: [],
        whatsapp_templates: ['', '', ''],
        retry_interval_value: 1, // proyecto@automatizacion_tracking
        retry_interval_unit: 'days', // proyecto@automatizacion_tracking
        keyword_actions: [], // proyecto@contact_tracking
        calendar_integration_ids: [],
        // proyecto@bot_seguimiento_calendar: { integration_id: google_calendar_id } — en qué
        // calendario de Google se crea la cita por agenda. Sin entrada → 'primary'.
        booking_calendar_ids: {},
        // proyecto@bot_seguimiento_calendar: formato de presentación de horarios al cliente
        slots_presentation: 'detailed',
        calendar_event_duration: 30,
        timezone: '', // proyecto@bot_seguimiento_calendar: hereda del inbox si queda vacío
      },
      // Tabs Contexto IA / Entrenamiento
      topTab: 0, // 0 = Agente IA, 1 = Agente seguimiento
      activeContextTab: 0,
      calendarIntegrations: [],
      isLoadingCalendars: false,
      // proyecto@bot_seguimiento_calendar: modal árbol de calendarios agendables.
      // Selección temporal mientras el modal está abierto: { integration_id: [cal_ids] }.
      showCalendarModal: false,
      calendarModalSelection: {},
      originalAiContext: null,
      originalComplementaryPrompt: null,
      isImprovingAI: false,
      showPromptModal: false, // proyecto@automatizacion_tracking: modal expandido para entrenamiento
      showAiContextModal: false,
      showValidationModal: false,
      // WhatsApp / Inbox
      selectedInboxId: null,
      maxAttempts: 3,
      availableWATemplates: [],
      isLoadingWATemplates: false,
      activeTemplateTab: 0,
      // proyecto@ai_agent_attachments
      attachments: [],
      isLoadingAttachments: false,
      isUploadingAttachment: false,
      attachmentName: '',
      attachmentFile: null,
      attachmentError: '',
      // renombrado inline de un adjunto
      editingAttachmentId: null,
      editingAttachmentName: '',
      renameError: '',
      // selector de archivos para insertar {{nombre}} en el Entrenamiento
      showAttachmentPicker: false,
      // selector de directivas para insertar @buscar_..., @discourse, etc.
      showDirectivePicker: false,
      // proyecto@ai_agent_assistant: Registry resuelto por cuenta e inbox
      capabilities: [],
      isLoadingCapabilities: false,
      // chip de tipo activo en el picker de directivas ('all' = todas)
      directiveFilter: 'all',
      // 'inline' | 'modal': textarea donde se insertará + posición del cursor
      pickerTarget: 'inline',
      pickerInsertPos: null,
      // scroll del textarea al abrir el picker; se restaura tras insertar para que la
      // vista no salte al final (focus + setSelectionRange fuerza scroll al cursor).
      pickerScrollTop: 0,
      // fuentes Discourse de la cuenta (para la directiva @buscar_foro)
    };
  },
  computed: {
    // proyecto@ai_agent_assistant
    hasLintErrors() {
      return this.lintFindings.some(f => f.level === 'error');
    },
    ...mapGetters({
      appIntegrations: 'integrations/getAppIntegrations',
      inboxes: 'inboxes/getInboxes',
      // @query_databases — catálogo de conexiones ERP + consultas activas para la
      // directiva {{consulta:}} (sin credenciales, mismo catálogo que la consola).
    }),
    // @query_databases — la directiva {{consulta:}} solo se ofrece si la cuenta
    isCreateMode() {
      return this.mode === 'create';
    },
    // Google Doc/Sheet y @agendar_calendar dependen de la conexión de Google
    // proyecto@bot_seguimiento_calendar: formatos de presentación de horarios (con mini-preview)
    slotsPresentationOptions() {
      const t = key =>
        this.$t(`TRACKING_TEMPLATES.CALENDARS.PRESENTATION.${key}`);
      return [
        {
          value: 'detailed',
          label: t('DETAILED'),
          preview:
            '1️⃣ jue 25 jun · 09:00 – 10:00 hs (hora de Mexico City) — Admin',
        },
        {
          value: 'by_agent',
          label: t('BY_AGENT'),
          preview:
            '👤 Admin (hora de Mexico City)\n   1️⃣ jue 25 jun · 09:00 – 10:00 hs',
        },
        {
          value: 'by_calendar',
          label: t('BY_CALENDAR'),
          preview:
            '📅 Casa (hora de Mexico City)\n   1️⃣ jue 25 jun · 09:00 – 10:00 hs',
        },
        {
          value: 'simple',
          label: t('SIMPLE'),
          preview: '1️⃣ jue 25 jun · 09:00 – 10:00 hs',
        },
        {
          value: 'by_day',
          label: t('BY_DAY'),
          preview: '📅 jue 25 jun\n   1️⃣ 09:00   2️⃣ 10:00',
        },
      ];
    },
    // proyecto@bot_seguimiento_calendar: lista plana de todos los calendarios seleccionados
    // (de todas las cuentas) para el tab Agendas. Cada ítem trae su cuenta para poder quitarlo.
    allSelectedCalendars() {
      const linked = (this.form.calendar_integration_ids || []).map(String);
      const result = [];
      this.calendarIntegrations.forEach(integration => {
        if (!linked.includes(String(integration.id))) return;
        const all = this.bookableCalendarsFor(integration);
        this.selectedBookingCalendars(integration).forEach(id => {
          const cal = all.find(c => c.id === id) || {
            id,
            summary: id,
            background_color: '#94a3b8',
            primary: false,
          };
          result.push({
            ...cal,
            integrationId: integration.id,
            email: integration.google_email,
            key: `${integration.id}:${id}`,
          });
        });
      });
      return result;
    },
    // proyecto@ai_agent_attachments: las llaves literales NO pueden ir dentro de un
    // mustache {{ }} (Vue 2 corta en el primer }} y rompe el template). Se exponen como
    // datos para usarlas en interpolaciones y como params de i18n.
    braceParams() {
      return { open: '{{', close: '}}' };
    },
    formTitle() {
      return this.isCreateMode
        ? this.$t('TRACKING_TEMPLATES.CREATE.TITLE')
        : this.$t('TRACKING_TEMPLATES.EDIT.TITLE');
    },
    submitText() {
      return this.isCreateMode
        ? this.$t('TRACKING_TEMPLATES.CREATE.BTN_TEXT')
        : this.$t('TRACKING_TEMPLATES.EDIT.BTN_TEXT');
    },
    isNameValid() {
      return this.form.name.length >= 2 && this.form.name.length <= 100;
    },
    isObjectiveValid() {
      return (
        this.form.objective.length >= 5 && this.form.objective.length <= 500
      );
    },
    isAiContextValid() {
      return this.form.ai_context.trim().length >= 10;
    },
    isComplementaryPromptValid() {
      return this.form.complementary_prompt.trim().length >= 10;
    },
    isInboxValid() {
      if (!this.hasTrackingBotInboxes) return true;
      return !!this.selectedInboxId;
    },
    isWhatsappTemplatesValid() {
      // Si el inbox no es WhatsApp, no se requieren plantillas
      if (!this.selectedInboxIsWhatsApp) return true;
      // Si está cargando o no hay plantillas disponibles, no se puede validar → no bloquear
      if (this.isLoadingWATemplates || this.availableWATemplates.length === 0)
        return true;
      // Todos los intentos deben tener plantilla asignada
      return this.form.whatsapp_templates
        .slice(0, this.maxAttempts)
        .every(tpl => tpl && tpl.trim() !== '');
    },
    // proyecto@automatizacion_tracking: mínimo 3 si la unidad es minutos, 1 en el resto
    minIntervalValue() {
      return this.form.retry_interval_unit === 'minutes' ? 3 : 1;
    },
    isFormValid() {
      return (
        this.isNameValid &&
        this.isObjectiveValid &&
        this.isAiContextValid &&
        this.isComplementaryPromptValid &&
        this.isInboxValid &&
        this.isWhatsappTemplatesValid
      );
    },
    canGeneratePrompt() {
      const hasObjective = this.form.objective && this.form.objective.trim();
      const hasContext = this.form.ai_context && this.form.ai_context.trim();
      return hasObjective && hasContext;
    },
    // Inboxes con tracking_bot habilitado
    trackingBotInboxes() {
      const apps = this.appIntegrations || [];
      const trackingBotApp = apps.find(app => app.id === 'tracking_bot');
      if (!trackingBotApp || !trackingBotApp.enabled) return [];

      const activeHooks = (trackingBotApp.hooks || []).filter(
        hook => hook.status === true
      );
      return activeHooks
        .filter(hook => hook.inbox && hook.inbox.id)
        .map(hook => {
          const inbox = this.inboxes.find(
            ib => ib.id === Number(hook.inbox.id)
          );
          return {
            id: hook.inbox.id,
            name: inbox
              ? inbox.name
              : hook.inbox.name || `Inbox #${hook.inbox.id}`,
            channelType: inbox ? inbox.channel_type : null,
          };
        });
    },
    hasTrackingBotInboxes() {
      return this.trackingBotInboxes.length > 0;
    },
    selectedInboxIsWhatsApp() {
      if (!this.selectedInboxId) return false;
      const inbox = this.trackingBotInboxes.find(
        ib => ib.id === Number(this.selectedInboxId)
      );
      if (!inbox) return false;
      const ct = inbox.channelType || '';
      return (
        ct === 'Channel::Whatsapp' ||
        ct === 'Channel::WhatsappCloud' ||
        ct === 'whatsapp'
      );
    },
    attemptTabs() {
      return Array.from({ length: this.maxAttempts }, (_, i) => i);
    },
    reglasTabIndex() {
      // WhatsApp ya no es una pestaña interna (vive en "Agente seguimiento"),
      // por eso los índices internos son fijos: Contexto=0, Entrenamiento=1,
      // Reglas=2, Agendas=3, Archivos=4.
      return 2;
    },
    agendasTabIndex() {
      return this.reglasTabIndex + 1;
    },
    // proyecto@ai_agent_attachments: tab "📎 Archivos" tras "📅 Agendas"
    archivosTabIndex() {
      return this.agendasTabIndex + 1;
    },
    // proyecto@bot_seguimiento_calendar: zonas horarias para el selector de Agendas
    timeZones() {
      return timeZoneOptions();
    },
    // proyecto@ai_agent_assistant: el catálogo sale del Registry del servidor, no de
    // una copia en JavaScript. El Registry ya sabe qué hay dado de alta en la cuenta,
    // cómo se escribe cada directiva con esos valores y —lo que aquí faltaba— qué le
    // hace cada una a tu prompt.
    directiveCatalog() {
      return this.capabilities
        .filter(c => c.available)
        .flatMap(capability =>
          (capability.tokens || []).map(entry => ({
            group: DIRECTIVE_GROUP_BY_KEY[capability.key] || 'actions',
            token: entry.token,
            label: entry.label || this.capabilityLabel(capability),
            effect: this.capabilityEffect(capability),
          }))
        );
    },
    // Las que esta cuenta no puede usar. Antes no aparecían y no había forma de saber
    // por qué faltaban.
    unavailableCapabilities() {
      return this.capabilities.filter(c => !c.available);
    },
    // proyecto@contact_tracking: grupos presentes en el catálogo (para los chips de
    // filtro del modal). Se muestran en orden y solo si tienen al menos una directiva.
    directiveGroups() {
      const present = new Set(this.directiveCatalog.map(d => d.group));
      return DIRECTIVE_GROUPS.filter(g => present.has(g.key));
    },
    // Catálogo filtrado por el chip activo ('all' = todas).
    filteredDirectiveCatalog() {
      if (this.directiveFilter === 'all') return this.directiveCatalog;
      return this.directiveCatalog.filter(
        d => d.group === this.directiveFilter
      );
    },
    validationErrors() {
      const errors = [];
      if (!this.isNameValid)
        errors.push('Nombre del Agente IA es requerido (mínimo 2 caracteres).');
      if (!this.isObjectiveValid)
        errors.push('Objetivo es requerido (mínimo 5 caracteres).');
      if (!this.isAiContextValid)
        errors.push('Contexto IA es requerido (mínimo 10 caracteres).');
      if (!this.isComplementaryPromptValid)
        errors.push('Entrenamiento es requerido (mínimo 10 caracteres).');
      if (!this.isInboxValid)
        errors.push('Debes seleccionar un Canal (Inbox).');
      if (!this.isWhatsappTemplatesValid)
        errors.push(
          'Todos los intentos de WhatsApp deben tener una plantilla asignada.'
        );
      return errors;
    },
  },
  watch: {
    // proyecto@ai_agent_assistant: revalida al cambiar lo que el linter mira.
    // Es estático y local, así que se puede correr mientras se escribe.
    'form.complementary_prompt': 'scheduleLint',
    'form.objective': 'scheduleLint',
    'form.ai_context': 'scheduleLint',
    'form.keyword_actions': { handler: 'scheduleLint', deep: true },
    templateData: {
      immediate: true,
      handler(val) {
        if (val && val.id) {
          this.form = {
            id: val.id,
            name: val.name || '',
            objective: val.objective || '',
            ai_context: val.ai_context || '',
            complementary_prompt: val.complementary_prompt || '',
            tags: Array.isArray(val.tags) ? [...val.tags] : [],
            whatsapp_templates: Array.isArray(val.whatsapp_templates)
              ? [...val.whatsapp_templates]
              : ['', '', ''],
            retry_interval_value: val.retry_interval_value || 1, // proyecto@automatizacion_tracking
            retry_interval_unit: val.retry_interval_unit || 'days', // proyecto@automatizacion_tracking
            keyword_actions: Array.isArray(val.keyword_actions) // proyecto@contact_tracking
              ? val.keyword_actions.map(ka => ({ ...ka }))
              : [],
            calendar_integration_ids: Array.isArray(
              val.calendar_integration_ids
            )
              ? [...val.calendar_integration_ids]
              : [],
            booking_calendar_ids:
              val.booking_calendar_ids &&
              typeof val.booking_calendar_ids === 'object'
                ? { ...val.booking_calendar_ids }
                : {},
            slots_presentation: val.slots_presentation || 'detailed',
            calendar_event_duration: val.calendar_event_duration || 30,
            timezone: val.timezone || '',
          };
          if (
            this.form.whatsapp_templates.length > 0 &&
            this.form.whatsapp_templates.some(t => t)
          ) {
            this.maxAttempts = this.form.whatsapp_templates.length;
          }
          // Pre-seleccionar inbox guardado
          if (val.inbox_id) {
            this.selectedInboxId = val.inbox_id;
          }
        }
        // Reset AI state
        this.activeContextTab = 0;
        this.originalAiContext = null;
        this.originalComplementaryPrompt = null;
        // proyecto@ai_agent_attachments: cargar adjuntos del agente (solo en edición)
        this.attachments = [];
        this.showAttachmentPicker = false;
        this.showDirectivePicker = false;
        if (val && val.id) {
          this.loadAttachments();
        }
      },
    },
    selectedInboxId(newVal) {
      if (newVal && this.selectedInboxIsWhatsApp) {
        this.loadWATemplates();
      } else {
        this.availableWATemplates = [];
      }
      // proyecto@ai_agent_assistant: el canal cambia lo que el linter puede validar
      // (modelo, ventana de WhatsApp, integración de Discourse).
      this.scheduleLint();
    },
    maxAttempts(newVal) {
      this.adjustTemplatesArray(newVal);
    },
    // proyecto@automatizacion_tracking: ajusta el valor si queda por debajo del mínimo al cambiar unidad
    'form.retry_interval_unit'(newUnit) {
      if (newUnit === 'minutes' && this.form.retry_interval_value < 3) {
        this.form.retry_interval_value = 3;
      }
    },
  },
  async mounted() {
    if (!this.appIntegrations || this.appIntegrations.length === 0) {
      await this.$store.dispatch('integrations/get');
    }
    if (!this.inboxes || this.inboxes.length === 0) {
      await this.$store.dispatch('inboxes/get');
    }
    // Si ya hay un inbox pre-seleccionado (modo edición), cargar plantillas WA
    if (this.selectedInboxId && this.selectedInboxIsWhatsApp) {
      this.loadWATemplates();
    }
    this.loadCalendarIntegrations();
  },
  methods: {
    onCancel() {
      this.$emit('cancel');
    },
    // proyecto@ai_agent_assistant: el mismo cuerpo alimenta el guardado y el linter,
    // para que lo que se valida sea exactamente lo que se guardaría.
    buildPayload() {
      const payload = {
        tracking_template: {
          name: this.form.name,
          objective: this.form.objective,
          ai_context: this.form.ai_context,
          complementary_prompt: this.form.complementary_prompt,
          tags: this.form.tags,
          inbox_id: this.selectedInboxId || null,
          whatsapp_templates: this.selectedInboxIsWhatsApp
            ? this.form.whatsapp_templates.slice(0, this.maxAttempts)
            : [],
          retry_interval_value: this.form.retry_interval_value, // proyecto@automatizacion_tracking
          retry_interval_unit: this.form.retry_interval_unit, // proyecto@automatizacion_tracking
          keyword_actions: this.form.keyword_actions || [], // proyecto@contact_tracking
          calendar_integration_ids: this.form.calendar_integration_ids || [],
          booking_calendar_ids: this.bookingCalendarIdsPayload(),
          slots_presentation: this.form.slots_presentation || 'detailed',
          calendar_event_duration: this.form.calendar_event_duration || 30,
          timezone: this.form.timezone || '', // proyecto@bot_seguimiento_calendar
        },
      };
      if (!this.isCreateMode) {
        payload.id = this.form.id;
      }
      return payload;
    },
    // proyecto@ai_agent_assistant: valida el borrador contra el motor. No persiste nada.
    scheduleLint: debounce(
      function scheduleLint() {
        this.runLint();
      },
      500,
      false
    ),
    async runLint() {
      this.isLinting = true;
      try {
        const { data } = await AiAgentAssistantAPI.lint(this.buildPayload());
        this.lintFindings = data.findings;
      } catch (error) {
        this.lintFindings = [];
      } finally {
        this.isLinting = false;
      }
    },
    onSubmit() {
      if (!this.isFormValid) {
        this.showValidationModal = true;
        return;
      }
      // Los ⛔ bloquean: son fallos verificables que romperían el agente en producción.
      if (this.hasLintErrors) {
        useAlert(this.$t('AI_AGENT_ASSISTANT.LINT_BLOCKED'));
        return;
      }
      const payload = this.buildPayload();
      // proyecto@ai_agent_assistant (F4): la nota del guardado viaja al snapshot, no
      // al agente. Solo en el guardado: el linter y el probador no la necesitan.
      payload.tracking_template.version_note = this.versionNote;
      this.$emit('save', payload);
    },
    // F6: los bloques se añaden al final del prompt, nunca lo reemplazan. El hueco
    // <así> es deliberado: hay que rellenarlo con el negocio antes de guardar.
    onPatternInsert(body) {
      const current = (this.form.complementary_prompt || '').trimEnd();
      this.form.complementary_prompt = current ? `${current}\n\n${body}` : body;
      this.scheduleLint();
    },
    openDuplicate() {
      this.duplicateName = `${this.form.name} (copia)`;
      this.showDuplicate = true;
    },
    // Ramificar copia lo GUARDADO, no lo que hay en pantalla: si hubiera cambios
    // sin guardar, una copia silenciosa de un borrador a medias sería peor que no
    // ofrecerlo. Por eso el aviso, y por eso no se guarda nada del original aquí.
    async onDuplicate() {
      this.isDuplicating = true;
      try {
        const { data } = await TrackingTemplatesAPI.duplicate(
          this.form.id,
          this.duplicateName.trim()
        );
        this.showDuplicate = false;
        useAlert(this.$t('AI_AGENT_ASSISTANT.VERSIONS.DUPLICATED'));
        this.$router.push({
          name: 'tracking_templates_list',
          query: { agent: data.id },
        });
      } catch (error) {
        useAlert(this.$t('AI_AGENT_ASSISTANT.VERSIONS.DUPLICATE_ERROR'));
      } finally {
        this.isDuplicating = false;
      }
    },
    // F4: tras restaurar, lo guardado ya no es lo que muestra el formulario.
    onVersionRestored() {
      this.$emit('restored', this.form.id);
    },
    onContextTabChange(index) {
      this.activeContextTab = index;
    },
    onTopTabChange(index) {
      this.topTab = index;
    },
    async improveWithAI(field) {
      if (this.isImprovingAI) return;

      const isGeneratePrompt = field === 'complementary_prompt';
      const mode = isGeneratePrompt ? 'generate_prompt' : 'improve';

      let text;
      if (isGeneratePrompt) {
        text =
          (this.form.complementary_prompt || '').trim() ||
          (this.form.ai_context || '').trim();
      } else {
        text = (this.form[field] || '').trim();
      }
      if (!text) return;

      // Guardar original
      if (field === 'ai_context') {
        this.originalAiContext = this.form.ai_context;
      } else if (field === 'complementary_prompt') {
        this.originalComplementaryPrompt = this.form.complementary_prompt;
      }

      this.isImprovingAI = true;
      try {
        const payload = { text, mode };
        if (isGeneratePrompt) {
          payload.context = (this.form.ai_context || '').trim();
          payload.objective = (this.form.objective || '').trim();
        }
        const response = await this.$store.dispatch(
          'contactTrackings/improveText',
          payload
        );
        if (response?.improved_text) {
          this.form[field] = response.improved_text;
        }
      } catch (error) {
        if (field === 'ai_context') this.originalAiContext = null;
        else if (field === 'complementary_prompt')
          this.originalComplementaryPrompt = null;
      } finally {
        this.isImprovingAI = false;
      }
    },
    restoreOriginal(field) {
      if (field === 'ai_context' && this.originalAiContext) {
        this.form.ai_context = this.originalAiContext;
        this.originalAiContext = null;
      } else if (
        field === 'complementary_prompt' &&
        this.originalComplementaryPrompt
      ) {
        this.form.complementary_prompt = this.originalComplementaryPrompt;
        this.originalComplementaryPrompt = null;
      }
    },
    // WA Templates
    async loadWATemplates() {
      this.isLoadingWATemplates = true;
      try {
        if (!this.inboxes || this.inboxes.length === 0) {
          await this.$store.dispatch('inboxes/get');
        }
        const templates = this.$store.getters['inboxes/getWhatsAppTemplates'](
          Number(this.selectedInboxId)
        );
        if (templates && templates.length > 0) {
          this.availableWATemplates = templates.map(t => ({
            id: t.id || t.name,
            name: t.name,
            language: t.language,
            body: extractTemplateBody(t),
          }));
        } else {
          this.availableWATemplates = [];
        }
      } catch (error) {
        this.availableWATemplates = [];
      } finally {
        this.isLoadingWATemplates = false;
      }
    },
    adjustTemplatesArray(attempts) {
      const limited = Math.min(attempts, 6);
      while (this.form.whatsapp_templates.length < limited) {
        this.form.whatsapp_templates.push('');
      }
      if (this.form.whatsapp_templates.length > limited) {
        this.form.whatsapp_templates.splice(limited);
      }
      if (this.activeTemplateTab >= limited) {
        this.activeTemplateTab = 0;
      }
    },
    getAttemptLabel(index) {
      const n = index + 1;
      if (index === 0) return `Intento ${n} (primero)`;
      if (index === this.maxAttempts - 1) return `Intento ${n} (último)`;
      return `Intento ${n}`;
    },
    getTemplateBody(templateName) {
      const tpl = this.availableWATemplates.find(t => t.name === templateName);
      return tpl ? tpl.body : '';
    },
    async loadCalendarIntegrations() {
      this.isLoadingCalendars = true;
      try {
        const { data } = await TrackingTemplatesAPI.getCalendarIntegrations();
        this.calendarIntegrations = data || [];
      } catch (e) {
        this.calendarIntegrations = [];
      } finally {
        this.isLoadingCalendars = false;
      }
    },
    // ── proyecto@bot_seguimiento_calendar: calendarios agendables ────────────────
    // Cada calendario marcado es un destino válido (el bot busca disponibilidad en todos
    // y crea la cita en el que esté libre). La cuenta (integración) queda vinculada cuando
    // tiene al menos un calendario marcado.
    bookableCalendarsFor(integration) {
      return Array.isArray(integration.calendars) ? integration.calendars : [];
    },
    // Por defecto (sin selección guardada) marcamos el calendario principal de la cuenta.
    defaultBookingCalendars(integration) {
      const primary = this.bookableCalendarsFor(integration).find(
        c => c.primary
      );
      return primary ? [primary.id] : [];
    },
    selectedBookingCalendars(integration) {
      const stored = this.form.booking_calendar_ids[String(integration.id)];
      return Array.isArray(stored)
        ? stored
        : this.defaultBookingCalendars(integration);
    },
    integrationById(integrationId) {
      return this.calendarIntegrations.find(i => i.id === integrationId);
    },
    // Quita un calendario de la lista consolidada; si la cuenta queda sin calendarios,
    // se desvincula (sale de calendar_integration_ids).
    removeSelectedCalendar(integrationId, calId) {
      const integration = this.integrationById(integrationId);
      if (!integration) return;
      const current = this.selectedBookingCalendars(integration).filter(
        id => id !== calId
      );
      if (current.length) {
        this.$set(
          this.form.booking_calendar_ids,
          String(integrationId),
          current
        );
      } else {
        this.$delete(this.form.booking_calendar_ids, String(integrationId));
        this.form.calendar_integration_ids =
          this.form.calendar_integration_ids.filter(id => id !== integrationId);
      }
    },
    // ── Modal de selección (árbol agrupado por cuenta) ───────────────────────────
    openCalendarModal() {
      const selection = {};
      const linked = (this.form.calendar_integration_ids || []).map(String);
      this.calendarIntegrations.forEach(integration => {
        selection[String(integration.id)] = linked.includes(
          String(integration.id)
        )
          ? [...this.selectedBookingCalendars(integration)]
          : [];
      });
      this.calendarModalSelection = selection;
      this.showCalendarModal = true;
    },
    closeCalendarModal() {
      this.showCalendarModal = false;
      this.calendarModalSelection = {};
    },
    isModalCalendarChecked(integrationId, calId) {
      return (
        this.calendarModalSelection[String(integrationId)] || []
      ).includes(calId);
    },
    toggleModalCalendar(integrationId, calId) {
      const key = String(integrationId);
      const current = [...(this.calendarModalSelection[key] || [])];
      const idx = current.indexOf(calId);
      if (idx === -1) {
        current.push(calId);
      } else {
        current.splice(idx, 1);
      }
      this.$set(this.calendarModalSelection, key, current);
    },
    confirmCalendarModal() {
      const booking = {};
      const integrationIds = [];
      Object.entries(this.calendarModalSelection).forEach(([intId, calIds]) => {
        const cals = Array.isArray(calIds) ? calIds.filter(Boolean) : [];
        if (cals.length) {
          booking[intId] = cals;
          integrationIds.push(Number(intId));
        }
      });
      this.form.booking_calendar_ids = booking;
      this.form.calendar_integration_ids = integrationIds;
      this.closeCalendarModal();
    },
    // Lista consolidada de calendarios seleccionados (todas las cuentas) para el tab Agendas.
    bookingCalendarIdsPayload() {
      const selected = (this.form.calendar_integration_ids || []).map(String);
      return Object.entries(this.form.booking_calendar_ids || {}).reduce(
        (acc, [intId, calIds]) => {
          const cals = Array.isArray(calIds) ? calIds.filter(Boolean) : [];
          if (selected.includes(String(intId)) && cals.length) {
            acc[String(intId)] = cals;
          }
          return acc;
        },
        {}
      );
    },
    // ── proyecto@ai_agent_attachments: gestión de archivos del Agente IA ──────────
    async loadAttachments() {
      if (!this.form.id) return;
      this.isLoadingAttachments = true;
      try {
        const { data } = await AiAgentAttachmentsAPI.list(this.form.id);
        this.attachments = data || [];
      } catch (e) {
        this.attachments = [];
      } finally {
        this.isLoadingAttachments = false;
      }
    },
    // @knowledge_sources: fuentes Discourse activas para @buscar_foro(nombre)
    // @query_databases — prefijo de la directiva: usa erp_type cuando es único y no
    // genérico (limpio, p.ej. `sae/`); si no, cae al nombre normalizado (sin espacios).
    // Devuelve null si el nombre tiene caracteres que la directiva no admite.
    onAttachmentFileChange(event) {
      const file = event.target.files && event.target.files[0];
      this.attachmentFile = file || null;
      // Sugerir un name slug a partir del filename si está vacío
      if (file && !this.attachmentName) {
        this.attachmentName = file.name
          .replace(/\.[^.]+$/, '')
          .toLowerCase()
          .replace(/[^a-z0-9_-]+/g, '-')
          .replace(/^-+|-+$/g, '')
          .slice(0, 60);
      }
    },
    async uploadAttachment() {
      this.attachmentError = '';
      const name = (this.attachmentName || '').trim();
      if (!name || !/^[a-zA-Z0-9_-]+$/.test(name)) {
        this.attachmentError = this.$t(
          'TRACKING_TEMPLATES.FORM.ATTACHMENTS.INVALID_NAME'
        );
        return;
      }
      if (!this.attachmentFile) {
        this.attachmentError = this.$t(
          'TRACKING_TEMPLATES.FORM.ATTACHMENTS.NO_FILE'
        );
        return;
      }
      this.isUploadingAttachment = true;
      try {
        const { data } = await AiAgentAttachmentsAPI.upload(this.form.id, {
          name,
          file: this.attachmentFile,
        });
        this.attachments.push(data);
        this.attachmentName = '';
        this.attachmentFile = null;
        if (this.$refs.attachmentFileInput) {
          this.$refs.attachmentFileInput.value = '';
        }
      } catch (e) {
        this.attachmentError =
          e?.response?.data?.errors?.join(', ') ||
          this.$t('TRACKING_TEMPLATES.FORM.ATTACHMENTS.UPLOAD_ERROR');
      } finally {
        this.isUploadingAttachment = false;
      }
    },
    async deleteAttachment(attachment) {
      try {
        await AiAgentAttachmentsAPI.remove(this.form.id, attachment.id);
        this.attachments = this.attachments.filter(a => a.id !== attachment.id);
      } catch (e) {
        // noop: se mantiene en la lista si falla
      }
    },
    // Token de adjunto {{nombre}} como string de runtime (no literal en el template).
    attachmentToken(name) {
      return `${this.braceParams.open}${name}${this.braceParams.close}`;
    },
    copyDirective(attachment) {
      const token = this.attachmentToken(attachment.name);
      if (navigator.clipboard?.writeText) {
        navigator.clipboard.writeText(token);
      }
    },
    startRenameAttachment(attachment) {
      this.renameError = '';
      this.editingAttachmentId = attachment.id;
      this.editingAttachmentName = attachment.name;
    },
    cancelRenameAttachment() {
      this.editingAttachmentId = null;
      this.editingAttachmentName = '';
      this.renameError = '';
    },
    async saveRenameAttachment(attachment) {
      const name = (this.editingAttachmentName || '').trim();
      this.renameError = '';
      if (!/^[a-zA-Z0-9_-]+$/.test(name)) {
        this.renameError = this.$t(
          'TRACKING_TEMPLATES.FORM.ATTACHMENTS.INVALID_NAME'
        );
        return;
      }
      if (name === attachment.name) {
        this.cancelRenameAttachment();
        return;
      }
      try {
        const { data } = await AiAgentAttachmentsAPI.rename(
          this.form.id,
          attachment.id,
          name
        );
        const updated = data || { ...attachment, name };
        this.attachments = this.attachments.map(a =>
          a.id === attachment.id ? { ...a, ...updated } : a
        );
        this.cancelRenameAttachment();
      } catch (e) {
        this.renameError = this.$t(
          'TRACKING_TEMPLATES.FORM.ATTACHMENTS.RENAME_ERROR'
        );
      }
    },
    // ── Selectores: insertar tokens ({{nombre}}, @buscar_..., etc.) en el Entrenamiento ──
    // Recuerda el textarea activo y la posición del cursor antes de abrir un modal
    rememberInsertPos(target) {
      this.pickerTarget = target;
      const textarea =
        target === 'modal'
          ? this.$refs.complementaryModalTextarea
          : this.$refs.complementaryTextarea;
      this.pickerInsertPos = textarea
        ? textarea.selectionStart
        : (this.form.complementary_prompt || '').length;
      this.pickerScrollTop = textarea ? textarea.scrollTop : 0;
    },
    // Inserta un token aislado por espacios en la posición recordada
    insertTokenAtPrompt(rawToken) {
      const text = this.form.complementary_prompt || '';
      const pos =
        this.pickerInsertPos == null ? text.length : this.pickerInsertPos;
      const before = text.slice(0, pos);
      const after = text.slice(pos);
      const needsSpaceBefore = before.length && !/\s$/.test(before);
      const newBefore = `${before}${needsSpaceBefore ? ' ' : ''}${rawToken} `;
      this.form.complementary_prompt = newBefore + after;
      this.$nextTick(() => {
        const textarea =
          this.pickerTarget === 'modal'
            ? this.$refs.complementaryModalTextarea
            : this.$refs.complementaryTextarea;
        if (textarea) {
          const caret = newBefore.length;
          textarea.focus();
          textarea.setSelectionRange(caret, caret);
          // Restaura el scroll previo: evita el salto al final al recuperar el foco.
          textarea.scrollTop = this.pickerScrollTop;
        }
      });
    },
    openAttachmentPicker(target = 'inline') {
      this.rememberInsertPos(target);
      this.showAttachmentPicker = true;
    },
    closeAttachmentPicker() {
      this.showAttachmentPicker = false;
    },
    insertAttachmentDirective(attachment) {
      this.showAttachmentPicker = false;
      this.insertTokenAtPrompt(this.attachmentToken(attachment.name));
    },
    openDirectivePicker(target = 'inline') {
      this.rememberInsertPos(target);
      this.directiveFilter = 'all';
      this.showDirectivePicker = true;
      this.loadCapabilities();
    },
    // Se pide al abrir el modal, no al cargar el formulario: depende del inbox
    // elegido y el modal no se abre en cada edición.
    async loadCapabilities() {
      this.isLoadingCapabilities = true;
      try {
        const { data } = await AiAgentAssistantAPI.getCapabilities({
          inboxId: this.selectedInboxId,
          trackingTemplateId: this.form.id,
        });
        this.capabilities = data.capabilities;
      } catch (error) {
        this.capabilities = [];
      } finally {
        this.isLoadingCapabilities = false;
      }
    },
    capabilityLabel(capability) {
      return this.$t(`AI_AGENT_ASSISTANT.CAPABILITIES.${capability.key}.LABEL`);
    },
    // La regla más cara del módulo, dicha justo donde se inserta la directiva.
    capabilityEffect(capability) {
      if (capability.swallows_prompt) return 'swallows';
      if (capability.renders_prompt) return 'renders';
      return 'keeps';
    },
    effectClasses(effect) {
      if (effect === 'swallows') {
        return 'text-red-700 bg-red-50 dark:text-red-300 dark:bg-red-800/20';
      }
      if (effect === 'renders') {
        return 'text-amber-700 bg-amber-50 dark:text-amber-300 dark:bg-amber-800/20';
      }
      return 'text-green-700 bg-green-50 dark:text-green-300 dark:bg-green-800/20';
    },
    closeDirectivePicker() {
      this.showDirectivePicker = false;
    },
    insertDirective(directive) {
      this.showDirectivePicker = false;
      this.insertTokenAtPrompt(directive.token);
    },
  },
};
</script>

<template>
  <div class="max-w-6xl">
    <!-- Title -->
    <h2 class="text-xl font-bold text-slate-800 dark:text-slate-100 mb-4">
      {{ formTitle }}
    </h2>

    <form class="space-y-4" @submit.prevent="onSubmit">
      <!-- Row 1: Nombre (40%) + Objetivo (60%) -->
      <div class="flex gap-4">
        <label class="w-2/5">
          <span class="text-sm font-medium text-slate-700 dark:text-slate-300">
            {{ $t('TRACKING_TEMPLATES.FORM.NAME.LABEL') }}
            <span class="text-red-500">*</span>
          </span>
          <input
            v-model="form.name"
            type="text"
            :placeholder="$t('TRACKING_TEMPLATES.FORM.NAME.PLACEHOLDER')"
            class="mt-1 w-full rounded-md border px-3 py-2 text-sm bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100"
            :class="
              form.name && !isNameValid
                ? 'border-red-400'
                : 'border-slate-200 dark:border-slate-600'
            "
          />
        </label>

        <label class="w-3/5">
          <span class="text-sm font-medium text-slate-700 dark:text-slate-300">
            {{ $t('TRACKING_TEMPLATES.FORM.OBJECTIVE.LABEL') }}
            <span class="text-red-500">*</span>
          </span>
          <input
            v-model="form.objective"
            type="text"
            :placeholder="$t('TRACKING_TEMPLATES.FORM.OBJECTIVE.PLACEHOLDER')"
            class="mt-1 w-full rounded-md border px-3 py-2 text-sm bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100"
            :class="
              form.objective && !isObjectiveValid
                ? 'border-red-400'
                : 'border-slate-200 dark:border-slate-600'
            "
          />
        </label>
      </div>

      <!-- Tabs de nivel superior: Agente IA / Agente seguimiento -->
      <woot-tabs
        class="[&_.tabs]:p-0 [&_.tabs]:mb-0"
        :index="topTab"
        @change="onTopTabChange"
      >
        <woot-tabs-item name="Agente IA" :show-badge="false" />
        <woot-tabs-item name="Agente seguimiento" :show-badge="false" />
      </woot-tabs>

      <!-- ===== Agente seguimiento: intervalo + canal + plantillas WhatsApp ===== -->
      <div v-show="topTab === 1" class="space-y-4">
      <!-- Intervalo entre intentos + Canal -->
      <div class="flex gap-3">
        <label class="flex-1">
          <span class="text-xs font-medium text-slate-600 dark:text-slate-400"
            >⏱️ Tiempo entre intentos</span
          >
          <input
            v-model.number="form.retry_interval_value"
            type="number"
            :min="minIntervalValue"
            class="mt-1 w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-800 px-3 py-2 text-sm"
          />
        </label>
        <label class="flex-1">
          <span class="text-xs font-medium text-slate-600 dark:text-slate-400"
            >Intervalo</span
          >
          <select
            v-model="form.retry_interval_unit"
            class="mt-1 w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-800 px-3 py-2 text-sm"
          >
            <option value="minutes">Minutos</option>
            <option value="hours">Horas</option>
            <option value="days">Días</option>
          </select>
        </label>
        <label class="flex-1">
          <span class="text-xs font-medium text-slate-600 dark:text-slate-400">
            {{ $t('TRACKING_TEMPLATES.FORM.WHATSAPP_SECTION.MAX_ATTEMPTS') }}
          </span>
          <input
            v-model.number="maxAttempts"
            type="number"
            min="1"
            max="6"
            class="mt-1 w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-800 px-3 py-2 text-sm"
          />
        </label>
        <label class="flex-1">
          <span class="text-xs font-medium text-slate-600 dark:text-slate-400">
            {{ $t('TRACKING_TEMPLATES.FORM.WHATSAPP_SECTION.INBOX_LABEL') }}
            <span class="text-red-500">*</span>
          </span>
          <select
            v-model="selectedInboxId"
            class="mt-1 w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-800 px-3 py-2 text-sm"
          >
            <option :value="null">
              {{ $t('TRACKING_TEMPLATES.FORM.WHATSAPP_SECTION.SELECT_INBOX') }}
            </option>
            <option
              v-for="inbox in trackingBotInboxes"
              :key="inbox.id"
              :value="inbox.id"
            >
              {{ inbox.name }}
            </option>
          </select>
        </label>
      </div>

      <!-- Plantillas WhatsApp por intento (solo cuando el canal es WhatsApp) -->
      <div v-if="selectedInboxIsWhatsApp" class="mt-2">
        <!-- Selector WA por intento (el Núm. intentos vive arriba, en la fila
             de intervalo/canal) -->
        <div v-if="availableWATemplates.length > 0">
          <div class="flex items-center gap-6 mb-2 flex-wrap">
            <div class="flex gap-2 flex-wrap">
              <button
                v-for="idx in attemptTabs"
                :key="idx"
                type="button"
                class="px-4 py-2 text-sm rounded-md transition-colors"
                :class="
                  activeTemplateTab === idx
                    ? 'bg-woot-500 text-white'
                    : form.whatsapp_templates[idx]
                    ? 'bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-600'
                    : 'bg-red-50 dark:bg-red-900/20 text-red-500 border border-red-300 dark:border-red-700 hover:bg-red-100'
                "
                @click="activeTemplateTab = idx"
              >
                {{ getAttemptLabel(idx) }}
                <span v-if="form.whatsapp_templates[idx]" class="ml-1"
                  >&#10003;</span
                >
                <span v-else class="ml-1">!</span>
              </button>
            </div>
          </div>
          <div
            v-for="idx in attemptTabs"
            v-show="activeTemplateTab === idx"
            :key="'tpl-' + idx"
            class="space-y-2"
          >
            <select
              v-model="form.whatsapp_templates[idx]"
              class="w-full rounded-md border px-3 py-2 text-sm bg-white dark:bg-slate-800"
              :class="
                !form.whatsapp_templates[idx]
                  ? 'border-red-400'
                  : 'border-slate-200 dark:border-slate-600'
              "
            >
              <option value="">-- Selecciona una plantilla --</option>
              <option
                v-for="tpl in availableWATemplates"
                :key="tpl.id"
                :value="tpl.name"
              >
                {{ tpl.name }} ({{ tpl.language }})
              </option>
            </select>
            <div
              v-if="form.whatsapp_templates[idx]"
              class="text-xs text-slate-500 dark:text-slate-400 bg-slate-50 dark:bg-slate-800 p-2 rounded border border-slate-100 dark:border-slate-700"
            >
              {{ getTemplateBody(form.whatsapp_templates[idx]) }}
            </div>
          </div>
        </div>

        <!-- Loading -->
        <div
          v-else-if="isLoadingWATemplates"
          class="text-sm text-slate-500 py-2"
        >
          {{ $t('TRACKING_TEMPLATES.FORM.WHATSAPP_SECTION.LOADING') }}
        </div>

        <!-- Sin plantillas WA -->
        <div
          v-else-if="!isLoadingWATemplates"
          class="p-3 rounded-md bg-slate-50 dark:bg-slate-800 text-sm text-slate-500 dark:text-slate-400"
        >
          {{ $t('TRACKING_TEMPLATES.FORM.WHATSAPP_SECTION.NO_TEMPLATES') }}
        </div>
      </div>
      </div>
      <!-- ===== fin Agente seguimiento ===== -->

      <!-- ===== Agente IA: Contexto IA, Entrenamiento, Reglas, Agendas, Archivos ===== -->
      <div v-show="topTab === 0" class="flex-1 flex flex-col">
        <div class="flex items-end justify-between">
          <woot-tabs
            class="context-tabs [&_.tabs]:p-0 [&_.tabs]:mb-0 flex-1"
            :index="activeContextTab"
            @change="onContextTabChange"
          >
            <woot-tabs-item name="Contexto IA *" :show-badge="false" />
            <woot-tabs-item name="Entrenamiento *" :show-badge="false" />
            <woot-tabs-item name="Reglas" :show-badge="false" />
            <woot-tabs-item name="Agendas" :show-badge="false" />
            <woot-tabs-item name="Archivos" :show-badge="false" />
          </woot-tabs>
          <div class="flex items-center gap-2 pb-2 pl-2 shrink-0">
            <!-- proyecto@contact_tracking: insertar directiva (@buscar_..., @discourse, etc.) -->
            <a
              v-if="activeContextTab === 1"
              href="#"
              class="text-woot-500 hover:text-woot-600 dark:text-woot-400 dark:hover:text-woot-300"
              title="Insertar directiva"
              @click.prevent="openDirectivePicker('inline')"
            >
              <fluent-icon icon="code" size="18" />
            </a>
            <!-- proyecto@ai_agent_attachments: insertar {{nombre}} desde un selector -->
            <a
              v-if="activeContextTab === 1 && attachments.length"
              href="#"
              class="text-green-500 hover:text-green-600 dark:text-green-400 dark:hover:text-green-300"
              :title="$t('TRACKING_TEMPLATES.FORM.ATTACHMENTS.INSERT_BTN')"
              @click.prevent="openAttachmentPicker('inline')"
            >
              <fluent-icon icon="attach" size="18" />
            </a>
            <a
              v-if="activeContextTab === 0 || activeContextTab === 1"
              href="#"
              class="text-slate-400 hover:text-woot-500 dark:text-slate-500 dark:hover:text-woot-400"
              title="Expandir editor"
              @click.prevent="
                activeContextTab === 0
                  ? (showAiContextModal = true)
                  : (showPromptModal = true)
              "
            >
              <fluent-icon icon="arrow-expand" size="18" />
            </a>
          </div>
        </div>

        <!-- Tab 0: Contexto IA -->
        <div v-show="activeContextTab === 0" class="mt-2">
          <textarea
            v-model="form.ai_context"
            rows="10"
            :placeholder="$t('TRACKING_TEMPLATES.FORM.AI_CONTEXT.PLACEHOLDER')"
            class="w-full bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200"
          />
          <div class="flex justify-between items-center mt-1">
            <span class="text-xs text-slate-500 dark:text-slate-400">
              Instrucciones para la IA al generar mensajes de seguimiento
            </span>
            <div class="flex gap-3">
              <a
                v-if="originalAiContext"
                href="#"
                class="text-xs text-slate-500 hover:text-slate-700 dark:hover:text-slate-300"
                @click.prevent="restoreOriginal('ai_context')"
              >
                &#8617; Restaurar original
              </a>
              <a
                href="#"
                class="text-xs inline-flex items-center gap-1"
                :class="
                  form.ai_context && form.ai_context.trim() && !isImprovingAI
                    ? 'text-woot-500 hover:text-woot-600 cursor-pointer'
                    : 'text-slate-300 dark:text-slate-600 cursor-not-allowed'
                "
                @click.prevent="
                  form.ai_context &&
                    form.ai_context.trim() &&
                    !isImprovingAI &&
                    improveWithAI('ai_context')
                "
              >
                <span
                  v-if="isImprovingAI && activeContextTab === 0"
                  class="inline-block w-4 h-4 border-2 border-woot-500 border-t-transparent rounded-full animate-spin"
                />
                <span v-else>&#10024;</span>
                {{
                  isImprovingAI && activeContextTab === 0
                    ? 'Procesando...'
                    : 'Mejorar con IA'
                }}
              </a>
            </div>
          </div>
        </div>

        <!-- Tab 1: Entrenamiento -->
        <div v-show="activeContextTab === 1" class="mt-2">
          <textarea
            ref="complementaryTextarea"
            v-model="form.complementary_prompt"
            rows="10"
            :placeholder="
              $t('TRACKING_TEMPLATES.FORM.COMPLEMENTARY_PROMPT.PLACEHOLDER')
            "
            class="w-full bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200"
          />
          <div class="flex justify-between items-center mt-1">
            <span class="text-xs text-slate-500 dark:text-slate-400">
              Este prompt se usa cuando el cliente hace preguntas relacionadas
              con el seguimiento
            </span>
            <div class="flex gap-3">
              <a
                v-if="originalComplementaryPrompt"
                href="#"
                class="text-xs text-slate-500 hover:text-slate-700 dark:hover:text-slate-300"
                @click.prevent="restoreOriginal('complementary_prompt')"
              >
                &#8617; Restaurar original
              </a>
              <a
                href="#"
                class="text-xs inline-flex items-center gap-1"
                :class="
                  canGeneratePrompt && !isImprovingAI
                    ? 'text-woot-500 hover:text-woot-600 cursor-pointer'
                    : 'text-slate-300 dark:text-slate-600 cursor-not-allowed'
                "
                @click.prevent="
                  canGeneratePrompt &&
                    !isImprovingAI &&
                    improveWithAI('complementary_prompt')
                "
              >
                <span
                  v-if="isImprovingAI && activeContextTab === 1"
                  class="inline-block w-4 h-4 border-2 border-woot-500 border-t-transparent rounded-full animate-spin"
                />
                <span v-else>&#10024;</span>
                {{
                  isImprovingAI && activeContextTab === 1
                    ? 'Procesando...'
                    : 'Generar Prompt con IA'
                }}
              </a>
            </div>
          </div>
        </div>

        <!-- Tab Reglas (índice 2) -->
        <div v-show="activeContextTab === reglasTabIndex" class="mt-2">
          <keyword-actions-editor v-model="form.keyword_actions" />
        </div>

        <!-- Tab Agendas -->
        <div v-show="activeContextTab === agendasTabIndex" class="mt-2">
          <p class="text-xs text-slate-500 dark:text-slate-400 mb-3">
            {{ $t('TRACKING_TEMPLATES.CALENDARS.DESCRIPTION') }}
          </p>

          <!-- Duración del evento -->
          <div class="mb-4">
            <span
              class="text-xs font-medium text-slate-600 dark:text-slate-400 block mb-2"
            >
              {{ $t('TRACKING_TEMPLATES.CALENDARS.EVENT_DURATION') }}
            </span>
            <div class="flex gap-2">
              <button
                v-for="option in [
                  { value: 30, label: '30 min' },
                  { value: 60, label: '1 hora' },
                  { value: 120, label: '2 horas' },
                ]"
                :key="option.value"
                type="button"
                class="px-4 py-2 text-sm rounded-md border transition-colors"
                :class="
                  form.calendar_event_duration === option.value
                    ? 'bg-woot-500 text-white border-woot-500'
                    : 'bg-white dark:bg-slate-800 text-slate-600 dark:text-slate-300 border-slate-200 dark:border-slate-600 hover:bg-slate-50 dark:hover:bg-slate-700'
                "
                @click="form.calendar_event_duration = option.value"
              >
                {{ option.label }}
              </button>
            </div>
          </div>

          <!-- proyecto@bot_seguimiento_calendar: zona horaria del agente para agendar -->
          <div class="mb-4">
            <span
              class="text-xs font-medium text-slate-600 dark:text-slate-400 block mb-2"
            >
              {{ $t('TRACKING_TEMPLATES.CALENDARS.TIMEZONE') }}
            </span>
            <select
              v-model="form.timezone"
              class="w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-800 px-3 py-2 text-sm text-slate-700 dark:text-slate-200"
            >
              <option value="">
                {{ $t('TRACKING_TEMPLATES.CALENDARS.TIMEZONE_INHERIT') }}
              </option>
              <option v-for="tz in timeZones" :key="tz.label" :value="tz.value">
                {{ tz.label }}
              </option>
            </select>
            <p class="text-xs text-slate-400 dark:text-slate-500 pt-1">
              {{ $t('TRACKING_TEMPLATES.CALENDARS.TIMEZONE_HELP') }}
            </p>
          </div>

          <!-- proyecto@bot_seguimiento_calendar: una sola lista de calendarios + modal árbol -->
          <div class="flex items-center justify-between mb-2">
            <span
              class="text-xs font-medium text-slate-600 dark:text-slate-400"
            >
              {{ $t('TRACKING_TEMPLATES.CALENDARS.BOOKING_TARGET_LABEL') }}
            </span>
            <button
              v-if="!isLoadingCalendars && calendarIntegrations.length > 0"
              type="button"
              class="text-xs text-woot-600 dark:text-woot-400 hover:underline"
              @click.prevent="openCalendarModal"
            >
              + {{ $t('TRACKING_TEMPLATES.CALENDARS.SELECT_CALENDARS') }}
            </button>
          </div>

          <div v-if="isLoadingCalendars" class="text-sm text-slate-500 py-2">
            {{ $t('TRACKING_TEMPLATES.CALENDARS.LOADING') }}
          </div>
          <div
            v-else-if="calendarIntegrations.length === 0"
            class="p-3 rounded-md bg-slate-50 dark:bg-slate-800 text-sm text-slate-500 dark:text-slate-400"
          >
            {{ $t('TRACKING_TEMPLATES.CALENDARS.NONE_AVAILABLE') }}
          </div>
          <template v-else>
            <div
              v-if="allSelectedCalendars.length"
              class="flex flex-wrap gap-1.5"
            >
              <span
                v-for="item in allSelectedCalendars"
                :key="item.key"
                :title="item.email"
                class="inline-flex items-center gap-1.5 text-xs rounded-full border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 pl-2 pr-1 py-1"
              >
                <span
                  class="inline-block w-2 h-2 rounded-sm flex-shrink-0"
                  :style="{ backgroundColor: item.background_color }"
                />
                <span class="text-slate-700 dark:text-slate-200">{{
                  item.summary
                }}</span>
                <span
                  v-if="item.primary"
                  class="text-slate-400 dark:text-slate-500"
                >
                  ·
                  {{
                    $t('TRACKING_TEMPLATES.CALENDARS.BOOKING_TARGET_PRIMARY')
                  }}
                </span>
                <button
                  type="button"
                  class="text-slate-400 hover:text-red-500 leading-none ml-0.5"
                  :aria-label="
                    $t('TRACKING_TEMPLATES.CALENDARS.REMOVE_CALENDAR')
                  "
                  @click.prevent="
                    removeSelectedCalendar(item.integrationId, item.id)
                  "
                >
                  ×
                </button>
              </span>
            </div>
            <div
              v-else
              class="p-3 rounded-md bg-slate-50 dark:bg-slate-800 text-sm text-slate-500 dark:text-slate-400"
            >
              {{ $t('TRACKING_TEMPLATES.CALENDARS.EMPTY_SELECTION') }}
            </div>
            <p class="text-xs text-slate-400 dark:text-slate-500 mt-2">
              {{ $t('TRACKING_TEMPLATES.CALENDARS.BOOKING_TARGET_HINT') }}
            </p>
          </template>

          <!-- proyecto@bot_seguimiento_calendar: formato de presentación de horarios -->
          <div class="mt-5">
            <span
              class="text-xs font-medium text-slate-600 dark:text-slate-400 block mb-2"
            >
              {{ $t('TRACKING_TEMPLATES.CALENDARS.PRESENTATION_LABEL') }}
            </span>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
              <label
                v-for="opt in slotsPresentationOptions"
                :key="opt.value"
                class="flex flex-col gap-1 p-3 rounded-md border cursor-pointer transition-colors"
                :class="
                  form.slots_presentation === opt.value
                    ? 'border-woot-400 bg-woot-50 dark:bg-woot-900/20'
                    : 'border-slate-200 dark:border-slate-600 hover:bg-slate-50 dark:hover:bg-slate-800'
                "
              >
                <span class="flex items-center gap-2">
                  <input
                    type="radio"
                    class="accent-woot-500"
                    :value="opt.value"
                    :checked="form.slots_presentation === opt.value"
                    @change="form.slots_presentation = opt.value"
                  />
                  <span
                    class="text-sm font-medium text-slate-700 dark:text-slate-200"
                  >
                    {{ opt.label }}
                  </span>
                </span>
                <pre
                  class="text-[11px] leading-snug text-slate-500 dark:text-slate-400 whitespace-pre-wrap font-sans pl-6"
                  >{{ opt.preview }}</pre
                >
              </label>
            </div>
          </div>
        </div>

        <!-- Tab Archivos (proyecto@ai_agent_attachments) -->
        <div v-show="activeContextTab === archivosTabIndex" class="mt-2">
          <p class="text-xs text-slate-500 dark:text-slate-400 mb-3">
            {{
              $t('TRACKING_TEMPLATES.FORM.ATTACHMENTS.DESCRIPTION', braceParams)
            }}
          </p>

          <!-- En modo creación hay que guardar primero para tener un Agente IA al que adjuntar -->
          <div
            v-if="!form.id"
            class="p-3 rounded-md bg-slate-50 dark:bg-slate-800 text-sm text-slate-500 dark:text-slate-400"
          >
            {{ $t('TRACKING_TEMPLATES.FORM.ATTACHMENTS.SAVE_FIRST') }}
          </div>

          <template v-else>
            <!-- Subir archivo -->
            <div class="mb-3">
              <span
                class="block text-xs font-medium text-slate-600 dark:text-slate-400"
              >
                {{ $t('TRACKING_TEMPLATES.FORM.ATTACHMENTS.NAME_LABEL') }}
              </span>
              <div class="flex items-center gap-2 mt-1">
                <input
                  v-model="attachmentName"
                  type="text"
                  :placeholder="
                    $t('TRACKING_TEMPLATES.FORM.ATTACHMENTS.NAME_PLACEHOLDER')
                  "
                  class="flex-1 min-w-0 rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-800 px-3 py-2 text-sm"
                />
                <!-- input nativo oculto: el filename largo no se muestra -->
                <input
                  ref="attachmentFileInput"
                  type="file"
                  class="hidden"
                  @change="onAttachmentFileChange"
                />
                <woot-button
                  color-scheme="success"
                  size="small"
                  class="shrink-0 upload-ctl-btn"
                  :icon="attachmentFile ? 'checkmark' : 'attach'"
                  @click.prevent="$refs.attachmentFileInput.click()"
                >
                  {{ $t('TRACKING_TEMPLATES.FORM.ATTACHMENTS.SELECT_FILE') }}
                </woot-button>
                <woot-button
                  size="small"
                  class="shrink-0 upload-ctl-btn min-w-[96px] justify-center"
                  :is-loading="isUploadingAttachment"
                  :is-disabled="isUploadingAttachment || !attachmentFile"
                  @click.prevent="uploadAttachment"
                >
                  {{ $t('TRACKING_TEMPLATES.FORM.ATTACHMENTS.UPLOAD') }}
                </woot-button>
              </div>
            </div>
            <p v-if="attachmentError" class="text-xs text-red-500 mb-2">
              {{ attachmentError }}
            </p>

            <!-- Listado -->
            <div
              v-if="isLoadingAttachments"
              class="text-sm text-slate-500 py-2"
            >
              {{ $t('TRACKING_TEMPLATES.FORM.ATTACHMENTS.LOADING') }}
            </div>
            <div
              v-else-if="attachments.length === 0"
              class="p-3 rounded-md bg-slate-50 dark:bg-slate-800 text-sm text-slate-500 dark:text-slate-400"
            >
              {{ $t('TRACKING_TEMPLATES.FORM.ATTACHMENTS.EMPTY', braceParams) }}
            </div>
            <ul v-else class="space-y-2 max-h-[208px] overflow-y-auto pr-1">
              <li
                v-for="att in attachments"
                :key="att.id"
                class="flex items-center gap-3 p-2.5 rounded-md border border-slate-200 dark:border-slate-600"
              >
                <fluent-icon
                  icon="document"
                  size="18"
                  class="text-slate-400 shrink-0"
                />
                <!-- Modo renombrar -->
                <template v-if="editingAttachmentId === att.id">
                  <div class="flex flex-col min-w-0 flex-1 gap-1">
                    <div class="flex items-center gap-1">
                      <span class="text-xs text-slate-400 shrink-0">{{
                        braceParams.open
                      }}</span>
                      <input
                        v-model="editingAttachmentName"
                        type="text"
                        class="reset-base box-border w-full h-8 m-0 text-xs rounded border border-solid border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 px-2 outline-none focus:border-woot-500"
                        @keyup.enter="saveRenameAttachment(att)"
                        @keyup.esc="cancelRenameAttachment"
                      />
                      <span class="text-xs text-slate-400 shrink-0">{{
                        braceParams.close
                      }}</span>
                    </div>
                    <span v-if="renameError" class="text-xs text-red-500">{{
                      renameError
                    }}</span>
                  </div>
                  <a
                    href="#"
                    class="text-xs text-woot-500 hover:text-woot-600"
                    @click.prevent="saveRenameAttachment(att)"
                  >
                    {{ $t('TRACKING_TEMPLATES.FORM.ATTACHMENTS.RENAME_SAVE') }}
                  </a>
                  <a
                    href="#"
                    class="text-xs text-slate-500 hover:text-slate-600"
                    @click.prevent="cancelRenameAttachment"
                  >
                    {{
                      $t('TRACKING_TEMPLATES.FORM.ATTACHMENTS.RENAME_CANCEL')
                    }}
                  </a>
                </template>
                <!-- Modo normal -->
                <template v-else>
                  <div class="flex flex-col min-w-0 flex-1">
                    <code
                      class="text-xs font-semibold text-woot-600 dark:text-woot-400"
                    >
                      {{ attachmentToken(att.name) }}
                    </code>
                    <span
                      class="text-xs text-slate-500 dark:text-slate-400 truncate"
                    >
                      {{ att.filename }}
                    </span>
                  </div>
                  <a
                    href="#"
                    class="text-xs text-slate-500 hover:text-woot-500"
                    :title="$t('TRACKING_TEMPLATES.FORM.ATTACHMENTS.COPY')"
                    @click.prevent="copyDirective(att)"
                  >
                    {{ $t('TRACKING_TEMPLATES.FORM.ATTACHMENTS.COPY') }}
                  </a>
                  <a
                    href="#"
                    class="text-xs text-slate-500 hover:text-woot-500"
                    @click.prevent="startRenameAttachment(att)"
                  >
                    {{ $t('TRACKING_TEMPLATES.FORM.ATTACHMENTS.RENAME') }}
                  </a>
                  <a
                    href="#"
                    class="text-xs text-red-500 hover:text-red-600"
                    @click.prevent="deleteAttachment(att)"
                  >
                    {{ $t('TRACKING_TEMPLATES.FORM.ATTACHMENTS.DELETE') }}
                  </a>
                </template>
              </li>
            </ul>
          </template>
        </div>
      </div>

      <!-- proyecto@ai_agent_assistant: semáforo del linter -->
      <LintBadges
        class="pt-4 border-t border-slate-200 dark:border-slate-700"
        :findings="lintFindings"
        :is-loading="isLinting"
      />

      <!-- Botones -->
      <div class="flex flex-wrap items-center justify-end gap-2 pt-4">
        <!-- proyecto@ai_agent_assistant (F4): qué cambiaste. Va al historial, no al
             agente: es lo que hace legible un diff dentro de tres meses. -->
        <input
          v-if="!isCreateMode"
          v-model="versionNote"
          type="text"
          maxlength="255"
          class="h-8 py-0 mb-0 mr-auto text-sm w-72"
          :placeholder="$t('AI_AGENT_ASSISTANT.VERSIONS.NOTE_PLACEHOLDER')"
        />
        <woot-button
          variant="clear"
          color-scheme="secondary"
          @click.prevent="onCancel"
        >
          {{ $t('TRACKING_TEMPLATES.EDIT.CANCEL') }}
        </woot-button>
        <woot-button
          variant="clear"
          icon="book-clock"
          @click.prevent="showPatterns = true"
        >
          {{ $t('AI_AGENT_ASSISTANT.PATTERNS.OPEN') }}
        </woot-button>
        <woot-button
          v-if="!isCreateMode"
          variant="clear"
          icon="arrow-rotate-counter-clockwise"
          @click.prevent="showVersions = true"
        >
          {{ $t('AI_AGENT_ASSISTANT.VERSIONS.OPEN') }}
        </woot-button>
        <!-- Ramificar, no versionar: para mejorar ESTE agente está el historial. -->
        <woot-button
          v-if="!isCreateMode"
          variant="clear"
          icon="copy"
          @click.prevent="openDuplicate"
        >
          {{ $t('AI_AGENT_ASSISTANT.VERSIONS.DUPLICATE') }}
        </woot-button>
        <woot-button
          variant="clear"
          icon="code"
          @click.prevent="showSandbox = true"
        >
          {{ $t('AI_AGENT_ASSISTANT.SANDBOX.OPEN') }}
        </woot-button>
        <woot-button
          :disabled="hasLintErrors"
          :title="hasLintErrors ? $t('AI_AGENT_ASSISTANT.LINT_BLOCKED') : ''"
          @click.prevent="onSubmit"
        >
          {{ submitText }}
        </woot-button>
      </div>

      <!-- proyecto@ai_agent_assistant: probador. Previsualiza el BORRADOR actual,
           no lo último guardado, por eso recibe buildPayload(). -->
      <SandboxDrawer
        :show="showSandbox"
        :payload="showSandbox ? buildPayload() : {}"
        @close="showSandbox = false"
      />

      <!-- proyecto@ai_agent_assistant (F4): historial en sitio. Iterar sobre el MISMO
           agente en vez de duplicarlo en «… V2 / V3 / V4». -->
      <!-- proyecto@ai_agent_assistant (F6): bloques insertables. Sabe callarse
           cuando el prompt en curso los volvería letra muerta. -->
      <PatternLibraryDrawer
        :show="showPatterns"
        :prompt="form.complementary_prompt"
        :inbox-id="selectedInboxId"
        :tracking-template-id="form.id"
        @close="showPatterns = false"
        @insert="onPatternInsert"
      />

      <!-- proyecto@ai_agent_assistant: el asistente ya no vive aquí en un cajón. Es
           una página propia, y se llega desde la cabecera: allí el agente se trabaja
           sobre una copia y al guardar queda como versión nueva de este mismo agente.
           Un chat de nueve pasos dentro de un modal de 75vh era el sitio equivocado. -->

      <!-- Ramificar. El nombre se pide aquí porque es único por cuenta y porque es
           la única forma de que la copia se distinga del original en la lista. -->
      <woot-modal
        :show="showDuplicate"
        :on-close="() => (showDuplicate = false)"
        size="small"
      >
        <woot-modal-header
          :header-title="$t('AI_AGENT_ASSISTANT.VERSIONS.DUPLICATE_TITLE')"
          :header-content="$t('AI_AGENT_ASSISTANT.VERSIONS.DUPLICATE_HINT')"
        />
        <div class="flex flex-col gap-4 px-8 pb-6">
          <label class="mb-0">
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-200"
            >
              {{ $t('AI_AGENT_ASSISTANT.VERSIONS.DUPLICATE_NAME') }}
            </span>
            <input v-model="duplicateName" type="text" class="mt-1 mb-0" />
          </label>
          <p class="m-0 text-xs text-slate-500 dark:text-slate-400">
            {{ $t('AI_AGENT_ASSISTANT.VERSIONS.DUPLICATE_SAVED_ONLY') }}
          </p>
          <div class="flex items-center gap-2">
            <woot-button
              :is-loading="isDuplicating"
              :is-disabled="!duplicateName.trim()"
              @click.prevent="onDuplicate"
            >
              {{ $t('AI_AGENT_ASSISTANT.VERSIONS.DUPLICATE_CONFIRM') }}
            </woot-button>
            <woot-button variant="clear" @click.prevent="showDuplicate = false">
              {{ $t('TRACKING_TEMPLATES.EDIT.CANCEL') }}
            </woot-button>
          </div>
        </div>
      </woot-modal>

      <VersionsDrawer
        v-if="!isCreateMode"
        :show="showVersions"
        :template-id="form.id"
        @close="showVersions = false"
        @restored="onVersionRestored"
      />
    </form>

    <!-- proyecto@bot_seguimiento_calendar: modal árbol de calendarios agendables -->
    <woot-modal
      :show="showCalendarModal"
      :on-close="closeCalendarModal"
      size="small"
    >
      <woot-modal-header
        :header-title="$t('TRACKING_TEMPLATES.CALENDARS.MODAL_TITLE')"
        :header-content="$t('TRACKING_TEMPLATES.CALENDARS.MODAL_SUBTITLE')"
      />
      <div class="px-8 pb-6 flex flex-col gap-4">
        <!-- Una sección por cuenta: su Primario y sus Secundarios -->
        <div
          v-for="integration in calendarIntegrations"
          :key="integration.id"
          class="flex flex-col gap-1"
        >
          <p class="text-xs font-medium text-slate-600 dark:text-slate-300">
            {{ integration.user_name }}
            <span class="font-normal text-slate-400 dark:text-slate-500"
              >· {{ integration.google_email }}</span
            >
          </p>
          <div
            v-if="bookableCalendarsFor(integration).length === 0"
            class="text-xs text-slate-400 dark:text-slate-500 italic py-1 pl-1"
          >
            {{
              $t('TRACKING_TEMPLATES.CALENDARS.BOOKING_TARGET_PRIMARY_FALLBACK')
            }}
          </div>
          <div v-else class="space-y-0.5">
            <label
              v-for="cal in bookableCalendarsFor(integration)"
              :key="cal.id"
              class="flex items-center gap-2 text-sm cursor-pointer p-1.5 rounded-md hover:bg-slate-50 dark:hover:bg-slate-800"
            >
              <input
                type="checkbox"
                class="accent-woot-500"
                :checked="isModalCalendarChecked(integration.id, cal.id)"
                @change="toggleModalCalendar(integration.id, cal.id)"
              />
              <span
                class="inline-block w-2.5 h-2.5 rounded-sm flex-shrink-0"
                :style="{ backgroundColor: cal.background_color }"
              />
              <span class="text-slate-700 dark:text-slate-200">{{
                cal.summary
              }}</span>
              <span
                class="text-xs"
                :class="
                  cal.primary
                    ? 'text-woot-500'
                    : 'text-slate-400 dark:text-slate-500'
                "
              >
                ({{
                  cal.primary
                    ? $t('TRACKING_TEMPLATES.CALENDARS.BOOKING_TARGET_PRIMARY')
                    : $t(
                        'TRACKING_TEMPLATES.CALENDARS.BOOKING_TARGET_SECONDARY'
                      )
                }})
              </span>
            </label>
          </div>
        </div>

        <div
          class="flex justify-end gap-2 pt-3 border-t border-slate-200 dark:border-slate-700"
        >
          <woot-button
            variant="clear"
            type="button"
            @click="closeCalendarModal"
          >
            {{ $t('TRACKING_TEMPLATES.CALENDARS.MODAL_CANCEL') }}
          </woot-button>
          <woot-button type="button" @click="confirmCalendarModal">
            {{ $t('TRACKING_TEMPLATES.CALENDARS.MODAL_DONE') }}
          </woot-button>
        </div>
      </div>
    </woot-modal>

    <!-- Modal de validación -->
    <woot-modal
      :show="showValidationModal"
      :on-close="() => (showValidationModal = false)"
      size="small"
    >
      <woot-modal-header
        header-title="⚠️ Información incompleta"
        header-content="Corrige los siguientes errores antes de guardar el Agente IA."
      />
      <div class="px-8 pb-6 flex flex-col gap-3">
        <ul class="space-y-2">
          <li
            v-for="(error, i) in validationErrors"
            :key="i"
            class="flex items-start gap-2 text-sm text-red-600 dark:text-red-400"
          >
            <span class="mt-0.5">•</span>
            <span>{{ error }}</span>
          </li>
        </ul>
        <div
          class="flex justify-end pt-3 border-t border-slate-200 dark:border-slate-700"
        >
          <woot-button type="button" @click="showValidationModal = false">
            Entendido
          </woot-button>
        </div>
      </div>
    </woot-modal>

    <!-- Modal expandido: Contexto IA -->
    <woot-modal
      :show="showAiContextModal"
      :on-close="() => (showAiContextModal = false)"
      size="medium"
    >
      <woot-modal-header
        header-title="🧠 Contexto IA"
        header-content="Instrucciones para la IA al generar mensajes de seguimiento."
      />
      <div class="px-8 pb-6 flex flex-col gap-3">
        <textarea
          v-model="form.ai_context"
          rows="20"
          :placeholder="$t('TRACKING_TEMPLATES.FORM.AI_CONTEXT.PLACEHOLDER')"
          class="w-full bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200"
        />
        <div
          class="flex justify-end pt-2 border-t border-slate-200 dark:border-slate-700"
        >
          <woot-button type="button" @click="showAiContextModal = false">
            Listo
          </woot-button>
        </div>
      </div>
    </woot-modal>

    <!-- Modal expandido: Entrenamiento -->
    <woot-modal
      :show="showPromptModal"
      :on-close="() => (showPromptModal = false)"
      size="medium"
    >
      <woot-modal-header
        header-title="💡 Entrenamiento"
        header-content="Instrucciones adicionales para responder preguntas del cliente sobre este Agente IA."
      />
      <div class="px-8 pb-6 flex flex-col gap-3">
        <!-- selectores de tokens: directiva (@buscar_...) y adjunto ({{nombre}}) -->
        <div class="flex items-center gap-2 justify-start">
          <a
            href="#"
            class="text-woot-500 hover:text-woot-600 dark:text-woot-400 dark:hover:text-woot-300"
            title="Insertar directiva"
            @click.prevent="openDirectivePicker('modal')"
          >
            <fluent-icon icon="code" size="18" />
          </a>
          <a
            v-if="attachments.length"
            href="#"
            class="text-green-500 hover:text-green-600 dark:text-green-400 dark:hover:text-green-300"
            :title="$t('TRACKING_TEMPLATES.FORM.ATTACHMENTS.INSERT_BTN')"
            @click.prevent="openAttachmentPicker('modal')"
          >
            <fluent-icon icon="attach" size="18" />
          </a>
        </div>
        <textarea
          ref="complementaryModalTextarea"
          v-model="form.complementary_prompt"
          rows="12"
          :placeholder="
            $t('TRACKING_TEMPLATES.FORM.COMPLEMENTARY_PROMPT.PLACEHOLDER')
          "
          class="w-full bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200"
        />
        <div
          class="flex justify-end pt-2 border-t border-slate-200 dark:border-slate-700"
        >
          <woot-button type="button" @click="showPromptModal = false">
            Listo
          </woot-button>
        </div>
      </div>
    </woot-modal>

    <!-- proyecto@ai_agent_attachments: selector de archivos para insertar {{nombre}} -->
    <woot-modal
      :show="showAttachmentPicker"
      :on-close="closeAttachmentPicker"
      size="medium"
    >
      <woot-modal-header
        :header-title="$t('TRACKING_TEMPLATES.FORM.ATTACHMENTS.PICKER_TITLE')"
        :header-content="
          $t('TRACKING_TEMPLATES.FORM.ATTACHMENTS.PICKER_HELP', braceParams)
        "
      />
      <div class="px-8 pb-6">
        <ul class="space-y-2 max-h-[320px] overflow-y-auto pr-1">
          <li v-for="att in attachments" :key="att.id">
            <button
              type="button"
              class="w-full flex items-center justify-between gap-3 text-left rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 px-3 py-2 hover:border-woot-500 hover:bg-woot-25 dark:hover:bg-slate-800 transition-colors"
              @click="insertAttachmentDirective(att)"
            >
              <span class="min-w-0">
                <span
                  class="block text-sm font-medium text-woot-600 dark:text-woot-400 truncate"
                >
                  {{ attachmentToken(att.name) }}
                </span>
                <span
                  class="block text-xs text-slate-500 dark:text-slate-400 truncate"
                >
                  {{ att.filename }}
                </span>
              </span>
              <fluent-icon
                icon="add"
                size="16"
                class="shrink-0 text-slate-400"
              />
            </button>
          </li>
          <!-- Lo que esta cuenta no puede usar. Antes no aparecía y no había forma
               de saber por qué faltaba. -->
          <li v-if="unavailableCapabilities.length" class="pt-2">
            <p
              class="mb-1 text-xs font-semibold text-slate-500 dark:text-slate-400"
            >
              {{ $t('AI_AGENT_ASSISTANT.PICKER.UNAVAILABLE') }}
            </p>
            <p
              v-for="capability in unavailableCapabilities"
              :key="capability.key"
              class="m-0 text-xs text-slate-400 dark:text-slate-500"
            >
              <code>{{ capability.syntax }}</code>
              {{ `— ${capabilityLabel(capability)}` }}
            </p>
          </li>
        </ul>
      </div>
    </woot-modal>

    <!-- proyecto@contact_tracking: selector de directivas para el Entrenamiento -->
    <woot-modal
      :show="showDirectivePicker"
      :on-close="closeDirectivePicker"
      size="medium"
    >
      <woot-modal-header
        header-title="⚡ Insertar directiva"
        header-content="Haz clic en una directiva para insertarla en el Entrenamiento. El bot la ejecutará al responder."
      />
      <div class="px-8 pb-6">
        <!-- filtro por tipo de directiva -->
        <div
          v-if="directiveGroups.length > 1"
          class="flex flex-wrap gap-2 mb-4"
        >
          <button
            type="button"
            class="text-xs font-medium rounded-full px-3 py-1 border transition-colors"
            :class="
              directiveFilter === 'all'
                ? 'bg-woot-500 text-white border-woot-500'
                : 'bg-white dark:bg-slate-900 text-slate-600 dark:text-slate-300 border-slate-200 dark:border-slate-600 hover:border-woot-500'
            "
            @click="directiveFilter = 'all'"
          >
            Todas
          </button>
          <button
            v-for="g in directiveGroups"
            :key="g.key"
            type="button"
            class="text-xs font-medium rounded-full px-3 py-1 border transition-colors"
            :class="
              directiveFilter === g.key
                ? 'bg-woot-500 text-white border-woot-500'
                : 'bg-white dark:bg-slate-900 text-slate-600 dark:text-slate-300 border-slate-200 dark:border-slate-600 hover:border-woot-500'
            "
            @click="directiveFilter = g.key"
          >
            {{ g.label }}
          </button>
        </div>
        <p
          v-if="isLoadingCapabilities"
          class="mb-2 text-xs text-slate-500 dark:text-slate-400"
        >
          {{ $t('AI_AGENT_ASSISTANT.PICKER.LOADING') }}
        </p>
        <!-- alto fijo calibrado para ~6 filas (cada fila a una línea via truncate) -->
        <ul class="space-y-2 h-[370px] overflow-y-auto pr-1">
          <li v-for="dir in filteredDirectiveCatalog" :key="dir.token">
            <button
              type="button"
              class="w-full flex items-center justify-between gap-3 text-left rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 px-3 py-2 hover:border-woot-500 hover:bg-woot-25 dark:hover:bg-slate-800 transition-colors"
              @click="insertDirective(dir)"
            >
              <span class="min-w-0">
                <span class="flex items-center gap-2">
                  <span
                    class="text-sm font-medium truncate text-woot-600 dark:text-woot-400"
                  >
                    {{ dir.token }}
                  </span>
                  <!-- proyecto@ai_agent_assistant: qué le hace a tu prompt, ANTES de
                       insertarla. Es la regla que dejó a tres agentes con 11 052
                       caracteres que el motor descarta. -->
                  <span
                    class="shrink-0 px-2 py-0.5 text-xs rounded"
                    :class="effectClasses(dir.effect)"
                  >
                    {{
                      $t(
                        `AI_AGENT_ASSISTANT.PICKER.EFFECT_${dir.effect.toUpperCase()}`
                      )
                    }}
                  </span>
                </span>
                <span
                  class="block text-xs text-slate-500 dark:text-slate-400 truncate"
                >
                  {{ dir.label }}
                </span>
                <!-- Ayuda de uso extendida (parámetros/ejemplos): se muestra
                     completa, con salto de línea, sin truncar. -->
                <span
                  v-if="dir.hint"
                  class="block mt-1 text-xs leading-snug text-slate-400 dark:text-slate-500 whitespace-normal"
                >
                  {{ dir.hint }}
                </span>
              </span>
              <fluent-icon
                icon="add"
                size="16"
                class="shrink-0 self-start mt-0.5 text-slate-400"
              />
            </button>
          </li>
        </ul>
      </div>
    </woot-modal>
  </div>
</template>

<style scoped>
select,
input[type='number'] {
  height: 38px !important;
  font-size: 14px !important;
}

input,
textarea {
  height: auto !important;
  font-size: 14px !important;
}

/* proyecto@ai_agent_attachments: botones de subida a la misma altura que el input */
.upload-ctl-btn {
  height: 38px !important;
  margin-bottom: 12px;
}
</style>
