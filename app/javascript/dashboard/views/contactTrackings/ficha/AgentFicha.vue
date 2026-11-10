<script>
// feat/ficha_agente_ia — LOS RECURSOS DE UN AGENTE QUE YA EXISTE
// ============================================================================
// Plan: docs/ficha_agente_ia_plan.md §8–§9. Mismo diseño que al crear (menú · tarjetas ·
// panel). Pedido del usuario (09/11/2026): si cambia la ficha, se detecta y se dice qué
// cambia en el Entrenamiento. Nada se toca sin su OK:
//
//   Agregaste «Precios»: ahora puede contestar datos exactos…      [Agregar ruta]
//   Quitaste «Agenda de Ana», pero la ruta agendar_cita la usa       [Quitar ruta]
//   «PATITAS»: 2 sin vectorizar
//
// Si la ficha nunca se guardó, se muestra la que se lee del Entrenamiento (D2) para
// confirmarla. En Archivos se suben al momento y quedan marcados (y guardados) para que
// el panel proponga mandarlos. El chat del Asistente también recibe estos cambios.
// 10/11/2026: «Agente y canal» trae también los datos del agente (nombre, nombre para el
// cliente, objetivo y contexto con ✨): el administrador ya no usa «Ficha de Agente IA».
// ============================================================================
import { useAlert } from 'dashboard/composables';
import FichaAPI from 'dashboard/api/fichaAgente';
import FichaCards, { GROUPS } from './FichaCards.vue';
import FichaNav from './FichaNav.vue';
import FichaFiles from './FichaFiles.vue';
import FichaReadiness from './FichaReadiness.vue';
import FichaAgenda from './FichaAgenda.vue';
import FichaTest from './FichaTest.vue';
import FichaLoading from './FichaLoading.vue';
import FichaChannel from './FichaChannel.vue';
import FichaWelcome from './FichaWelcome.vue';
import FichaQuestions from './FichaQuestions.vue';
import FichaIdentity from './FichaIdentity.vue';
import FichaVariables from './FichaVariables.vue';
import FichaBusiness from './FichaBusiness.vue';
import { sheetVar } from './FichaSheet.vue';
import FileRule, { defaultRule, ruleSummary } from './FileRule.vue';
import FichaModal from './FichaModal.vue';
import KeywordActionsEditor from 'dashboard/components/contacts/ContactTracking/KeywordActionsEditor.vue';

const SECTIONS = [
  'channel',
  'sources',
  'calendar',
  'tickets',
  'files',
  'welcome',
  'questions',
  'business',
  'variables',
  'rules',
];
const SECTION_ICONS = {
  channel: 'settings',
  welcome: 'chat-multiple',
  questions: 'list',
  sources: 'library',
  calendar: 'calendar',
  tickets: 'folder',
  files: 'attach',
  rules: 'flash-on',
  business: 'briefcase',
  variables: 'tag',
};
const SOURCE_KINDS = GROUPS.find(group => group.id === 'sources').kinds;
const copy = value => JSON.parse(JSON.stringify(value || []));
// El contexto de un agente que ya existe puede ser largo (lo escribieron a mano).
const MAX_CONTEXT_EXISTING = 5000;

