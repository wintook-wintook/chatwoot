<!--
  Ajustes › Demostraciones (DemoKitsController): armar una demo en minutos.
  - Importar: una demo que trae Kontrolya o un archivo .json; se ve qué va a crear, se elige quién de la cuenta va en
    cada lugar (quien atiende las citas, a quien le pasa el agente) y la bandeja, y se crea todo.
  - Exportar: los agentes listos elegidos con sus bandejas, sus personas (como lugares) y las categorías del catálogo.
  - Demos importadas: abrir el chat de la página, «Limpiar lo de la demo» (pláticas, cotizaciones, citas) o «Quitar la
    demo» (y lo que creó).
-->
<script>
import { useAlert } from 'dashboard/composables';
import DemoKitsAPI from 'dashboard/api/demoKits';

const T = 'DEMO_KITS';

export default {
  name: 'DemoKits',
  data() {
    return {
      loading: true,
      kits: [],
      imports: [],
      agents: [],
      categories: [],
      users: [],
      inboxes: [],
      // Importar
      source: null, // { kit } o { data }
      preview: null,
      people: {},
      inboxChoice: {},
      importing: false,
      // Exportar
      exportName: '',
      exportAgents: [],
      exportCategories: [],
      exporting: false,
      busyId: null,
    };
  },
  computed: {
    canImport() {
      return !!this.preview && !this.importing;
    },
    canExport() {
      return this.exportAgents.length > 0 && !this.exporting;
    },
  },
  mounted() {
    this.load();
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    async load() {
      this.loading = true;
      try {
        const { data } = await DemoKitsAPI.get();
        Object.assign(this, {
          kits: data.kits,
          imports: data.imports,
          agents: data.agents,
          categories: data.categories,
          users: data.users,
          inboxes: data.inboxes,
        });
      } catch (e) {
        useAlert(this.t('LOAD_ERROR'));
      } finally {
        this.loading = false;
      }
    },
    errorOf(e, fallback) {
      return e.response?.data?.error || this.t(fallback);
    },
    // Importar ---------------------------------------------------------------
    async pickKit(key) {
      await this.loadPreview({ kit: key });
    },
    pickFile(event) {
      const [file] = event.target.files || [];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = () => {
        try {
          this.loadPreview({ data: JSON.parse(reader.result) });
        } catch (e) {
          useAlert(this.t('IMPORT.BAD_FILE'));
        }
      };
      reader.readAsText(file);
      event.target.value = '';
    },
    async loadPreview(source) {
      try {
        const { data } = await DemoKitsAPI.preview(source);
        this.source = source;
        this.preview = data;
        // Por omisión: las personas con Google conectado, en orden; bandejas de chat de la página → nueva.
        const calendar = this.users.filter(u => u.calendar);
        this.people = Object.fromEntries(
          (data.people || []).map((p, i) => [
            p.ref,
            (calendar[i] || calendar[0] || {}).id || '',
          ])
        );
        this.inboxChoice = Object.fromEntries(
          (data.inboxes || []).map(i => [
            i.ref,
            i.channel === 'web_widget' ? 'new' : '',
          ])
        );
      } catch (e) {
        useAlert(this.errorOf(e, 'IMPORT.BAD_FILE'));
      }
    },
    cancelImport() {
      this.source = null;
      this.preview = null;
    },
    async runImport() {
      this.importing = true;
      try {
        await DemoKitsAPI.import({
          ...this.source,
          people: this.people,
          inboxes: this.inboxChoice,
        });
        useAlert(this.t('IMPORT.DONE'));
        this.cancelImport();
        await this.load();
      } catch (e) {
        useAlert(this.errorOf(e, 'IMPORT.ERROR'));
      } finally {
        this.importing = false;
      }
    },
    // Exportar ---------------------------------------------------------------
    toggle(list, id) {
      const i = list.indexOf(id);
      if (i >= 0) list.splice(i, 1);
      else list.push(id);
    },
    async runExport() {
      this.exporting = true;
      try {
        const { data } = await DemoKitsAPI.export({
          name: this.exportName,
          template_ids: this.exportAgents,
          category_ids: this.exportCategories,
        });
        const url = window.URL.createObjectURL(data);
        const link = document.createElement('a');
        link.href = url;
        link.download = `demo-${(this.exportName || 'kontrolya')
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, '-')}.json`;
        link.click();
        window.URL.revokeObjectURL(url);
      } catch (e) {
        useAlert(this.t('EXPORT.ERROR'));
      } finally {
        this.exporting = false;
      }
    },
    // Demos importadas -------------------------------------------------------
    widgetUrl(row) {
      const [token] = row.website_tokens || [];
      return token ? `/widget_tests?website_token=${token}` : null;
    },
    async clean(row) {
      // eslint-disable-next-line no-alert
      if (!window.confirm(this.t('IMPORTS.CLEAN_CONFIRM', { name: row.name })))
        return;
      this.busyId = row.id;
      try {
        const { data } = await DemoKitsAPI.clean(row.id);
        useAlert(this.t('IMPORTS.CLEANED', data.cleaned));
      } catch (e) {
        useAlert(this.t('IMPORTS.ERROR'));
      } finally {
        this.busyId = null;
      }
    },
    async remove(row) {
      // eslint-disable-next-line no-alert
      if (!window.confirm(this.t('IMPORTS.REMOVE_CONFIRM', { name: row.name })))
        return;
      this.busyId = row.id;
      try {
        await DemoKitsAPI.delete(row.id);
        useAlert(this.t('IMPORTS.REMOVED'));
        await this.load();
      } catch (e) {
        useAlert(this.t('IMPORTS.ERROR'));
      } finally {
        this.busyId = null;
      }
    },
    kindLabel(kind) {
      const key = `${T}.KINDS.${kind}`;
      return this.$te(key) ? this.$t(key) : kind;
    },
  },
};
</script>

