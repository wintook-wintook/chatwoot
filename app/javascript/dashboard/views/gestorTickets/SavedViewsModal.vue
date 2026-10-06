<!--
  @tickets_cases F5 — gestion de las vistas guardadas del Gestor de Tickets:
  renombrar, compartir o dejar de compartir, y eliminar.

  Quien puede tocar que lo decide el backend (CustomFilterPolicy); aqui solo se
  repite la regla para no ofrecer botones que van a devolver 401: su dueno
  siempre, y un administrador ademas sobre las compartidas.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';

const VIEW_FILTER_TYPE = 'case_ticket';
// Tope del modelo (CustomFilter::MAX_FILTER_PER_USER). Se muestra para que el
// limite no aparezca por sorpresa al guardar.
const MAX_PER_USER = 50;

export default {
  name: 'SavedViewsModal',
  data() {
    return {
      show: true,
      editingId: null,
      editingName: '',
      pendingDelete: null,
      showDeleteModal: false,
      maxPerUser: MAX_PER_USER,
    };
  },
  computed: {
    ...mapGetters({
      currentUserID: 'getCurrentUserID',
      currentRole: 'getCurrentRole',
    }),
    views() {
      return this.$store.getters['customViews/getCustomViewsByFilterType'](
        VIEW_FILTER_TYPE
      );
    },
    myViews() {
      return this.views.filter(v => v.user_id === this.currentUserID);
    },
    sharedViews() {
      return this.views.filter(v => v.user_id !== this.currentUserID);
    },
    isAdmin() {
      return this.currentRole === 'administrator';
    },
    groups() {
      return [
        {
          key: 'mine',
          label: this.$t('CASE_TICKETS.VIEWS.MINE'),
          rows: this.myViews,
        },
        {
          key: 'shared',
          label: this.$t('CASE_TICKETS.VIEWS.SHARED_BY_OTHERS'),
          rows: this.sharedViews,
        },
      ];
    },
    deleteMessageValue() {
      return this.pendingDelete ? this.pendingDelete.name : '';
    },
  },
  methods: {
    canEdit(view) {
      if (view.user_id === this.currentUserID) return true;
      return this.isAdmin && view.shared;
    },
    startRename(view) {
      this.editingId = view.id;
      this.editingName = view.name;
    },
    cancelRename() {
      this.editingId = null;
      this.editingName = '';
    },
    async confirmRename(view) {
      const name = this.editingName.trim();
      if (!name || name === view.name) {
        this.cancelRename();
        return;
      }
      await this.persist(view, { name }, 'RENAMED');
      this.cancelRename();
    },
    async toggleShared(view) {
      await this.persist(
        view,
        { shared: !view.shared },
        view.shared ? 'UNSHARED' : 'SHARED_OK'
      );
    },
    async persist(view, changes, messageKey) {
      try {
        await this.$store.dispatch('customViews/update', {
          id: view.id,
          ...changes,
        });
        useAlert(this.$t(`CASE_TICKETS.VIEWS.MANAGE.${messageKey}`));
        this.$emit('changed');
      } catch (error) {
        useAlert(this.$t('CASE_TICKETS.VIEWS.UPDATE_ERROR'));
      }
    },
    askDelete(view) {
      this.pendingDelete = view;
      this.showDeleteModal = true;
    },
    closeDelete() {
      this.pendingDelete = null;
      this.showDeleteModal = false;
    },
    async confirmDelete() {
      const view = this.pendingDelete;
      this.closeDelete();
      try {
        await this.$store.dispatch('customViews/delete', {
          id: view.id,
          filterType: VIEW_FILTER_TYPE,
        });
        useAlert(this.$t('CASE_TICKETS.VIEWS.MANAGE.DELETED'));
        this.$emit('changed', view.id);
      } catch (error) {
        useAlert(this.$t('CASE_TICKETS.VIEWS.MANAGE.DELETE_ERROR'));
      }
    },
    onClose() {
      this.$emit('close');
    },
  },
};
</script>

