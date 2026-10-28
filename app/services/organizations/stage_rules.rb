# Plan-Organizaciones O3 — lo que pasa una organización a prospecto o a cliente sola.
# Cada regla se enciende en Ventas › Parámetros de ventas (case_settings.organization_rules).
#
#   prospect_on_opportunity      se crea una oportunidad (incluye «Convertido» del Embudo de
#                                contactos, que la crea) para un contacto sin organización
#   prospect_on_quote_sent       se envía una cotización a un contacto sin organización
#   customer_on_won              se gana una oportunidad
#   customer_on_contract         se da de alta un contrato
#   customer_on_quote_accepted   se acepta una cotización
#
# A prospecto: crea la organización del contacto (su empresa escrita o público en general)
# y la liga. A cliente: cambia la etapa de la organización del registro (o la crea ya como
# cliente si no tenía). Nunca regresa a prospecto ni mueve otra cosa. Lo que haga queda en
# la bitácora con el motivo. Un error aquí no detiene lo que lo disparó.
class Organizations::StageRules
  RULES = %w[prospect_on_opportunity prospect_on_quote_sent customer_on_won customer_on_contract
             customer_on_quote_accepted].freeze

  def self.call(rule, record)
    new(rule, record).call
  rescue StandardError => e
    Rails.logger.error("[Organizations::StageRules] #{rule} #{record.class.name}##{record.id}: #{e.message}")
    nil
  end

  def initialize(rule, record)
    @rule = rule.to_s
    @record = record
    @contact = record.contact
  end

  def call
    return unless @contact && enabled?

    @rule.start_with?('prospect') ? make_prospect : make_customer
  end

  private

  def enabled?
    CaseSetting.for_account(@record.account).organization_rules.to_h[@rule] == true
  end

  def make_prospect
    return if @contact.organization_id

    link(create_organization(:prospect))
  end

  def make_customer
    organization = @record.organization || @contact.organization
    return link(create_organization(:customer)) if organization.nil?

    organization.change_stage!(:customer, nil, reason: @rule) if organization.prospect?
  end

  def create_organization(stage)
    organization = Organization.build_for(@contact, stage: stage)
    organization.save!
    organization.events.create!(action: 'created', data: { to: stage.to_s, reason: @rule })
    organization
  end

  def link(organization)
    @contact.update!(organization: organization) if @contact.organization_id.nil?
    @record.update_columns(organization_id: organization.id) if @record.organization_id.nil? # rubocop:disable Rails/SkipsModelValidations
    organization
  end
end
