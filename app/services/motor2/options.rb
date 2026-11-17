# frozen_string_literal: true

# Motor 2.0 — lo que la cuenta le puede dar a un agente, para la ficha: las tarjetas de fuentes
# y agendas (ContactTrackings::Ficha::Catalog, el del 1.0 tal cual), tipos de caso, usuarios y
# equipos (a quién pasar), y bandejas.
class Motor2::Options
  SOURCE_KINDS = %w[sheet doc articles canned forum contpaq discourse].freeze

  def initialize(account, inbox: nil, template: nil)
    @account = account
    @inbox = inbox
    @template = template
  end

  def call
    cards = catalog.call
    { sources: cards.select { |c| SOURCE_KINDS.include?(c[:kind]) }, calendars: cards.select { |c| c[:kind] == 'calendar' },
      **people, case_types: case_types, business: AgentBase::BusinessData.lines(@account),
      inboxes: @account.inboxes.order(:name).map { |i| { id: i.id, name: i.name, channel_type: i.channel_type } } }
  end

  # «¿Listo para atender?» del 1.0 con las fuentes que marcó la ficha 2.0.
  def self.readiness(template)
    cards = ContactTrackings::Ficha::Catalog.new(template.account, inbox: template.inbox, template: template).call
    sources = [Motor2::Search::CANNED, *template.motor2.to_h['sources']] # las predefinidas van siempre
    business = business_text(template)
    ContactTrackings::Ficha::Readiness.new(template.account, offers: cards.select { |c| sources.include?(c[:key]) }, template: template,
                                                             ai_context: template.ai_context.presence || business.presence)
  end

  def self.business_text(template)
    own = Array(template.motor2.to_h['business']).map { |r| r.to_h.values.join(': ') }
    (AgentBase::BusinessData.lines(template.account) + own).join("\n")
  end

  private

  def people
    { users: @account.users.order(:name).map { |u| { id: u.id, name: u.available_name || u.name } },
      teams: @account.teams.order(:name).map { |t| { id: t.id, name: t.name } } }
  end

  def case_types
    @account.case_types.active.order(:position).map { |t| { id: t.id, name: t.name, case_class: t.case_class } }
  end

  def catalog = ContactTrackings::Ficha::Catalog.new(@account, inbox: @inbox, template: @template)
end