<template>
  <woot-modal :show.sync="show" :on-close="onClose">
    <woot-modal-header
      :header-title="$t('CASE_TICKETS.VIEWS.MANAGE.TITLE')"
      :header-content="$t('CASE_TICKETS.VIEWS.MANAGE.SUBTITLE')"
    />

    <div class="px-8 pb-8">
      <p v-if="!views.length" class="py-6 text-sm text-center text-slate-500">
        {{ $t('CASE_TICKETS.VIEWS.MANAGE.EMPTY') }}
      </p>

      <template v-for="group in groups">
        <div v-if="group.rows.length" :key="group.key" class="mb-5">
          <h4
            class="mb-2 text-xs font-semibold tracking-wide uppercase text-slate-500 dark:text-slate-400"
          >
            {{ group.label }}
          </h4>
          <ul class="m-0 list-none">
            <li
              v-for="view in group.rows"
              :key="view.id"
              class="flex gap-2 items-center py-2 border-b border-slate-50 dark:border-slate-800"
            >
              <div class="flex-1 min-w-0">
                <div
                  v-if="editingId === view.id"
                  class="flex gap-2 items-center"
                >
                  <input
                    v-model="editingName"
                    type="text"
                    class="flex-1 !mb-0 text-sm"
                    @keyup.enter="confirmRename(view)"
                    @keyup.esc="cancelRename"
                  />
                  <woot-button
                    size="tiny"
                    icon="checkmark"
                    :title="$t('CASE_TICKETS.VIEWS.MANAGE.CONFIRM')"
                    @click="confirmRename(view)"
                  />
                  <woot-button
                    size="tiny"
                    variant="clear"
                    icon="dismiss"
                    :title="$t('CASE_TICKETS.VIEWS.MANAGE.CANCEL')"
                    @click="cancelRename"
                  />
                </div>
                <div v-else class="flex gap-2 items-center min-w-0">
                  <span
                    class="text-sm truncate text-slate-800 dark:text-slate-100"
                  >
                    {{ view.name }}
                  </span>
                  <span
                    v-if="view.shared"
                    class="px-1.5 py-0.5 text-xs rounded bg-woot-50 text-woot-600 dark:bg-woot-800/40 dark:text-woot-300"
                  >
                    {{ $t('CASE_TICKETS.VIEWS.MANAGE.BADGE_SHARED') }}
                  </span>
                  <span
                    v-if="group.key === 'shared'"
                    class="text-xs truncate text-slate-500 dark:text-slate-400"
                  >
                    {{ view.owner_name }}
                  </span>
                </div>
              </div>

              <template v-if="editingId !== view.id && canEdit(view)">
                <woot-button
                  size="tiny"
                  variant="clear"
                  :icon="view.shared ? 'lock-closed' : 'share'"
                  :title="
                    view.shared
                      ? $t('CASE_TICKETS.VIEWS.MANAGE.UNSHARE')
                      : $t('CASE_TICKETS.VIEWS.MANAGE.SHARE')
                  "
                  @click="toggleShared(view)"
                />
                <woot-button
                  size="tiny"
                  variant="clear"
                  icon="edit"
                  :title="$t('CASE_TICKETS.VIEWS.MANAGE.RENAME')"
                  @click="startRename(view)"
                />
                <woot-button
                  size="tiny"
                  variant="clear"
                  color-scheme="alert"
                  icon="delete"
                  :title="$t('CASE_TICKETS.VIEWS.MANAGE.DELETE')"
                  @click="askDelete(view)"
                />
              </template>
            </li>
          </ul>
        </div>
      </template>

      <p class="m-0 text-xs text-slate-500 dark:text-slate-400">
        {{
          $t('CASE_TICKETS.VIEWS.MANAGE.QUOTA', {
            count: views.length,
            max: maxPerUser,
          })
        }}
      </p>
    </div>

    <woot-delete-modal
      v-if="pendingDelete"
      :show.sync="showDeleteModal"
      :on-close="closeDelete"
      :on-confirm="confirmDelete"
      :title="$t('CASE_TICKETS.VIEWS.MANAGE.DELETE_TITLE')"
      :message="
        pendingDelete.shared
          ? $t('CASE_TICKETS.VIEWS.MANAGE.DELETE_MESSAGE_SHARED')
          : $t('CASE_TICKETS.VIEWS.MANAGE.DELETE_MESSAGE')
      "
      :message-value="deleteMessageValue"
      :confirm-text="$t('CASE_TICKETS.VIEWS.MANAGE.DELETE_YES')"
      :reject-text="$t('CASE_TICKETS.VIEWS.MANAGE.DELETE_NO')"
    />
  </woot-modal>
</template>
