<script>
// proyecto@adaptar_prompts_publicados (F2) — PESTAÑA «CONFIGURAR» DEL ASISTENTE
// ============================================================================
// Lo que el Entrenamiento usa y la cuenta no tiene (AdaptationInventory, F0), con la
// forma de resolver cada cosa:
//   text          escribir el valor de un <PENDIENTE: X>
//   create_inline crear la fuente o la etiqueta ahí mismo (los mismos modales que la
//                 ruta: AddSourceModal), o elegir otra de la cuenta
//   select        elegir otra de la cuenta (tipo de caso, consulta del ERP)
//   upload        subir el archivo a la pestaña Archivos del agente
//   link          se configura en otra pantalla: se abre en otra pestaña del navegador
//                 y, al volver, el Asistente revisa otra vez (window focus)
//
// «Aplicar» manda las respuestas a AdaptationApplier (F1) y entrega el texto nuevo al
// Asistente, que lo pone en el editor y lo guarda como versión «Configurado». Esta
// pestaña no guarda nada por su cuenta. Lo que se crea (fuente, etiqueta, archivo)
// avisa con ASSISTANT_SOURCES_CHANGED, igual que desde la ruta.
// Plan: docs/adaptar_prompts_publicados_plan.md
// ============================================================================
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { emitter } from 'shared/helpers/mitt';
import AssistantAPI from 'dashboard/api/assistant';
import AiAgentAttachmentsAPI from 'dashboard/api/aiAgentAttachments';
import KnowledgeBaseAPI from 'dashboard/routes/dashboard/settings/knowledgeSources/api';
import AddSourceModal from 'dashboard/routes/dashboard/settings/knowledgeSources/AddSourceModal.vue';
import { ASSISTANT_SOURCES_CHANGED } from './sourceDirective';

const GROUPS = ['business', 'sources', 'case_types', 'outside'];

