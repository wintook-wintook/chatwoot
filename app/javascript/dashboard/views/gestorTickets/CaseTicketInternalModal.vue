<!--
  @tickets_cases Fase C
  Modal para crear un ticket INTERNO (agente → agente, sin contacto).
  El solicitante es el usuario actual; se asigna a un agente y/o equipo.
  Incluye naturaleza ITIL y los campos personalizados (2K) del tipo elegido.

  Plan-Casos E2 — también es el alta del botón «+ {tipo|clase}» de Lista y
  Tablero: recibe la clase (solo ofrece sus tipos) y el tipo elegido, y pide el
  CLIENTE. En Soporte es opcional (sin cliente = caso interno, como siempre);
  una oportunidad (Comercial) lo exige y lleva sus datos comerciales.
-->
<script>
import { mapGetters } from 'vuex';
import { forType, idAvailable } from 'dashboard/helper/caseClassification';
import { DEFAULT_CASE_CLASS, typesOfClass } from 'dashboard/helper/caseClasses';
import { isCommercialType } from 'dashboard/helper/caseCommercial';
import {
  isWorkOrderType,
  workOrderPayload,
} from 'dashboard/helper/caseWorkOrder';
import { isProjectType, projectPayload } from 'dashboard/helper/caseProject';
import ContactPicker from './ContactPicker.vue';

// Espejo de Cases::PriorityMatrix (backend). impacto × urgencia → prioridad.
const PRIORITY_MATRIX = {
  high: { low: 'high', medium: 'high', high: 'urgent' },
  medium: { low: 'low', medium: 'medium', high: 'high' },
  low: { low: 'low', medium: 'low', high: 'medium' },
};

