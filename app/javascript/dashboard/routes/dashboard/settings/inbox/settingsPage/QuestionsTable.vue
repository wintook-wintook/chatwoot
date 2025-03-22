<template>
    <div class="mt-6 flex-1">
      <ve-table :fixed-header="true" max-height="calc(100vh - 2rem)" :columns="columns" :table-data="dataTable"
        :border-around="false" />
    </div>
  </template>
  
  <script>
  import { VeTable } from 'vue-easytable';
  import Spinner from 'shared/components/Spinner.vue';
  import EmptyState from 'dashboard/components/widgets/EmptyState.vue';
  import ChipAnswer from './ChipAnswer.vue'
  export default {
    components: {
      EmptyState,
      Spinner,
      VeTable,
      ChipAnswer,
    },
    props: {
      dataTable: {
        type: Array,
        default: () => [],
      },
      onToggleEditQuestion: {
        type: Function,
        default: data => { },
      },
      onToggleDeleteQuestion: {
        type: Function,
        default: data => { },
      },
    },
    data() {
      return {
        sortConfig: {},
      };
    },
    methods: {
      // Maneja la edición de una respuesta
      onEditAnswer(row, answer) {
        // console.log('Editando respuesta:', answer, 'de la pregunta:', row.question);
        // Aquí puedes mostrar un modal, un formulario o cualquier interfaz para editar.
        // Por ejemplo:
        this.$emit('edit-answer', { row, answer });
      },
  
      // Maneja la eliminación de una respuesta
      onDeleteAnswer(row, answer) {
        // console.log('Eliminando respuesta:', answer, 'de la pregunta:', row.question);
        // // Confirmación antes de eliminar
        // if (confirm(`¿Estás seguro de eliminar la respuesta: "${answer.answer}"?`)) {
        //   // Lógica para eliminar la respuesta
        //   row.answers = row.answers.filter(a => a.answer_id !== answer.answer_id);
        //   // Puedes emitir un evento si necesitas que el padre maneje esta acción
          this.$emit('delete-answer', { row, answer });
        }
      },
    computed: {
      columns() {
        return [{
          field: 'question_id',
          key: 'question_id',
          title: 'No. pregunta',
          width: 10,
          align: 'left',
        },
        {
          field: 'question',
          key: 'question',
          title: 'Descripcion de pregunta',
          width: 200,
          align: 'left',
          renderBodyCell: ({ row }) => (
            <div class="row--user-block">
              <div class="user-block">
                <h6 class="overflow-hidden text-base whitespace-nowrap text-ellipsis">
                  <woot-button
                    variant="clear"
                    onClick={() => this.onToggleEditQuestion(row)}
                  >
                    {row.question}
                  </woot-button>
                </h6>
  
                <div class="chip-container flex flex-wrap gap-4">
                  {row.answers.map((answer) => (
                    <div
                      key={answer.answer_id}
                      class="flex items-center bg-gray-100  px-4 py-2 m-2 text-sm"
                    >
                    <woot-button
                        v-tooltip="$t('INBOX_MGMT.DELETE.BUTTON_TEXT')"
                        variant="smooth"
                        color-scheme="alert"
                        size="tiny"
                        class-names="grey-btn px-2"
                        icon="dismiss-circle"
                        onClick={() => this.onDeleteAnswer(row, answer)}
                      />
                    
                      <woot-button
                        v-tooltip="$t('INBOX_MGMT.SETTINGS')"
                        variant="smooth"
                        size="tiny"
                        color-scheme="secondary"
                        class-names="grey-btn mr-4"
                        onClick={() => this.onEditAnswer(row, answer)}
                      >
                          {answer.answer}
  
                      </woot-button>
                      
                    </div>
                  ))}
                </div>
              </div>
            </div>
          ),
        },
        {
          field: 'question_id',
          key: 'question_id',
          title: '',
          width: 10,
          align: 'right',
          renderBodyCell: ({ row }) => (
            <div class="button-wrapper">
              <woot-button
                color-scheme="alert"
                variant="smooth"
                size="20"
                class-names="grey-btn"
                icon="delete"
                v-tooltip="Eliminar pregunta..."
                onClick={() => this.onToggleDeleteQuestion(row)}
              ></woot-button>
            </div>
          ),
        }
        ];
      },
    },
  };
  </script>
  
  <style lang="scss" scoped>
  @import '~dashboard/assets/scss/mixins';
  
  .vocabulario-table-wrap {
    flex: 1 1;
    height: 100%;
    overflow: hidden;
  }
  
  .vocabulario-table-wrap::v-deep {
    .ve-table {
      padding-bottom: var(--space-large);
    }
  
    .row--user-block {
      align-items: center;
      display: flex;
      text-align: left;
  
      .user-block {
        min-width: 0;
      }
  
      .user-thumbnail-box {
        margin-right: var(--space-small);
      }
  
      .user-name {
        font-size: var(--font-size-small);
        font-weight: var(--font-weight-medium);
        margin: 0;
        text-transform: capitalize;
      }
  
      .view-details--button {
        color: var(--color-body);
      }
  
      .user-email {
        margin: 0;
      }
    }
  
    .ve-table-header-th {
      padding: var(--space-small) var(--space-two) !important;
    }
  
    .ve-table-body-td {
      padding: var(--space-small) var(--space-two) !important;
    }
  
    .ve-table-header-th {
      font-size: var(--font-size-mini) !important;
    }
  
    .ve-table-sort {
      top: -4px;
    }
  }
  
  .contacts--loader {
    align-items: center;
    display: flex;
    font-size: var(--font-size-default);
    justify-content: center;
    padding: var(--space-big);
  }
  
  .cell--social-profiles {
    a {
      color: var(--s-300);
      display: inline-block;
      font-size: var(--font-size-medium);
      min-width: var(--space-large);
      text-align: center;
    }
  }
  </style>
  