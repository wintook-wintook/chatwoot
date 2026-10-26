<script setup>
// Plan-Roles-Permisos P3 — Ajustes › Roles: los roles de la cuenta, editables
// directo (cada cambio se guarda solo) y con «Restaurar como venía». El
// Administrador es fijo: se muestra pero no se edita.
import { computed, onMounted, ref } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'dashboard/composables/useI18n';
import AccessRolesAPI from 'dashboard/api/accessRoles';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';

const { t } = useI18n();

const roles = ref([]);
const areaLevels = ref({});
const actions = ref([]);
const isLoading = ref(true);
const selectedKey = ref('supervisor');
const confirmingRestore = ref(false);

const ADMIN_KEY = 'administrator';
const base = 'ACCESS_ROLES';

const selectedRole = computed(() =>
  roles.value.find(role => role.key === selectedKey.value)
);
const areas = computed(() => Object.keys(areaLevels.value));

const roleName = key => t(`${base}.ROLES.${key.toUpperCase()}`);
const areaName = area => t(`${base}.AREAS.${area.toUpperCase()}`);
const levelName = level => t(`${base}.LEVELS.${level.toUpperCase()}`);
const actionName = action => t(`${base}.ACTIONS.${action.toUpperCase()}`);

const fetchRoles = async () => {
  try {
    const { data } = await AccessRolesAPI.get();
    roles.value = data.access_roles;
    areaLevels.value = data.area_levels;
    actions.value = data.actions;
  } catch {
    useAlert(t(`${base}.ERROR`));
  } finally {
    isLoading.value = false;
  }
};

const replaceRole = role => {
  roles.value = roles.value.map(r => (r.id === role.id ? role : r));
};

const save = async changes => {
  try {
    const { data } = await AccessRolesAPI.update(
      selectedRole.value.id,
      changes
    );
    replaceRole(data.access_role);
    useAlert(t(`${base}.SAVED`));
  } catch {
    useAlert(t(`${base}.ERROR`));
    fetchRoles();
  }
};

const setLevel = (area, level) => save({ areas: { [area]: level } });
const setAction = (action, value) => save({ actions: { [action]: value } });

const restore = async () => {
  confirmingRestore.value = false;
  try {
    const { data } = await AccessRolesAPI.restore(selectedRole.value.id);
    replaceRole(data.access_role);
    useAlert(t(`${base}.RESTORED`));
  } catch {
    useAlert(t(`${base}.ERROR`));
  }
};

const selectRole = key => {
  selectedKey.value = key;
  confirmingRestore.value = false;
};

