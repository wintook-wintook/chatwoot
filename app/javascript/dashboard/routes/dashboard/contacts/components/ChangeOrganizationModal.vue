<!--
  Plan-Organizaciones — «Cambiar de organización» del contacto (solo así se cambia uno que
  ya tiene). 1) la nueva (o ninguna); 2) ¿pasar también lo suyo?; 3) si no: quién queda en
  su lugar en la anterior (obligatorio: uno de ahí o uno nuevo). Lo vivo pasa a esa persona;
  lo cerrado se queda con él como historial.
-->
<script>
import { useAlert } from 'dashboard/composables';
import OrganizationsAPI from 'dashboard/api/organizations';
import OrganizationPicker from 'dashboard/views/organizations/OrganizationPicker.vue';

const KINDS = [
  'case_tickets',
  'quotes',
  'contracts',
  'customer_assets',
  'maintenance_plans',
];

export default {
  name: 'ChangeOrganizationModal',
  components: { OrganizationPicker },
  props: {
    show: { type: Boolean, default: false },
    contact: { type: Object, required: true },
  },
  emits: ['close', 'changed'],
  data() {
    return {
      preview: null,
      target: null,
      noOrganization: false,
      move: null,
      replacementId: null,
      newContact: { name: '', email: '', phone_number: '' },
      saving: false,
    };
  },
  computed: {
    from() {
      return (this.preview && this.preview.organization) || {};
    },
    candidates() {
      return (this.preview && this.preview.candidates) || [];
    },
    // «3 oportunidades y casos, 2 cotizaciones…» (solo lo que hay).
    summary() {
      if (!this.preview) return '';
      const counts = this.preview.counts.all;
      return KINDS.filter(kind => counts[kind])
        .map(kind =>
          this.$t(`ORGANIZATIONS.CHANGE.KINDS.${kind}`, { count: counts[kind] })
        )
        .join(', ');
    },
    hasTarget() {
      return this.noOrganization || !!this.target;
    },
    sameTarget() {
      return !!this.target && this.target.id === this.from.id;
    },
    hasReplacement() {
      if (this.replacementId === 'new') return !!this.newContact.name.trim();
      return !!this.replacementId;
    },
    canSave() {
      if (!this.hasTarget || this.sameTarget || this.move === null)
        return false;
      return this.move || this.hasReplacement;
    },
  },
  watch: {
    show: {
      immediate: true,
      handler(open) {
        if (open) this.reset();
      },
    },
  },
  methods: {
    async reset() {
      Object.assign(this.$data, this.$options.data.call(this));
      try {
        const { data } = await OrganizationsAPI.changePreview(this.contact.id);
        this.preview = data;
        if (!this.candidates.length) this.replacementId = 'new';
      } catch (error) {
        useAlert(
          error?.response?.data?.error || this.$t('ORGANIZATIONS.ERROR')
        );
        this.$emit('close');
      }
    },
    chooseTarget(organization) {
      this.target = organization;
      if (organization) this.noOrganization = false;
    },
    payload() {
      const data = {
        contact_id: this.contact.id,
        to_organization_id: this.noOrganization ? null : this.target.id,
        move: this.move,
      };
      if (this.move) return data;
      if (this.replacementId === 'new') data.new_contact = this.newContact;
      else data.replacement_contact_id = this.replacementId;
      return data;
    },
    async save() {
      if (!this.canSave) return;
      this.saving = true;
      try {
        await OrganizationsAPI.changeContact(this.payload());
        useAlert(this.$t('ORGANIZATIONS.CHANGE.DONE'));
        this.$emit('changed');
      } catch (error) {
        useAlert(
          error?.response?.data?.error || this.$t('ORGANIZATIONS.ERROR')
        );
      } finally {
        this.saving = false;
      }
    },
  },
};
</script>

