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
//
// feat/configurar_siempre: lo que ya existe (✔) sale junto a lo que falta y también se
// puede cambiar por otra fuente de la cuenta o por una nueva creada aquí. La búsqueda de
// datos de otro negocio corre sola al abrir la pestaña; se recuerda por texto, así que
// solo vuelve a llamar a la IA si el Entrenamiento cambió desde la última búsqueda.
//
// feat/reemplazo_directo_variables: a cada dato que señala la IA se le escribe al lado
// el valor propio y «Reemplazar» lo cambia en el texto en un solo paso (sin pasar por
// <PENDIENTE:>). Lo reemplazado se recuerda en el agente —o en la conversación si aún
// no hay agente— y sale en «Datos de tu negocio» con «Ahora dice: …» para cambiarlo.
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

// La pestaña se destruye al cambiar a otra; la última búsqueda con IA queda aquí para no
// repetirla con el mismo texto.
const suggestionCache = { text: null, variables: [] };

export default {
  components: { AddSourceModal },
  props: {
    items: { type: Array, default: () => [] },
    draft: { type: String, default: '' },
    templateId: { type: Number, default: null },
    sessionId: { type: [Number, String], default: null },
    loading: { type: Boolean, default: false },
  },
  data() {
    return {
      answers: {},
      isApplying: false,
      creatingSource: null,
      savingSource: false,
      uploadingKey: null,
      // F7: lo que el modelo señaló como datos de un negocio (null = no se ha buscado),
      // cada uno con el `value` propio que se escribe al lado.
      suggestions: null,
      // Con qué texto se buscó (para ofrecer «Buscar otra vez» si cambió).
      suggestedFor: null,
      suggestError: null,
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
    // En cada grupo, primero lo que falta y luego lo que ya existe.
    groups() {
      return GROUPS.map(group => ({
        group,
        items: [
          ...this.missing.filter(item => item.group === group),
          ...this.ready.filter(item => item.group === group),
        ],
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
    // Lo que ya existe se crea en blanco: el nombre actual ya está tomado.
    creatingInitial() {
      const item = this.creatingSource;
      if (!item) return null;
      return this.isOk(item) ? { ...item.create, name: '' } : item.create;
    },
    // Solo las que tienen valor: una caja vacía deja ese texto como estaba.
    filledSuggestions() {
      return (this.suggestions || []).filter(v => String(v.value || '').trim());
    },
    // Qué va a cambiar «Reemplazar»: los usuarios creían que se cambiaba todo lo listado.
    replaceNote() {
      if (!this.filledSuggestions.length) return this.t('REPLACE_NOTE_NONE');
      const lista = this.filledSuggestions.map(v => `«${v.text}»`).join(', ');
      return this.t('REPLACE_NOTE', { list: lista });
    },
    canSearchAgain() {
      return (
        this.suggestions !== null &&
        !this.isSuggesting &&
        this.suggestedFor !== this.draft
      );
    },
  },
  watch: {
    // Lo que ya no falta (se aplicó o se creó) deja de ocupar su respuesta. F6: lo que se
    // configuró antes en este agente (versión nueva del autor) sale prellenado.
    items: {
      immediate: true,
      handler(lista) {
        const faltan = lista.filter(i => i.status === 'missing');
        const vigentes = new Set(lista.map(i => i.key));
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
  mounted() {
    this.autoSuggest();
  },
  methods: {
    t(key, args) {
      return this.$t(`TRACKING_ASSISTANT_VIEW.CONFIGURE.${key}`, args);
    },
    places(count) {
      return count === 1 ? this.t('PLACE_ONE') : this.t('PLACES', { count });
    },
    kindLabel(item) {
      return this.t(`KIND.${item.kind.toUpperCase()}`);
    },
    // Lo que se ve de cada cosa: el nombre del dato o la directiva tal como está escrita.
    title(item) {
      if (item.kind === 'variable') return item.name;
      return item.wrote || item.name || this.kindLabel(item);
    },
    isOk(item) {
      return item.status === 'ok';
    },
    valuePlaceholder(item) {
      return item.current
        ? this.t('NEW_VALUE_PLACEHOLDER')
        : this.t('VALUE_PLACEHOLDER');
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
    // Para lo que ya existe no se ofrece el mismo nombre: cambiarlo por sí mismo no hace nada.
    optionsFor(item) {
      const opciones = Array.isArray(item.options) ? item.options : [];
      if (!this.isOk(item)) return opciones;
      const actual = String(item.name || '').toLowerCase();
      return opciones.filter(opcion => opcion.toLowerCase() !== actual);
    },
    hasOptions(item) {
      return this.optionsFor(item).length > 0;
    },
    selectPlaceholder(item) {
      if (this.isOk(item)) return this.t('CHANGE_TO');
      return item.fix === 'select' ? this.t('CHOOSE') : this.t('USE_OTHER');
    },
    createLabel(item) {
      if (this.isOk(item)) return this.t('CREATE_OTHER');
      return this.t('CREATE_SOURCE', { name: item.name });
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
    // Si reemplaza a una que ya existía, la nueva queda elegida para «Aplicar».
    async createSource(payload) {
      const item = this.creatingSource;
      this.savingSource = true;
      try {
        await KnowledgeBaseAPI.createSource(this.accountId, payload);
        this.creatingSource = null;
        if (item && this.isOk(item)) {
          this.setAnswer(item.key, payload.name);
          useAlert(this.t('SOURCE_ADDED_CHANGE', { name: payload.name }));
        } else {
          useAlert(this.t('SOURCE_ADDED'));
        }
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
          this.templateId,
          this.sessionId
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
    // ── F7: el modelo propone datos de un negocio; se reemplazan por los tuyos ──
    // Al abrir la pestaña: lo ya buscado con este mismo texto se reusa sin llamar a la IA.
    autoSuggest() {
      if (!this.draft.trim()) return;
      if (suggestionCache.text === this.draft) {
        this.showSuggestions(suggestionCache.variables, this.draft);
        return;
      }
      this.suggest();
    },
    async suggest() {
      const texto = this.draft;
      this.isSuggesting = true;
      this.suggestError = null;
      try {
        const { data } = await AssistantAPI.suggestVariables(
          texto,
          this.templateId,
          this.sessionId
        );
        if (data.error) {
          this.suggestError = `SUGGEST_ERROR_${data.error.toUpperCase()}`;
          return;
        }
        const variables = data.variables || [];
        suggestionCache.text = texto;
        suggestionCache.variables = variables;
        this.showSuggestions(variables, texto);
      } catch (error) {
        this.suggestError = 'SUGGEST_ERROR_FAILED';
      } finally {
        this.isSuggesting = false;
      }
    },
    showSuggestions(variables, texto) {
      this.suggestions = variables.map(v => ({ ...v, value: '' }));
      this.suggestedFor = texto;
    },
    async markVariables() {
      const elegidas = this.filledSuggestions.map(v => ({
        text: v.text,
        label: v.label,
        value: v.value.trim(),
      }));
      if (!elegidas.length) return;
      this.isMarking = true;
      try {
        const { data } = await AssistantAPI.markVariables(
          this.draft,
          elegidas,
          this.templateId,
          this.sessionId
        );
        const notas = elegidas.map(v => `${v.text} → ${v.value}`);
        this.$emit('applied', { ...data, notes: notas });
        useAlert(this.t('MARKED', { count: elegidas.length }));
        this.suggestions = null;
        suggestionCache.text = null;
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
    <p class="mb-3 text-sm text-slate-600 dark:text-slate-300">
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
      <h4 class="mb-2 text-sm font-semibold text-slate-600 dark:text-slate-300">
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
              {{ places(item.occurrences) }}
            </span>
            <span v-if="isOk(item)" class="text-green-700 dark:text-green-400">
              {{ t('OK_BADGE') }}
            </span>
          </span>
          <span
            class="font-mono text-xs break-all text-slate-800 dark:text-slate-100"
          >
            {{ title(item) }}
          </span>
          <span
            v-if="item.current"
            class="block text-xs break-all text-slate-600 dark:text-slate-300"
          >
            {{ t('CURRENT_VALUE', { value: item.current }) }}
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
            :placeholder="valuePlaceholder(item)"
            @input="setAnswer(item.key, $event.target.value)"
          />

          <!-- create_inline: crear la fuente ahí mismo (o una nueva en lugar de la que ya existe) -->
          <woot-button
            v-if="isSource(item)"
            size="tiny"
            variant="smooth"
            icon="add"
            @click="creatingSource = item"
          >
            {{ createLabel(item) }}
          </woot-button>

          <!-- create_inline / select: usar otra que ya existe en la cuenta -->
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
              {{ selectPlaceholder(item) }}
            </option>
            <option
              v-for="opcion in optionsFor(item)"
              :key="`${item.key}-${opcion}`"
              :value="opcion"
            >
              {{ opcion }}
            </option>
          </select>

          <!-- upload: el archivo con el nombre que pide el prompt -->
          <template v-if="item.fix === 'upload' && !isOk(item)">
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
      <h4 class="mb-1 text-sm font-semibold text-slate-600 dark:text-slate-300">
        {{ t('SUGGEST_TITLE') }}
      </h4>
      <p class="mb-2 text-sm text-slate-600 dark:text-slate-300">
        {{ t('SUGGEST_HELP') }}
      </p>
      <p
        v-if="isSuggesting"
        class="mb-0 text-sm text-slate-600 dark:text-slate-300"
      >
        {{ t('SUGGEST_RUNNING') }}
      </p>
      <p
        v-else-if="suggestError"
        class="mb-2 text-xs text-amber-800 dark:text-amber-400"
      >
        {{ t(suggestError) }}
      </p>
      <woot-button
        v-if="!isSuggesting && (suggestions === null || canSearchAgain)"
        size="small"
        variant="smooth"
        icon="search"
        :class="{ 'mb-2': suggestions !== null }"
        @click="suggest"
      >
        {{ suggestions === null ? t('SUGGEST_BUTTON') : t('SUGGEST_AGAIN') }}
      </woot-button>
      <template v-if="suggestions !== null && !isSuggesting">
        <p
          v-if="!suggestions.length"
          class="mb-0 text-sm text-slate-600 dark:text-slate-300"
        >
          {{ t('SUGGEST_NONE') }}
        </p>
        <div
          v-for="sugerencia in suggestions"
          :key="sugerencia.text"
          class="flex flex-wrap items-center gap-2 py-2 text-xs border-b border-slate-100 dark:border-slate-700"
        >
          <div class="flex-1 min-w-[10rem]">
            <span
              class="font-mono break-all text-slate-800 dark:text-slate-100"
            >
              {{ sugerencia.text }}
            </span>
            <span class="text-slate-500 dark:text-slate-400">
              {{ places(sugerencia.count) }}
            </span>
            <span class="block text-slate-500 dark:text-slate-400">
              {{ sugerencia.label }}
            </span>
          </div>
          <label
            class="flex items-center flex-1 min-w-[14rem] gap-2 !mb-0 text-xs"
          >
            <span class="text-slate-600 dark:text-slate-300">
              {{ t('REPLACE_WITH') }}
            </span>
            <input
              v-model="sugerencia.value"
              type="text"
              class="flex-1 !mb-0 !py-1 text-xs"
              :placeholder="t('REPLACE_PLACEHOLDER')"
              maxlength="500"
            />
          </label>
        </div>
        <p
          v-if="suggestions.length"
          class="mt-2 mb-0 text-xs text-slate-600 dark:text-slate-300"
        >
          {{ replaceNote }}
        </p>
        <woot-button
          v-if="suggestions.length"
          class="mt-2"
          size="small"
          :is-disabled="!filledSuggestions.length"
          :is-loading="isMarking"
          @click="markVariables"
        >
          {{ t('MARK_BUTTON', { count: filledSuggestions.length }) }}
        </woot-button>
      </template>
    </section>

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
      :initial="creatingInitial"
      @close="creatingSource = null"
      @save="createSource"
    />
  </div>
</template>
