<script setup>
import { useAlert } from 'dashboard/composables';
import AddCanned from './AddCanned.vue';
import EditCanned from './EditCanned.vue';
import CannedTabs from '../wintook/canned/CannedTabs.vue';
import ForumBots from '../integrations/Addons/ForumBots.vue';
import SystemSettings from '../integrations/Addons/SystemSettings.vue';
import Synonyms from '../wintook/canned/Synonyms.vue';
import Vocabulary from '../wintook/canned/Vocabulary.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
// proyecto@respuestas_predefinidas R2: la tabla paginada (incluye el estado de R1).
import CannedResponsesTable from './CannedResponsesTable.vue';
// proyecto@auditoria_predefinidas: la pestaña «Auditoría».
import CannedAudit from './audit/CannedAudit.vue';
// proyecto@arreglar_predefinidas: «Arreglar con IA» (pasa del tope y cada sección de la
// auditoría) y «Corregir todas» de redacción.
import FixModal from './audit/FixModal.vue';
import BulkWritingModal from './audit/BulkWritingModal.vue';
import { computed, nextTick, onMounted, ref } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import { useStore } from 'dashboard/composables/store';
import { useRoute } from 'dashboard/composables/route';
// proyecto@predefinidas_que_contestan: el probador abre una respuesta con ?fix=<id>.
import CannedResponseAPI from 'dashboard/api/cannedResponse';
import { MAX_CHARS } from './audit/cannedSize';

const store = useStore();
const { t } = useI18n();

const showAddPopup = ref(false);
const selectedTabIndex = ref(0);
const loading = ref({});
const showEditPopup = ref(false);
const showDeleteConfirmationPopup = ref(false);
const activeResponse = ref({});
const cannedResponseAPI = ref({ message: '' });

const table = ref(null);
const auditView = ref(null);
const reloadTable = () => {
  if (table.value) table.value.reload();
  if (auditView.value) auditView.value.refreshAfterEdit();
};
// «Ver en la tabla» de la auditoría: la lista con el filtro de tamaño puesto.
const showTableWithSize = async size => {
  selectedTabIndex.value = 0;
  await nextTick();
  if (table.value) table.value.filterBySize(size);
};
const fixTarget = ref(null);
// La tabla manda la predefinida; la auditoría, { kind, response | finding }.
const openFix = payload => {
  fixTarget.value = payload.kind
    ? payload
    : { kind: 'oversize', response: payload };
};
const showBulk = ref(false);
const closeFix = () => {
  fixTarget.value = null;
};

const deleteConfirmText = computed(
  () =>
    `${t('CANNED_MGMT.DELETE.CONFIRM.YES')} ${activeResponse.value.short_code}`
);

const deleteRejectText = computed(
  () =>
    `${t('CANNED_MGMT.DELETE.CONFIRM.NO')} ${activeResponse.value.short_code}`
);

const deleteMessage = computed(() => {
  return ` ${activeResponse.value.short_code} ? `;
});

const showAlertMessage = message => {
  loading[activeResponse.value.id] = false;
  activeResponse.value = {};
  cannedResponseAPI.value.message = message;
  useAlert(message);
};

const openAddPopup = () => {
  showAddPopup.value = true;
};
const hideAddPopup = () => {
  showAddPopup.value = false;
  reloadTable();
};

// ?fix=<id> (desde el 👎 del probador): si pasa del tope, «Arreglar con IA»; si no, editarla.
const route = useRoute();
const openFromLink = async () => {
  const id = Number(route.query && route.query.fix);
  if (!id) return;
  try {
    const { data } = await CannedResponseAPI.list({ page: 1, per_page: 1, id });
    const record = (data.payload || [])[0];
    if (!record) return;
    if ((record.agent_chars || 0) > MAX_CHARS) openFix(record);
    // eslint-disable-next-line no-use-before-define
    else openEditPopup(record);
  } catch (e) {
    // sin la respuesta, la lista como siempre
  }
};
onMounted(openFromLink);

