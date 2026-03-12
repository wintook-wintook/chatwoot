<!-- ================================================================================ -->
<!-- proyecto@conversation_private                                                   -->
<!-- ================================================================================ -->
<!-- Component: NewConversationFromContacts.vue                                      -->
<!-- Descripción: Modal de 2 pasos para iniciar conversación privada desde la vista  -->
<!--              de conversaciones. Paso 1: seleccionar contacto (últimos 5 sin     -->
<!--              conversaciones, ordenados por -created_at). Paso 2: seleccionar    -->
<!--              inbox y escribir nota privada. Auto-redirige al crear.             -->
<!-- ================================================================================ -->

<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import Thumbnail from 'dashboard/components/widgets/Thumbnail.vue';
import InboxDropdownItem from 'dashboard/components/widgets/InboxDropdownItem.vue';
import Spinner from 'shared/components/Spinner.vue';
import ContactAPI from 'dashboard/api/contacts';
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
  },
  setup() {
    const v$ = useVuelidate();
    return { v$ };
  },
  data() {
    return {
      // Step control: 'select_contact' or 'compose_message'
      currentStep: 'select_contact',
      // Contact selection
      recentContacts: [],
      searchQuery: '',
      searchResults: [],
      isLoadingContacts: false,
      isSearching: false,
      selectedContact: null,
      // Message form
      message: '',
      targetInbox: {},
      isCreating: false,
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
      currentUser: 'getCurrentUser',
      uiFlags: 'contacts/getUIFlags',
    }),
    displayedContacts() {
      if (this.searchQuery && this.searchResults.length > 0) {
        return this.searchResults;
      }
      return this.recentContacts;
    },
    inboxes() {
      if (!this.selectedContact) return [];
      const inboxList = this.selectedContact.contactableInboxes || [];
      return inboxList.map(inbox => ({
        ...inbox.inbox,
        sourceId: inbox.source_id,
      }));
    },
    showNoInboxAlert() {
      if (!this.selectedContact) return false;
      if (!this.selectedContact.contactableInboxes) return false;
      return this.inboxes.length === 0;
    },
  },
  watch: {
    show(newVal) {
      if (newVal) {
        this.currentStep = 'select_contact';
        this.selectedContact = null;
        this.searchQuery = '';
        this.searchResults = [];
        this.message = '';
        this.targetInbox = {};
        this.v$.$reset();
        this.fetchRecentContacts();
      }
    },
  },
  methods: {
    onCancel() {
      this.$emit('cancel');
    },
    goBackToContacts() {
      this.currentStep = 'select_contact';
      this.selectedContact = null;
      this.message = '';
      this.targetInbox = {};
      this.v$.$reset();
    },
    computedInboxSource(inbox) {
      if (!inbox.channel_type) return '';
      return getInboxSource(inbox.channel_type, inbox.phone_number, inbox);
    },
    hasNoConversations(contact) {
      return !contact.conversations_count || contact.conversations_count === 0;
    },
    async fetchRecentContacts() {
      this.isLoadingContacts = true;
      try {
        const response = await ContactAPI.get(1, '-created_at');
        const contacts = response.data.payload || [];
        this.recentContacts = contacts
          .filter(c => this.hasNoConversations(c))
          .slice(0, 5);
      } catch (error) {
        this.recentContacts = [];
      } finally {
        this.isLoadingContacts = false;
      }
    },
    async onSearch() {
      if (!this.searchQuery || this.searchQuery.length < 2) {
        this.searchResults = [];
        return;
      }
      this.isSearching = true;
      try {
        const response = await ContactAPI.search(
          encodeURIComponent(this.searchQuery),
          1,
          '-created_at'
        );
        this.searchResults = (response.data.payload || [])
          .filter(c => this.hasNoConversations(c))
          .slice(0, 5);
      } catch (error) {
        this.searchResults = [];
      } finally {
        this.isSearching = false;
      }
    },
    async selectContact(contact) {
      this.selectedContact = contact;
      this.currentStep = 'compose_message';
      // Fetch contactable inboxes
      await this.$store.dispatch(
        'contacts/fetchContactableInbox',
        contact.id
      );
      // Update selectedContact with inbox data from store
      const updatedContact = this.$store.getters['contacts/getContact'](
        contact.id
      );
      if (updatedContact && updatedContact.contactableInboxes) {
        this.selectedContact = {
          ...this.selectedContact,
          contactableInboxes: updatedContact.contactableInboxes,
        };
      }
    },
    async onFormSubmit() {
      this.v$.$touch();
      if (this.v$.$invalid) return;

      this.isCreating = true;
      try {
        const payload = {
          inboxId: this.targetInbox.id,
          sourceId: this.targetInbox.sourceId,
          contactId: this.selectedContact.id,
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
      <!-- STEP 1: Select contact -->
      <div v-if="currentStep === 'select_contact'">
        <woot-modal-header
          :header-title="$t('NEW_CONVERSATION.FROM_CONTACTS.TITLE')"
          :header-content="$t('NEW_CONVERSATION.FROM_CONTACTS.DESC')"
        />
        <div class="w-full px-8 pb-6">
          <!-- Search input -->
          <!-- <div class="mb-3">
            <input
              v-model="searchQuery"
              type="text"
              class="w-full"
              :placeholder="$t('NEW_CONVERSATION.FROM_CONTACTS.SEARCH_PLACEHOLDER')"
              @input="onSearch"
            />
          </div> -->

          <!-- Loading -->
          <div
            v-if="isLoadingContacts || isSearching"
            class="flex items-center justify-center py-6"
          >
            <Spinner />
          </div>

          <!-- Contact list -->
          <div
            v-else-if="displayedContacts.length > 0"
            class="flex flex-col gap-1 max-h-[400px] overflow-y-auto"
          >
            <div
              v-for="contact in displayedContacts"
              :key="contact.id"
              class="flex items-center gap-3 p-2.5 rounded-md border border-solid border-slate-100 dark:border-slate-700 hover:bg-slate-25 dark:hover:bg-slate-800 cursor-pointer transition-colors"
              @click="selectContact(contact)"
            >
              <Thumbnail
                :src="contact.thumbnail"
                size="32px"
                :username="contact.name"
                :status="contact.availability_status"
              />
              <div class="flex flex-col min-w-0 flex-1">
                <span
                  class="text-sm font-medium text-slate-800 dark:text-slate-100 truncate"
                >
                  {{ contact.name }}
                </span>
                <span
                  class="text-xs text-slate-500 dark:text-slate-400 truncate"
                >
                  {{ contact.email || contact.phone_number || '' }}
                </span>
              </div>
              <fluent-icon
                icon="chevron-right"
                size="16"
                class="text-slate-400 flex-shrink-0"
              />
            </div>
          </div>

          <!-- No results -->
          <div
            v-else
            class="flex items-center justify-center py-6 text-sm text-slate-500 dark:text-slate-400"
          >
            {{ searchQuery
              ? $t('NEW_CONVERSATION.FROM_CONTACTS.NO_RESULTS')
              : $t('NEW_CONVERSATION.FROM_CONTACTS.NO_CONTACTS')
            }}
          </div>

          <!-- Cancel -->
          <div class="flex justify-end mt-4">
            <button class="button clear" @click.prevent="onCancel">
              {{ $t('NEW_CONVERSATION.FORM.CANCEL') }}
            </button>
          </div>
        </div>
      </div>

      <!-- STEP 2: Compose message -->
      <div v-else-if="currentStep === 'compose_message'">
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

              <!-- Selected contact (read-only, clickable to go back) -->
              <div class="w-[50%]">
                <label>
                  {{ $t('NEW_CONVERSATION.FORM.TO.LABEL') }}
                  <div
                    class="flex items-center h-[2.4735rem] rounded-sm py-1 px-2 bg-slate-25 dark:bg-slate-900 border border-solid border-slate-75 dark:border-slate-600 cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-800"
                    @click="goBackToContacts"
                  >
                    <Thumbnail
                      :src="selectedContact.thumbnail"
                      size="24px"
                      :username="selectedContact.name"
                      :status="selectedContact.availability_status"
                    />
                    <h4
                      class="m-0 ml-2 mr-2 text-sm text-slate-700 dark:text-slate-100 flex-1 truncate"
                    >
                      {{ selectedContact.name }}
                    </h4>
                    <fluent-icon
                      icon="edit"
                      size="12"
                      class="text-slate-400"
                    />
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
          <div class="flex flex-row justify-between w-full gap-2 px-0 py-2">
            <woot-button
              variant="smooth"
              color-scheme="secondary"
              icon="arrow-left"
              @click.prevent="goBackToContacts"
            >
              {{ $t('NEW_CONVERSATION.FROM_CONTACTS.BACK') }}
            </woot-button>
            <div class="flex gap-2">
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
          </div>
        </form>
      </div>
    </div>
  </woot-modal>
</template>
