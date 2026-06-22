<!--
  @tickets_cases — Ajustes generales del módulo: modo simple (osTicket) vs ITIL.
-->
<script>
import { mapGetters } from 'vuex';

export default {
  name: 'TicketSettings',
  computed: {
    ...mapGetters({
      itilEnabled: 'caseTickets/getItilEnabled',
      uiFlags: 'caseTickets/getSettingsUIFlags',
    }),
    isFetching() {
      return this.uiFlags.isFetching;
    },
    isSaving() {
      return this.uiFlags.isSaving;
    },
  },
  mounted() {
    this.$store.dispatch('caseTickets/fetchSettings');
  },
  methods: {
    async toggleItil() {
      try {
        await this.$store.dispatch('caseTickets/updateSettings', {
          itil_enabled: !this.itilEnabled,
        });
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.SETTINGS.SAVED'),
        });
      } catch (_e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.SETTINGS.SAVE_ERROR'),
        });
      }
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900"
  >
    <div
      class="flex items-center justify-between flex-shrink-0 px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <div class="flex items-center gap-4">
        <woot-button
          size="small"
          variant="clear"
          color-scheme="secondary"
          icon="arrow-left"
          @click="$router.push({ name: 'gestorTickets_index' })"
        >
          {{ $t('CASE_TICKETS.SETTINGS.BACK') }}
        </woot-button>
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('CASE_TICKETS.SETTINGS.TITLE') }}
        </h1>
      </div>
    </div>

    <div
      v-if="isFetching"
      class="flex items-center justify-center flex-1 text-slate-400 dark:text-slate-500"
    >
      <span>{{ $t('CASE_TICKETS.SETTINGS.LOADING') }}</span>
    </div>

    <div v-else class="flex flex-col flex-1 gap-2 px-6 py-4 overflow-y-auto">
      <p class="m-0 mb-2 text-sm text-slate-500 dark:text-slate-400">
        {{ $t('CASE_TICKETS.SETTINGS.HELP') }}
      </p>

      <div
        class="flex items-start gap-4 p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
      >
        <div class="flex-1">
          <div class="flex items-center gap-2">
            <fluent-icon
              :icon="itilEnabled ? 'building-bank' : 'list'"
              size="18"
              class="text-woot-500"
            />
            <span
              class="text-base font-semibold text-slate-800 dark:text-slate-100"
            >
              {{
                itilEnabled
                  ? $t('CASE_TICKETS.SETTINGS.MODE_ITIL')
                  : $t('CASE_TICKETS.SETTINGS.MODE_SIMPLE')
              }}
            </span>
          </div>
          <p class="mt-1 mb-0 text-sm text-slate-500 dark:text-slate-400">
            {{
              itilEnabled
                ? $t('CASE_TICKETS.SETTINGS.MODE_ITIL_DESC')
                : $t('CASE_TICKETS.SETTINGS.MODE_SIMPLE_DESC')
            }}
          </p>
        </div>
        <woot-switch :value="itilEnabled" @input="toggleItil" />
      </div>

      <ul
        class="mt-2 ml-1 text-xs list-disc list-inside text-slate-400 dark:text-slate-500"
      >
        <li>{{ $t('CASE_TICKETS.SETTINGS.NOTE_DATA') }}</li>
        <li>{{ $t('CASE_TICKETS.SETTINGS.NOTE_REVERSIBLE') }}</li>
      </ul>
    </div>
  </div>
</template>