export default {
  name: 'CaseTicketInternalModal',
  components: { ContactPicker },
  props: {
    show: { type: Boolean, default: false },
    // @tickets_cases — si viene un ticket, el modal es de EDICIÓN.
    ticket: { type: Object, default: null },
    // Plan-Casos E2 — alta desde Lista/Tablero: clase y tipo del encabezado.
    caseClass: { type: String, default: '' },
    presetTypeId: { type: [String, Number], default: '' },
  },
  emits: ['close', 'created', 'updated'],
  data() {
    return {
      activeTab: 'ticket', // 'ticket' | 'assign' | 'custom'
      form: {
        assignee_id: '',
        team_id: '',
        case_type_id: null,
        ticket_kind: 'service_request',
        affected_service_id: null,
        category_id: null,
        title: '',
        impact: null,
        urgency: null,
        priority: 'medium',
        description: '',
        // Plan-Casos E2 — datos de la oportunidad (solo tipo Comercial).
        amount: '',
        currency: '',
        expected_close_at: '',
        probability: '',
        // Plan-Clase-Orden-de-Trabajo F2a — datos de la orden (solo ese tipo).
        work_address: '',
        estimated_hours: '',
        actual_hours: '',
        billable: false,
        // Plan-Clase-Proyecto P1 — datos del proyecto (solo ese tipo).
        project_start_on: '',
        project_due_on: '',
        budget_hours: '',
        budget_amount: '',
        progress: '',
      },
      contact: null, // Plan-Casos E2 — cliente elegido (null = caso interno)
      // 2K — valores de los campos personalizados del tipo seleccionado
      customValues: {},
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'caseTickets/getUIFlags',
      types: 'caseTickets/getTypes',
      agents: 'agents/getAgents',
      teams: 'teams/getTeams',
      services: 'caseTickets/getServices',
      categories: 'caseTickets/getCategories',
      currentUser: 'getCurrentUser',
      caseSettings: 'caseTickets/getCaseSettings',
    }),
    isEdit() {
      return !!this.ticket;
    },
    // Plan-Casos E2 — en el alta por clase solo se ofrecen los tipos de esa clase.
    // Hoja de ruta E1.4 — al editar, solo tipos de la clase del caso (la clase es
    // fija; un caso sin tipo cuenta como Soporte).
    typeOptions() {
      if (this.isEdit) return typesOfClass(this.types, this.ticketClass);
      if (!this.caseClass) return this.types || [];
      return typesOfClass(this.types, this.caseClass);
    },
    ticketClass() {
      const type = (this.types || []).find(
        t => t.id === this.ticket?.case_type_id
      );
      return type?.case_class || DEFAULT_CASE_CLASS;
    },
    isCommercial() {
      return isCommercialType(this.selectedType);
    },
    isWorkOrder() {
      return isWorkOrderType(this.selectedType);
    },
    isProject() {
      return isProjectType(this.selectedType);
    },
    // Plan-Clase-Proyecto P2 — con casos o hitos el avance se calcula solo.
    progressAuto() {
      return !!this.ticket?.project_summary?.progress_auto;
    },
    // Fila Impacto · Urgencia · Prioridad: en una orden es una fila flexible para
    // que quepan las horas al lado de la prioridad.
    priorityRowClass() {
      if (this.isWorkOrder) return 'flex flex-wrap items-start';
      return this.itilEnabled ? 'grid grid-cols-3' : '';
    },
    // Una oportunidad siempre es de un cliente; en Soporte es opcional.
    contactRequired() {
      return this.isCommercial;
    },
    headerTitle() {
      if (this.isEdit) return this.$t('CASE_TICKETS.EDIT.TITLE');
      if (!this.caseClass) return this.$t('CASE_TICKETS.INTERNAL.TITLE');
      return this.$t('CASE_TICKETS.CREATE.TITLE', {
        name: this.selectedType?.name || '',
      });
    },
    // Tipo de caso elegido en el form.
    selectedType() {
      return (this.types || []).find(t => t.id === this.form.case_type_id);
    },
    // @tickets_cases — modo ITIL propio del tipo elegido en el form (ya no es
    // un ajuste global de cuenta).
    itilEnabled() {
      return !!this.selectedType?.itil_enabled && !this.isCommercial;
    },
    // @tickets_cases — al crear, el responsable arranca en el agente firmado.
    // Solo si ese usuario figura entre los agentes de la cuenta (un superadmin
    // que no es agente no aparece en el select y dejarlo daría un valor muerto).
    defaultAssigneeId() {
      const id = this.currentUser?.id;
      if (!id) return '';
      return this.agents.some(ag => ag.id === id) ? id : '';
    },
    tabs() {
      const base = [
        { key: 'ticket', label: this.$t('CASE_TICKETS.MODAL.TAB_TICKET') },
      ];
      // En edición también: el guardado manda la asignación por su propio
      // endpoint (assign), que es el que deja el evento y avisa al agente.
      base.push({
        key: 'assign',
        label: this.$t('CASE_TICKETS.MODAL.TAB_ASSIGN'),
      });
      base.push({
        key: 'custom',
        label: this.$t('CASE_TICKETS.MODAL.TAB_CUSTOM'),
      });
      // Plan-Clase-Orden-de-Trabajo — dirección del servicio, después de Campos.
      if (this.isWorkOrder) {
        base.push({
          key: 'address',
          label: this.$t('CASE_TICKETS.MODAL.TAB_ADDRESS'),
        });
      }
      return base;
    },
    activeTabIndex() {
      const idx = this.tabs.findIndex(t => t.key === this.activeTab);
      return idx === -1 ? 0 : idx;
    },
    ticketKindOptions() {
      return this.$t('CASE_TICKETS.TICKET_KIND');
    },
    priorityOptions() {
      return this.$t('CASE_TICKETS.PRIORITIES');
    },
    impactOptions() {
      return this.$t('CASE_TICKETS.IMPACT');
    },
    urgencyOptions() {
      return this.$t('CASE_TICKETS.URGENCY');
    },
    // Prioridad derivada por matriz cuando hay impacto y urgencia.
    derivedPriority() {
      if (!this.form.impact || !this.form.urgency) return null;
      return (
        (PRIORITY_MATRIX[this.form.impact] || {})[this.form.urgency] || null
      );
    },
    // Plan-Clase-Comercial F2: solo la clasificación global o propia del tipo elegido.
    typedServices() {
      return forType(this.services, this.form.case_type_id);
    },
    typedCategories() {
      return forType(this.categories, this.form.case_type_id);
    },
    // Categorías aplanadas (categoría + subcategorías con guion) para el select.
    flatCategories() {
      const out = [];
      this.typedCategories.forEach(c => {
        out.push({ id: c.id, label: c.name });
        (c.subcategories || []).forEach(sub => {
          out.push({ id: sub.id, label: `— ${sub.name}` });
        });
      });
      return out;
    },
    // 2K — campos personalizados del tipo de caso seleccionado.
    selectedTypeFields() {
      return this.selectedType?.custom_fields || [];
    },
    // ¿Todos los campos requeridos tienen valor?
    customFieldsValid() {
      return this.selectedTypeFields.every(f => {
        if (!f.required) return true;
        const v = this.customValues[f.key];
        if (f.field_type === 'checkbox') return v === true;
        return v !== undefined && v !== null && String(v).trim() !== '';
      });
    },
    isValid() {
      if (this.contactRequired && !this.contact && !this.isEdit) return false;
      return this.form.title.trim().length > 0 && this.customFieldsValid;
    },
  },
  watch: {
    // Al cambiar de tipo, suelta el servicio/categoría que ya no aplica.
    'form.case_type_id'() {
      if (this.isCommercial && !this.form.currency) {
        this.form.currency = this.caseSettings?.default_currency || 'MXN';
      }
      if (!idAvailable(this.typedServices, this.form.affected_service_id)) {
        this.form.affected_service_id = null;
      }
      if (!idAvailable(this.typedCategories, this.form.category_id)) {
        this.form.category_id = null;
      }
    },
    // Al cambiar de tipo, inicializa los valores de sus campos (checkbox→false).
    selectedTypeFields: {
      immediate: true,
      handler(fields) {
        const next = {};
        fields.forEach(f => {
          const fallback = f.field_type === 'checkbox' ? false : '';
          next[f.key] =
            f.key in this.customValues ? this.customValues[f.key] : fallback;
        });
        this.customValues = next;
      },
    },
  },
  mounted() {
    // @tickets_cases — en edición, precargar el formulario desde el ticket.
    if (this.isEdit) this.prefillFromTicket();
    this.$store.dispatch('caseTickets/fetchTypes').then(() => {
      if (this.isEdit || this.form.case_type_id) return;
      // Plan-Casos E2 — el tipo del encabezado; si no hay, el primero de la clase.
      const preset = this.typeOptions.find(
        t => String(t.id) === String(this.presetTypeId)
      );
      const first = preset || this.typeOptions[0];
      if (first) this.form.case_type_id = first.id;
    });
    this.$store.dispatch('agents/get').then(() => {
      // Precarga el responsable solo en alta; en edición no se toca la asignación.
      if (!this.isEdit && !this.form.assignee_id) {
        this.form.assignee_id = this.defaultAssigneeId;
      }
    });
    this.$store.dispatch('teams/get');
    this.$store.dispatch('caseTickets/fetchServices');
    this.$store.dispatch('caseTickets/fetchCategories');
    this.$store.dispatch('caseTickets/fetchSettings'); // modo simple/ITIL
  },
  methods: {
    onTabChange(index) {
      const tab = this.tabs[index];
      if (tab) this.activeTab = tab.key;
    },
    // @tickets_cases — vuelca el ticket al formulario para editarlo.
    prefillFromTicket() {
      const t = this.ticket;
      this.form = {
        ...this.form,
        case_type_id: t.case_type_id ?? null,
        ticket_kind: t.ticket_kind ?? 'service_request',
        affected_service_id: t.affected_service_id ?? null,
        category_id: t.category_id ?? null,
        title: t.title ?? '',
        impact: t.impact ?? null,
        urgency: t.urgency ?? null,
        priority: t.priority ?? 'medium',
        description: t.description ?? '',
        work_address: t.work_address ?? '',
        estimated_hours: t.estimated_hours ?? '',
        actual_hours: t.actual_hours ?? '',
        billable: !!t.billable,
        project_start_on: t.project_start_on ?? '',
        project_due_on: t.project_due_on ?? '',
        budget_hours: t.budget_hours ?? '',
        budget_amount: t.budget_amount ?? '',
        // El capturado a mano (el efectivo puede venir calculado por la P2).
        progress: t.progress_manual ?? '',
        assignee_id: t.assignee_id ?? '',
        team_id: t.team_id ?? '',
        amount: t.amount ?? '',
        currency: t.currency ?? '',
        expected_close_at: t.expected_close_at ?? '',
        probability: t.probability ?? '',
      };
      this.customValues = { ...(t.custom_attributes ?? {}) };
    },
    async onSubmit() {
      if (this.isEdit) {
        await this.submitEdit();
        return;
      }
      try {
        const ticket = await this.$store.dispatch('caseTickets/createTicket', {
          // Plan-Casos E2 — con cliente es un caso suyo; sin cliente, interno.
          ...(this.contact
            ? { contact_id: this.contact.id, ...this.commercialPayload() }
            : { internal: true }),
          assignee_id: this.form.assignee_id || undefined,
          team_id: this.form.team_id || undefined,
          case_type_id: this.form.case_type_id,
          ticket_kind: this.form.ticket_kind,
          affected_service_id: this.form.affected_service_id || undefined,
          category_id: this.form.category_id || undefined,
          title: this.form.title.trim(),
          impact: this.form.impact || undefined,
          urgency: this.form.urgency || undefined,
          // Si la matriz deriva la prioridad, no se envía la manual (el backend la calcula).
          priority: this.derivedPriority ? undefined : this.form.priority,
          description: this.form.description.trim() || undefined,
          custom_attributes: this.selectedTypeFields.length
            ? this.customValues
            : undefined,
          ...(this.isWorkOrder ? workOrderPayload(this.form) : {}),
          ...(this.isProject ? projectPayload(this.form) : {}),
        });
        this.$emitter.emit('newToastMessage', {
          message: this.contact
            ? this.$t('CASE_TICKETS.CREATE.SUCCESS', {
                folio: ticket.folio || `#${ticket.id}`,
              })
            : this.$t('CASE_TICKETS.INTERNAL.SUCCESS'),
        });
        this.$emit('created', ticket);
        this.$emit('close');
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message:
            e.response?.data?.error || this.$t('CASE_TICKETS.INTERNAL.ERROR'),
        });
      }
    },
    // Plan-Casos E2 — vacío = no se manda (el backend pone la moneda de la
    // cuenta y la probabilidad de la etapa inicial).
    commercialPayload() {
      if (!this.isCommercial) return {};
      const f = this.form;
      return {
        amount: f.amount === '' ? undefined : f.amount,
        currency: f.currency.trim().toUpperCase() || undefined,
        expected_close_at: f.expected_close_at || undefined,
        probability: f.probability === '' ? undefined : f.probability,
      };
    },
    // Solo lo que cambió (undefined = no se toca; null = quitar).
    assignmentChanges() {
      const changes = {};
      const same = (a, b) => String(a ?? '') === String(b ?? '');
      if (!same(this.form.assignee_id, this.ticket.assignee_id)) {
        changes.assigneeId = this.form.assignee_id || null;
      }
      if (!same(this.form.team_id, this.ticket.team_id)) {
        changes.teamId = this.form.team_id || null;
      }
      return Object.keys(changes).length ? changes : null;
    },
    // @tickets_cases — guardar la edición: campos núcleo, datos comerciales,
    // custom y, si cambió, la asignación.
    async submitEdit() {
      const fields = {
        title: this.form.title.trim(),
        description: this.form.description.trim(),
        case_type_id: this.form.case_type_id,
        ticket_kind: this.form.ticket_kind,
        affected_service_id: this.form.affected_service_id,
        category_id: this.form.category_id,
        impact: this.form.impact,
        urgency: this.form.urgency,
      };
      // Solo se manda la prioridad manual cuando la matriz NO la deriva.
      if (!this.derivedPriority) fields.priority = this.form.priority;
      if (this.selectedTypeFields.length) {
        fields.custom_attributes = this.customValues;
      }
      if (this.isWorkOrder) {
        Object.assign(fields, workOrderPayload(this.form, { clear: true }));
      }
      if (this.isProject) {
        Object.assign(fields, projectPayload(this.form, { clear: true }));
        if (this.progressAuto) delete fields.progress;
      }
      // Vacío = limpiar el dato (null), a diferencia del alta.
      if (this.isCommercial) {
        const f = this.form;
        Object.assign(fields, {
          amount: f.amount === '' ? null : f.amount,
          currency:
            String(f.currency || '')
              .trim()
              .toUpperCase() || null,
          expected_close_at: f.expected_close_at || null,
          probability: f.probability === '' ? null : f.probability,
        });
      }
      try {
        let ticket = await this.$store.dispatch('caseTickets/editTicket', {
          ticketId: this.ticket.id,
          contactId: this.ticket.contact_id,
          fields,
        });
        const assignment = this.assignmentChanges();
        if (assignment) {
          ticket = await this.$store.dispatch('caseTickets/assignTicket', {
            ticketId: this.ticket.id,
            contactId: this.ticket.contact_id,
            ...assignment,
          });
        }
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.EDIT.SUCCESS'),
        });
        this.$emit('updated', ticket);
        this.$emit('close');
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message:
            e.response?.data?.error || this.$t('CASE_TICKETS.EDIT.ERROR'),
        });
      }
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="() => $emit('close')" size="medium">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header :header-title="headerTitle" />
      <form
        class="flex flex-col self-stretch w-full gap-3 p-8 pt-4"
        @submit.prevent="onSubmit"
      >
        <woot-tabs :index="activeTabIndex" @change="onTabChange">
          <woot-tabs-item
            v-for="(t, i) in tabs"
            :key="t.key"
            :index="i"
            :name="t.label"
            :show-badge="false"
          />
        </woot-tabs>

        <!-- Altura fija = altura del tab "Datos" (~424px), el más alto, para que
             el modal no salte al cambiar de pestaña ni deje hueco antes de los
             botones. Si se eligen impacto+urgencia, el hint de prioridad derivada
             agrega ~36px (reflujo natural del formulario, no salto entre tabs). -->
        <div class="min-h-[26.5rem]">
          <!-- Tab: Datos del ticket -->
          <div
            v-show="activeTab === 'ticket'"
            class="grid grid-cols-2 gap-3 [&_.input]:!mb-0"
          >
            <!-- Tipo de caso -->
            <label class="flex flex-col gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-300"
              >
                {{ $t('CASE_TICKETS.MODAL.CASE_TYPE_LABEL') }}
              </span>
              <select v-model="form.case_type_id" class="input">
                <option v-for="t in typeOptions" :key="t.id" :value="t.id">
                  {{ t.name }}
                </option>
              </select>
            </label>

            <!-- Naturaleza ITIL (oculto en modo simple) -->
            <label v-if="itilEnabled" class="flex flex-col gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-300"
              >
                {{ $t('CASE_TICKETS.MODAL.TICKET_KIND_LABEL') }}
              </span>
              <select v-model="form.ticket_kind" class="input">
                <option
                  v-for="(label, key) in ticketKindOptions"
                  :key="key"
                  :value="key"
                >
                  {{ label }}
                </option>
              </select>
            </label>

            <!-- Edición: el cliente se muestra pero no se cambia (el caso
                 sigue ligado a su contacto y a su conversación). -->
            <div v-if="isEdit" class="flex flex-col col-span-2 gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-300"
              >
                {{ $t('CASE_TICKETS.CREATE.CONTACT') }}
              </span>
              <div
                class="px-3 py-2 border rounded-lg border-slate-100 dark:border-slate-700 bg-slate-25 dark:bg-slate-800"
              >
                <p
                  class="m-0 text-sm font-medium truncate text-slate-800 dark:text-slate-100"
                >
                  {{
                    ticket.contact_name || $t('CASE_TICKETS.EDIT.NO_CONTACT')
                  }}
                </p>
                <p
                  v-if="ticket.contact_email"
                  class="m-0 text-xs truncate text-slate-500 dark:text-slate-400"
                >
                  {{ ticket.contact_email }}
                </p>
              </div>
              <span class="text-xs text-slate-500 dark:text-slate-400">
                {{ $t('CASE_TICKETS.EDIT.CONTACT_LOCKED') }}
              </span>
            </div>

            <!-- Plan-Casos E2 — cliente (solo en el alta por clase) -->
            <div
              v-if="!isEdit && caseClass"
              class="flex flex-col col-span-2 gap-1"
            >
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-300"
              >
                {{
                  contactRequired
                    ? $t('CASE_TICKETS.CREATE.CONTACT')
                    : $t('CASE_TICKETS.CREATE.CONTACT_OPTIONAL')
                }}
              </span>
              <ContactPicker v-model="contact" />
              <span
                v-if="!contact"
                class="text-xs"
                :class="
                  contactRequired
                    ? 'text-amber-700 dark:text-amber-300'
                    : 'text-slate-500 dark:text-slate-400'
                "
              >
                {{
                  contactRequired
                    ? $t('CASE_TICKETS.CREATE.CONTACT_REQUIRED')
                    : $t('CASE_TICKETS.CREATE.CONTACT_INTERNAL_HINT')
                }}
              </span>
            </div>

            <!-- Título -->
            <label class="flex flex-col col-span-2 gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-300"
              >
                {{ $t('CASE_TICKETS.MODAL.TITLE_LABEL') }}
              </span>
              <input
                v-model="form.title"
                type="text"
                class="input"
                :placeholder="$t('CASE_TICKETS.INTERNAL.TITLE_PLACEHOLDER')"
                required
              />
            </label>

            <!-- Descripción -->
            <label class="flex flex-col col-span-2 gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-300"
              >
                {{ $t('CASE_TICKETS.MODAL.DESCRIPTION_LABEL') }}
              </span>
              <textarea
                v-model="form.description"
                class="input !h-24"
                :placeholder="$t('CASE_TICKETS.MODAL.DESCRIPTION_PLACEHOLDER')"
              />
            </label>

            <!-- Plan-Casos E2 — datos de la oportunidad (alta y edición) -->
            <div
              v-if="isCommercial"
              class="grid grid-cols-4 col-span-2 gap-3 p-3 rounded-lg bg-violet-50 dark:bg-slate-800/50"
            >
              <label class="flex flex-col gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-300"
                >
                  {{ $t('CASE_TICKETS.COMMERCIAL.FIELDS.AMOUNT') }}
                </span>
                <input
                  v-model="form.amount"
                  type="number"
                  min="0"
                  step="0.01"
                  class="input"
                />
              </label>
              <label class="flex flex-col gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-300"
                >
                  {{ $t('CASE_TICKETS.COMMERCIAL.FIELDS.CURRENCY') }}
                </span>
                <input
                  v-model="form.currency"
                  type="text"
                  maxlength="3"
                  class="uppercase input"
                />
              </label>
              <label class="flex flex-col gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-300"
                >
                  {{ $t('CASE_TICKETS.COMMERCIAL.FIELDS.EXPECTED_CLOSE') }}
                </span>
                <input
                  v-model="form.expected_close_at"
                  type="date"
                  class="input"
                />
              </label>
              <label class="flex flex-col gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-300"
                >
                  {{ $t('CASE_TICKETS.COMMERCIAL.FIELDS.PROBABILITY') }} %
                </span>
                <input
                  v-model="form.probability"
                  type="number"
                  min="0"
                  max="100"
                  class="input"
                />
              </label>
            </div>

            <!-- Plan-Clase-Orden-de-Trabajo F2a — datos de la orden (alta y edición) -->
            <div
              v-if="isWorkOrder"
              class="flex items-center col-span-2 gap-3 px-3 py-2 rounded-lg bg-teal-50 dark:bg-slate-800/50"
            >
              <label class="flex items-center gap-2">
                <input v-model="form.billable" type="checkbox" class="!mb-0" />
                <span class="text-sm text-slate-700 dark:text-slate-300">
                  {{ $t('CASE_TICKETS.WORK_ORDER.FIELDS.BILLABLE') }}
                </span>
              </label>
            </div>

            <!-- Plan-Clase-Proyecto P1 — datos del proyecto -->
            <div
              v-if="isProject"
              class="grid grid-cols-4 col-span-2 gap-3 p-3 rounded-lg bg-indigo-50 dark:bg-slate-800/50"
            >
              <label class="flex flex-col gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-300"
                >
                  {{ $t('CASE_TICKETS.PROJECT.FIELDS.START') }}
                </span>
                <input
                  v-model="form.project_start_on"
                  type="date"
                  class="input"
                />
              </label>
              <label class="flex flex-col gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-300"
                >
                  {{ $t('CASE_TICKETS.PROJECT.FIELDS.DUE') }}
                </span>
                <input
                  v-model="form.project_due_on"
                  type="date"
                  class="input"
                />
              </label>
              <label class="flex flex-col gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-300"
                >
                  {{ $t('CASE_TICKETS.PROJECT.FIELDS.BUDGET_HOURS') }}
                </span>
                <input
                  v-model="form.budget_hours"
                  type="number"
                  min="0"
                  step="0.5"
                  class="input"
                />
              </label>
              <label class="flex flex-col gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-300"
                >
                  {{ $t('CASE_TICKETS.PROJECT.FIELDS.BUDGET_AMOUNT') }}
                </span>
                <input
                  v-model="form.budget_amount"
                  type="number"
                  min="0"
                  step="0.01"
                  class="input"
                />
              </label>
              <label v-if="isEdit && !progressAuto" class="flex flex-col gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-300"
                >
                  {{ $t('CASE_TICKETS.PROJECT.FIELDS.PROGRESS') }} %
                </span>
                <input
                  v-model="form.progress"
                  type="number"
                  min="0"
                  max="100"
                  step="5"
                  class="input"
                />
              </label>
            </div>

            <!-- Servicio afectado -->
            <label class="flex flex-col gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-300"
              >
                {{
                  isCommercial
                    ? $t('CASE_TICKETS.MODAL.INTEREST_PRODUCTS_LABEL')
                    : $t('CASE_TICKETS.MODAL.AFFECTED_SERVICE_LABEL')
                }}
              </span>
              <select v-model="form.affected_service_id" class="input">
                <option :value="null">
                  {{ $t('CASE_TICKETS.MODAL.UNSPECIFIED') }}
                </option>
                <option v-for="s in typedServices" :key="s.id" :value="s.id">
                  {{ s.name }}
                </option>
              </select>
            </label>

            <!-- Categoría -->
            <label class="flex flex-col gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-300"
              >
                {{ $t('CASE_TICKETS.MODAL.CATEGORY_LABEL') }}
              </span>
              <select v-model="form.category_id" class="input">
                <option :value="null">
                  {{ $t('CASE_TICKETS.MODAL.UNSPECIFIED') }}
                </option>
                <option v-for="c in flatCategories" :key="c.id" :value="c.id">
                  {{ c.label }}
                </option>
              </select>
            </label>

            <!-- Impacto · Urgencia · Prioridad (impacto/urgencia ocultos en modo simple) -->
            <div class="col-span-2 gap-3" :class="priorityRowClass">
              <!-- Impacto -->
              <label
                v-if="itilEnabled"
                class="flex flex-col gap-1"
                :class="isWorkOrder ? 'w-40' : ''"
              >
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-300"
                >
                  {{ $t('CASE_TICKETS.MODAL.IMPACT_LABEL') }}
                </span>
                <select v-model="form.impact" class="input">
                  <option :value="null">
                    {{ $t('CASE_TICKETS.MODAL.UNSPECIFIED') }}
                  </option>
                  <option
                    v-for="(label, key) in impactOptions"
                    :key="key"
                    :value="key"
                  >
                    {{ label }}
                  </option>
                </select>
              </label>

              <!-- Urgencia -->
              <label
                v-if="itilEnabled"
                class="flex flex-col gap-1"
                :class="isWorkOrder ? 'w-40' : ''"
              >
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-300"
                >
                  {{ $t('CASE_TICKETS.MODAL.URGENCY_LABEL') }}
                </span>
                <select v-model="form.urgency" class="input">
                  <option :value="null">
                    {{ $t('CASE_TICKETS.MODAL.UNSPECIFIED') }}
                  </option>
                  <option
                    v-for="(label, key) in urgencyOptions"
                    :key="key"
                    :value="key"
                  >
                    {{ label }}
                  </option>
                </select>
              </label>

              <!-- Prioridad (más angosta en una orden: comparte fila con las horas) -->
              <label
                class="flex flex-col gap-1"
                :class="isWorkOrder ? 'w-40' : ''"
              >
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-300"
                >
                  {{ $t('CASE_TICKETS.MODAL.PRIORITY_LABEL') }}
                </span>
                <select
                  v-model="form.priority"
                  class="input"
                  :disabled="!!derivedPriority"
                >
                  <option value="low">
                    {{ $t('CASE_TICKETS.PRIORITIES.low') }}
                  </option>
                  <option value="medium">
                    {{ $t('CASE_TICKETS.PRIORITIES.medium') }}
                  </option>
                  <option value="high">
                    {{ $t('CASE_TICKETS.PRIORITIES.high') }}
                  </option>
                  <option value="urgent">
                    {{ $t('CASE_TICKETS.PRIORITIES.urgent') }}
                  </option>
                </select>
                <span
                  v-if="derivedPriority"
                  class="text-xs text-slate-500 dark:text-slate-400"
                >
                  {{
                    $t('CASE_TICKETS.MODAL.PRIORITY_DERIVED', {
                      priority: priorityOptions[derivedPriority],
                    })
                  }}
                </span>
              </label>
              <!-- Plan-Clase-Orden-de-Trabajo — horas en la fila de prioridad -->
              <label v-if="isWorkOrder" class="flex flex-col w-32 gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-300"
                >
                  {{ $t('CASE_TICKETS.WORK_ORDER.FIELDS.ESTIMATED_HOURS') }}
                </span>
                <input
                  v-model="form.estimated_hours"
                  type="number"
                  min="0"
                  step="0.25"
                  class="input"
                />
              </label>
              <label
                v-if="isWorkOrder && isEdit"
                class="flex flex-col w-32 gap-1"
              >
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-300"
                >
                  {{ $t('CASE_TICKETS.WORK_ORDER.FIELDS.ACTUAL_HOURS') }}
                </span>
                <input
                  v-model="form.actual_hours"
                  type="number"
                  min="0"
                  step="0.25"
                  class="input"
                />
              </label>
            </div>
          </div>

          <!-- Tab: Asignación -->
          <div
            v-show="activeTab === 'assign'"
            class="grid grid-cols-2 gap-3 [&_.input]:!mb-0"
          >
            <!-- Equipo -->
            <label class="flex flex-col gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-300"
              >
                {{ $t('CASE_TICKETS.ASSIGN.TEAM_LABEL') }}
              </span>
              <select v-model="form.team_id" class="input">
                <option value="">
                  {{ $t('CASE_TICKETS.INTERNAL.ASSIGNEE_NONE') }}
                </option>
                <option v-for="tm in teams" :key="tm.id" :value="tm.id">
                  {{ tm.name }}
                </option>
              </select>
            </label>

            <!-- Agente -->
            <label class="flex flex-col gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-300"
              >
                {{ $t('CASE_TICKETS.INTERNAL.ASSIGNEE_LABEL') }}
              </span>
              <select v-model="form.assignee_id" class="input">
                <option value="">
                  {{ $t('CASE_TICKETS.INTERNAL.ASSIGNEE_NONE') }}
                </option>
                <option v-for="ag in agents" :key="ag.id" :value="ag.id">
                  {{ ag.name }}
                </option>
              </select>
            </label>
            <p class="col-span-2 text-xs text-slate-400 dark:text-slate-500">
              {{ $t('CASE_TICKETS.MODAL.ASSIGN_HINT') }}
            </p>
          </div>

          <!-- Plan-Clase-Orden-de-Trabajo — Tab: Dirección del servicio (solo orden) -->
          <div
            v-if="isWorkOrder"
            v-show="activeTab === 'address'"
            class="flex flex-col gap-3 [&_.input]:!mb-0"
          >
            <label class="flex flex-col gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-300"
              >
                {{ $t('CASE_TICKETS.WORK_ORDER.FIELDS.ADDRESS') }}
              </span>
              <textarea
                v-model="form.work_address"
                maxlength="255"
                rows="3"
                class="input"
                :placeholder="
                  $t('CASE_TICKETS.WORK_ORDER.FORM.ADDRESS_PLACEHOLDER')
                "
              />
            </label>
            <p class="m-0 text-xs text-slate-400 dark:text-slate-500">
              {{ $t('CASE_TICKETS.WORK_ORDER.FORM.ADDRESS_HINT') }}
            </p>
          </div>

          <!-- Tab: Campos personalizados (2K) -->
          <div v-show="activeTab === 'custom'">
            <div
              v-if="!selectedTypeFields.length"
              class="py-6 text-sm text-center text-slate-400 dark:text-slate-500"
            >
              {{ $t('CASE_TICKETS.MODAL.NO_CUSTOM_FIELDS') }}
            </div>
            <div v-else class="grid grid-cols-2 gap-3 [&_.input]:!mb-0">
              <label
                v-for="field in selectedTypeFields"
                :key="field.key"
                class="flex"
                :class="
                  field.field_type === 'checkbox'
                    ? 'flex-row items-center col-span-2 gap-2.5 px-3 py-2.5 border rounded-md cursor-pointer border-slate-200 dark:border-slate-600 bg-slate-25 dark:bg-slate-800'
                    : 'flex-col gap-1'
                "
              >
                <input
                  v-if="field.field_type === 'checkbox'"
                  v-model="customValues[field.key]"
                  type="checkbox"
                  class="w-4 h-4 shrink-0"
                />
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-300"
                >
                  {{ field.label
                  }}<span v-if="field.required" class="text-red-500"> *</span>
                </span>
                <select
                  v-if="field.field_type === 'list'"
                  v-model="customValues[field.key]"
                  class="input"
                  :required="field.required"
                >
                  <option value="">
                    {{ $t('CASE_TICKETS.MODAL.UNSPECIFIED') }}
                  </option>
                  <option v-for="opt in field.options" :key="opt" :value="opt">
                    {{ opt }}
                  </option>
                </select>
                <input
                  v-else-if="field.field_type === 'number'"
                  v-model="customValues[field.key]"
                  type="number"
                  class="input"
                  :required="field.required"
                />
                <input
                  v-else-if="field.field_type === 'date'"
                  v-model="customValues[field.key]"
                  type="date"
                  class="input"
                  :required="field.required"
                />
                <input
                  v-else-if="field.field_type === 'text'"
                  v-model="customValues[field.key]"
                  type="text"
                  class="input"
                  :required="field.required"
                />
              </label>
            </div>
          </div>
        </div>

        <div class="flex items-center justify-end gap-2">
          <woot-button variant="clear" type="button" @click="$emit('close')">
            {{ $t('CASE_TICKETS.MODAL.CANCEL') }}
          </woot-button>
          <woot-button
            type="submit"
            :is-loading="isEdit ? uiFlags.isSaving : uiFlags.isCreating"
            :disabled="!isValid"
          >
            {{
              isEdit
                ? $t('CASE_TICKETS.EDIT.SUBMIT')
                : $t('CASE_TICKETS.INTERNAL.SUBMIT')
            }}
          </woot-button>
        </div>
      </form>
    </div>
  </woot-modal>
</template>
