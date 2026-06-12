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
import TrackingTemplatesAPI from 'dashboard/api/trackingTemplates';

export default {
  components: { KeywordActionsEditor },

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
  emits: ['save', 'cancel'],
  data() {
    return {
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
        calendar_event_duration: 30,
      },
      // Tabs Contexto IA / Entrenamiento
      activeContextTab: 0,
      calendarIntegrations: [],
      isLoadingCalendars: false,
      originalAiContext: null,
      originalComplementaryPrompt: null,
      isImprovingAI: false,
      showPromptModal: false, // proyecto@automatizacion_tracking: modal expandido para entrenamiento
      showAiContextModal: false,
      showValidationModal: false,
      // WhatsApp / Inbox
      selectedInboxId: null,
      selectedKbaseHookId: null,
      maxAttempts: 3,
      availableWATemplates: [],
      isLoadingWATemplates: false,
      activeTemplateTab: 0,
    };
  },
  computed: {
    ...mapGetters({
      appIntegrations: 'integrations/getAppIntegrations',
      inboxes: 'inboxes/getInboxes',
    }),
    isCreateMode() {
      return this.mode === 'create';
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
      return this.form.objective.length >= 5 && this.form.objective.length <= 500;
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
      if (this.isLoadingWATemplates || this.availableWATemplates.length === 0) return true;
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
      return this.selectedInboxIsWhatsApp ? 3 : 2;
    },
    agendasTabIndex() {
      return this.reglasTabIndex + 1;
    },
    validationErrors() {
      const errors = [];
      if (!this.isNameValid) errors.push('Nombre del Agente IA es requerido (mínimo 2 caracteres).');
      if (!this.isObjectiveValid) errors.push('Objetivo es requerido (mínimo 5 caracteres).');
      if (!this.isAiContextValid) errors.push('Contexto IA es requerido (mínimo 10 caracteres).');
      if (!this.isComplementaryPromptValid) errors.push('Entrenamiento es requerido (mínimo 10 caracteres).');
      if (!this.isInboxValid) errors.push('Debes seleccionar un Canal (Inbox).');
      if (!this.isWhatsappTemplatesValid) errors.push('Todos los intentos de WhatsApp deben tener una plantilla asignada.');
      return errors;
    },
    discourseHooks() {
      const apps = this.appIntegrations || [];
      const app = apps.find(a => a.id === 'discourse');
      if (!app) return [];
      return (app.hooks || [])
        .filter(h => h.status === true)
        .map(h => ({ id: h.id, name: h.settings?.url || `Discourse #${h.id}` }));
    },
  },
  watch: {
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
            calendar_integration_ids: Array.isArray(val.calendar_integration_ids)
              ? [...val.calendar_integration_ids]
              : [],
            calendar_event_duration: val.calendar_event_duration || 30,
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
          if (val.kbase_hook_id) {
            this.selectedKbaseHookId = val.kbase_hook_id;
          }
        }
        // Reset AI state
        this.activeContextTab = 0;
        this.originalAiContext = null;
        this.originalComplementaryPrompt = null;
      },
    },
    selectedInboxId(newVal) {
      if (newVal && this.selectedInboxIsWhatsApp) {
        this.loadWATemplates();
      } else {
        this.availableWATemplates = [];
      }
    },
    selectedInboxIsWhatsApp(isWA) {
      if (!isWA) {
        if (this.activeContextTab === 2) {
          // Estaba en Plantillas WhatsApp → resetear
          this.activeContextTab = 0;
        } else if (this.activeContextTab === 3) {
          // Estaba en Reglas (índice 3 con WA) → pasa a índice 2 sin WA
          this.activeContextTab = 2;
        }
      } else if (this.activeContextTab === 2) {
        // Estaba en Reglas (índice 2 sin WA) → pasa a índice 3 con WA
        this.activeContextTab = 3;
      }
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
    onSubmit() {
      if (!this.isFormValid) {
        this.showValidationModal = true;
        return;
      }
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
          retry_interval_unit: this.form.retry_interval_unit,   // proyecto@automatizacion_tracking
          keyword_actions: this.form.keyword_actions || [],      // proyecto@contact_tracking
          kbase_hook_id: this.selectedKbaseHookId || null,
          calendar_integration_ids: this.form.calendar_integration_ids || [],
          calendar_event_duration: this.form.calendar_event_duration || 30,
        },
      };
      if (!this.isCreateMode) {
        payload.id = this.form.id;
      }
      this.$emit('save', payload);
    },
    onContextTabChange(index) {
      this.activeContextTab = index;
    },
    async improveWithAI(field) {
      if (this.isImprovingAI) return;

      const isGeneratePrompt = field === 'complementary_prompt';
      const mode = isGeneratePrompt ? 'generate_prompt' : 'improve';

      let text;
      if (isGeneratePrompt) {
        text = (this.form.complementary_prompt || '').trim() || (this.form.ai_context || '').trim();
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
        const response = await this.$store.dispatch('contactTrackings/improveText', payload);
        if (response?.improved_text) {
          this.form[field] = response.improved_text;
        }
      } catch (error) {
        if (field === 'ai_context') this.originalAiContext = null;
        else if (field === 'complementary_prompt') this.originalComplementaryPrompt = null;
      } finally {
        this.isImprovingAI = false;
      }
    },
    restoreOriginal(field) {
      if (field === 'ai_context' && this.originalAiContext) {
        this.form.ai_context = this.originalAiContext;
        this.originalAiContext = null;
      } else if (field === 'complementary_prompt' && this.originalComplementaryPrompt) {
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
        const templates = this.$store.getters[
          'inboxes/getWhatsAppTemplates'
        ](Number(this.selectedInboxId));
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
    toggleCalendarIntegration(id) {
      const idx = this.form.calendar_integration_ids.indexOf(id);
      if (idx === -1) {
        this.form.calendar_integration_ids.push(id);
      } else {
        this.form.calendar_integration_ids.splice(idx, 1);
      }
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
            :class="form.name && !isNameValid ? 'border-red-400' : 'border-slate-200 dark:border-slate-600'"
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
            :class="form.objective && !isObjectiveValid ? 'border-red-400' : 'border-slate-200 dark:border-slate-600'"
          />
        </label>
      </div>

      <!-- Intervalo entre intentos + Canal -->
      <div class="flex gap-3">
        <label class="flex-1">
          <span class="text-xs font-medium text-slate-600 dark:text-slate-400">⏱️ Tiempo entre intentos</span>
          <input
            v-model.number="form.retry_interval_value"
            type="number"
            :min="minIntervalValue"
            class="mt-1 w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-800 px-3 py-2 text-sm"
          />
        </label>
        <label class="flex-1">
          <span class="text-xs font-medium text-slate-600 dark:text-slate-400">Intervalo</span>
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
        <label class="flex-1">
          <span class="text-xs font-medium text-slate-600 dark:text-slate-400">Base de Conocimiento</span>
          <select
            v-model="selectedKbaseHookId"
            class="mt-1 w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-800 px-3 py-2 text-sm"
          >
            <option :value="null">— Sin base de conocimiento —</option>
            <option
              v-for="hook in discourseHooks"
              :key="hook.id"
              :value="hook.id"
            >
              {{ hook.name }}
            </option>
          </select>
        </label>
      </div>

      <!-- Contexto IA y Prompt Complementario (en tabs) -->
      <div class="flex-1 flex flex-col">
        <div class="flex items-end justify-between">
          <woot-tabs
            class="context-tabs [&_.tabs]:p-0 [&_.tabs]:mb-0 flex-1"
            :index="activeContextTab"
            @change="onContextTabChange"
          >
            <woot-tabs-item name="🧠  Contexto IA *" :show-badge="false" />
            <woot-tabs-item name="💡  Entrenamiento *" :show-badge="false" />
            <woot-tabs-item v-if="selectedInboxIsWhatsApp" name="📱  Plantillas WhatsApp" :show-badge="false" />
            <woot-tabs-item name="📋  Reglas" :show-badge="false" />
            <woot-tabs-item name="📅  Agendas" :show-badge="false" />
          </woot-tabs>
          <a
            v-if="activeContextTab === 0 || activeContextTab === 1"
            href="#"
            class="text-slate-400 hover:text-woot-500 dark:text-slate-500 dark:hover:text-woot-400 pb-2 pl-2"
            title="Expandir editor"
            @click.prevent="activeContextTab === 0 ? showAiContextModal = true : showPromptModal = true"
          >
            <fluent-icon icon="arrow-expand" size="18" />
          </a>
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
                :class="form.ai_context && form.ai_context.trim() && !isImprovingAI
                  ? 'text-woot-500 hover:text-woot-600 cursor-pointer'
                  : 'text-slate-300 dark:text-slate-600 cursor-not-allowed'"
                @click.prevent="form.ai_context && form.ai_context.trim() && !isImprovingAI && improveWithAI('ai_context')"
              >
                <span v-if="isImprovingAI && activeContextTab === 0" class="inline-block w-4 h-4 border-2 border-woot-500 border-t-transparent rounded-full animate-spin" />
                <span v-else>&#10024;</span>
                {{ isImprovingAI && activeContextTab === 0 ? 'Procesando...' : 'Mejorar con IA' }}
              </a>
            </div>
          </div>
        </div>

        <!-- Tab 1: Entrenamiento -->
        <div v-show="activeContextTab === 1" class="mt-2">
          <textarea
            v-model="form.complementary_prompt"
            rows="10"
            :placeholder="$t('TRACKING_TEMPLATES.FORM.COMPLEMENTARY_PROMPT.PLACEHOLDER')"
            class="w-full bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200"
          />
          <div class="flex justify-between items-center mt-1">
            <span class="text-xs text-slate-500 dark:text-slate-400">
              Este prompt se usa cuando el cliente hace preguntas relacionadas con el seguimiento
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
                :class="canGeneratePrompt && !isImprovingAI
                  ? 'text-woot-500 hover:text-woot-600 cursor-pointer'
                  : 'text-slate-300 dark:text-slate-600 cursor-not-allowed'"
                @click.prevent="canGeneratePrompt && !isImprovingAI && improveWithAI('complementary_prompt')"
              >
                <span v-if="isImprovingAI && activeContextTab === 1" class="inline-block w-4 h-4 border-2 border-woot-500 border-t-transparent rounded-full animate-spin" />
                <span v-else>&#10024;</span>
                {{ isImprovingAI && activeContextTab === 1 ? 'Procesando...' : 'Generar Prompt con IA' }}
              </a>
            </div>
          </div>
        </div>

        <!-- Tab 2: Plantillas WhatsApp (solo cuando canal es WhatsApp) -->
        <div v-if="selectedInboxIsWhatsApp" v-show="activeContextTab === 2" class="mt-2">
          <!-- Selector WA por intento -->
          <div v-if="availableWATemplates.length > 0">
            <div class="flex items-center gap-6 mb-2 flex-wrap">
              <label class="w-28 shrink-0">
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
              <div class="flex gap-2 flex-wrap mt-4">
              <button
                v-for="idx in attemptTabs"
                :key="idx"
                type="button"
                class="px-4 py-2 text-sm rounded-md transition-colors"
                :class="activeTemplateTab === idx
                  ? 'bg-woot-500 text-white'
                  : form.whatsapp_templates[idx]
                    ? 'bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-600'
                    : 'bg-red-50 dark:bg-red-900/20 text-red-500 border border-red-300 dark:border-red-700 hover:bg-red-100'"
                @click="activeTemplateTab = idx"
              >
                {{ getAttemptLabel(idx) }}
                <span v-if="form.whatsapp_templates[idx]" class="ml-1">&#10003;</span>
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
                :class="!form.whatsapp_templates[idx] ? 'border-red-400' : 'border-slate-200 dark:border-slate-600'"
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
          <div v-else-if="isLoadingWATemplates" class="text-sm text-slate-500 py-2">
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

        <!-- Tab Reglas (índice 3 con WA, 2 sin WA) -->
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
            <span class="text-xs font-medium text-slate-600 dark:text-slate-400 block mb-2">
              {{ $t('TRACKING_TEMPLATES.CALENDARS.EVENT_DURATION') }}
            </span>
            <div class="flex gap-2">
              <button
                v-for="option in [{value: 30, label: '30 min'}, {value: 60, label: '1 hora'}, {value: 120, label: '2 horas'}]"
                :key="option.value"
                type="button"
                class="px-4 py-2 text-sm rounded-md border transition-colors"
                :class="form.calendar_event_duration === option.value
                  ? 'bg-woot-500 text-white border-woot-500'
                  : 'bg-white dark:bg-slate-800 text-slate-600 dark:text-slate-300 border-slate-200 dark:border-slate-600 hover:bg-slate-50 dark:hover:bg-slate-700'"
                @click="form.calendar_event_duration = option.value"
              >
                {{ option.label }}
              </button>
            </div>
          </div>
          <div v-if="isLoadingCalendars" class="text-sm text-slate-500 py-2">
            {{ $t('TRACKING_TEMPLATES.CALENDARS.LOADING') }}
          </div>
          <div v-else-if="calendarIntegrations.length === 0" class="p-3 rounded-md bg-slate-50 dark:bg-slate-800 text-sm text-slate-500 dark:text-slate-400">
            {{ $t('TRACKING_TEMPLATES.CALENDARS.NONE_AVAILABLE') }}
          </div>
          <div v-else class="space-y-2">
            <label
              v-for="integration in calendarIntegrations"
              :key="integration.id"
              class="flex items-center gap-3 p-3 rounded-md border cursor-pointer transition-colors"
              :class="form.calendar_integration_ids.includes(integration.id)
                ? 'border-woot-400 bg-woot-50 dark:bg-woot-900/20'
                : 'border-slate-200 dark:border-slate-600 hover:bg-slate-50 dark:hover:bg-slate-800'"
              @click.prevent="toggleCalendarIntegration(integration.id)"
            >
              <input
                type="checkbox"
                :checked="form.calendar_integration_ids.includes(integration.id)"
                class="accent-woot-500"
                @change.prevent
              />
              <div class="flex flex-col">
                <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
                  {{ integration.user_name }}
                </span>
                <span class="text-xs text-slate-500 dark:text-slate-400">
                  {{ integration.google_email }}
                </span>
              </div>
            </label>
            <p v-if="form.calendar_integration_ids.length > 0" class="text-xs text-woot-600 dark:text-woot-400 pt-1">
              {{ $t('TRACKING_TEMPLATES.CALENDARS.SELECTED_COUNT', { count: form.calendar_integration_ids.length }) }}
            </p>
          </div>
        </div>
      </div>

      <!-- Botones -->
      <div class="flex items-center justify-end gap-2 pt-4 border-t border-slate-200 dark:border-slate-700">
        <woot-button
          variant="clear"
          color-scheme="secondary"
          @click.prevent="onCancel"
        >
          {{ $t('TRACKING_TEMPLATES.EDIT.CANCEL') }}
        </woot-button>
        <woot-button @click.prevent="onSubmit">
          {{ submitText }}
        </woot-button>
      </div>
    </form>

    <!-- Modal de validación -->
    <woot-modal :show="showValidationModal" :on-close="() => showValidationModal = false" size="small">
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
        <div class="flex justify-end pt-3 border-t border-slate-200 dark:border-slate-700">
          <woot-button type="button" @click="showValidationModal = false">
            Entendido
          </woot-button>
        </div>
      </div>
    </woot-modal>

    <!-- Modal expandido: Contexto IA -->
    <woot-modal :show="showAiContextModal" :on-close="() => showAiContextModal = false" size="medium">
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
        <div class="flex justify-end pt-2 border-t border-slate-200 dark:border-slate-700">
          <woot-button type="button" @click="showAiContextModal = false">
            Listo
          </woot-button>
        </div>
      </div>
    </woot-modal>

    <!-- Modal expandido: Entrenamiento -->
    <woot-modal :show="showPromptModal" :on-close="() => showPromptModal = false" size="medium">
      <woot-modal-header
        header-title="💡 Entrenamiento"
        header-content="Instrucciones adicionales para responder preguntas del cliente sobre este Agente IA."
      />
      <div class="px-8 pb-6 flex flex-col gap-3">
        <textarea
          v-model="form.complementary_prompt"
          rows="20"
          :placeholder="$t('TRACKING_TEMPLATES.FORM.COMPLEMENTARY_PROMPT.PLACEHOLDER')"
          class="w-full bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200"
        />
        <div class="flex justify-end pt-2 border-t border-slate-200 dark:border-slate-700">
          <woot-button type="button" @click="showPromptModal = false">
            Listo
          </woot-button>
        </div>
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
</style>