export default {
  components: {
    FichaCards,
    FichaNav,
    FichaFiles,
    FichaReadiness,
    FichaAgenda,
    FichaTest,
    FichaLoading,
    FichaChannel,
    FichaWelcome,
    FichaQuestions,
    FichaIdentity,
    FichaVariables,
    FichaBusiness,
    FileRule,
    FichaModal,
    KeywordActionsEditor,
  },
  props: {
    templateId: { type: Number, required: true },
    // Para ✨ (lo que la IA sabe del agente).
    templateName: { type: String, default: '' },
  },
  emits: ['applied', 'changes', 'saved'],
  data() {
    return {
      section: 'sources',
      cards: [],
      items: [],
      saved: [],
      // Reglas (palabras clave → acción): se guardan con la ficha.
      rules: [],
      savedRules: [],
      changes: { added: [], removed: [], not_ready: [], confirmed: true },
      query: '',
      kind: '',
      readiness: [],
      follow: {
        inboxId: '',
        retryValue: 1,
        retryUnit: 'days',
        attempts: 3,
        whatsappTemplates: [],
        emailSignature: '',
      },
      welcome: '',
      questionsData: { questions: [], when: 'start' },
      // Variables por condición y datos del negocio (en el Entrenamiento).
      variables: [],
      businessData: [],
      // Datos del agente (Agente y canal): { name, displayName, objective, business }.
      profile: { name: '', displayName: '', objective: '', business: '' },
      missing: [],
      profileSuggesting: false,
      maxContext: MAX_CONTEXT_EXISTING,
      savedExtras: '',
      welcomeSuggesting: false,
      // Recursos › Agenda (se guarda con la ficha).
      agenda: {},
      savedAgenda: {},
      // Cuándo se manda cada archivo: { nombre: { ask, welcome, attempts } }.
      fileRules: {},
      savedFileRules: {},
      attempts: 3,
      routes: [],
      ruleName: null,
      activating: false,
      loading: true,
      busy: false,
    };
  },
  computed: {
    dirty() {
      return (
        JSON.stringify(this.items) !== JSON.stringify(this.saved) ||
        JSON.stringify(this.rules) !== JSON.stringify(this.savedRules) ||
        JSON.stringify(this.agenda) !== JSON.stringify(this.savedAgenda) ||
        JSON.stringify(this.fileRules) !==
          JSON.stringify(this.savedFileRules) ||
        JSON.stringify(this.extras()) !== this.savedExtras
      );
    },
    pending() {
      return this.changes.added.length + this.changes.removed.length;
    },
    navItems() {
      return SECTIONS.map(id => {
        const base = {
          id,
          icon: SECTION_ICONS[id],
          label: this.t(`NAV_${id.toUpperCase()}`),
        };
        if (id === 'channel')
          return {
            ...base,
            state:
              this.follow.inboxId &&
              this.profile.name.trim().length >= 2 &&
              this.profile.objective.trim().length >= 5
                ? 'ok'
                : 'todo',
          };
        if (id === 'welcome')
          return { ...base, state: this.welcome.trim() ? 'ok' : null };
        if (id === 'questions') {
          const n = this.questionsData.questions.length;
          return { ...base, count: n, total: n };
        }
        if (id === 'business' || id === 'variables') {
          const n =
            id === 'business'
              ? this.businessRows().length
              : this.variables.length + this.sheetVars().length;
          return { ...base, count: n, total: n };
        }
        if (id === 'rules')
          return {
            id,
            icon: SECTION_ICONS[id],
            label: this.t('NAV_RULES'),
            count: this.rules.length,
            total: this.rules.length,
          };
        const grupo = GROUPS.find(group => group.id === id);
        const tarjetas = this.cards.filter(card =>
          grupo.kinds.includes(card.kind)
        );
        const marcadas = tarjetas.filter(card =>
          this.items.some(item => item.key === card.key)
        );
        return {
          id,
          icon: SECTION_ICONS[id],
          label: this.t(`NAV_${id.toUpperCase()}`),
          count: marcadas.length,
          total: tarjetas.length,
        };
      });
    },
    fileRouteOptions() {
      return this.routes.map(ruta => ({ value: ruta.name, label: ruta.label }));
    },
    fileTicketOptions() {
      const tipos = this.cards.filter(card => card.kind === 'case_type');
      if (!tipos.length) return [];
      return [
        { value: '*', label: this.t('RULE_ANY_TICKET') },
        ...tipos.map(card => ({ value: card.name, label: card.name })),
      ];
    },
    kindChips() {
      return [
        '',
        ...SOURCE_KINDS.filter(kind =>
          this.cards.some(card => card.kind === kind)
        ),
      ];
    },
    fileNames() {
      return this.cards
        .filter(card => card.kind === 'file')
        .map(card => card.name);
    },
  },
  mounted() {
    this.load();
  },
  methods: {
    t(key, args) {
      return this.$t(`TRACKING_TEMPLATES.FICHA.${key}`, args);
    },
    kindLabel(kind) {
      return kind ? this.t(`KIND_${kind.toUpperCase()}`) : this.t('KIND_ALL');
    },
    take(data) {
      this.cards = data.cards || [];
      this.items = copy(data.items);
      this.saved = copy(data.items);
      this.rules = copy(data.keyword_actions);
      this.savedRules = copy(data.keyword_actions);
      this.changes = data.changes || this.changes;
      this.readiness = data.readiness || [];
      this.agenda = { ...(data.agenda || {}) };
      this.savedAgenda = { ...(data.agenda || {}) };
      this.fileRules = copy(data.file_rules || {});
      this.savedFileRules = copy(data.file_rules || {});
      this.attempts = data.attempts || 3;
      this.routes = data.routes || [];
      // Canal y seguimiento, bienvenida y preguntas (se guardan con la ficha).
      const seguimiento = data.follow || {};
      this.follow = {
        inboxId: seguimiento.inbox_id || '',
        retryValue: seguimiento.retry_interval_value || 1,
        retryUnit: seguimiento.retry_interval_unit || 'days',
        attempts: seguimiento.attempts || 3,
        whatsappTemplates: seguimiento.whatsapp_templates || [],
        emailSignature: seguimiento.email_signature || '',
      };
      this.welcome = data.welcome || '';
      this.variables = copy((data.variables || {}).variables);
      this.businessData = (data.business_data || []).map(d => ({
        label: d.label,
        value: d.value,
      }));
      const datos = data.profile || {};
      this.profile = {
        name: datos.name || '',
        displayName: datos.customer_display_name || '',
        objective: datos.objective || '',
        business: datos.ai_context || '',
      };
      const preguntas = data.questions || {};
      this.questionsData = {
        questions: (preguntas.questions || []).map(q => ({
          text: q.text,
          var: q.var,
          options: q.options || [],
        })),
        when: preguntas.when || 'start',
      };
      this.savedExtras = JSON.stringify(this.extras());
      this.$emit(
        'changes',
        this.changes.added.length + this.changes.removed.length
      );
    },
    async load() {
      this.loading = true;
      try {
        const { data } = await FichaAPI.get(this.templateId);
        this.take(data);
      } catch (error) {
        useAlert(this.t('LOAD_ERROR'));
      } finally {
        this.loading = false;
      }
    },
    async save(items = this.items) {
      this.busy = true;
      try {
        // Los archivos los decide su regla: todos van en la ficha.
        // (más los recién subidos, que todavía no tienen tarjeta).
        const llaves = [
          ...this.cards
            .filter(card => card.kind === 'file')
            .map(card => card.key),
          ...items
            .filter(item => item.key.startsWith('file:'))
            .map(item => item.key),
        ];
        const conArchivos = [
          ...items.filter(item => !item.key.startsWith('file:')),
          ...[...new Set(llaves)].map(key => ({ key })),
        ];
        const { data } = await FichaAPI.save(this.templateId, conArchivos, {
          keyword_actions: this.rules,
          agenda: this.agenda,
          file_rules: this.fileRules,
          ...this.extras(),
        });
        this.take(data);
        useAlert(this.t('SAVED'));
        this.$emit('saved');
      } catch (error) {
        const datos = error && error.response && error.response.data;
        useAlert((datos && datos.error) || this.t('SAVE_ERROR'));
      } finally {
        this.busy = false;
      }
    },
    // Un archivo recién subido se marca y se guarda: el panel ya propone mandarlo.
    onUploaded(attachment) {
      const llave = `file:${attachment.id}`;
      const marcadas = this.saved.some(item => item.key === llave)
        ? this.saved
        : [...this.saved, { key: llave }];
      this.save(marcadas);
    },
    async apply({ add = [], remove = [], phrases = {} }) {
      this.busy = true;
      try {
        const { data } = await FichaAPI.apply(this.templateId, {
          add,
          remove,
          phrases,
        });
        this.take(data);
        useAlert(this.t('APPLIED'));
        this.$emit('applied');
      } catch (error) {
        const datos = error && error.response && error.response.data;
        useAlert((datos && datos.error) || this.t('APPLY_ERROR'));
      } finally {
        this.busy = false;
      }
    },
    calendarIds() {
      return this.items
        .map(item => (item.key.match(/^calendar:(\d+)$/) || [])[1])
        .filter(Boolean)
        .map(Number);
    },
    // Desde la prueba: la frase se suma a la descripción de esa ruta del Entrenamiento.
    addPhrase({ route, phrase }) {
      if (!route) return;
      this.apply({ phrases: { [route]: [phrase] } });
    },
    ruleFor(nombre) {
      return { ...defaultRule(), ...(this.fileRules[nombre] || {}) };
    },
    summaryFor(nombre) {
      return ruleSummary(this.ruleFor(nombre), key => this.t(key));
    },
    setRule(nombre, regla) {
      this.fileRules = { ...this.fileRules, [nombre]: regla };
    },
    // Lo de Canal y seguimiento, Bienvenida y Preguntas, como lo guarda el servidor.
    extras() {
      return {
        name: this.profile.name.trim(),
        customer_display_name: this.profile.displayName.trim(),
        objective: this.profile.objective.trim(),
        ai_context: this.profile.business.trim(),
        inbox_id: this.follow.inboxId || null,
        retry_interval_value: this.follow.retryValue,
        retry_interval_unit: this.follow.retryUnit,
        attempts: this.follow.attempts,
        whatsapp_templates: this.follow.whatsappTemplates,
        email_signature: this.follow.emailSignature,
        welcome: this.welcome.trim(),
        questions: this.questionsData.questions.filter(q =>
          (q.text || '').trim()
        ),
        questions_when: this.questionsData.when,
        variables: this.variables.filter(v => (v.name || '').trim()),
        business_data: this.businessRows(),
      };
    },
    businessRows() {
      return this.businessData.filter(
        d => (d.label || '').trim() && (d.value || '').trim()
      );
    },
    sheetVars() {
      return this.items
        .filter(item => item.sheet && item.sheet.remember)
        .map(item => {
          const card = this.cards.find(c => c.key === item.key) || {};
          return {
            name: sheetVar(item.sheet.search_by),
            column: item.sheet.search_by,
            sheet: card.name,
          };
        })
        .filter(v => v.name);
    },
    questionVars() {
      return this.questionsData.questions
        .map((q, i) => ({ name: (q.var || '').trim(), n: i + 1 }))
        .filter(v => v.name);
    },
    welcomeFiles() {
      return this.fileNames.map(nombre => ({
        key: nombre,
        name: nombre,
        welcome: !!this.ruleFor(nombre).welcome,
      }));
    },
    toggleWelcomeFile(file) {
      const regla = this.ruleFor(file.name);
      this.setRule(file.name, { ...regla, welcome: !regla.welcome });
    },
    async suggestWelcome() {
      this.welcomeSuggesting = true;
      try {
        const { data } = await FichaAPI.suggest({
          ...this.suggestContext(),
          field: 'welcome',
          welcome: this.welcome,
        });
        if (data.welcome) this.welcome = data.welcome;
      } catch (error) {
        const datos = error && error.response && error.response.data;
        useAlert((datos && datos.error) || this.t('SUGGEST_ERROR'));
      } finally {
        this.welcomeSuggesting = false;
      }
    },
    suggestContext() {
      return {
        name: this.profile.name.trim() || this.templateName,
        items: this.items,
        objective: this.profile.objective.trim(),
      };
    },
    // ✨ objetivo o contexto con lo marcado (una llamada a OpenAI).
    async suggestProfile(campo) {
      this.profileSuggesting = campo;
      try {
        const { data } = await FichaAPI.suggest({
          ...this.suggestContext(),
          field: 'fields',
          business: this.profile.business,
          customer_display_name: this.profile.displayName,
        });
        const nuevo = { ...this.profile };
        if (campo === 'objective' && data.objective)
          nuevo.objective = data.objective;
        if (campo === 'context' && data.ai_context) {
          nuevo.business = data.ai_context;
          this.missing = data.missing || [];
        }
        this.profile = nuevo;
      } catch (error) {
        const datos = error && error.response && error.response.data;
        useAlert((datos && datos.error) || this.t('SUGGEST_ERROR'));
      } finally {
        this.profileSuggesting = false;
      }
    },
    welcomeQuestion() {
      const primera = this.questionsData.questions[0];
      return this.questionsData.when === 'welcome' && primera
        ? (primera.text || '').trim()
        : '';
    },
    hasChannel() {
      return this.readiness.some(
        item => item.key === 'channel' && item.status === 'ok'
      );
    },
    // Desde aquí contesta a clientes reales: se pide confirmación.
    async activate() {
      const ok = await this.$refs.activateDialog.showConfirmation();
      if (!ok) return;
      this.activating = true;
      try {
        const { data } = await FichaAPI.activate(this.templateId);
        this.take(data);
        useAlert(this.t('ACTIVATED'));
      } catch (error) {
        const datos = error && error.response && error.response.data;
        useAlert((datos && datos.error) || this.t('ACTIVATE_ERROR'));
      } finally {
        this.activating = false;
      }
    },
    applyAll() {
      this.apply({
        add: this.changes.added.map(item => item.key),
        remove: [...new Set(this.changes.removed.map(item => item.route))],
      });
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0 gap-3">
    <FichaLoading v-if="loading" />
    <template v-else>
      <div
        v-if="!changes.confirmed"
        class="flex items-center gap-2 px-3 py-2 text-sm rounded-lg shrink-0 bg-woot-25 text-woot-800 dark:bg-woot-900/20 dark:text-woot-100"
      >
        <fluent-icon icon="info" size="16" />
        {{ t('DEDUCED') }}
      </div>

      <div
        class="grid flex-1 min-h-0 gap-4 md:grid-cols-[240px_minmax(0,1fr)] xl:grid-cols-[240px_minmax(0,1fr)_320px] xl:grid-rows-[minmax(0,1fr)]"
      >
        <FichaNav v-model="section" :items="navItems" />

        <!-- Sección -->
        <div class="flex flex-col min-h-0 gap-3">
          <!-- Fuentes: buscador y tipos fijos; solo las tarjetas hacen scroll. -->
          <template v-if="section === 'sources'">
            <div class="flex flex-wrap items-center gap-2 shrink-0">
              <div class="relative flex-1 min-w-[12rem]">
                <fluent-icon
                  icon="search"
                  size="14"
                  class="absolute -translate-y-1/2 left-2.5 top-1/2 text-slate-400"
                />
                <input
                  v-model="query"
                  type="search"
                  class="!mb-0 !pl-8 !h-9 text-sm"
                  :placeholder="t('SEARCH')"
                />
              </div>
              <div class="flex flex-wrap gap-1">
                <button
                  v-for="item in kindChips"
                  :key="item || 'all'"
                  type="button"
                  class="px-2.5 py-1 text-xs border rounded-full"
                  :class="
                    kind === item
                      ? 'border-woot-500 bg-woot-500 text-white'
                      : 'border-slate-200 text-slate-600 dark:border-slate-700 dark:text-slate-300'
                  "
                  @click="kind = item"
                >
                  {{ kindLabel(item) }}
                </button>
              </div>
            </div>
            <div class="flex-1 min-h-0 pr-1 overflow-auto">
              <FichaCards
                v-model="items"
                :cards="cards"
                :only="['sources']"
                :query="query"
                :kind="kind"
                :disabled="busy"
                :show-headers="false"
                :suggest-context="suggestContext()"
              />
            </div>
          </template>
          <!-- Preguntas: «¿Cuándo pregunta?» fijo; solo las preguntas hacen scroll. -->
          <div
            v-else-if="section === 'questions'"
            class="flex flex-col flex-1 min-h-0 gap-3"
          >
            <FichaQuestions
              v-model="questionsData"
              :route-options="fileRouteOptions"
              :suggest-context="suggestContext()"
              :has-welcome="!!welcome.trim()"
              :disabled="busy"
            />
          </div>
          <div
            v-else-if="section === 'business'"
            class="flex flex-col flex-1 min-h-0 gap-3"
          >
            <FichaBusiness
              v-model="businessData"
              :agent-name="profile.displayName"
              :disabled="busy"
            />
          </div>
          <div
            v-else-if="section === 'variables'"
            class="flex flex-col flex-1 min-h-0 gap-3"
          >
            <FichaVariables
              v-model="variables"
              :sheet-vars="sheetVars()"
              :question-vars="questionVars()"
              :suggest-context="suggestContext()"
              :disabled="busy"
            />
          </div>
          <!-- Agenda: las agendas en carrusel fijo; lo de abajo hace scroll. -->
          <div
            v-else-if="section === 'calendar'"
            class="flex flex-col flex-1 min-h-0 gap-3"
          >
            <p class="!m-0 text-sm text-slate-600 dark:text-slate-300 shrink-0">
              {{ t('CALENDAR_HINT') }}
            </p>
            <FichaCards
              v-model="items"
              class="shrink-0"
              :cards="cards"
              :only="['calendar']"
              :disabled="busy"
              :show-headers="false"
              carousel
            />
            <div
              v-if="calendarIds().length"
              class="flex-1 min-h-0 pt-3 pr-1 overflow-auto border-t border-slate-100 dark:border-slate-700"
            >
              <FichaAgenda
                v-model="agenda"
                :integration-ids="calendarIds()"
                :disabled="busy"
              />
            </div>
          </div>
          <div
            v-else-if="section === 'files'"
            class="flex flex-col flex-1 min-h-0 gap-3"
          >
            <p class="!m-0 text-sm text-slate-600 dark:text-slate-300 shrink-0">
              {{ t('FILES_HINT_EXISTING') }}
            </p>
            <FichaFiles
              :template-id="templateId"
              :existing-names="fileNames"
              @uploaded="onUploaded"
            >
              <template #list>
                <ul class="!m-0 !p-0 list-none flex flex-col gap-1.5">
                  <li
                    v-for="nombre in fileNames"
                    :key="nombre"
                    class="flex flex-col gap-1.5 p-2 border rounded-lg border-slate-200 dark:border-slate-700"
                  >
                    <span
                      class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-200"
                    >
                      <fluent-icon icon="attach" size="14" />
                      {{ nombre }}
                    </span>
                    <div class="flex items-center gap-2 pl-6 text-xs">
                      <span class="flex-1 text-slate-600 dark:text-slate-300">
                        {{ summaryFor(nombre) }}
                      </span>
                      <woot-button
                        size="tiny"
                        variant="smooth"
                        icon="settings"
                        :is-disabled="busy"
                        @click="ruleName = nombre"
                      >
                        {{ t('CONFIGURE') }}
                      </woot-button>
                    </div>
                  </li>
                </ul>
              </template>
            </FichaFiles>
          </div>
          <div
            v-else
            class="flex flex-col flex-1 min-h-0 gap-3 pr-1 overflow-auto"
          >
            <template v-if="section === 'channel'">
              <h3
                class="!m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
              >
                {{ t('IDENTITY_TITLE') }}
              </h3>
              <FichaIdentity
                v-model="profile"
                :suggesting="profileSuggesting"
                :can-suggest="items.length > 0"
                :missing.sync="missing"
                :max-context="maxContext"
                objective-required
                :disabled="busy"
                @suggest="suggestProfile"
              />
              <h3
                class="!m-0 !mt-4 pt-4 border-t border-slate-100 dark:border-slate-700 text-sm font-semibold text-slate-800 dark:text-slate-100"
              >
                {{ t('FOLLOW_TITLE') }}
              </h3>
              <FichaChannel v-model="follow" />
            </template>
            <template v-else-if="section === 'welcome'">
              <FichaWelcome
                :text.sync="welcome"
                :files="welcomeFiles()"
                :first-question="welcomeQuestion()"
                :suggesting="welcomeSuggesting"
                :disabled="busy"
                @toggle="toggleWelcomeFile"
                @suggest="suggestWelcome"
              />
            </template>
            <template v-else-if="section === 'rules'">
              <p class="!m-0 text-sm text-slate-600 dark:text-slate-300">
                {{ t('RULES_HINT') }}
              </p>
              <KeywordActionsEditor v-model="rules" />
            </template>
            <template v-else>
              <p class="!m-0 text-sm text-slate-600 dark:text-slate-300">
                {{ t(`${section.toUpperCase()}_HINT`) }}
              </p>
              <FichaCards
                v-model="items"
                :cards="cards"
                :only="[section]"
                :disabled="busy"
                :show-headers="false"
                :escalation-options="fileRouteOptions"
                :suggest-context="suggestContext()"
              />
            </template>
          </div>
        </div>

        <!-- Panel: cambios para el Entrenamiento -->
        <aside
          class="flex flex-col min-h-0 gap-3 p-4 overflow-auto border rounded-lg md:col-span-2 xl:col-span-1 border-slate-200 dark:border-slate-700 bg-slate-25 dark:bg-slate-800/40"
        >
          <h3
            class="!m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
          >
            {{ t('CHANGES_TITLE') }}
          </h3>
          <p v-if="dirty" class="!m-0 text-xs text-amber-800">
            {{ t('SAVE_FIRST') }}
          </p>
          <p
            v-else-if="!pending && !changes.not_ready.length"
            class="!m-0 flex items-center gap-2 text-sm text-green-700"
          >
            <fluent-icon icon="checkmark-circle" size="16" />
            {{ t('IN_SYNC') }}
          </p>
          <template v-else>
            <p class="!m-0 text-xs text-slate-500">{{ t('CHANGES_HINT') }}</p>
            <ul
              class="!m-0 !p-0 list-none flex flex-col gap-2 overflow-auto min-h-0"
            >
              <li
                v-for="item in changes.added"
                :key="`add-${item.key}`"
                class="flex flex-col gap-1 text-sm"
              >
                <span class="flex items-start gap-2">
                  <fluent-icon
                    icon="add"
                    size="14"
                    class="mt-0.5 text-green-700 shrink-0"
                  />
                  <span class="text-slate-700 dark:text-slate-200">
                    {{ t('ADDED', { name: item.name, what: item.label }) }}
                  </span>
                </span>
                <woot-button
                  size="tiny"
                  variant="smooth"
                  class="self-end"
                  :is-disabled="busy"
                  @click="apply({ add: [item.key] })"
                >
                  {{ t('ADD_ROUTE') }}
                </woot-button>
              </li>
              <li
                v-for="item in changes.removed"
                :key="`rm-${item.key}-${item.route}`"
                class="flex flex-col gap-1 text-sm"
              >
                <span class="flex items-start gap-2">
                  <fluent-icon
                    icon="dismiss"
                    size="14"
                    class="mt-0.5 text-red-600 shrink-0"
                  />
                  <span class="text-slate-700 dark:text-slate-200">
                    {{ t('REMOVED', { name: item.name, route: item.route }) }}
                  </span>
                </span>
                <woot-button
                  size="tiny"
                  variant="smooth"
                  color-scheme="alert"
                  class="self-end"
                  :is-disabled="busy"
                  @click="apply({ remove: [item.route] })"
                >
                  {{ t('REMOVE_ROUTE') }}
                </woot-button>
              </li>
              <li
                v-for="item in changes.not_ready"
                :key="`nr-${item.key}`"
                class="flex items-start gap-2 text-sm text-amber-800 dark:text-amber-200"
              >
                <fluent-icon icon="warning" size="14" class="mt-0.5 shrink-0" />
                {{ t('NOT_READY', { name: item.name, why: item.warning }) }}
              </li>
            </ul>
            <woot-button
              v-if="pending > 1"
              size="small"
              icon="checkmark"
              :is-disabled="busy"
              @click="applyAll"
            >
              {{ t('APPLY_ALL', { count: pending }) }}
            </woot-button>
          </template>

          <FichaTest
            class="pt-3 border-t border-slate-200 dark:border-slate-700"
            :template-id="templateId"
            :disabled="busy"
            @addPhrase="addPhrase"
          />
          <FichaReadiness
            v-if="readiness.length"
            class="pt-3 border-t border-slate-200 dark:border-slate-700"
            :items="readiness"
            :can-activate="hasChannel()"
            :activating="activating"
            @activate="activate"
          />

          <div class="flex flex-col gap-1 mt-auto">
            <woot-button
              icon="checkmark"
              :is-loading="busy"
              :is-disabled="busy || (!dirty && changes.confirmed)"
              @click="save()"
            >
              {{ changes.confirmed ? t('SAVE') : t('CONFIRM') }}
            </woot-button>
            <span v-if="dirty" class="text-xs text-center text-slate-500">
              {{ t('UNSAVED') }}
            </span>
          </div>
        </aside>
      </div>
    </template>
    <FichaModal
      :show="!!ruleName"
      :title="ruleName ? t('FILE_RULE_TITLE', { name: ruleName }) : ''"
      :subtitle="t('FILE_RULE_SUBTITLE')"
      @close="ruleName = null"
    >
      <FileRule
        v-if="ruleName"
        class="!text-sm !gap-y-3"
        :value="ruleFor(ruleName)"
        :attempts="attempts"
        :route-options="fileRouteOptions"
        :ticket-options="fileTicketOptions"
        :show-booking="calendarIds().length > 0"
        @input="setRule(ruleName, $event)"
      />
    </FichaModal>
    <woot-confirm-modal
      ref="activateDialog"
      :title="t('ACTIVATE_TITLE')"
      :description="t('ACTIVATE_DESCRIPTION')"
      :confirm-label="t('ACTIVATE_YES')"
      :cancel-label="t('ACTIVATE_NO')"
    />
  </div>
</template>
