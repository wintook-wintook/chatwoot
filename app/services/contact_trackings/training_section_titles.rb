# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — QUÉ SECCIONES OFRECER EN "AGREGAR SECCIÓN"
# ================================================================================
# Las del contrato del Asistente (las que conoce y valida) y, después, las que más usa
# la cuenta en sus agentes, sin repetir. Medido el 17/09/2026: 110 nombres distintos en
# 28 prompts — no puede haber una lista fija, y tampoco sirve ofrecer los 110.
# ================================================================================

class ContactTrackings::TrainingSectionTitles
  CONTRACT = ContactTrackings::Assistant::ProseChecks::SECTIONS.map { |s| s.delete('[]') }.freeze
  EXTRA = ['NO SIMULAR'].freeze
  MAX_FROM_ACCOUNT = 10

  def initialize(account)
    @account = account
  end

  def call
    sugeridas = (CONTRACT + EXTRA).uniq
    { suggested: sugeridas, from_account: account_titles.reject { |t| sugeridas.include?(t) }.first(MAX_FROM_ACCOUNT) }
  end

  private

  def account_titles
    conteo = Hash.new(0)
    @account.tracking_templates.find_each do |template|
      template.training_blocks['blocks'].to_a.each do |bloque|
        conteo[bloque['title'].to_s.upcase] += 1 if bloque['type'] == 'section' && bloque['title'].present?
      end
    end
    conteo.sort_by { |titulo, n| [-n, titulo] }.map(&:first)
  end
end
