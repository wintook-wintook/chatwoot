<!-- ================================================================================ -->
<!-- proyecto@conversation_private                                                   -->
<!-- ================================================================================ -->
<!-- Component: NewPrivateConversation.vue                                           -->
<!-- Descripción: Modal para iniciar una nueva conversación con nota privada desde   -->
<!--              el panel de contactos. Verifica si ya existen conversaciones y     -->
<!--              permite navegar a la última o crear una nueva.                     -->
<!-- ================================================================================ -->

<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import Thumbnail from 'dashboard/components/widgets/Thumbnail.vue';
import InboxDropdownItem from 'dashboard/components/widgets/InboxDropdownItem.vue';
import Spinner from 'shared/components/Spinner.vue';
import { getInboxSource } from 'dashboard/helper/inbox';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';

export default {
  components: {
    Thumbnail,
    InboxDropdownItem,
    Spinner,
  },
  props: {
    show: {
      type: Boolean,
      default: false,
    },
    contact: {
      type: Object,
      default: () => ({}),
    },
  },
  setup() {
    const v$ = useVuelidate();
    return { v$ };
  },
  data() {
    return {
      message: '',
      targetInbox: {},
      isCreating: false,
      isCheckingConversations: false,
      hasExistingConversations: false,
    };
  },
  validations() {
    return {
      message: { required },
      targetInbox: { required },
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'contacts/getUIFlags',
      currentUser: 'getCurrentUser',
    }),
    contactConversations() {
      return this.$store.getters['contactConversations/getContactConversation'](
        this.contact.id
      );
    },
    inboxes() {
      const inboxList = this.contact.contactableInboxes || [];
      return inboxList.map(inbox => ({
        ...inbox.inbox,
        sourceId: inbox.source_id,
      }));
    },
    showNoInboxAlert() {
      if (!this.contact.contactableInboxes) return false;
      return this.inboxes.length === 0 && !this.uiFlags.isFetchingInboxes;
    },
    sortedConversations() {
      const conversations = this.contactConversations || [];
      return [...conversations].sort((a, b) => {
        return new Date(b.created_at) - new Date(a.created_at);
      });
    },
  },
  watch: {
    'contact.id'(id) {
      if (id) {
        this.$store.dispatch('contacts/fetchContactableInbox', id);
      }
    },
    show(newVal) {
      if (newVal && this.contact.id) {
        this.checkExistingConversations();
      }
    },
  },
  mounted() {
    const { id } = this.contact;
    if (id) {
      this.$store.dispatch('contacts/fetchContactableInbox', id);
    }
  },
  methods: {
    onCancel() {
      this.hasExistingConversations = false;
      this.$emit('cancel');
    },
    computedInboxSource(inbox) {
      if (!inbox.channel_type) return '';
      return getInboxSource(inbox.channel_type, inbox.phone_number, inbox);
    },
    resetForm() {
      this.message = '';
      this.targetInbox = {};
      this.hasExistingConversations = false;
      this.v$.$reset();
    },
    async checkExistingConversations() {
      this.isCheckingConversations = true;
      try {
        await this.$store.dispatch(
          'contactConversations/get',
          this.contact.id
        );
        const conversations = this.contactConversations;
        if (conversations && conversations.length > 0) {
          this.hasExistingConversations = true;
        } else {
          this.hasExistingConversations = false;
        }
      } catch (error) {
        this.hasExistingConversations = false;
      } finally {
        this.isCheckingConversations = false;
      }
    },
    getLastConversation() {
      const conversations = this.contactConversations;
      if (!conversations || conversations.length === 0) return null;
      // Ordenar por created_at descendente y tomar la más reciente
      const sorted = [...conversations].sort((a, b) => {
        return new Date(b.created_at) - new Date(a.created_at);
      });
      return sorted[0];
    },
    goToLastConversation() {
      const lastConversation = this.getLastConversation();
      if (lastConversation) {
        this.goToConversation(lastConversation);
      }
    },
    goToConversation(conversation) {
      this.resetForm();
      this.$emit('cancel');
      this.$router.push(
        `/app/accounts/${this.$route.params.accountId}/conversations/${conversation.id}`
      );
    },
    getInboxName(conversation) {
      const inbox = this.$store.getters['inboxes/getInbox'](conversation.inbox_id);
      return inbox ? inbox.name : `Inbox #${conversation.inbox_id}`;
    },
    async onFormSubmit() {
      this.v$.$touch();
      if (this.v$.$invalid) return;

      this.isCreating = true;
      try {
        const payload = {
          inboxId: this.targetInbox.id,
          sourceId: this.targetInbox.sourceId,
          contactId: this.contact.id,
          message: {
            content: this.message,
            private: true,
          },
          assigneeId: this.currentUser.id,
        };

        const data = await this.$store.dispatch('contactConversations/create', {
          params: payload,
          isFromWhatsApp: false,
        });

        useAlert(this.$t('NEW_CONVERSATION.PRIVATE.SUCCESS_MESSAGE'));
        this.resetForm();
        this.$emit('cancel');

        this.$router.push(
          `/app/accounts/${data.account_id}/conversations/${data.id}`
        );
      } catch (error) {
        useAlert(this.$t('NEW_CONVERSATION.PRIVATE.ERROR_MESSAGE'));
      } finally {
        this.isCreating = false;
      }
    },
  },
};
</script>