const openEditPopup = response => {
  showEditPopup.value = true;
  activeResponse.value = response;
};
const hideEditPopup = () => {
  showEditPopup.value = false;
  reloadTable();
};

const openDeletePopup = response => {
  showDeleteConfirmationPopup.value = true;
  activeResponse.value = response;
};

const closeDeletePopup = () => {
  showDeleteConfirmationPopup.value = false;
};

const deleteCannedResponse = async id => {
  try {
    await store.dispatch('deleteCannedResponse', id);
    showAlertMessage(t('CANNED_MGMT.DELETE.API.SUCCESS_MESSAGE'));
    reloadTable();
  } catch (error) {
    const errorMessage =
      error?.message || t('CANNED_MGMT.DELETE.API.ERROR_MESSAGE');
    showAlertMessage(errorMessage);
  }
};

const confirmDeletion = () => {
  loading[activeResponse.value.id] = true;
  closeDeletePopup();
  deleteCannedResponse(activeResponse.value.id);
};
</script>

<template>
  <div class="flex-1 overflow-auto">
    <BaseSettingsHeader
      :title="$t('CANNED_MGMT.HEADER')"
      feature-name="canned_responses"
    >
      <template #actions>
        <woot-button
          class="button nice rounded-md"
          icon="add-circle"
          @click="openAddPopup"
        >
          {{ $t('CANNED_MGMT.HEADER_BTN_TXT') }}
        </woot-button>
      </template>
    </BaseSettingsHeader>
    <CannedTabs
      :selected-tab-index="selectedTabIndex"
      @update:selectedTabIndex="selectedTabIndex = $event"
    />

    <div v-if="selectedTabIndex == 0" class="mt-6 flex-1">
      <!-- proyecto@respuestas_predefinidas R2: paginada, con filtros, orden y acciones en
           lote; sin el botón «Generar Entrenamiento» del sistema anterior (servicio externo
           WINTOOK_OPENAI setTraining), reemplazado por «Fuente de datos» (R1). -->
      <CannedResponsesTable
        ref="table"
        @edit="openEditPopup"
        @delete="openDeletePopup"
        @fix="openFix"
      />
    </div>

    <div v-if="selectedTabIndex == 1" class="mt-6">
      <CannedAudit
        ref="auditView"
        @edit="openEditPopup"
        @show-table="showTableWithSize"
        @fix="openFix"
        @bulk="showBulk = true"
        @applied="reloadTable"
      />
    </div>
    <Vocabulary v-if="selectedTabIndex == 2" />
    <Synonyms v-if="selectedTabIndex == 3" />
    <ForumBots v-if="selectedTabIndex == 4" />
    <SystemSettings v-if="selectedTabIndex == 5" />

    <FixModal
      v-if="fixTarget"
      :show="!!fixTarget"
      :target="fixTarget"
      @close="closeFix"
      @applied="reloadTable"
    />
    <BulkWritingModal
      v-if="showBulk"
      :show="showBulk"
      @close="showBulk = false"
      @applied="reloadTable"
    />

    <woot-modal :show.sync="showAddPopup" :on-close="hideAddPopup">
      <AddCanned :on-close="hideAddPopup" />
    </woot-modal>

    <woot-modal :show.sync="showEditPopup" :on-close="hideEditPopup">
      <EditCanned
        v-if="showEditPopup"
        :id="activeResponse.id"
        :edshort-code="activeResponse.short_code"
        :edcontent="activeResponse.content"
        :edactive-response="activeResponse"
        :on-close="hideEditPopup"
      />
    </woot-modal>

    <woot-delete-modal
      :show.sync="showDeleteConfirmationPopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="$t('CANNED_MGMT.DELETE.CONFIRM.TITLE')"
      :message="$t('CANNED_MGMT.DELETE.CONFIRM.MESSAGE')"
      :message-value="deleteMessage"
      :confirm-text="deleteConfirmText"
      :reject-text="deleteRejectText"
    />
  </div>
</template>
