<script setup>
// ================================================================================
// proyecto@user_contact
// ================================================================================
import { ref, computed } from 'vue';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'dashboard/composables/useI18n';
import { useAlert } from 'dashboard/composables';
import WootSubmitButton from 'dashboard/components/buttons/FormSubmitButton.vue';
import Auth from '../../../../api/auth';
import wootConstants from 'dashboard/constants/globals';
import ContactAPI from 'dashboard/api/contacts';

const props = defineProps({
  id: {
    type: Number,
    required: true,
  },
  name: {
    type: String,
    required: true,
  },
  email: {
    type: String,
    default: '',
  },
  type: {
    type: String,
    default: '',
  },
  availability: {
    type: String,
    default: '',
  },
  customRoleId: {
    type: Number,
    default: null,
  },
  // Plan-Roles-Permisos — supervisor, seller, technician o viewer (nil en admin).
  accessRoleKey: {
    type: String,
    default: null,
  },
  // Plan-Trabajo-Campo R3 — habilidades y zona (despacho).
  fieldProfile: {
    type: Object,
    default: () => ({}),
  },
  // proyecto@user_contact
  agentContactId: {
    type: Number,
    default: null,
  },
  agentContact: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['close']);

const { AVAILABILITY_STATUS_KEYS } = wootConstants;

const store = useStore();
const { t } = useI18n();

// proyecto@user_contact
const agentContactId = ref(props.agentContactId);
const contactSearch = ref('');
const contactResults = ref([]);
const selectedContact = ref(props.agentContact || null);
const showContactDropdown = ref(false);

const agentName = ref(props.name);
const agentAvailability = ref(props.availability);
// Plan-Roles-Permisos — un agente sin rol es Supervisor.
const ACCESS_ROLE_KEYS = ['supervisor', 'seller', 'technician', 'viewer'];
const initialRoleId = () => {
  if (props.customRoleId) return props.customRoleId;
  if (props.type === 'administrator') return 'administrator';
  return `access_${props.accessRoleKey || 'supervisor'}`;
};
const selectedRoleId = ref(initialRoleId());
const agentCredentials = ref({ email: props.email });
const skills = ref((props.fieldProfile.skills || []).join(', '));
const zone = ref(props.fieldProfile.zone || '');

const rules = {
  agentName: { required, minLength: minLength(1) },
  selectedRoleId: { required },
  agentAvailability: { required },
};

const v$ = useVuelidate(rules, {
  agentName,
  selectedRoleId,
  agentAvailability,
});

const pageTitle = computed(
  () => `${t('AGENT_MGMT.EDIT.TITLE')} - ${props.name}`
);

const onContactSearch = async () => {
  if (contactSearch.value.length < 2) {
    contactResults.value = [];
    showContactDropdown.value = false;
    return;
  }
  try {
    const response = await ContactAPI.search(contactSearch.value, 1);
    contactResults.value = response.data.payload || [];
    showContactDropdown.value = contactResults.value.length > 0;
  } catch {
    contactResults.value = [];
  }
};

const selectContact = contact => {
  selectedContact.value = contact;
  agentContactId.value = contact.id;
  contactSearch.value = '';
  contactResults.value = [];
  showContactDropdown.value = false;
};

const clearContact = () => {
  selectedContact.value = null;
  agentContactId.value = null;
  contactSearch.value = '';
};

const uiFlags = useMapGetter('agents/getUIFlags');
const getCustomRoles = useMapGetter('customRole/getCustomRoles');

const roles = computed(() => {
  // Plan-Roles-Permisos — los 5 roles (Ajustes › Roles) en lugar de «Agente».
  const defaultRoles = [
    {
      id: 'administrator',
      name: 'administrator',
      label: t('ACCESS_ROLES.ROLES.ADMINISTRATOR'),
    },
    ...ACCESS_ROLE_KEYS.map(key => ({
      id: `access_${key}`,
      name: `access_${key}`,
      accessRoleKey: key,
      label: t(`ACCESS_ROLES.ROLES.${key.toUpperCase()}`),
    })),
  ];

  const customRoles = getCustomRoles.value.map(role => ({
    id: role.id,
    name: `custom_${role.id}`,
    label: role.name,
  }));

  return [...defaultRoles, ...customRoles];
});

const selectedRole = computed(() =>
  roles.value.find(
    role =>
      role.id === selectedRoleId.value || role.name === selectedRoleId.value
  )
);

const availabilityStatuses = computed(() =>
  t('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUSES_LIST').map(
    (statusLabel, index) => ({
      label: statusLabel,
      value: AVAILABILITY_STATUS_KEYS[index],
      disabled: props.availability === AVAILABILITY_STATUS_KEYS[index],
    })
  )
);

const editAgent = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  try {
    const payload = {
      id: props.id,
      name: agentName.value,
      availability: agentAvailability.value,
      agent_contact_id: agentContactId.value, // proyecto@user_contact
      // Plan-Trabajo-Campo R3
      field_profile: {
        skills: skills.value
          .split(',')
          .map(skill => skill.trim())
          .filter(Boolean),
        zone: zone.value.trim(),
      },
    };

    if (selectedRole.value.name.startsWith('custom_')) {
      payload.custom_role_id = selectedRole.value.id;
    } else if (selectedRole.value.accessRoleKey) {
      payload.role = 'agent';
      payload.access_role_key = selectedRole.value.accessRoleKey;
      payload.custom_role_id = null;
    } else {
      payload.role = selectedRole.value.name;
      payload.custom_role_id = null;
    }

    await store.dispatch('agents/update', payload);
    useAlert(t('AGENT_MGMT.EDIT.API.SUCCESS_MESSAGE'));
    emit('close');
  } catch (error) {
    useAlert(t('AGENT_MGMT.EDIT.API.ERROR_MESSAGE'));
  }
};

