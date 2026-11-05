<script>
// proyecto@respuestas_predefinidas R3 — LAS CATEGORÍAS
// ============================================================================
// Plan: docs/respuestas_predefinidas_plan.md §2. Crear, renombrar y borrar categorías
// (borrar deja sus respuestas sin categoría), y las SUGERIDAS por el principio de los
// nombres (D3): «PATITAS (14 respuestas · la usa 1 agente) [Crear y asignar]». Nada se
// mueve solo: la persona acepta cada una.
//
// El nombre es el que se escribe en @buscar_predefinidas(NOMBRE): sin paréntesis y sin
// «!» al principio (lo valida también el servidor).
// ============================================================================
import CategoryAPI from 'dashboard/api/cannedResponseCategory';
import { useAlert } from 'dashboard/composables';

const INVALID_NAME = /[()]|^!/;

export default {
  props: {
    show: { type: Boolean, default: false },
  },
  emits: ['close', 'changed'],
  data() {
    return {
      categories: [],
      suggestions: [],
      newName: '',
      editingId: null,
      editingName: '',
      confirmingId: null,
      busy: false,
    };
  },
  computed: {
    newNameInvalid() {
      return INVALID_NAME.test(this.newName.trim());
    },
  },
  watch: {
    show(abierto) {
      if (abierto) this.load();
    },
  },
  methods: {
    close() {
      this.editingId = null;
      this.confirmingId = null;
      this.$emit('close');
    },
    async load() {
      try {
        const [lista, sugeridas] = await Promise.all([
          CategoryAPI.get(),
          CategoryAPI.suggestions(),
        ]);
        this.categories = lista.data || [];
        this.suggestions = sugeridas.data || [];
      } catch (error) {
        useAlert(this.$t('CANNED_MGMT.CATEGORIES.LOAD_ERROR'));
      }
    },
    async run(accion) {
      this.busy = true;
      try {
        await accion();
        await this.load();
        this.$emit('changed');
      } catch (error) {
        useAlert(this.$t('CANNED_MGMT.CATEGORIES.SAVE_ERROR'));
      } finally {
        this.busy = false;
      }
    },
    create() {
      const nombre = this.newName.trim();
      if (!nombre || this.newNameInvalid) return;
      this.run(async () => {
        await CategoryAPI.create({
          canned_response_category: { name: nombre },
        });
        this.newName = '';
      });
    },
    startEdit(categoria) {
      this.editingId = categoria.id;
      this.editingName = categoria.name;
    },
    saveEdit() {
      const nombre = this.editingName.trim();
      if (!nombre || INVALID_NAME.test(nombre)) return;
      const id = this.editingId;
      this.run(async () => {
        await CategoryAPI.update(id, {
          canned_response_category: { name: nombre },
        });
        this.editingId = null;
      });
    },
    remove(categoria) {
      this.confirmingId = null;
      this.run(() => CategoryAPI.delete(categoria.id));
    },
    accept(sugerida) {
      this.run(() =>
        CategoryAPI.createWith(sugerida.name, sugerida.canned_ids)
      );
    },
  },
};
</script>

