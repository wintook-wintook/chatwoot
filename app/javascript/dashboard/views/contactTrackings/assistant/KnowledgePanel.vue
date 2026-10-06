<script>
// proyecto@asistente_agentes_ia — CONOCIMIENTO SUGERIDO (pestaña del modal del encargo)
// ============================================================================
// Las respuestas predefinidas que el agente necesita, propuestas desde el encargo
// (KnowledgeSuggestions): los datos del negocio que ya se leyeron y lo que las rutas
// prometen buscar y nadie cargó. Se revisan, se editan y se crean las elegidas.
//
// Pedido del usuario (24/09/2026): que el prompt no cargue información que cambia.
// Creadas, la ruta busca solo en ellas (@buscar_predefinidas(GRUPO)) y, si se marca,
// los datos salen del Contexto del agente.
//
// Se piden recién al abrir la pestaña: es una llamada a OpenAI, y quien no la abre
// no la paga.
// ============================================================================
import Spinner from 'shared/components/Spinner.vue';
import AssistantAPI from 'dashboard/api/assistant';
import { creatable, itemState } from './knowledgeGroup';

export default {
  components: { Spinner },
  props: {
    briefId: { type: [Number, String], default: null },
    // La pestaña está a la vista: recién ahí se piden las sugerencias.
    active: { type: Boolean, default: false },
    // Hay un Entrenamiento en pantalla: se le puede aplicar el grupo.
    hasDraft: { type: Boolean, default: false },
  },
  emits: ['change', 'applyGroup'],
  data() {
    return {
      loading: false,
      loadedFor: null,
      error: '',
      group: '',
      items: [],
      picked: {},
      moveContext: false,
      creating: false,
      result: null,
    };
  },
  computed: {
    pickedItems() {
      return this.items.filter(i => this.picked[i.key] && creatable(i));
    },
  },
  watch: {
    active(value) {
      if (value) this.load();
    },
    briefId() {
      this.loadedFor = null;
      this.items = [];
      this.result = null;
      if (this.active) this.load();
    },
  },
  mounted() {
    if (this.active) this.load();
  },
  methods: {
    itemState,
    creatable,
    async load() {
      if (!this.briefId || this.loading || this.loadedFor === this.briefId)
        return;
      this.loading = true;
      this.error = '';
      try {
        const { data } = await AssistantAPI.knowledgeSuggestions(this.briefId);
        this.group = data.group || '';
        this.items = (data.items || []).map(i => ({ ...i }));
        // Marcadas de entrada: las listas. Lo que falta o hay que revisar, no.
        this.picked = Object.fromEntries(
          this.items.map(i => [i.key, itemState(i) === 'ready'])
        );
        this.loadedFor = this.briefId;
      } catch (error) {
        this.error = this.$t('TRACKING_ASSISTANT_VIEW.KNOWLEDGE_ERROR');
      } finally {
        this.loading = false;
      }
    },
    // El nombre sale del grupo de ARRIBA y del título: cambiar el grupo los cambia a todos.
    shortCode(item) {
      return `${this.group.trim().toUpperCase()} ${item.title}`.trim();
    },
    setContent(item, content) {
      const antes = creatable(item);
      item.content = content;
      // Al llenar el <PENDIENTE:> pasa a elegible, y se marca.
      if (!antes && creatable(item)) {
        this.picked = { ...this.picked, [item.key]: true };
      }
    },
    // «Lo revisé»: los números que no venían en las instrucciones los confirmó la persona.
    confirm(item) {
      this.$set(item, 'checkedByHand', true);
      this.picked = { ...this.picked, [item.key]: true };
    },
    toggle(item) {
      this.picked = { ...this.picked, [item.key]: !this.picked[item.key] };
    },
    async create() {
      if (!this.pickedItems.length || this.creating) return;
      this.creating = true;
      this.error = '';
      try {
        const { data } = await AssistantAPI.createKnowledge(
          this.briefId,
          this.group,
          this.pickedItems.map(i => ({
            short_code: this.shortCode(i),
            content: i.content,
          }))
        );
        this.result = data;
        const hechas = new Set([...data.created, ...data.skipped]);
        this.items = this.items.map(i =>
          hechas.has(this.shortCode(i)) ? { ...i, status: 'existing' } : i
        );
        this.$emit('change', {
          group: data.group,
          moved: this.moveContext,
          created: data.created.length,
        });
      } catch (error) {
        this.error = this.$t('TRACKING_ASSISTANT_VIEW.KNOWLEDGE_ERROR');
      } finally {
        this.creating = false;
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3 text-xs">
    <p class="!m-0 text-slate-600 dark:text-slate-300">
      {{ $t('TRACKING_ASSISTANT_VIEW.KNOWLEDGE_HINT') }}
    </p>

    <div v-if="loading" class="flex items-center gap-2 text-slate-600">
      <Spinner size="" />
      {{ $t('TRACKING_ASSISTANT_VIEW.KNOWLEDGE_LOADING') }}
    </div>
    <p v-if="error" class="!m-0 text-red-600 dark:text-red-400">{{ error }}</p>

    <template v-if="items.length">
      <label class="flex items-center gap-2 !m-0">
        <span class="font-medium text-slate-800 dark:text-slate-100">
          {{ $t('TRACKING_ASSISTANT_VIEW.KNOWLEDGE_GROUP') }}
        </span>
        <input
          v-model="group"
          type="text"
          class="!w-40 !mb-0 !py-1 font-mono text-xs uppercase"
          maxlength="20"
        />
        <span class="text-slate-500 dark:text-slate-400">
          {{
            $t('TRACKING_ASSISTANT_VIEW.KNOWLEDGE_GROUP_HINT', {
              group: group || '…',
            })
          }}
        </span>
      </label>

      <div
        v-for="item in items"
        :key="item.key"
        class="flex gap-2 p-2 border rounded-lg border-slate-100 dark:border-slate-700"
      >
        <input
          type="checkbox"
          class="!m-0 mt-1"
          :checked="Boolean(picked[item.key]) && creatable(item)"
          :disabled="!creatable(item)"
          @change="toggle(item)"
        />
        <div class="flex flex-col flex-1 min-w-0 gap-1">
          <div class="flex flex-wrap items-center gap-2">
            <span
              class="font-mono font-medium text-slate-800 dark:text-slate-100"
            >
              {{
                item.status === 'existing' ? item.short_code : shortCode(item)
              }}
            </span>
            <span
              class="px-1.5 rounded"
              :class="{
                'bg-green-50 text-green-700 dark:bg-green-900/20 dark:text-green-300':
                  itemState(item) === 'ready',
                'bg-amber-50 text-amber-800 dark:bg-amber-900/20 dark:text-amber-800':
                  itemState(item) === 'missing' ||
                  itemState(item) === 'unverified',
                'bg-slate-100 text-slate-500 dark:bg-slate-700 dark:text-slate-300':
                  itemState(item) === 'existing',
              }"
            >
              {{
                $t(
                  `TRACKING_ASSISTANT_VIEW.KNOWLEDGE_STATE_${itemState(
                    item
                  ).toUpperCase()}`,
                  { numbers: (item.unverified || []).join(', ') }
                )
              }}
            </span>
            <button
              v-if="itemState(item) === 'unverified'"
              type="button"
              class="underline text-woot-600 dark:text-woot-400"
              @click="confirm(item)"
            >
              {{ $t('TRACKING_ASSISTANT_VIEW.KNOWLEDGE_CONFIRM') }}
            </button>
          </div>
          <textarea
            rows="2"
            class="!mb-0 text-xs"
            :value="item.content"
            :disabled="item.status === 'existing'"
            @input="setContent(item, $event.target.value)"
          />
        </div>
      </div>

      <label class="flex items-start gap-2 !m-0 cursor-pointer">
        <input v-model="moveContext" type="checkbox" class="!m-0 mt-0.5" />
        <span class="text-slate-700 dark:text-slate-200">
          {{ $t('TRACKING_ASSISTANT_VIEW.KNOWLEDGE_MOVE_CONTEXT') }}
        </span>
      </label>

      <div class="flex flex-wrap items-center gap-2">
        <woot-button
          size="small"
          :is-loading="creating"
          :is-disabled="!pickedItems.length || creating || !group"
          @click="create"
        >
          {{
            $t('TRACKING_ASSISTANT_VIEW.KNOWLEDGE_CREATE', {
              count: pickedItems.length,
            })
          }}
        </woot-button>
        <woot-button
          v-if="result && hasDraft"
          size="small"
          variant="smooth"
          @click="$emit('applyGroup', result.group)"
        >
          {{
            $t('TRACKING_ASSISTANT_VIEW.KNOWLEDGE_APPLY', {
              group: result.group,
            })
          }}
        </woot-button>
      </div>

      <p v-if="result" class="!m-0 text-slate-600 dark:text-slate-300">
        {{
          $t('TRACKING_ASSISTANT_VIEW.KNOWLEDGE_DONE', {
            created: result.created.length,
            skipped: result.skipped.length,
            group: result.group,
          })
        }}
        <template v-if="result.failed.length">
          ·
          {{
            $t('TRACKING_ASSISTANT_VIEW.KNOWLEDGE_FAILED', {
              list: result.failed.map(f => f.short_code).join(', '),
            })
          }}
        </template>
      </p>
    </template>

    <p
      v-else-if="!loading && loadedFor"
      class="!m-0 text-slate-600 dark:text-slate-300"
    >
      {{ $t('TRACKING_ASSISTANT_VIEW.KNOWLEDGE_NONE') }}
    </p>
  </div>
</template>