const resetPassword = async () => {
  try {
    await Auth.resetPassword(agentCredentials.value);
    useAlert(t('AGENT_MGMT.EDIT.PASSWORD_RESET.ADMIN_SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('AGENT_MGMT.EDIT.PASSWORD_RESET.ERROR_MESSAGE'));
  }
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header :header-title="pageTitle" />
    <form class="w-full" @submit.prevent="editAgent">
      <div class="w-full">
        <label :class="{ error: v$.agentName.$error }">
          {{ $t('AGENT_MGMT.EDIT.FORM.NAME.LABEL') }}
          <input
            v-model.trim="agentName"
            type="text"
            :placeholder="$t('AGENT_MGMT.EDIT.FORM.NAME.PLACEHOLDER')"
            @input="v$.agentName.$touch"
          />
        </label>
      </div>

      <div class="w-full">
        <label :class="{ error: v$.selectedRoleId.$error }">
          {{ $t('AGENT_MGMT.EDIT.FORM.AGENT_TYPE.LABEL') }}
          <select v-model="selectedRoleId" @change="v$.selectedRoleId.$touch">
            <option v-for="role in roles" :key="role.id" :value="role.id">
              {{ role.label }}
            </option>
          </select>
          <span v-if="v$.selectedRoleId.$error" class="message">
            {{ $t('AGENT_MGMT.EDIT.FORM.AGENT_TYPE.ERROR') }}
          </span>
        </label>
      </div>

      <!-- Plan-Trabajo-Campo R3 — para el despacho de técnicos -->
      <div class="grid w-full grid-cols-1 gap-x-4 sm:grid-cols-2">
        <label>
          {{ $t('DISPATCH.PROFILE.SKILLS') }}
          <input
            v-model="skills"
            type="text"
            :placeholder="$t('DISPATCH.PROFILE.SKILLS_PLACEHOLDER')"
          />
        </label>
        <label>
          {{ $t('DISPATCH.PROFILE.ZONE') }}
          <input
            v-model="zone"
            type="text"
            :placeholder="$t('DISPATCH.PROFILE.ZONE_PLACEHOLDER')"
          />
        </label>
      </div>

      <div class="w-full">
        <label :class="{ error: v$.agentAvailability.$error }">
          {{ $t('PROFILE_SETTINGS.FORM.AVAILABILITY.LABEL') }}
          <select
            v-model="agentAvailability"
            @change="v$.agentAvailability.$touch"
          >
            <option
              v-for="status in availabilityStatuses"
              :key="status.value"
              :value="status.value"
            >
              {{ status.label }}
            </option>
          </select>
          <span v-if="v$.agentAvailability.$error" class="message">
            {{ $t('AGENT_MGMT.EDIT.FORM.AGENT_AVAILABILITY.ERROR') }}
          </span>
        </label>
      </div>

      <!-- proyecto@user_contact: selector de contacto vinculado al agente -->
      <div class="w-full mt-2">
        <label>{{ 'Contacto WhatsApp del usuario' }}</label>
        <div
          v-if="selectedContact"
          class="flex items-center gap-2 p-2 rounded border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800"
        >
          <span class="flex-1 text-sm">
            {{ selectedContact.name }}
            <span
              v-if="selectedContact.phone_number"
              class="text-slate-500 ml-1"
            >
              ({{ selectedContact.phone_number }})
            </span>
          </span>
          <woot-button
            icon="dismiss"
            variant="clear"
            size="tiny"
            color-scheme="secondary"
            @click.prevent="clearContact"
          />
        </div>
        <div v-else class="relative">
          <input
            v-model="contactSearch"
            type="text"
            placeholder="Buscar contacto por nombre o teléfono..."
            @input="onContactSearch"
          />
          <div
            v-if="showContactDropdown"
            class="absolute z-50 w-full bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded shadow-lg max-h-48 overflow-y-auto"
          >
            <div
              v-for="contact in contactResults"
              :key="contact.id"
              class="px-3 py-2 cursor-pointer hover:bg-slate-100 dark:hover:bg-slate-700 text-sm"
              @mousedown.prevent="selectContact(contact)"
            >
              {{ contact.name }}
              <span v-if="contact.phone_number" class="text-slate-500 ml-1">
                {{ contact.phone_number }}
              </span>
            </div>
          </div>
        </div>
      </div>
      <!-- fin proyecto@user_contact -->

      <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
        <div class="w-[50%]">
          <WootSubmitButton
            :disabled="v$.$invalid || uiFlags.isUpdating"
            :button-text="$t('AGENT_MGMT.EDIT.FORM.SUBMIT')"
            :loading="uiFlags.isUpdating"
          />
          <button class="button clear" @click.prevent="emit('close')">
            {{ $t('AGENT_MGMT.EDIT.CANCEL_BUTTON_TEXT') }}
          </button>
        </div>
        <div class="w-[50%] text-right">
          <woot-button
            icon="lock-closed"
            variant="clear"
            @click.prevent="resetPassword"
          >
            {{ $t('AGENT_MGMT.EDIT.PASSWORD_RESET.ADMIN_RESET_BUTTON') }}
          </woot-button>
        </div>
      </div>
    </form>
  </div>
</template>