<template>
  <!-- Molde nativo (settings/agents/AddAgent.vue): encabezado del modal y un form sin
       relleno propio (Modal.vue ya se lo pone). -->
  <woot-modal :show="show" size="medium" :on-close="close">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="$t('CANNED_MGMT.CATEGORIES.TITLE')"
        :header-content="$t('CANNED_MGMT.CATEGORIES.HINT')"
      />
      <form
        class="flex flex-col items-start w-full gap-6"
        @submit.prevent="create"
      >
        <!-- Nueva categoría -->
        <div class="w-full">
          <label :class="{ error: newNameInvalid }">
            {{ $t('CANNED_MGMT.CATEGORIES.NEW_LABEL') }}
            <div class="flex items-center gap-2">
              <input
                v-model="newName"
                type="text"
                class="flex-1 !mb-0"
                :placeholder="$t('CANNED_MGMT.CATEGORIES.NEW_PLACEHOLDER')"
              />
              <woot-button
                icon="add"
                :is-disabled="!newName.trim() || newNameInvalid || busy"
              >
                {{ $t('CANNED_MGMT.CATEGORIES.ADD') }}
              </woot-button>
            </div>
            <span v-if="newNameInvalid" class="message">
              {{ $t('CANNED_MGMT.CATEGORIES.INVALID_NAME') }}
            </span>
          </label>
        </div>

        <!-- Tus categorías -->
        <section class="flex flex-col w-full gap-2">
          <h3
            class="!m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
          >
            {{
              $t('CANNED_MGMT.CATEGORIES.YOURS', { count: categories.length })
            }}
          </h3>
          <div
            v-if="!categories.length"
            class="flex items-center gap-2 px-4 py-3 text-sm border border-dashed rounded-lg border-slate-200 dark:border-slate-700 text-slate-500 dark:text-slate-400"
          >
            <fluent-icon icon="folder" size="16" />
            {{ $t('CANNED_MGMT.CATEGORIES.EMPTY') }}
          </div>
          <ul
            v-else
            class="!m-0 !p-0 list-none border rounded-lg divide-y border-slate-100 dark:border-slate-700 divide-slate-100 dark:divide-slate-700"
          >
            <li
              v-for="categoria in categories"
              :key="categoria.id"
              class="flex items-center gap-3 px-4 py-2.5"
              @mouseleave="confirmingId = null"
            >
              <template v-if="editingId === categoria.id">
                <input
                  v-model="editingName"
                  type="text"
                  class="flex-1 !mb-0"
                  @keydown.enter.prevent="saveEdit"
                  @keydown.esc.stop.prevent="editingId = null"
                />
                <woot-button
                  type="button"
                  size="small"
                  :is-disabled="busy"
                  @click="saveEdit"
                >
                  {{ $t('CANNED_MGMT.CATEGORIES.SAVE') }}
                </woot-button>
                <woot-button
                  type="button"
                  size="small"
                  variant="clear"
                  color-scheme="secondary"
                  @click="editingId = null"
                >
                  {{ $t('CANNED_MGMT.CATEGORIES.CANCEL') }}
                </woot-button>
              </template>
              <template v-else>
                <fluent-icon
                  icon="folder"
                  size="16"
                  class="shrink-0 text-slate-400"
                />
                <span
                  class="flex-1 min-w-0 font-medium truncate text-slate-800 dark:text-slate-100"
                >
                  {{ categoria.name }}
                </span>
                <span
                  class="px-2 py-0.5 text-xs rounded-full bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300"
                >
                  {{
                    $t('CANNED_MGMT.CATEGORIES.COUNT', {
                      count: categoria.canned_count,
                    })
                  }}
                </span>
                <span
                  v-if="confirmingId === categoria.id"
                  class="text-xs text-slate-500 dark:text-slate-400"
                >
                  {{ $t('CANNED_MGMT.CATEGORIES.DELETE_HINT') }}
                </span>
                <div class="flex items-center gap-1 shrink-0">
                  <woot-button
                    v-tooltip.top="$t('CANNED_MGMT.CATEGORIES.RENAME')"
                    type="button"
                    size="tiny"
                    variant="smooth"
                    color-scheme="secondary"
                    icon="edit"
                    @click="startEdit(categoria)"
                  />
                  <woot-button
                    v-if="confirmingId !== categoria.id"
                    v-tooltip.top="$t('CANNED_MGMT.CATEGORIES.DELETE')"
                    type="button"
                    size="tiny"
                    variant="smooth"
                    color-scheme="alert"
                    icon="dismiss-circle"
                    @click="confirmingId = categoria.id"
                  />
                  <woot-button
                    v-else
                    type="button"
                    size="tiny"
                    color-scheme="alert"
                    :is-disabled="busy"
                    @click="remove(categoria)"
                  >
                    {{ $t('CANNED_MGMT.CATEGORIES.DELETE_CONFIRM') }}
                  </woot-button>
                </div>
              </template>
            </li>
          </ul>
        </section>

        <!-- Sugeridas por los nombres (D3) -->
        <section
          v-if="suggestions.length"
          class="flex flex-col w-full gap-3 p-4 border rounded-lg bg-woot-25 border-woot-100 dark:bg-woot-900/20 dark:border-woot-800"
        >
          <div>
            <h3
              class="!m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
            >
              {{ $t('CANNED_MGMT.CATEGORIES.SUGGESTED') }}
            </h3>
            <p class="!m-0 mt-1 text-xs text-slate-600 dark:text-slate-300">
              {{ $t('CANNED_MGMT.CATEGORIES.SUGGESTED_HINT') }}
            </p>
          </div>
          <div
            v-for="sugerida in suggestions"
            :key="sugerida.name"
            class="flex items-center gap-3 px-3 py-2 bg-white rounded-md dark:bg-slate-800"
          >
            <fluent-icon icon="wand" size="16" class="shrink-0 text-woot-500" />
            <span class="font-medium text-slate-800 dark:text-slate-100">
              {{ sugerida.name }}
            </span>
            <span
              class="px-2 py-0.5 text-xs rounded-full bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300"
            >
              {{
                $t('CANNED_MGMT.CATEGORIES.SUGGESTED_COUNT', {
                  count: sugerida.count,
                })
              }}
            </span>
            <span
              v-if="sugerida.agents"
              class="px-2 py-0.5 text-xs rounded-full bg-woot-50 text-woot-700 dark:bg-woot-800 dark:text-woot-100"
            >
              {{
                $t('CANNED_MGMT.CATEGORIES.SUGGESTED_AGENTS', {
                  count: sugerida.agents,
                })
              }}
            </span>
            <span class="flex-1" />
            <woot-button
              type="button"
              size="small"
              variant="smooth"
              icon="add"
              :is-disabled="busy"
              @click="accept(sugerida)"
            >
              {{ $t('CANNED_MGMT.CATEGORIES.ACCEPT') }}
            </woot-button>
          </div>
        </section>

        <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
          <button class="button clear" @click.prevent="close">
            {{ $t('CANNED_MGMT.CATEGORIES.CLOSE') }}
          </button>
        </div>
      </form>
    </div>
  </woot-modal>
</template>
