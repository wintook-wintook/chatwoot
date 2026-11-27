<script>
// proyecto@crear_agente_conversando — F3: DEFINICIÓN, VARIABLES Y DATOS FIJOS
// ============================================================================
// Plan: docs/creacion_conversacional_agentes_plan.md §6. La pestaña que la
// conversación va llenando mientras se arma un agente desde cero. Cada parte se
// corrige con su modal de siempre (Definición, F1 Variables, F2 Datos fijos) y el chat
// sigue desde lo corregido: viaja en el turno siguiente. Al «Crear el Entrenamiento»
// las Variables y los Datos fijos pasan tal cual (BriefFromChat).
// ============================================================================
import DefinitionModal from './DefinitionModal.vue';
import VariablesModal from './VariablesModal.vue';
import ConstantsModal from './ConstantsModal.vue';
import {
  constantsBody,
  constantsOf,
  fieldsOf,
  variablesBody,
  variablesOf,
} from './draftingFields';

export default {
  components: { DefinitionModal, VariablesModal, ConstantsModal },
  props: {
    // proposal de la conversación: objective, ai_context, variables, datos_fijos.
    proposal: { type: Object, default: null },
    canProofread: { type: Boolean, default: false },
    inboxId: { type: Number, default: null },
  },
  emits: ['update'],
  data() {
    // focus: null | índice | 'new' (ver VariablesModal); confirming: «variables-2».
    return { modal: null, focus: null, confirming: null };
  },
  computed: {
    fields() {
      return fieldsOf(this.proposal);
    },
    definition() {
      return {
        name: (this.proposal || {}).name || '',
        objective: this.fields.objective,
        ai_context: this.fields.ai_context,
      };
    },
    variables() {
      return variablesOf(this.fields.variables);
    },
    constants() {
      return constantsOf(this.fields.datos_fijos);
    },
    variableNames() {
      return this.variables.variables.map(v => v.name);
    },
    isEmpty() {
      return !Object.values(this.fields).some(Boolean);
    },
  },
  methods: {
    open(modal, focus = null) {
      this.focus = focus;
      this.modal = modal;
    },
    removeVariable(index) {
      this.confirming = null;
      this.$emit('update', {
        variables: variablesBody({
          ...this.variables,
          variables: this.variables.variables.filter((_, i) => i !== index),
        }),
      });
    },
    removeConstant(index) {
      this.confirming = null;
      this.$emit('update', {
        datos_fijos: constantsBody({
          ...this.constants,
          constants: this.constants.constants.filter((_, i) => i !== index),
        }),
      });
    },
    valuesText(variable) {
      const valores = [...variable.options];
      if (variable.free)
        valores.push(this.$t('TRACKING_ASSISTANT_VIEW.FIELDS_FREE_VALUE'));
      return valores.join(' · ');
    },
    constantText(constante) {
      return constante.type === 'pregunta'
        ? `«${constante.value}»`
        : constante.value;
    },
    saveDefinition(valores) {
      this.modal = null;
      this.$emit('update', valores);
    },
    saveVariables(data) {
      this.modal = null;
      this.$emit('update', { variables: variablesBody(data) });
    },
    saveConstants(data) {
      this.modal = null;
      this.$emit('update', { datos_fijos: constantsBody(data) });
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0 gap-4 overflow-y-auto text-sm">
    <p class="!m-0 text-xs text-slate-600 dark:text-slate-300">
      {{ $t('TRACKING_ASSISTANT_VIEW.FIELDS_HINT') }}
    </p>
    <p v-if="isEmpty" class="!m-0 text-slate-500 dark:text-slate-400">
      {{ $t('TRACKING_ASSISTANT_VIEW.FIELDS_EMPTY') }}
    </p>

    <section class="flex flex-col gap-1">
      <div class="flex items-center justify-between">
        <h4
          class="!m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.TREE_DEFINITION') }}
        </h4>
        <woot-button
          size="small"
          variant="clear"
          icon="edit"
          @click="open('definition')"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.FIELDS_EDIT') }}
        </woot-button>
      </div>
      <p class="!m-0 text-slate-700 dark:text-slate-200">
        <span class="text-xs text-slate-500 dark:text-slate-400">
          {{ $t('TRACKING_ASSISTANT_VIEW.TREE_OBJECTIVE') }}:
        </span>
        {{ fields.objective || $t('TRACKING_ASSISTANT_VIEW.FIELDS_NOT_YET') }}
      </p>
      <p
        class="!m-0 text-slate-700 dark:text-slate-200 line-clamp-3 whitespace-pre-line"
      >
        <span class="text-xs text-slate-500 dark:text-slate-400">
          {{ $t('TRACKING_ASSISTANT_VIEW.TREE_CONTEXT') }}:
        </span>
        {{ fields.ai_context || $t('TRACKING_ASSISTANT_VIEW.FIELDS_NOT_YET') }}
      </p>
    </section>

    <section class="flex flex-col gap-1">
      <div class="flex items-center justify-between">
        <h4
          class="!m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.FIELDS_VARIABLES') }}
        </h4>
        <woot-button
          size="small"
          variant="smooth"
          color-scheme="success"
          icon="add"
          @click="open('variables', 'new')"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.TREE_ITEM_ADD') }}
        </woot-button>
      </div>
      <p
        v-if="!variables.variables.length"
        class="!m-0 text-slate-500 dark:text-slate-400"
      >
        {{ $t('TRACKING_ASSISTANT_VIEW.FIELDS_NO_VARIABLES') }}
      </p>
      <div
        v-for="(variable, index) in variables.variables"
        :key="variable.name"
        class="flex items-center gap-2 px-1 rounded hover:bg-slate-50 dark:hover:bg-slate-700"
        @mouseleave="confirming = null"
      >
        <span class="font-mono text-xs text-slate-800 dark:text-slate-100">
          {{ variable.name }}
        </span>
        <span class="flex-1 min-w-0 text-slate-600 dark:text-slate-300">
          {{ valuesText(variable) }}
        </span>
        <span
          v-if="variable.initial"
          class="text-xs text-slate-500 dark:text-slate-400"
        >
          {{
            $t('TRACKING_ASSISTANT_VIEW.FIELDS_STARTS_AT', {
              value: variable.initial,
            })
          }}
        </span>
        <woot-button
          v-tooltip="$t('TRACKING_ASSISTANT_VIEW.TREE_ITEM_EDIT')"
          size="tiny"
          variant="clear"
          color-scheme="secondary"
          icon="edit"
          @click="open('variables', index)"
        />
        <woot-button
          v-if="confirming !== `variables-${index}`"
          v-tooltip="$t('TRACKING_ASSISTANT_VIEW.TREE_ITEM_DELETE')"
          size="tiny"
          variant="clear"
          color-scheme="secondary"
          icon="delete"
          @click="confirming = `variables-${index}`"
        />
        <woot-button
          v-else
          size="tiny"
          variant="smooth"
          color-scheme="alert"
          @click="removeVariable(index)"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.TREE_ITEM_DELETE_CONFIRM') }}
        </woot-button>
      </div>
    </section>

    <section class="flex flex-col gap-1">
      <div class="flex items-center justify-between">
        <h4
          class="!m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.FIELDS_CONSTANTS') }}
        </h4>
        <woot-button
          size="small"
          variant="smooth"
          color-scheme="success"
          icon="add"
          @click="open('constants', 'new')"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.TREE_ITEM_ADD') }}
        </woot-button>
      </div>
      <p
        v-if="!constants.constants.length"
        class="!m-0 text-slate-500 dark:text-slate-400"
      >
        {{ $t('TRACKING_ASSISTANT_VIEW.FIELDS_NO_CONSTANTS') }}
      </p>
      <div
        v-for="(constante, index) in constants.constants"
        :key="constante.name"
        class="flex items-center gap-2 px-1 rounded hover:bg-slate-50 dark:hover:bg-slate-700"
        @mouseleave="confirming = null"
      >
        <span class="font-mono text-xs text-slate-800 dark:text-slate-100">
          {{ constante.name }}
        </span>
        <span
          class="flex-1 min-w-0 truncate text-slate-600 dark:text-slate-300"
        >
          {{ constantText(constante) }}
        </span>
        <span
          v-if="constante.savesTo"
          class="text-xs text-slate-500 dark:text-slate-400"
        >
          {{ `→ ${constante.savesTo}` }}
        </span>
        <woot-button
          v-tooltip="$t('TRACKING_ASSISTANT_VIEW.TREE_ITEM_EDIT')"
          size="tiny"
          variant="clear"
          color-scheme="secondary"
          icon="edit"
          @click="open('constants', index)"
        />
        <woot-button
          v-if="confirming !== `constants-${index}`"
          v-tooltip="$t('TRACKING_ASSISTANT_VIEW.TREE_ITEM_DELETE')"
          size="tiny"
          variant="clear"
          color-scheme="secondary"
          icon="delete"
          @click="confirming = `constants-${index}`"
        />
        <woot-button
          v-else
          size="tiny"
          variant="smooth"
          color-scheme="alert"
          @click="removeConstant(index)"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.TREE_ITEM_DELETE_CONFIRM') }}
        </woot-button>
      </div>
    </section>

    <DefinitionModal
      :show="modal === 'definition'"
      :definition="definition"
      :can-proofread="canProofread"
      :inbox-id="inboxId"
      @close="modal = null"
      @save="saveDefinition"
    />
    <VariablesModal
      :show="modal === 'variables'"
      :value="variables"
      :focus="focus"
      @close="modal = null"
      @save="saveVariables"
    />
    <ConstantsModal
      :show="modal === 'constants'"
      :value="constants"
      :focus="focus"
      :variables="variableNames"
      @close="modal = null"
      @save="saveConstants"
    />
  </div>
</template>