onMounted(fetchRoles);
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="$t('ACCESS_ROLES.LOADING')"
    :no-records-found="false"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('ACCESS_ROLES.HEADER')"
        :description="$t('ACCESS_ROLES.DESCRIPTION')"
        feature-name="agents"
      />
    </template>
    <template #body>
      <div class="grid grid-cols-1 gap-6 md:grid-cols-[16rem_1fr]">
        <!-- Lista de roles -->
        <ul class="flex flex-col gap-1 p-0 m-0 list-none">
          <li>
            <button
              type="button"
              class="flex flex-col items-start w-full gap-0.5 px-3 py-2 text-left rounded-lg"
              :class="
                selectedKey === ADMIN_KEY
                  ? 'bg-woot-50 dark:bg-woot-900/30'
                  : 'hover:bg-slate-50 dark:hover:bg-slate-800'
              "
              @click="selectRole(ADMIN_KEY)"
            >
              <span class="font-medium text-slate-800 dark:text-slate-100">
                {{ roleName(ADMIN_KEY) }}
              </span>
            </button>
          </li>
          <li v-for="role in roles" :key="role.key">
            <button
              type="button"
              class="flex flex-col items-start w-full gap-0.5 px-3 py-2 text-left rounded-lg"
              :class="
                selectedKey === role.key
                  ? 'bg-woot-50 dark:bg-woot-900/30'
                  : 'hover:bg-slate-50 dark:hover:bg-slate-800'
              "
              @click="selectRole(role.key)"
            >
              <span
                class="flex items-center gap-2 font-medium text-slate-800 dark:text-slate-100"
              >
                {{ roleName(role.key) }}
                <span
                  v-if="role.customized"
                  class="px-1.5 text-xs font-normal rounded bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-300"
                >
                  {{ $t('ACCESS_ROLES.CUSTOMIZED') }}
                </span>
              </span>
              <span class="text-xs text-slate-500 dark:text-slate-400">
                {{
                  $tc('ACCESS_ROLES.AGENTS_COUNT', role.agents_count, {
                    count: role.agents_count,
                  })
                }}
              </span>
            </button>
          </li>
        </ul>

        <!-- Administrador: fijo -->
        <div
          v-if="selectedKey === ADMIN_KEY"
          class="p-4 text-sm border rounded-lg border-slate-75 dark:border-slate-700 text-slate-600 dark:text-slate-300"
        >
          {{ $t('ACCESS_ROLES.ADMIN_NOTE') }}
        </div>

        <!-- Rol editable -->
        <div v-else-if="selectedRole" class="flex flex-col gap-6">
          <div class="flex flex-wrap items-start justify-between gap-3">
            <div>
              <h2
                class="m-0 text-lg font-semibold text-slate-800 dark:text-slate-100"
              >
                {{ roleName(selectedRole.key) }}
              </h2>
              <p class="m-0 text-sm text-slate-600 dark:text-slate-300">
                {{
                  $t(
                    `ACCESS_ROLES.ROLE_HINTS.${selectedRole.key.toUpperCase()}`
                  )
                }}
              </p>
            </div>
            <div v-if="selectedRole.customized" class="flex items-center gap-2">
              <template v-if="confirmingRestore">
                <span
                  class="max-w-xs text-sm text-slate-600 dark:text-slate-300"
                >
                  {{
                    $t('ACCESS_ROLES.RESTORE_CONFIRM', {
                      name: roleName(selectedRole.key),
                    })
                  }}
                </span>
                <woot-button size="small" color-scheme="alert" @click="restore">
                  {{ $t('ACCESS_ROLES.RESTORE') }}
                </woot-button>
                <woot-button
                  size="small"
                  variant="clear"
                  @click="confirmingRestore = false"
                >
                  {{ $t('AGENT_MGMT.EDIT.CANCEL_BUTTON_TEXT') }}
                </woot-button>
              </template>
              <woot-button
                v-else
                size="small"
                variant="hollow"
                icon="arrow-clockwise"
                @click="confirmingRestore = true"
              >
                {{ $t('ACCESS_ROLES.RESTORE') }}
              </woot-button>
            </div>
          </div>

          <section>
            <h3
              class="mb-2 text-sm font-semibold text-slate-700 dark:text-slate-200"
            >
              {{ $t('ACCESS_ROLES.AREAS_TITLE') }}
            </h3>
            <div
              class="border divide-y rounded-lg border-slate-75 dark:border-slate-700 divide-slate-75 dark:divide-slate-700"
            >
              <div
                v-for="area in areas"
                :key="area"
                class="flex items-center justify-between gap-4 px-4 py-2"
              >
                <span class="text-sm text-slate-800 dark:text-slate-100">
                  {{ areaName(area) }}
                </span>
                <select
                  class="w-56 mb-0 text-sm"
                  :value="selectedRole.areas[area]"
                  :disabled="areaLevels[area].length < 2"
                  @change="setLevel(area, $event.target.value)"
                >
                  <option
                    v-for="level in areaLevels[area]"
                    :key="level"
                    :value="level"
                  >
                    {{ levelName(level) }}
                  </option>
                </select>
              </div>
            </div>
          </section>

          <section>
            <h3
              class="mb-2 text-sm font-semibold text-slate-700 dark:text-slate-200"
            >
              {{ $t('ACCESS_ROLES.ACTIONS_TITLE') }}
            </h3>
            <div class="flex flex-col gap-2">
              <label
                v-for="action in actions"
                :key="action"
                class="flex items-center gap-2 text-sm text-slate-800 dark:text-slate-100"
              >
                <input
                  type="checkbox"
                  class="m-0"
                  :checked="selectedRole.actions[action]"
                  @change="setAction(action, $event.target.checked)"
                />
                {{ actionName(action) }}
              </label>
            </div>
          </section>
        </div>
      </div>
    </template>
  </SettingsLayout>
</template>
