<script setup>
import { computed } from 'vue';
import ConversationBasicFilter from './widgets/conversation/ConversationBasicFilter.vue';

const props = defineProps({
  pageTitle: {
    type: String,
    required: true,
  },
  hasAppliedFilters: {
    type: Boolean,
    required: true,
  },
  hasHideFiltersForAgents: {
    type: Boolean,
    required: true,
  },
  hasActiveFolders: {
    type: Boolean,
    required: true,
  },
  activeStatus: {
    type: String,
    required: true,
  },
  // feat/chat_interno: [+] «Nuevo chat» en la lista de la bandeja «Interno».
  showNewInternalChat: {
    type: Boolean,
    default: false,
  },
  // feat/chat_interno_pulido: «Chat interno» sin estado (Abiertas), filtros ni orden.
  isInternalChat: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'addFolders',
  'deleteFolders',
  'resetFilters',
  'basicFilterChange',
  'filtersModal',
  'newInternalChat',
]);

const onBasicFilterChange = (value, type) => {
  emit('basicFilterChange', value, type);
};

const hasAppliedFiltersOrActiveFolders = computed(() => {
  return props.hasAppliedFilters || props.hasActiveFolders;
});
</script>

<template>
  <div
    class="flex items-center justify-between px-4 py-0"
    :class="{
      'pb-3 border-b border-slate-75 dark:border-slate-700':
        hasAppliedFiltersOrActiveFolders,
    }"
  >
    <div class="flex max-w-[85%] justify-center items-center">
      <h1
        class="text-xl font-medium break-words truncate text-black-900 dark:text-slate-100"
        :title="pageTitle"
      >
        {{ pageTitle }}
      </h1>
      <span
        v-if="!hasAppliedFiltersOrActiveFolders && !isInternalChat"
        class="p-1 my-0.5 mx-1 rounded-md capitalize bg-slate-50 dark:bg-slate-800 text-xxs text-slate-600 dark:text-slate-300"
      >
        {{ $t(`CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.${activeStatus}.TEXT`) }}
      </span>
    </div>
    <div class="flex items-center gap-1">
      <div v-if="hasAppliedFilters && !hasActiveFolders">
        <woot-button
          v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.ADD.SAVE_BUTTON')"
          size="tiny"
          variant="smooth"
          color-scheme="secondary"
          icon="save"
          @click="emit('addFolders')"
        />
        <woot-button
          v-tooltip.top-end="$t('FILTER.CLEAR_BUTTON_LABEL')"
          size="tiny"
          variant="smooth"
          color-scheme="alert"
          icon="dismiss-circle"
          @click="emit('resetFilters')"
        />
      </div>
      <div v-if="hasActiveFolders">
        <woot-button
          v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.EDIT.EDIT_BUTTON')"
          size="tiny"
          variant="smooth"
          color-scheme="secondary"
          icon="edit"
          @click="emit('filtersModal')"
        />
        <woot-button
          v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.DELETE.DELETE_BUTTON')"
          size="tiny"
          variant="smooth"
          color-scheme="alert"
          icon="delete"
          @click="emit('deleteFolders')"
        />
      </div>
      <woot-button
        v-if="!hasHideFiltersForAgents && !hasActiveFolders && !isInternalChat"
        v-tooltip.right="$t('FILTER.TOOLTIP_LABEL')"
        variant="smooth"
        color-scheme="secondary"
        icon="filter"
        size="tiny"
        @click="emit('filtersModal')"
      />
      <!-- feat/chat_interno_pulido: botón con texto en lugar de un [+] suelto -->
      <woot-button
        v-if="showNewInternalChat"
        v-tooltip.bottom="$t('INTERNAL_CHAT.NEW_CHAT_TOOLTIP')"
        variant="smooth"
        color-scheme="primary"
        icon="edit"
        size="small"
        @click="emit('newInternalChat')"
      >
        {{ $t('INTERNAL_CHAT.NEW_CHAT') }}
      </woot-button>
      <ConversationBasicFilter
        v-if="!hasAppliedFiltersOrActiveFolders && !isInternalChat"
        @changeFilter="onBasicFilterChange"
      />
    </div>
  </div>
</template>