<!-- eslint-disable vue/no-mutating-props -->
<template>
  <woot-modal :show.sync="show" :on-close="onCancel">
    <div class="flex flex-col h-auto overflow-auto">
      <!-- Loading state while checking conversations -->
      <div v-if="isCheckingConversations" class="flex items-center justify-center p-8">
        <spinner />
        <span class="ml-2 text-sm text-slate-600 dark:text-slate-300">
          {{ $t('NEW_CONVERSATION.PRIVATE.CHECKING') }}
        </span>
      </div>

      <!-- Existing conversations found -->
      <div v-else-if="hasExistingConversations">
        <woot-modal-header
          :header-title="$t('NEW_CONVERSATION.PRIVATE.EXISTING_TITLE')"
          :header-content="$t('NEW_CONVERSATION.PRIVATE.EXISTING_DESC')"
        />
        <div class="w-full px-8 pb-6">
          <div class="flex flex-col gap-2 mb-4 max-h-[300px] overflow-y-auto">
            <div
              v-for="conversation in sortedConversations"
              :key="conversation.id"
              class="flex items-center justify-between p-3 rounded-md border border-solid border-slate-100 dark:border-slate-700 hover:bg-slate-25 dark:hover:bg-slate-800 cursor-pointer"
              @click="goToConversation(conversation)"
            >
              <div class="flex flex-col gap-0.5">
                <span class="text-sm font-medium text-slate-800 dark:text-slate-100">
                  #{{ conversation.id }} - {{ conversation.inbox_id ? getInboxName(conversation) : '' }}
                </span>
                <span class="text-xs text-slate-500 dark:text-slate-400">
                  {{ conversation.last_non_activity_message
                    ? conversation.last_non_activity_message.content
                      ? conversation.last_non_activity_message.content.substring(0, 80) + (conversation.last_non_activity_message.content.length > 80 ? '...' : '')
                      : $t('NEW_CONVERSATION.PRIVATE.NO_MESSAGES')
                    : $t('NEW_CONVERSATION.PRIVATE.NO_MESSAGES')
                  }}
                </span>
              </div>
              <div class="flex items-center gap-2">
                <span
                  class="inline-block px-2 py-0.5 text-xs rounded-full"
                  :class="{
                    'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200': conversation.status === 'open',
                    'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200': conversation.status === 'pending',
                    'bg-slate-100 text-slate-800 dark:bg-slate-700 dark:text-slate-200': conversation.status === 'resolved',
                    'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200': conversation.status === 'snoozed',
                  }"
                >
                  {{ conversation.status }}
                </span>
                <fluent-icon icon="chevron-right" size="16" class="text-slate-400" />
              </div>
            </div>
          </div>
          <div class="flex flex-row justify-between w-full gap-2">
            <woot-button
              variant="smooth"
              color-scheme="secondary"
              @click="hasExistingConversations = false"
            >
              {{ $t('NEW_CONVERSATION.PRIVATE.CREATE_NEW_ANYWAY') }}
            </woot-button>
            <div class="flex gap-2">
              <button class="button clear" @click.prevent="onCancel">
                {{ $t('NEW_CONVERSATION.FORM.CANCEL') }}
              </button>
              <woot-button
                color-scheme="primary"
                icon="chat"
                @click="goToLastConversation"
              >
                {{ $t('NEW_CONVERSATION.PRIVATE.GO_TO_LAST') }}
              </woot-button>
            </div>
          </div>
        </div>
      </div>

      <!-- New conversation form -->
      <div v-else>
        <woot-modal-header
          :header-title="$t('NEW_CONVERSATION.PRIVATE.TITLE')"
          :header-content="$t('NEW_CONVERSATION.PRIVATE.DESC')"
        />
        <form
          class="w-full pt-4 px-8 pb-8"
          @submit.prevent="onFormSubmit"
        >
          <!-- No inbox alert -->
          <div
            v-if="showNoInboxAlert"
            class="relative mx-0 mt-0 mb-2.5 p-2 rounded-md border border-solid border-yellow-200 dark:border-yellow-800 bg-yellow-50 dark:bg-yellow-900/20"
          >
            <p class="mb-0 text-sm text-yellow-800 dark:text-yellow-200">
              {{ $t('NEW_CONVERSATION.NO_INBOX') }}
            </p>
          </div>

          <div v-else>
            <!-- Inbox + Contact row -->
            <div class="flex flex-row gap-2">
              <!-- Inbox selector -->
              <div class="w-[50%]">
                <label>
                  {{ $t('NEW_CONVERSATION.FORM.INBOX.LABEL') }}
                </label>
                <div
                  class="multiselect-wrap--small"
                  :class="{ 'has-multi-select-error': v$.targetInbox.$error }"
                >
                  <multiselect
                    v-model="targetInbox"
                    track-by="id"
                    label="name"
                    :placeholder="$t('FORMS.MULTISELECT.SELECT')"
                    selected-label=""
                    select-label=""
                    deselect-label=""
                    :max-height="160"
                    close-on-select
                    :options="[...inboxes]"
                  >
                    <template #singleLabel="{ option }">
                      <InboxDropdownItem
                        v-if="option.name"
                        :name="option.name"
                        :inbox-identifier="computedInboxSource(option)"
                        :channel-type="option.channel_type"
                      />
                      <span v-else>
                        {{ $t('NEW_CONVERSATION.FORM.INBOX.PLACEHOLDER') }}
                      </span>
                    </template>
                    <template #option="{ option }">
                      <InboxDropdownItem
                        :name="option.name"
                        :inbox-identifier="computedInboxSource(option)"
                        :channel-type="option.channel_type"
                      />
                    </template>
                  </multiselect>
                </div>
                <label :class="{ error: v$.targetInbox.$error }">
                  <span v-if="v$.targetInbox.$error" class="message">
                    {{ $t('NEW_CONVERSATION.FORM.INBOX.ERROR') }}
                  </span>
                </label>
              </div>

              <!-- Contact info (read-only) -->
              <div class="w-[50%]">
                <label>
                  {{ $t('NEW_CONVERSATION.FORM.TO.LABEL') }}
                  <div
                    class="flex items-center h-[2.4735rem] rounded-sm py-1 px-2 bg-slate-25 dark:bg-slate-900 border border-solid border-slate-75 dark:border-slate-600"
                  >
                    <Thumbnail
                      :src="contact.thumbnail"
                      size="24px"
                      :username="contact.name"
                      :status="contact.availability_status"
                    />
                    <h4
                      class="m-0 ml-2 mr-2 text-sm text-slate-700 dark:text-slate-100"
                    >
                      {{ contact.name }}
                    </h4>
                  </div>
                </label>
              </div>
            </div>

            <!-- Private note textarea -->
            <div class="w-full mt-3">
              <label :class="{ error: v$.message.$error }">
                <div class="flex items-center gap-1 mb-1">
                  <fluent-icon
                    icon="lock-closed"
                    size="14"
                    class="text-yellow-600 dark:text-yellow-400"
                  />
                  <span
                    class="text-xs font-medium text-yellow-700 dark:text-yellow-400"
                  >
                    {{ $t('NEW_CONVERSATION.PRIVATE.NOTE_LABEL') }}
                  </span>
                </div>
                <textarea
                  v-model="message"
                  class="min-h-[8rem] bg-yellow-50 dark:bg-yellow-900/20 border-yellow-300 dark:border-yellow-700"
                  type="text"
                  :placeholder="$t('NEW_CONVERSATION.PRIVATE.PLACEHOLDER')"
                  @input="v$.message.$touch"
                />
                <span v-if="v$.message.$error" class="message">
                  {{ $t('NEW_CONVERSATION.FORM.MESSAGE.ERROR') }}
                </span>
              </label>
            </div>
          </div>

          <!-- Action buttons -->
          <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
            <button class="button clear" @click.prevent="onCancel">
              {{ $t('NEW_CONVERSATION.FORM.CANCEL') }}
            </button>
            <woot-button
              type="submit"
              :is-loading="isCreating"
              color-scheme="warning"
              icon="lock-closed"
            >
              {{ $t('NEW_CONVERSATION.PRIVATE.SUBMIT') }}
            </woot-button>
          </div>
        </form>
      </div>
    </div>
  </woot-modal>
</template>
