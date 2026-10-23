<script setup>
import EmptyState from 'dashboard/components/widgets/EmptyState.vue';
import { computed, onMounted } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useRoute } from 'dashboard/composables/route';

// feat/licencias (F5): si la cuenta se suspendió porque venció su licencia, se dice eso (y que
// los mensajes de sus clientes se siguen guardando) en lugar del aviso genérico.
const currentUser = useMapGetter('getCurrentUser');
const route = useRoute();
const licenseExpired = computed(() => {
  const user = currentUser.value;
  const accounts = (user && user.accounts) || [];
  const account = accounts.find(
    item => item.id === Number(route.params.accountId)
  );
  return Boolean(account && account.license_expired);
});
const title = computed(() =>
  licenseExpired.value
    ? 'LICENSES.SUSPENDED.TITLE'
    : 'APP_GLOBAL.ACCOUNT_SUSPENDED.TITLE'
);
const message = computed(() =>
  licenseExpired.value
    ? 'LICENSES.SUSPENDED.MESSAGE'
    : 'APP_GLOBAL.ACCOUNT_SUSPENDED.MESSAGE'
);

const toggleSupportWidgetVisibility = () => {
  if (window.$chatwoot) {
    window.$chatwoot.toggleBubbleVisibility('show');
  }
};

const setupListenerForWidgetEvent = () => {
  window.addEventListener('chatwoot:on-message', () => {
    toggleSupportWidgetVisibility();
  });
};

onMounted(() => {
  toggleSupportWidgetVisibility();
  setupListenerForWidgetEvent();
});
</script>

<template>
  <div class="items-center bg-slate-50 flex justify-center h-full w-full">
    <EmptyState :title="$t(title)" :message="$t(message)" />
  </div>
</template>