<template>
  <div class="flex-1 overflow-auto p-4">
    <div class="flex flex-col max-w-4xl gap-6 mx-auto">
      <p class="m-0 text-sm text-slate-600 dark:text-slate-300">
        {{ t('INTRO') }}
      </p>
      <p v-if="loading" class="m-0 text-sm text-slate-500">
        {{ t('LOADING') }}
      </p>

      <template v-else>
        <!-- Importar -->
        <section
          class="p-4 border rounded-lg border-slate-200 dark:border-slate-700"
          data-test="demo-import"
        >
          <h2 class="m-0 mb-1 text-base font-semibold">
            {{ t('IMPORT.TITLE') }}
          </h2>
          <p class="m-0 mb-3 text-xs text-slate-500">{{ t('IMPORT.HINT') }}</p>

          <template v-if="!preview">
            <div class="grid gap-3 sm:grid-cols-2">
              <button
                v-for="kit in kits"
                :key="kit.key"
                type="button"
                class="p-3 text-left border rounded-lg border-slate-200 hover:border-woot-500 dark:border-slate-700"
                @click="pickKit(kit.key)"
              >
                <span class="block text-sm font-semibold">{{ kit.name }}</span>
                <span class="block mt-1 text-xs text-slate-500">
                  {{ kit.description }}
                </span>
                <span class="block mt-2 text-xs text-slate-600">
                  {{
                    t('IMPORT.SUMMARY', {
                      agents: kit.summary.agents.length,
                      items: kit.summary.items,
                      inboxes: kit.summary.inboxes.length,
                    })
                  }}
                </span>
              </button>
            </div>
            <label
              class="inline-flex items-center gap-2 mt-3 text-sm cursor-pointer text-woot-600"
            >
              <fluent-icon icon="file-upload" size="16" />
              {{ t('IMPORT.FROM_FILE') }}
              <input
                type="file"
                accept=".json,application/json"
                class="hidden"
                @change="pickFile"
              />
            </label>
          </template>

          <div v-else class="flex flex-col gap-3">
            <div>
              <p class="m-0 text-sm font-semibold">{{ preview.name }}</p>
              <p v-if="preview.description" class="m-0 text-xs text-slate-500">
                {{ preview.description }}
              </p>
              <ul class="m-0 mt-2 text-sm list-disc list-inside">
                <li v-for="agent in preview.agents" :key="agent.name">
                  {{ t('IMPORT.AGENT', { name: agent.name }) }}
                  ({{ kindLabel(agent.kind) }})
                </li>
                <li>
                  {{
                    t('IMPORT.CATALOG', {
                      items: preview.items,
                      categories: preview.categories,
                    })
                  }}
                </li>
              </ul>
            </div>

            <div v-if="preview.people.length">
              <span class="field-label">{{ t('IMPORT.PEOPLE') }}</span>
              <p class="m-0 mb-1 text-xs text-slate-500">
                {{ t('IMPORT.PEOPLE_HINT') }}
              </p>
              <label
                v-for="person in preview.people"
                :key="person.ref"
                class="grid items-center grid-cols-2 gap-2 text-sm"
              >
                <span>{{ person.name }}</span>
                <select v-model="people[person.ref]" class="!mb-1">
                  <option value="">{{ t('IMPORT.NOBODY') }}</option>
                  <option v-for="u in users" :key="u.id" :value="u.id">
                    {{ u.name }}{{ u.calendar ? ' · Google' : '' }}
                  </option>
                </select>
              </label>
            </div>

            <div v-if="preview.inboxes.length">
              <span class="field-label">{{ t('IMPORT.INBOXES') }}</span>
              <label
                v-for="inbox in preview.inboxes"
                :key="inbox.ref"
                class="grid items-center grid-cols-2 gap-2 text-sm"
              >
                <span>{{ inbox.name }}</span>
                <select v-model="inboxChoice[inbox.ref]" class="!mb-1">
                  <option v-if="inbox.channel === 'web_widget'" value="new">
                    {{ t('IMPORT.NEW_WEB_INBOX') }}
                  </option>
                  <option v-else value="">
                    {{ t('IMPORT.CHOOSE_INBOX') }}
                  </option>
                  <option v-for="i in inboxes" :key="i.id" :value="i.id">
                    {{ i.name }}
                  </option>
                </select>
              </label>
            </div>

            <p class="m-0 text-xs text-slate-500">
              {{ t('IMPORT.UPDATE_HINT') }}
            </p>
            <div class="flex gap-2">
              <woot-button
                :is-loading="importing"
                :disabled="!canImport"
                @click="runImport"
              >
                {{ t('IMPORT.BUTTON') }}
              </woot-button>
              <woot-button variant="clear" @click="cancelImport">
                {{ t('CANCEL') }}
              </woot-button>
            </div>
          </div>
        </section>

        <!-- Demos importadas -->
        <section
          v-if="imports.length"
          class="p-4 border rounded-lg border-slate-200 dark:border-slate-700"
        >
          <h2 class="m-0 mb-3 text-base font-semibold">
            {{ t('IMPORTS.TITLE') }}
          </h2>
          <div
            v-for="row in imports"
            :key="row.id"
            class="flex flex-wrap items-center justify-between gap-2 py-2 border-b border-slate-100 dark:border-slate-700 last:border-0"
          >
            <div class="min-w-0">
              <span class="block text-sm font-semibold">{{ row.name }}</span>
              <span class="block text-xs text-slate-500">
                {{
                  t('IMPORTS.LINE', {
                    date: new Date(row.created_at).toLocaleString(),
                    user: row.user || '—',
                    agents: row.counts.tracking_template_ids,
                    items: row.counts.catalog_item_ids,
                  })
                }}
              </span>
            </div>
            <div class="flex flex-wrap gap-2">
              <a
                v-if="widgetUrl(row)"
                :href="widgetUrl(row)"
                target="_blank"
                rel="noopener noreferrer"
                class="text-xs text-woot-600 underline self-center"
              >
                {{ t('IMPORTS.OPEN_CHAT') }}
              </a>
              <woot-button
                size="small"
                variant="smooth"
                :is-loading="busyId === row.id"
                @click="clean(row)"
              >
                {{ t('IMPORTS.CLEAN') }}
              </woot-button>
              <woot-button
                size="small"
                variant="smooth"
                color-scheme="alert"
                :is-loading="busyId === row.id"
                @click="remove(row)"
              >
                {{ t('IMPORTS.REMOVE') }}
              </woot-button>
            </div>
          </div>
        </section>

        <!-- Exportar -->
        <section
          class="p-4 border rounded-lg border-slate-200 dark:border-slate-700"
          data-test="demo-export"
        >
          <h2 class="m-0 mb-1 text-base font-semibold">
            {{ t('EXPORT.TITLE') }}
          </h2>
          <p class="m-0 mb-3 text-xs text-slate-500">{{ t('EXPORT.HINT') }}</p>
          <label class="block">
            <span class="field-label">{{ t('EXPORT.NAME') }}</span>
            <input
              v-model="exportName"
              type="text"
              :placeholder="t('EXPORT.NAME_PLACEHOLDER')"
            />
          </label>
          <div class="grid gap-4 sm:grid-cols-2">
            <div>
              <span class="field-label">{{ t('EXPORT.AGENTS') }}</span>
              <label
                v-for="agent in agents"
                :key="agent.id"
                class="flex items-center gap-2 text-sm"
              >
                <input
                  type="checkbox"
                  class="!m-0"
                  :checked="exportAgents.includes(agent.id)"
                  @change="toggle(exportAgents, agent.id)"
                />
                {{ agent.name }}
                <span class="text-xs text-slate-500">
                  {{ kindLabel(agent.kind) }}
                </span>
              </label>
            </div>
            <div>
              <span class="field-label">{{ t('EXPORT.CATEGORIES') }}</span>
              <label
                v-for="category in categories"
                :key="category.id"
                class="flex items-center gap-2 text-sm"
              >
                <input
                  type="checkbox"
                  class="!m-0"
                  :checked="exportCategories.includes(category.id)"
                  @change="toggle(exportCategories, category.id)"
                />
                {{ category.name }}
                <span class="text-xs text-slate-500"
                  >({{ category.items }})</span
                >
              </label>
            </div>
          </div>
          <p class="m-0 my-2 text-xs text-slate-500">
            {{ t('EXPORT.SAFE_HINT') }}
          </p>
          <woot-button
            :is-loading="exporting"
            :disabled="!canExport"
            icon="arrow-download"
            @click="runExport"
          >
            {{ t('EXPORT.BUTTON') }}
          </woot-button>
        </section>
      </template>
    </div>
  </div>
</template>
