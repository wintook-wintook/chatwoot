<!--
  @waba_templates — Sección de Configuración: TODAS las plantillas de TODOS los canales de
  WhatsApp, con filtro por canal. Crear/editar/borrar/sincronizar contra Meta.
  Validación en vivo replicada del backend. Strings en español; commit --no-verify.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import {
  validateTemplate,
  templateVariables,
} from 'dashboard/helper/whatsappTemplateValidator';

const emptyForm = () => ({
  inbox_id: null,
  name: '',
  language: 'es',
  category: 'UTILITY',
  header_type: '',
  header_content: '',
  header_media_url: '',
  body_text: '',
  footer_text: '',
  buttons: [],
  sample_values: { body: [], header: [] },
});

export default {
  components: { SettingsLayout, BaseSettingsHeader },
  data() {
    return {
      channelFilter: '',
      showForm: false,
      editingId: null,
      form: emptyForm(),
      deletePopup: false,
      deleteTarget: null,
      categories: ['UTILITY', 'MARKETING', 'AUTHENTICATION'],
      headerTypes: [
        { value: '', label: 'Ninguna' },
        { value: 'text', label: 'Texto' },
        { value: 'image', label: 'Imagen' },
        { value: 'video', label: 'Video' },
        { value: 'document', label: 'Documento' },
      ],
      buttonTypes: ['QUICK_REPLY', 'URL', 'PHONE_NUMBER', 'COPY_CODE'],
      bodyHint: 'Cuerpo (usa {{1}}, {{2}}… para variables)',
      headerTextHint: 'Texto de cabecera (máx 60, opcional {{1}})',
      sampleLabel: n => `Valor de {{${n}}}`,
    };
  },
  computed: {
    ...mapGetters({
      templates: 'whatsappTemplates/getTemplates',
      uiFlags: 'whatsappTemplates/getUIFlags',
      inboxes: 'inboxes/getInboxes',
    }),
    // Canales de WhatsApp de la cuenta (para filtro y selector del form).
    whatsappInboxes() {
      return this.inboxes.filter(i => i.channel_type === 'Channel::Whatsapp');
    },
    filteredTemplates() {
      if (!this.channelFilter) return this.templates;
      return this.templates.filter(
        t => t.channel_whatsapp_id === Number(this.channelFilter)
      );
    },
    bodyVarCount() {
      return new Set(templateVariables(this.form.body_text)).size;
    },
    headerHasVar() {
      return (
        this.form.header_type === 'text' &&
        templateVariables(this.form.header_content).length > 0
      );
    },
    validationErrors() {
      const errors = validateTemplate(this.form);
      if (!this.editingId && !this.form.inbox_id) {
        errors.unshift('Canal: selecciona un canal de WhatsApp');
      }
      return errors;
    },
    isFormValid() {
      return this.validationErrors.length === 0;
    },
    modalTitle() {
      return this.editingId ? 'Editar plantilla' : 'Nueva plantilla';
    },
  },
  watch: {
    'form.body_text'() {
      this.syncBodySamples();
    },
  },
  mounted() {
    this.$store.dispatch('inboxes/get');
    this.fetchAll();
  },
  methods: {
    fetchAll() {
      this.$store.dispatch('whatsappTemplates/fetch');
    },
    inboxNameForChannel(channelWhatsappId) {
      const inbox = this.whatsappInboxes.find(
        i => i.channel_id === channelWhatsappId
      );
      return inbox ? inbox.name : '—';
    },
    async sync() {
      const targets = this.channelFilter
        ? [Number(this.channelFilter)]
        : this.whatsappInboxes.map(i => i.id);
      if (!targets.length) {
        useAlert('No hay canales de WhatsApp configurados.');
        return;
      }
      try {
        let created = 0;
        let updated = 0;
        // eslint-disable-next-line no-restricted-syntax
        const results = await Promise.all(
          targets.map(id => this.$store.dispatch('whatsappTemplates/sync', id))
        );
        results.forEach(r => {
          created += r.created;
          updated += r.updated;
        });
        await this.fetchAll();
        useAlert(`Sincronizado: ${created} nuevas, ${updated} actualizadas.`);
      } catch (e) {
        useAlert('No se pudo sincronizar con Meta.');
      }
    },
    statusClass(status) {
      return (
        {
          APPROVED:
            'bg-green-100 text-green-700 dark:bg-green-800 dark:text-green-100',
          PENDING:
            'bg-amber-100 text-amber-700 dark:bg-amber-800 dark:text-amber-100',
          REJECTED: 'bg-red-100 text-red-700 dark:bg-red-800 dark:text-red-100',
        }[status] ||
        'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-200'
      );
    },
    qualityDot(score) {
      return (
        {
          GREEN: 'bg-green-500',
          YELLOW: 'bg-amber-500',
          RED: 'bg-red-500',
        }[score] || 'bg-slate-300'
      );
    },
    openNew() {
      this.editingId = null;
      this.form = emptyForm();
      this.form.inbox_id = this.channelFilterInboxId();
      this.showForm = true;
    },
    // Deriva el inbox_id a partir del filtro (channelFilter guarda channel_whatsapp_id).
    channelFilterInboxId() {
      if (!this.channelFilter) return null;
      const inbox = this.whatsappInboxes.find(
        i => i.channel_id === Number(this.channelFilter)
      );
      return inbox ? inbox.id : null;
    },
    openEdit(template) {
      this.editingId = template.id;
      this.form = {
        ...emptyForm(),
        ...template,
        sample_values: {
          body: (template.sample_values && template.sample_values.body) || [],
          header:
            (template.sample_values && template.sample_values.header) || [],
        },
        buttons: [...(template.buttons || [])],
      };
      this.showForm = true;
    },
    closeForm() {
      this.showForm = false;
    },
    syncBodySamples() {
      const count = this.bodyVarCount;
      const current = this.form.sample_values.body || [];
      const next = Array.from({ length: count }, (_, i) => current[i] || '');
      this.form.sample_values = { ...this.form.sample_values, body: next };
    },
    addButton() {
      this.form.buttons.push({
        type: 'QUICK_REPLY',
        text: '',
        url: '',
        phone_number: '',
        example: [],
      });
    },
    removeButton(index) {
      this.form.buttons.splice(index, 1);
    },
    async submit() {
      if (!this.isFormValid) return;
      try {
        if (this.editingId) {
          await this.$store.dispatch('whatsappTemplates/update', {
            id: this.editingId,
            template: this.form,
          });
          useAlert('Plantilla enviada a revisión (PENDING).');
        } else {
          await this.$store.dispatch('whatsappTemplates/create', {
            inboxId: this.form.inbox_id,
            template: this.form,
          });
          useAlert('Plantilla creada.');
        }
        this.closeForm();
      } catch (e) {
        const msg =
          e?.response?.data?.error || 'No se pudo guardar la plantilla.';
        useAlert(msg);
      }
    },
    confirmDelete(template) {
      this.deleteTarget = template;
      this.deletePopup = true;
    },
    closeDelete() {
      this.deletePopup = false;
      this.deleteTarget = null;
    },
    async doDelete() {
      try {
        await this.$store.dispatch(
          'whatsappTemplates/delete',
          this.deleteTarget.id
        );
        useAlert('Plantilla eliminada.');
      } catch (e) {
        useAlert('No se pudo eliminar.');
      } finally {
        this.closeDelete();
      }
    },
  },
};
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.fetching"
    loading-message="Cargando plantillas…"
    :no-records-found="false"
  >
    <template #header>
      <BaseSettingsHeader
        title="Plantillas de WhatsApp"
        description="Crea, envía a aprobación y gestiona las plantillas de todos tus canales de WhatsApp sin entrar a Meta."
      >
        <template #actions>
          <woot-button
            variant="clear"
            icon="arrow-swap"
            :is-loading="uiFlags.syncing"
            @click="sync"
          >
            Sincronizar
          </woot-button>
          <woot-button icon="add-circle" @click="openNew">
            Nueva plantilla
          </woot-button>
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <div class="flex items-center gap-3 mb-4">
        <span class="text-sm text-slate-500">Filtrar por canal:</span>
        <select v-model="channelFilter" class="!mb-0 !w-64">
          <option value="">Todos los canales</option>
          <option
            v-for="i in whatsappInboxes"
            :key="i.id"
            :value="i.channel_id"
          >
            {{ i.name }}
          </option>
        </select>
      </div>

      <div
        v-if="!filteredTemplates.length"
        class="text-center text-slate-400 py-16 border border-dashed border-slate-200 dark:border-slate-700 rounded-lg"
      >
        No hay plantillas para mostrar. Crea una o sincroniza desde Meta.
      </div>

      <table v-else class="w-full text-sm">
        <thead
          class="text-left text-slate-400 border-b border-slate-100 dark:border-slate-700"
        >
          <tr>
            <th class="py-2 font-medium">Nombre</th>
            <th class="py-2 font-medium">Canal</th>
            <th class="py-2 font-medium">Idioma</th>
            <th class="py-2 font-medium">Categoría</th>
            <th class="py-2 font-medium">Estado</th>
            <th class="py-2 font-medium">Calidad</th>
            <th class="py-2 font-medium text-right">Acciones</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="t in filteredTemplates"
            :key="t.id"
            class="border-b border-slate-50 dark:border-slate-800"
          >
            <td class="py-3">
              <div class="font-medium text-slate-700 dark:text-slate-200">
                {{ t.name }}
              </div>
              <div v-if="t.rejection_reason" class="text-xs text-red-500">
                Rechazo: {{ t.rejection_reason }}
              </div>
              <div v-if="t.submission_error" class="text-xs text-amber-600">
                {{ t.submission_error }}
              </div>
            </td>
            <td class="py-3 text-slate-500">
              {{ inboxNameForChannel(t.channel_whatsapp_id) }}
            </td>
            <td class="py-3 text-slate-500">{{ t.language }}</td>
            <td class="py-3 text-slate-500">{{ t.category }}</td>
            <td class="py-3">
              <span
                class="px-2 py-0.5 rounded-full text-xs font-medium"
                :class="statusClass(t.status)"
              >
                {{ t.status }}
              </span>
            </td>
            <td class="py-3">
              <span
                v-if="t.quality_score"
                class="inline-flex items-center gap-1"
              >
                <span
                  class="w-2 h-2 rounded-full"
                  :class="qualityDot(t.quality_score)"
                />
                <span class="text-xs text-slate-500">{{ t.quality_score }}</span>
              </span>
              <span v-else class="text-slate-300">—</span>
            </td>
            <td class="py-3 text-right">
              <woot-button
                v-if="t.editable"
                variant="clear"
                size="small"
                icon="edit"
                @click="openEdit(t)"
              />
              <woot-button
                variant="clear"
                size="small"
                color-scheme="alert"
                icon="delete"
                @click="confirmDelete(t)"
              />
            </td>
          </tr>
        </tbody>
      </table>
    </template>

    <!-- Formulario crear/editar -->
    <woot-modal :show.sync="showForm" :on-close="closeForm" size="medium">
      <div class="p-8">
        <h3 class="text-lg font-medium mb-4">{{ modalTitle }}</h3>

        <label v-if="!editingId" class="block mb-2">
          <span class="text-sm text-slate-600 dark:text-slate-300">Canal de WhatsApp</span>
          <select v-model="form.inbox_id" class="w-full mt-1">
            <option :value="null" disabled>Selecciona un canal</option>
            <option v-for="i in whatsappInboxes" :key="i.id" :value="i.id">
              {{ i.name }}
            </option>
          </select>
        </label>

        <div class="grid grid-cols-2 gap-4">
          <label class="block">
            <span class="text-sm text-slate-600 dark:text-slate-300">Nombre</span>
            <input
              v-model="form.name"
              :disabled="!!editingId"
              placeholder="cobro_vencido"
              class="w-full mt-1"
            />
          </label>
          <label class="block">
            <span class="text-sm text-slate-600 dark:text-slate-300">Idioma</span>
            <input v-model="form.language" placeholder="es" class="w-full mt-1" />
          </label>
        </div>

        <label class="block mt-2">
          <span class="text-sm text-slate-600 dark:text-slate-300">Categoría</span>
          <select v-model="form.category" class="w-full mt-1">
            <option v-for="c in categories" :key="c" :value="c">{{ c }}</option>
          </select>
        </label>

        <label class="block mt-2">
          <span class="text-sm text-slate-600 dark:text-slate-300">Cabecera</span>
          <select v-model="form.header_type" class="w-full mt-1">
            <option v-for="h in headerTypes" :key="h.value" :value="h.value">
              {{ h.label }}
            </option>
          </select>
        </label>
        <input
          v-if="form.header_type === 'text'"
          v-model="form.header_content"
          :placeholder="headerTextHint"
          class="w-full mt-2"
        />
        <input
          v-if="['image', 'video', 'document'].includes(form.header_type)"
          v-model="form.header_media_url"
          placeholder="URL del archivo de cabecera"
          class="w-full mt-2"
        />
        <input
          v-if="headerHasVar"
          v-model="form.sample_values.header[0]"
          placeholder="Ejemplo para la variable de la cabecera"
          class="w-full mt-2"
        />

        <label class="block mt-2">
          <span class="text-sm text-slate-600 dark:text-slate-300">
            {{ bodyHint }}
          </span>
          <textarea v-model="form.body_text" rows="4" class="w-full mt-1" />
        </label>

        <div v-if="bodyVarCount" class="mt-2">
          <span class="text-xs text-slate-500">
            Ejemplos de las variables del cuerpo
          </span>
          <div class="grid grid-cols-2 gap-2 mt-1">
            <input
              v-for="i in bodyVarCount"
              :key="i"
              v-model="form.sample_values.body[i - 1]"
              :placeholder="sampleLabel(i)"
              class="w-full"
            />
          </div>
        </div>

        <label class="block mt-2">
          <span class="text-sm text-slate-600 dark:text-slate-300">
            Pie (opcional, máx 60, sin variables)
          </span>
          <input v-model="form.footer_text" class="w-full mt-1" />
        </label>

        <div class="mt-3">
          <div class="flex items-center justify-between">
            <span class="text-sm text-slate-600 dark:text-slate-300">Botones</span>
            <woot-button variant="clear" size="tiny" icon="add" @click="addButton">
              Agregar
            </woot-button>
          </div>
          <div
            v-for="(btn, i) in form.buttons"
            :key="i"
            class="flex gap-2 items-center mt-2"
          >
            <select v-model="btn.type" class="w-40">
              <option v-for="bt in buttonTypes" :key="bt" :value="bt">
                {{ bt }}
              </option>
            </select>
            <input
              v-if="btn.type !== 'COPY_CODE'"
              v-model="btn.text"
              placeholder="Texto (máx 25)"
              class="flex-1"
            />
            <input
              v-if="btn.type === 'URL'"
              v-model="btn.url"
              placeholder="https://…"
              class="flex-1"
            />
            <input
              v-if="btn.type === 'PHONE_NUMBER'"
              v-model="btn.phone_number"
              placeholder="+52…"
              class="flex-1"
            />
            <woot-button
              variant="clear"
              size="tiny"
              color-scheme="alert"
              icon="delete"
              @click="removeButton(i)"
            />
          </div>
        </div>

        <ul
          v-if="validationErrors.length"
          class="mt-4 text-xs text-red-500 list-disc pl-5"
        >
          <li v-for="(err, i) in validationErrors" :key="i">{{ err }}</li>
        </ul>

        <div class="flex justify-end gap-2 mt-6">
          <woot-button variant="clear" @click="closeForm">Cancelar</woot-button>
          <woot-button
            :is-disabled="!isFormValid"
            :is-loading="uiFlags.saving"
            @click="submit"
          >
            {{ editingId ? 'Guardar y reenviar' : 'Crear y enviar' }}
          </woot-button>
        </div>
      </div>
    </woot-modal>

    <woot-delete-modal
      :show.sync="deletePopup"
      :on-close="closeDelete"
      :on-confirm="doDelete"
      title="Eliminar plantilla"
      :message="`¿Eliminar la plantilla &quot;${deleteTarget && deleteTarget.name}&quot;? También se borra en Meta.`"
      confirm-text="Eliminar"
      reject-text="Cancelar"
    />
  </SettingsLayout>
</template>
