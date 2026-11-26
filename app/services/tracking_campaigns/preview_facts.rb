# frozen_string_literal: true

# Campaña con IA · Reactivar y Recordar — en la muestra de la audiencia, lo último que compró o lo que le vence a cada
# contacto (los de la página; TrackingCampaigns::ContactFacts), para ver a quién le va a llegar qué.
module TrackingCampaigns::PreviewFacts
  KEYS = %w[last_purchase days_since due_what due_date due_amount].freeze
  LIMIT = 100 # una página de «A quién» (TrackingCampaigns::AudiencePage)

  module_function

  def call(account, result)
    return result unless result[:contacts].is_a?(Array)

    contacts = account.contacts.where(id: result[:contacts].first(LIMIT).pluck(:id)).index_by(&:id)
    result.merge(contacts: result[:contacts].map { |row| with_facts(row, contacts[row[:id]]) })
  end

  def with_facts(row, contact)
    contact ? row.merge(facts: TrackingCampaigns::ContactFacts.new(contact).values.slice(*KEYS)) : row
  end
end
