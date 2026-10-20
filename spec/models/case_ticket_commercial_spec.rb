# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — Plan-Clase-Comercial F3: oportunidades (resultado, motivos,
# pospuestas, embudo) y las protecciones de los hallazgos #2–#8.
RSpec.describe CaseTicket, 'oportunidades comerciales' do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:venta)   { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial) }
  let(:soporte) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let!(:lost_reason) { CaseOutcomeReason.ensure_defaults_for(account).find_by(outcome: :lost, label: 'Precio') }

  def opportunity(attrs = {})
    described_class.create!({ account: account, title: 'Licencias', contact: contact, case_type: venta }.merge(attrs))
  end

  def reason(outcome)
    account.case_outcome_reasons.where(outcome: outcome).ordered.first
  end

  def column(label)
    venta.case_type_columns.find_by!(label: label)
  end

  describe 'alta' do
    it 'un tipo Comercial nace con el embudo y nunca es público' do
      venta.update!(public: true)
      expect(venta.reload.public).to be(false)
      expect(venta.case_type_columns.ordered.pluck(:label))
        .to eq(%w[Prospecto Calificado Propuesta Negociación Pospuesta Ganada Perdida Cancelada])
      expect(column('Ganada').outcome).to eq('won')
    end

    it 'no hay oportunidad sin cliente' do
      requester = create(:user, account: account)
      opp = described_class.new(account: account, title: 'Interna', case_type: venta, requester: requester)
      expect(opp).not_to be_valid
      expect(opp.errors[:contact_id]).to be_present
    end

    it 'toma la moneda de la cuenta, la probabilidad de la primera etapa y no lleva SLA' do
      opp = opportunity(amount: 1500, impact: :high, urgency: :high, priority: :low)
      expect(opp.currency).to eq('MXN')
      expect(opp.probability).to eq(10)
      expect(opp.resolution_time_target).to be_nil
      expect(opp.priority).to eq('low') # la matriz ITIL no la pisa
    end
  end

  describe 'cierre con resultado' do
    it 'ganada: con motivo, probabilidad 100 y en la columna Ganada' do
      opp = opportunity(status: :in_progress)
      opp.close_with_outcome!(:won, reason_id: reason(:won).id)
      expect(opp.reload).to have_attributes(status: 'closed', outcome: 'won', probability: 100,
                                            case_type_column_id: column('Ganada').id)
      expect(opp.case_events.last.event_type).to eq('outcome_set')
    end

    it 'perdida exige un motivo del catálogo del mismo resultado' do
      opp = opportunity(status: :in_progress)
      expect { opp.close_with_outcome!(:lost) }.to raise_error(/motivo/)
      cancel_reason = account.case_outcome_reasons.find_by(outcome: :cancelled, label: 'Duplicada')
      expect { opp.close_with_outcome!(:lost, reason_id: cancel_reason.id) }.to raise_error(/no corresponde/)

      opp.close_with_outcome!(:lost, reason_id: lost_reason.id, note: 'Más caro que X')
      expect(opp.reload).to have_attributes(outcome: 'lost', outcome_reason_id: lost_reason.id, probability: 0)
      expect(opp.case_events.last.payload).to include('outcome' => 'lost', 'outcome_reason' => 'Precio')
    end

    it 'no se resuelve ni se cancela como un ticket' do
      opp = opportunity(status: :in_progress)
      expect { opp.transition!(:resolved) }.to raise_error(CaseTicket::COMMERCIAL_STATUS_MSG)
      expect { opp.transition!(:cancelled) }.to raise_error(CaseTicket::COMMERCIAL_STATUS_MSG)
    end

    it 'reabrir borra el resultado, lo deja en el evento y no mira la ventana (#2)' do
      CaseSetting.for_account(account).update!(reopen_window_days: 1)
      opp = opportunity(status: :in_progress)
      opp.close_with_outcome!(:lost, reason_id: lost_reason.id)
      opp.update_columns(closed_at: 1.year.ago)

      expect(opp.within_reopen_window?).to be(true)
      opp.reopen!(reason: 'Volvió a interesarse')
      expect(opp.reload).to have_attributes(status: 'in_progress', outcome: nil, outcome_reason_id: nil)
      expect(opp.case_events.last.payload).to include('previous_outcome' => 'lost')
    end
  end

  describe 'catálogo de motivos' do
    it 'siembra los cuatro catálogos y completa los que falten en una cuenta existente' do
      expect(account.case_outcome_reasons.distinct.pluck(:outcome)).to match_array(%w[won lost postponed cancelled])

      account.case_outcome_reasons.where(outcome: %w[won postponed]).delete_all
      CaseOutcomeReason.ensure_defaults_for(account)
      expect(account.case_outcome_reasons.outcome_won).to exist
      expect(account.case_outcome_reasons.outcome_postponed).to exist
      expect(account.case_outcome_reasons.outcome_lost.count).to eq(5) # no duplica lo que ya había
    end

    it 'ganada exige motivo si hay catálogo de ganadas activo, y no lo exige si no hay' do
      opp = opportunity(status: :in_progress)
      expect { opp.close_with_outcome!(:won) }.to raise_error(/motivo/)

      account.case_outcome_reasons.outcome_won.update_all(active: false)
      opp.close_with_outcome!(:won)
      expect(opp.reload.outcome).to eq('won')
    end

    it 'posponer exige un motivo de pospuesta y se limpia al retomar' do
      opp = opportunity(status: :in_progress)
      date = 1.week.from_now.to_date
      expect { opp.postpone!(until_date: date) }.to raise_error(/motivo de la pospuesta/)
      expect { opp.postpone!(until_date: date, reason_id: lost_reason.id) }.to raise_error(/no corresponde/)

      opp.postpone!(until_date: date, reason_id: reason(:postponed).id)
      expect(opp.reload.postpone_reason).to eq(reason(:postponed))
      expect(opp.case_events.last.payload).to include('reason_label' => reason(:postponed).label)

      opp.resume!
      expect(opp.reload.postpone_reason_id).to be_nil
    end
  end

  describe 'pospuesta' do
    it 'posponer y retomar regresa a la etapa donde estaba' do
      opp = opportunity(status: :in_progress)
      opp.update!(case_type_column_id: column('Propuesta').id)
      expect(opp.probability).to eq(50)

      expect { opp.postpone!(until_date: Date.current) }.to raise_error(/fecha futura/)
      opp.postpone!(until_date: 1.week.from_now.to_date, reason: 'Presupuesto en enero', reason_id: reason(:postponed).id)
      expect(opp.reload).to be_postponed
      expect(opp.case_type_column_id).to eq(column('Pospuesta').id)

      opp.resume!
      expect(opp.reload).to have_attributes(status: 'in_progress', postponed_until: nil,
                                            case_type_column_id: column('Propuesta').id)
    end

    it 'el job retoma las que ya llegaron a su fecha' do
      opp = opportunity(status: :in_progress)
      opp.postpone!(until_date: 2.days.from_now.to_date, reason_id: reason(:postponed).id)
      opp.update_columns(postponed_until: Date.current)

      Cases::ResumePostponedJob.perform_now
      expect(opp.reload).to have_attributes(status: 'in_progress', postponed_until: nil)
    end
  end

  describe 'protecciones' do
    it 'el bot de estado y el portal no ven oportunidades (#6)' do
      opportunity
      ticket = described_class.create!(account: account, title: 'Falla', contact: contact, case_type: soporte)
      # Acotado a la cuenta: el entorno test usa la base de desarrollo (Trampa 19).
      expect(account.case_tickets.non_commercial).to contain_exactly(ticket)
      expect(account.case_tickets.commercial.count).to eq(1)
    end

    it 'una automatización con tipo de otra clase abre un caso nuevo (#4)' do
      conversation = create(:conversation, account: account, contact: contact)
      ticket = described_class.create!(account: account, title: 'Falla', contact: contact,
                                       conversation: conversation, case_type: soporte)

      ActionService.new(conversation).send(:assign_case_type, [venta.id])
      expect(ticket.reload.case_type_id).to eq(soporte.id)
      expect(conversation.case_tickets.where(case_type: venta).count).to eq(1)
    end

    it 'la respuesta del cliente reabre el más reciente y avisa en el de otra clase (#3)' do
      conversation = create(:conversation, account: account, contact: contact)
      ticket = described_class.create!(account: account, title: 'Falla', contact: contact,
                                       conversation: conversation, case_type: soporte)
      ticket.update_columns(status: described_class.statuses[:closed], closed_at: 2.days.ago)
      opp = opportunity(conversation: conversation, status: :in_progress)
      opp.close_with_outcome!(:won, reason_id: reason(:won).id)

      message = create(:message, account: account, conversation: conversation, message_type: :incoming)
      CaseTicketListener.instance.message_created(Events::Base.new('message.created', Time.zone.now, message: message))

      expect(opp.reload.status).to eq('in_progress')
      expect(ticket.reload.status).to eq('closed')
      expect(ticket.case_events.last).to have_attributes(event_type: 'message_received')
    end
  end
end