export default {
  components: { AddSourceModal },
  props: {
    items: { type: Array, default: () => [] },
    draft: { type: String, default: '' },
    templateId: { type: Number, default: null },
    loading: { type: Boolean, default: false },
  },
  data() {
    return {
      answers: {},
      showOk: false,
      isApplying: false,
      creatingSource: null,
      savingSource: false,
      uploadingKey: null,
      // F7: lo que el modelo señaló como datos de un negocio (null = no se ha buscado).
      suggestions: null,
      chosenSuggestions: [],
      isSuggesting: false,
      isMarking: false,
    };
  },
  computed: {
    ...mapGetters({ accountId: 'getCurrentAccountId' }),
    missing() {
      return this.items.filter(item => item.status === 'missing');
    },
    ready() {
      return this.items.filter(item => item.status === 'ok');
    },
    groups() {
      return GROUPS.map(group => ({
        group,
        items: this.missing.filter(item => item.group === group),
      })).filter(bloque => bloque.items.length);
    },
    // Solo lo que tiene valor: un campo vacío deja la marca como estaba.
    filledAnswers() {
      return Object.fromEntries(
        Object.entries(this.answers).filter(([, value]) =>
          String(value || '').trim()
        )
      );
    },
    // F6: algo salió prellenado con lo configurado antes en este agente.
    hasRemembered() {
      return this.missing.some(item => item.remembered);
    },
    canApply() {
      return Object.keys(this.filledAnswers).length > 0 && !this.isApplying;
    },
    okToggleLabel() {
      const flecha = this.showOk ? '▾' : '▸';
      return `${flecha} ${this.t('OK_TOGGLE', { count: this.ready.length })}`;
    },
  },
  watch: {
    // Lo que ya no falta (se aplicó o se creó) deja de ocupar su respuesta. F6: lo que se
    // configuró antes en este agente (versión nueva del autor) sale prellenado.
    items: {
      immediate: true,
      handler(lista) {
        const faltan = lista.filter(i => i.status === 'missing');
        const vigentes = new Set(faltan.map(i => i.key));
        const respuestas = Object.fromEntries(
          Object.entries(this.answers).filter(([key]) => vigentes.has(key))
        );
        faltan.forEach(item => {
          if (item.remembered && !respuestas[item.key]) {
            respuestas[item.key] = item.remembered;
          }
        });
        this.answers = respuestas;
      },
    },
  },
  methods: {
    t(key, args) {
      return this.$t(`TRACKING_ASSISTANT_VIEW.CONFIGURE.${key}`, args);
    },
    kindLabel(item) {
      return this.t(`KIND.${item.kind.toUpperCase()}`);
    },
    // Lo que se ve de cada cosa: el nombre del dato o la directiva tal como está escrita.
    title(item) {
      if (item.kind === 'variable') return item.name;
      return item.wrote || item.name || this.kindLabel(item);
    },
    readyLabel(item) {
      return `✔ ${this.title(item)}`;
    },
    // ↗: se abre en otra pestaña del navegador.
    linkLabel(item) {
      const texto =
        item.kind === 'case_type'
          ? this.t('CREATE_CASE_TYPE')
          : this.t('OPEN_LINK');
      return `${texto} ↗`;
    },
    isSource(item) {
      return item.fix === 'create_inline';
    },
    hasOptions(item) {
      return Array.isArray(item.options) && item.options.length > 0;
    },
    setAnswer(key, value) {
      this.answers = { ...this.answers, [key]: value };
    },
    answerFor(key) {
      return this.answers[key] || '';
    },
    linkHref(item) {
      if (!item.link) return '';
      return this.$router.resolve({
        name: item.link.route,
        params: { accountId: this.accountId, ...(item.link.params || {}) },
        query: item.link.query || {},
      }).href;
    },
    refresh() {
      emitter.emit(ASSISTANT_SOURCES_CHANGED);
    },
    // ── Crear la fuente ahí mismo (mismo modal y misma API que desde la ruta) ──
    async createSource(payload) {
      this.savingSource = true;
      try {
        await KnowledgeBaseAPI.createSource(this.accountId, payload);
        this.creatingSource = null;
        useAlert(this.t('SOURCE_ADDED'));
        this.refresh();
      } catch (error) {
        const respuesta =
          (error && error.response && error.response.data) || {};
        useAlert(
          (respuesta.errors && respuesta.errors[0]) ||
            respuesta.error ||
            this.t('SOURCE_ADD_ERROR')
        );
      } finally {
        this.savingSource = false;
      }
    },
    // ── Subir el archivo con el nombre que pide el prompt ──────────────────────
    async upload(item, event) {
      const file = event.target.files && event.target.files[0];
      event.target.value = '';
      if (!file || !this.templateId) return;

      this.uploadingKey = item.key;
      try {
        await AiAgentAttachmentsAPI.upload(this.templateId, {
          name: item.name,
          file,
        });
        useAlert(this.t('UPLOADED', { name: item.name }));
        this.refresh();
      } catch (error) {
        useAlert(this.t('UPLOAD_ERROR'));
      } finally {
        this.uploadingKey = null;
      }
    },
    // ── Aplicar: el servidor reescribe, el Asistente pone el texto y lo versiona ──
    async apply() {
      if (!this.canApply) return;
      const respuestas = this.filledAnswers;
      this.isApplying = true;
      try {
        const { data } = await AssistantAPI.applyAdaptation(
          this.draft,
          respuestas,
          this.templateId
        );
        if (data.applied.length) {
          const notas = data.applied.map(key => `${key} → ${respuestas[key]}`);
          this.$emit('applied', { ...data, notes: notas });
          useAlert(this.t('APPLIED', { count: data.applied.length }));
        }
        if (data.rejected.length) this.alertRejected(data.rejected);
      } catch (error) {
        useAlert(this.t('APPLY_ERROR'));
      } finally {
        this.isApplying = false;
      }
    },
    // ── F7: el modelo propone datos de un negocio; los elegidos pasan a variables ──
    async suggest() {
      this.isSuggesting = true;
      try {
        const { data } = await AssistantAPI.suggestVariables(this.draft);
        if (data.error)
          useAlert(this.t(`SUGGEST_ERROR_${data.error.toUpperCase()}`));
        this.suggestions = (data.variables || []).map(v => ({ ...v }));
        this.chosenSuggestions = this.suggestions.map(v => v.text);
      } catch (error) {
        useAlert(this.t('SUGGEST_ERROR_FAILED'));
      } finally {
        this.isSuggesting = false;
      }
    },
    async markVariables() {
      const elegidas = (this.suggestions || []).filter(v =>
        this.chosenSuggestions.includes(v.text)
      );
      if (!elegidas.length) return;
      this.isMarking = true;
      try {
        const { data } = await AssistantAPI.markVariables(
          this.draft,
          elegidas.map(v => ({ text: v.text, label: v.label })),
          this.templateId
        );
        const notas = elegidas.map(
          v => `${v.text} → ${this.t('MARKED_NOTE', { label: v.label })}`
        );
        this.$emit('applied', { ...data, notes: notas });
        useAlert(this.t('MARKED', { count: elegidas.length }));
        this.suggestions = null;
      } catch (error) {
        const respuesta =
          (error && error.response && error.response.data) || {};
        useAlert(respuesta.message || this.t('APPLY_ERROR'));
      } finally {
        this.isMarking = false;
      }
    },
    alertRejected(rejected) {
      const nombre = key => {
        const item = this.items.find(i => i.key === key);
        return item ? this.title(item) : key;
      };
      const lista = rejected
        .map(
          r =>
            `${nombre(r.key)} (${this.t(`REASON.${r.reason.toUpperCase()}`)})`
        )
        .join(' · ');
      useAlert(this.t('REJECTED', { list: lista }));
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0 overflow-y-auto text-sm">
    <p class="mb-3 text-xs text-slate-500 dark:text-slate-400">
      {{ draft.trim() ? t('HINT') : t('EMPTY') }}
    </p>
    <p
      v-if="hasRemembered"
      class="mb-3 text-xs text-woot-700 dark:text-woot-300"
    >
      {{ t('REMEMBERED') }}
    </p>

    <p
      v-if="draft.trim() && !missing.length && !loading"
      class="mb-3 text-sm text-green-700 dark:text-green-400"
    >
      {{ t('ALL_DONE') }}
    </p>

    <section v-for="bloque in groups" :key="bloque.group" class="mb-4">
      <h4
        class="mb-2 text-xs font-semibold tracking-wide uppercase text-slate-600 dark:text-slate-300"
      >
        {{ t(`GROUP_${bloque.group.toUpperCase()}`) }}
      </h4>

      <div
        v-for="item in bloque.items"
        :key="item.key"
        class="flex flex-wrap items-start gap-2 py-2 border-b border-slate-100 dark:border-slate-700"
      >
        <div class="flex-1 min-w-[10rem]">
          <span
            class="block text-xs text-slate-500 dark:text-slate-400"
            :title="item.line ? `L${item.line}` : ''"
          >
            {{ kindLabel(item) }}
            <span v-if="item.occurrences > 1">
              {{ t('PLACES', { count: item.occurrences }) }}
            </span>
          </span>
          <span
            class="font-mono text-xs break-all text-slate-800 dark:text-slate-100"
          >
            {{ title(item) }}
          </span>
          <span
            v-if="item.reason === 'google_disabled'"
            class="block text-xs text-amber-800 dark:text-amber-400"
          >
            {{ t('GOOGLE_DISABLED') }}
          </span>
        </div>

        <div class="flex flex-wrap items-center flex-1 min-w-[14rem] gap-2">
          <!-- text: el valor del dato -->
          <input
            v-if="item.fix === 'text'"
            type="text"
            class="flex-1 !mb-0 !py-1 text-xs"
            :value="answerFor(item.key)"
            :placeholder="t('VALUE_PLACEHOLDER')"
            @input="setAnswer(item.key, $event.target.value)"
          />

          <!-- create_inline: crear la fuente o la etiqueta ahí mismo -->
          <woot-button
            v-if="isSource(item)"
            size="tiny"
            variant="smooth"
            icon="add"
            @click="creatingSource = item"
          >
            {{ t('CREATE_SOURCE', { name: item.name }) }}
          </woot-button>

          <!-- create_inline / select: usar una que ya existe en la cuenta -->
          <select
            v-if="
              (item.fix === 'create_inline' || item.fix === 'select') &&
              hasOptions(item)
            "
            class="flex-1 min-w-[10rem] !mb-0 !py-1 text-xs"
            :value="answerFor(item.key)"
            @change="setAnswer(item.key, $event.target.value)"
          >
            <option value="">
              {{ item.fix === 'select' ? t('CHOOSE') : t('USE_OTHER') }}
            </option>
            <option
              v-for="opcion in item.options"
              :key="`${item.key}-${opcion}`"
              :value="opcion"
            >
              {{ opcion }}
            </option>
          </select>

          <!-- upload: el archivo con el nombre que pide el prompt -->
          <template v-if="item.fix === 'upload'">
            <label
              v-if="templateId"
              class="!mb-0 button tiny smooth"
              :class="{ disabled: uploadingKey === item.key }"
            >
              {{ t('UPLOAD') }}
              <input
                type="file"
                class="hidden"
                :disabled="uploadingKey === item.key"
                @change="upload(item, $event)"
              />
            </label>
            <span v-else class="text-xs text-slate-500 dark:text-slate-400">
              {{ t('UPLOAD_NEEDS_SAVE') }}
            </span>
          </template>

          <!-- link: se configura en otra pantalla, en otra pestaña del navegador -->
          <a
            v-if="item.link"
            :href="linkHref(item)"
            target="_blank"
            rel="noopener noreferrer"
            class="text-xs underline text-woot-600 dark:text-woot-400"
            :title="t('LINK_HINT')"
          >
            {{ linkLabel(item) }}
          </a>
        </div>
      </div>
    </section>

    <!-- F7: ¿el texto trae datos de otro negocio? El modelo propone; tú eliges. -->
    <section
      v-if="draft.trim()"
      class="p-3 mb-4 border rounded-md border-slate-100 dark:border-slate-700"
    >
      <h4
        class="mb-1 text-xs font-semibold tracking-wide uppercase text-slate-600 dark:text-slate-300"
      >
        {{ t('SUGGEST_TITLE') }}
      </h4>
      <p class="mb-2 text-xs text-slate-500 dark:text-slate-400">
        {{ t('SUGGEST_HELP') }}
      </p>
      <woot-button
        v-if="suggestions === null"
        size="small"
        variant="smooth"
        icon="search"
        :is-loading="isSuggesting"
        @click="suggest"
      >
        {{ t('SUGGEST_BUTTON') }}
      </woot-button>
      <template v-else>
        <p
          v-if="!suggestions.length"
          class="mb-0 text-xs text-slate-500 dark:text-slate-400"
        >
          {{ t('SUGGEST_NONE') }}
        </p>
        <label
          v-for="sugerencia in suggestions"
          :key="sugerencia.text"
          class="flex flex-wrap items-center gap-2 !mb-1 text-xs"
        >
          <input
            v-model="chosenSuggestions"
            type="checkbox"
            class="!mb-0"
            :value="sugerencia.text"
          />
          <span class="font-mono break-all text-slate-800 dark:text-slate-100">
            {{ sugerencia.text }}
          </span>
          <span class="text-slate-500 dark:text-slate-400">
            {{ t('PLACES', { count: sugerencia.count }) }}
          </span>
          <input
            v-model="sugerencia.label"
            type="text"
            class="flex-1 min-w-[8rem] !mb-0 !py-1 text-xs"
            maxlength="60"
          />
        </label>
        <woot-button
          v-if="suggestions.length"
          class="mt-2"
          size="small"
          :is-disabled="!chosenSuggestions.length"
          :is-loading="isMarking"
          @click="markVariables"
        >
          {{ t('MARK_BUTTON', { count: chosenSuggestions.length }) }}
        </woot-button>
      </template>
    </section>

    <div v-if="ready.length" class="mb-4">
      <button
        type="button"
        class="text-xs text-slate-500 dark:text-slate-400"
        @click="showOk = !showOk"
      >
        {{ okToggleLabel }}
      </button>
      <ul v-if="showOk" class="mt-1 ml-4 list-none">
        <li
          v-for="item in ready"
          :key="item.key"
          class="font-mono text-xs text-slate-600 dark:text-slate-300"
        >
          {{ readyLabel(item) }}
        </li>
      </ul>
    </div>

    <div
      v-if="draft.trim()"
      class="flex flex-wrap items-center justify-between gap-2 pt-2 mt-auto"
    >
      <woot-button
        variant="clear"
        size="small"
        color-scheme="secondary"
        icon="arrow-clockwise"
        :is-loading="loading"
        @click="refresh"
      >
        {{ t('RECHECK') }}
      </woot-button>
      <woot-button
        size="small"
        :is-disabled="!canApply"
        :is-loading="isApplying"
        @click="apply"
      >
        {{ t('APPLY') }}
      </woot-button>
    </div>

    <AddSourceModal
      :show="!!creatingSource"
      :saving="savingSource"
      :initial="creatingSource ? creatingSource.create : null"
      @close="creatingSource = null"
      @save="createSource"
    />
  </div>
</template>
