# frozen_string_literal: true

# == Schema Information
#
# Table name: case_ticket_relations
#
#  id                :bigint           not null, primary key
#  relation_type     :integer          default("duplicate"), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  related_ticket_id :bigint           not null
#  ticket_id         :bigint           not null
#
# Indexes
#
#  index_case_ticket_relations_on_account_id         (account_id)
#  index_case_ticket_relations_on_related_ticket_id  (related_ticket_id)
#  index_case_ticket_relations_unique                (ticket_id,related_ticket_id,relation_type) UNIQUE
#

# @tickets_cases 2E — Relación dirigida ticket → related_ticket.
# La semántica se lee desde ticket_id hacia related_ticket_id (ver RELATION_TYPES en i18n).
class CaseTicketRelation < ApplicationRecord
  belongs_to :account
  belongs_to :ticket,         class_name: 'CaseTicket'
  belongs_to :related_ticket, class_name: 'CaseTicket'

  enum relation_type: {
    duplicate:        0, # ticket es duplicado de related
    parent_child:     1, # ticket es padre de related
    incident_problem: 2, # ticket (incidente) pertenece a related (problema)
    incident_change:  3, # ticket (incidente) asociado a related (cambio)
    change_problem:   4  # ticket (cambio) resuelve related (problema)
  }

  validates :relation_type, presence: true
  validates :ticket_id, uniqueness: { scope: %i[related_ticket_id relation_type] }
  validate  :not_self_reference
  validate  :same_account
  validate  :no_inverse_duplicate

  private

  def not_self_reference
    errors.add(:related_ticket_id, 'no puede relacionarse consigo mismo') if ticket_id == related_ticket_id
  end

  def same_account
    return if ticket.blank? || related_ticket.blank?

    if ticket.account_id != related_ticket.account_id || ticket.account_id != account_id
      errors.add(:related_ticket_id, 'debe pertenecer a la misma cuenta')
    end
  end

  # Evita ciclo inmediato: si ya existe la relación inversa del mismo tipo (related → ticket),
  # no se permite crear la directa (ticket → related). Cubre duplicados y padre/hijo recíprocos.
  def no_inverse_duplicate
    return if ticket_id.blank? || related_ticket_id.blank?

    exists = CaseTicketRelation.where(
      ticket_id: related_ticket_id,
      related_ticket_id: ticket_id,
      relation_type: relation_type
    ).where.not(id: id).exists?
    errors.add(:base, 'La relación inversa ya existe') if exists
  end
end