<template>
  <woot-modal
    :show="show"
    :on-close="() => $emit('close')"
    modal-type="right-aligned"
    size="wide"
  >
    <div class="flex flex-col h-auto">
      <woot-modal-header
        :header-title="$t('ORGANIZATIONS.CHANGE.TITLE', { name: contact.name })"
        :header-content="
          $t('ORGANIZATIONS.CHANGE.CURRENT', { name: from.name || '' })
        "
      />
      <div v-if="preview" class="flex flex-col gap-5 px-8 pt-4">
        <!-- 1. A cuál -->
        <section class="flex flex-col gap-2">
          <span class="text-sm font-medium text-slate-800 dark:text-slate-100">
            {{ $t('ORGANIZATIONS.CHANGE.STEP_TARGET') }}
          </span>
          <OrganizationPicker
            v-if="!noOrganization"
            :value="target"
            @input="chooseTarget"
          />
          <p v-if="sameTarget" class="m-0 text-xs text-red-600">
            {{ $t('ORGANIZATIONS.CHANGE.SAME') }}
          </p>
          <label class="flex items-center gap-2 mb-0 text-sm">
            <input
              v-model="noOrganization"
              type="checkbox"
              class="!m-0"
              @change="target = null"
            />
            {{ $t('ORGANIZATIONS.CHANGE.NO_ORGANIZATION') }}
          </label>
        </section>

        <!-- 2. ¿Pasar lo suyo? -->
        <section class="flex flex-col gap-2">
          <span class="text-sm font-medium text-slate-800 dark:text-slate-100">
            {{ $t('ORGANIZATIONS.CHANGE.STEP_MOVE') }}
          </span>
          <p class="m-0 text-sm text-slate-600 dark:text-slate-300">
            {{
              summary
                ? $t('ORGANIZATIONS.CHANGE.HAS', {
                    name: from.name,
                    items: summary,
                  })
                : $t('ORGANIZATIONS.CHANGE.HAS_NOTHING', { name: from.name })
            }}
          </p>
          <label
            class="flex items-start gap-2 p-3 mb-0 border rounded-md cursor-pointer"
            :class="
              move === true
                ? 'border-woot-500 bg-woot-25 dark:bg-woot-900/30'
                : 'border-slate-100 dark:border-slate-700'
            "
          >
            <input v-model="move" type="radio" :value="true" class="mt-1" />
            <span class="flex flex-col">
              <span class="text-sm font-medium">
                {{ $t('ORGANIZATIONS.CHANGE.MOVE_YES') }}
              </span>
              <span class="text-xs text-slate-500">
                {{ $t('ORGANIZATIONS.CHANGE.MOVE_YES_HINT') }}
              </span>
            </span>
          </label>
          <label
            class="flex items-start gap-2 p-3 mb-0 border rounded-md cursor-pointer"
            :class="
              move === false
                ? 'border-woot-500 bg-woot-25 dark:bg-woot-900/30'
                : 'border-slate-100 dark:border-slate-700'
            "
          >
            <input v-model="move" type="radio" :value="false" class="mt-1" />
            <span class="flex flex-col">
              <span class="text-sm font-medium">
                {{ $t('ORGANIZATIONS.CHANGE.MOVE_NO') }}
              </span>
              <span class="text-xs text-slate-500">
                {{
                  $t('ORGANIZATIONS.CHANGE.MOVE_NO_HINT', { name: from.name })
                }}
              </span>
            </span>
          </label>
        </section>

        <!-- 3. Quién queda en su lugar (obligatorio si no se lleva lo suyo) -->
        <section v-if="move === false" class="flex flex-col gap-2">
          <span class="text-sm font-medium text-slate-800 dark:text-slate-100">
            {{
              $t('ORGANIZATIONS.CHANGE.STEP_REPLACEMENT', {
                name: from.name,
                contact: contact.name,
              })
            }}
          </span>
          <select v-model="replacementId" class="!mb-0">
            <option :value="null" disabled>
              {{ $t('ORGANIZATIONS.CHANGE.CHOOSE') }}
            </option>
            <option
              v-for="candidate in candidates"
              :key="candidate.id"
              :value="candidate.id"
            >
              {{ candidate.name }}
            </option>
            <option value="new">
              {{ $t('ORGANIZATIONS.CHANGE.NEW_CONTACT') }}
            </option>
          </select>
          <div
            v-if="replacementId === 'new'"
            class="grid grid-cols-1 gap-x-4 sm:grid-cols-3"
          >
            <label>
              {{ $t('ORGANIZATIONS.CHANGE.NEW_NAME') }}
              <input v-model="newContact.name" type="text" />
            </label>
            <label>
              {{ $t('ORGANIZATIONS.CHANGE.NEW_EMAIL') }}
              <input v-model="newContact.email" type="email" />
            </label>
            <label>
              {{ $t('ORGANIZATIONS.CHANGE.NEW_PHONE') }}
              <input v-model="newContact.phone_number" type="text" />
            </label>
          </div>
          <p class="m-0 text-xs text-slate-500">
            {{ $t('ORGANIZATIONS.CHANGE.REPLACEMENT_HINT') }}
          </p>
        </section>
      </div>
      <div
        class="sticky bottom-0 z-10 flex justify-end gap-2 px-8 py-3 mt-4 bg-white border-t dark:bg-slate-800 border-slate-50 dark:border-slate-700"
      >
        <button type="button" class="button clear" @click="$emit('close')">
          {{ $t('ORGANIZATIONS.FORM.CANCEL') }}
        </button>
        <woot-button :is-loading="saving" :disabled="!canSave" @click="save">
          {{ $t('ORGANIZATIONS.CHANGE.CONFIRM') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
