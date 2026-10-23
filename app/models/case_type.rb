# frozen_string_literal: true

# == Schema Information
#
# Table name: case_types
#
#  id           :bigint           not null, primary key
#  case_class   :integer          default("support"), not null
#  color        :string           default("#3b82f6"), not null
#  itil_enabled :boolean          default(FALSE), not null
#  name         :string           not null
#  position     :integer          default(0), not null
#  prefix       :string           default(""), not null
#  public       :boolean          default(FALSE), not null
#  retired_at   :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#
# Indexes
#
#  index_case_types_on_account_id_and_case_class  (account_id,case_class)
#  index_case_types_on_account_id_and_position    (account_id,position)
#

class CaseType < ApplicationRecord
  belongs_to :account
  has_many   :case_tickets, dependent: :nullify
  has_many   :case_type_fields, dependent: :destroy # @tickets_cases 2K
  has_many   :case_type_columns, dependent: :destroy # @tickets_cases — columnas del Kanban por tipo
  # @tickets_cases — Plan-Clase-Comercial F2: clasificación propia del tipo (las
  # globales tienen case_type_id NULL y no se tocan). Se borra con el tipo (decisión E).
  has_many   :case_services, dependent: :destroy
  has_many   :case_categories, -> { where(parent_id: nil) }, dependent: :destroy, inverse_of: :case_type

  # @tickets_cases — Clase de caso (Plan-Clase-Comercial). Se guarda el entero:
  # valores nuevos SIEMPRE al final, igual que filter_type de CustomFilter (Trampa 17).
  enum case_class: { support: 0, commercial: 1, work_order: 2, project: 3 }, _prefix: :class

  # Plan-Clase-Orden-de-Trabajo F1 — lo que cada clase hace, en un solo lugar (en
  # vez de preguntar «¿es Comercial?» por todo el código):
  #   sla        → lleva metas de SLA y entra al monitor de SLA y a Métricas de Soporte;
  #   portal     → puede ser público en el portal y consultarse ahí por folio;
  #   bot_status → el bot @estado_ticket se lo informa al cliente.
  # Un caso sin tipo cuenta como Soporte.
  CLASS_CAPABILITIES = {
    'support' => %i[sla portal bot_status],
    'commercial' => [],
    'work_order' => %i[bot_status],
    'project' => %i[bot_status]
  }.freeze

  def self.classes_with(capability)
    CLASS_CAPABILITIES.select { |_klass, caps| caps.include?(capability) }.keys
  end

  def self.class_capability?(klass, capability)
    CLASS_CAPABILITIES.fetch((klass || 'support').to_s, []).include?(capability)
  end

  validates :name,  presence: true, length: { maximum: 100 }
  validates :color, presence: true
  # Hoja de ruta E1.4 — un tipo con casos no cambia de clase en su lugar (sus casos
  # la heredan). Para eso está Cases::TypeClassChange: crea el tipo en la otra clase
  # y retira este con sus casos tal cual. Sin casos sí se cambia directo.
  validate :case_class_unchanged, on: :update
  # El prefijo entra en el folio ({PREFIX}): fijo desde el primer caso del tipo.
  validate :prefix_unchanged, on: :update, if: :prefix_changed?

  scope :ordered, -> { order(:position, :id) }
  # Retirado (cambió de clase): sigue con sus casos, pero ya no se usa para crear nuevos.
  scope :active, -> { where(retired_at: nil) }
  # @tickets_cases — User Portal: tipos visibles en el formulario público del cliente.
  scope :public_only, -> { where(public: true, retired_at: nil) }

  before_validation :ensure_prefix, on: :create
  # Plan-Clase-Comercial F3 (hallazgo #6): solo las clases con portal (Soporte) se
  # ofrecen en el portal público; en las demás (una oportunidad, una orden) se apaga solo.
  before_validation -> { self.public = false }, unless: -> { CaseType.class_capability?(case_class, :portal) }
  # @tickets_cases — al crear un tipo se siembran columnas por defecto (espejo del
  # tablero fijo: simple 5 / ITIL 6, según el modo de la cuenta) como punto de
  # partida editable. El admin puede editarlas o borrarlas desde el panel.
  after_create :seed_default_columns
  # Sin casos se cambia la clase directo: las etapas pasan a ser las de la clase nueva.
  after_update :reseed_columns_for_new_class, if: :saved_change_to_case_class?

  # Tipos por defecto que se crean cuando una cuenta abre el módulo sin tipos.
  DEFAULTS = [
    { name: 'Soporte',               color: '#3b82f6', prefix: 'SOP' },
    { name: 'Comercial',             color: '#8b5cf6', prefix: 'COM' },
    { name: 'Implementación',        color: '#06b6d4', prefix: 'IMP' },
    { name: 'Seguimiento interno',   color: '#f59e0b', prefix: 'SEG' },
    { name: 'Incidente del sistema', color: '#ef4444', prefix: 'INC' }
  ].freeze

  # Crea los tipos por defecto para una cuenta si aún no tiene ninguno.
  # Retorna la colección de tipos de la cuenta.
  def self.ensure_defaults_for(account)
    return account.case_types.ordered if account.case_types.exists?

    DEFAULTS.each_with_index do |t, position|
      account.case_types.create!(name: t[:name], color: t[:color], prefix: t[:prefix], position: position)
    end
    account.case_types.ordered
  end

  def prefix_locked?
    persisted? && case_tickets.exists?
  end

  def retired?
    retired_at.present?
  end

  private

  # Si no se especifica prefijo, autogenera uno de las 3 primeras letras del nombre.
  def ensure_prefix
    return if prefix.present?

    self.prefix = name.to_s.gsub(/[^a-zA-Z]/, '').upcase[0, 3]
  end

  def case_class_unchanged
    return unless case_class_changed? && case_tickets.exists?

    errors.add(:case_class, 'no se cambia en un tipo con casos: usa «Cambiar de clase»')
  end

  def reseed_columns_for_new_class
    case_type_columns.destroy_all
    CaseTypeColumn.seed_defaults_for(self, itil: itil_enabled)
  end

  def prefix_unchanged
    errors.add(:prefix, 'no se puede cambiar: el tipo ya tiene casos con folio') if prefix_locked?
  end

  # Columnas por defecto según la clase (embudo comercial) o el modo (simple/ITIL) del tipo.
  def seed_default_columns
    CaseTypeColumn.seed_defaults_for(self, itil: itil_enabled)
  end
end
