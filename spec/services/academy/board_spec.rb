# frozen_string_literal: true

require 'rails_helper'

# Academia Kontrolya F1 — «Mi capacitación»: los ejercicios se revisan con los datos de verdad.
RSpec.describe Academy::Board do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :administrator, name: 'Ana Ruiz') }
  let(:other) { create(:user, account: account, role: :agent) }
  let(:admin) { Access::Grant.new(nil, nil) }
  let(:board) { described_class.new(account: account, user: user, grant: admin) }
  let(:practice) { Academy::Practice.new(account, user) }

  def step(mod, key) = board.call[:modules].find { |m| m[:key] == mod }[:steps].find { |s| s[:key] == key }
  def check(mod, key) = board.check(mod, key) # rubocop:disable Rails/Delegate

  it 'el catálogo está bien (guías, checks y pantallas existen)' do
    expect(Academy::Catalog.problems).to eq([])
  end

  it 'muestra los módulos con sus pasos pendientes' do
    result = board.call
    expect(result[:modules].pluck(:key)).to eq(%w[conversaciones contactos casos])
    expect(result[:done]).to eq(0)
    expect(step('contactos', 'nota')).to include(status: 'pending', blocked: true)
  end

  it 'una lección queda leída al abrirla' do
    board.start('conversaciones', 'leer')
    expect(step('conversaciones', 'leer')[:status]).to eq('done')
  end

  describe 'conversaciones (trabajo real: cuenta desde «Hazlo»)' do
    let(:conversation) { create(:conversation, account: account) }

    it 'una respuesta de antes no vale; una después sí' do
      create(:message, conversation: conversation, account: account, sender: user, message_type: :outgoing)
      board.start('conversaciones', 'responder')
      expect(check('conversaciones', 'responder')[:found]).to be(false)

      travel 1.minute do
        create(:message, conversation: conversation, account: account, sender: user, message_type: :outgoing)
        expect(check('conversaciones', 'responder')).to include(found: true)
      end
      expect(step('conversaciones', 'responder')).to include(status: 'done', attempts: 2)
    end

    it 'la primera vez que revisa sin «Hazlo» empieza a contar y se lo dice' do
      result = check('conversaciones', 'mencion')
      expect(result[:found]).to be(false)
      expect(result[:message]).to include('ya empezó a contar')
    end

    it 'la mención debe ir en nota privada, y ser suya' do
      board.start('conversaciones', 'mencion')
      travel 1.minute do
        create(:message, conversation: conversation, account: account, sender: other, private: true,
                         content: "Mira [@Ana](mention://user/#{user.id}/Ana)")
        expect(check('conversaciones', 'mencion')[:found]).to be(false)

        create(:message, conversation: conversation, account: account, sender: user, private: true,
                         content: "Ayúdame [@Beto](mention://user/#{other.id}/Beto)")
        expect(check('conversaciones', 'mencion')[:found]).to be(true)
      end
    end
  end

  describe 'contactos y casos (sobre su Cliente de práctica)' do
    it 'recorre los ejercicios de punta a punta' do # rubocop:disable RSpec/MultipleExpectations
      expect(check('contactos', 'practica')[:found]).to be(false)
      contact = practice.create!
      expect(contact).to have_attributes(owner_id: user.id, phone_number: nil, email: nil)
      expect(check('contactos', 'practica')[:found]).to be(true)

      contact.update!(organization: Organization.create!(account: account, name: 'Empresa de práctica'))
      expect(check('contactos', 'organizacion')[:found]).to be(true)

      contact.notes.create!(account: account, user: other, content: 'de otro')
      expect(check('contactos', 'nota')[:found]).to be(false)
      contact.notes.create!(account: account, user: user, content: 'Le interesa el plan anual')
      expect(check('contactos', 'nota')[:found]).to be(true)

      expect(step('casos', 'tarea')[:blocked]).to be(true)
      ticket = CaseTicket.create!(account: account, title: 'Plan anual', contact: contact)
      expect(check('casos', 'caso')[:found]).to be(true)
      expect(step('casos', 'tarea')).to include(blocked: false, path: "tickets/#{ticket.id}")

      task = ticket.case_tasks.create!(account: account, title: 'Mandar la propuesta')
      CaseEvent.create!(account: account, case_ticket: ticket, actor: user, event_type: :task_created, origin: :agent,
                        case_task: task)
      expect(check('casos', 'tarea')[:found]).to be(true)

      expect(check('casos', 'etapa')[:found]).to be(false)
      CaseEvent.create!(account: account, case_ticket: ticket, actor: user, event_type: :column_changed, origin: :agent)
      expect(check('casos', 'etapa')[:found]).to be(true)

      starts = 1.day.from_now
      CaseMeeting.create!(account: account, case_ticket: ticket, title: 'Llamada', starts_at: starts, ends_at: starts + 30.minutes,
                          organizer: user)
      expect(check('casos', 'agendar')[:found]).to be(true)
    end

    it 'el Cliente de práctica es de cada quien' do
      Academy::Practice.new(account, other).create!
      expect(practice.contact).to be_nil
      expect(check('contactos', 'practica')[:found]).to be(false)
    end

    it 'borrar la práctica quita el contacto, sus casos y la organización si solo era suya' do
      contact = practice.create!
      org = Organization.create!(account: account, name: 'Empresa de práctica')
      contact.update!(organization: org)
      ticket = CaseTicket.create!(account: account, title: 'Plan anual', contact: contact)

      expect(practice.destroy!).to be(true)
      expect(Contact.exists?(contact.id)).to be(false)
      expect(CaseTicket.exists?(ticket.id)).to be(false)
      expect(Organization.exists?(org.id)).to be(false)
    end
  end

  it 'cada rol ve solo los módulos de sus áreas' do
    role = AccessRole.for_account(account).find { |r| r.key == 'technician' } # conversaciones, clientes, servicio
    au = account.account_users.find_by(user: other)
    au.update!(access_role: role)
    keys = described_class.new(account: account, user: other, grant: Access::Grant.for(au)).call[:modules].pluck(:key)
    expect(keys).to eq(%w[conversaciones contactos casos])

    viewer = AccessRole.for_account(account).find { |r| r.key == 'viewer' }
    au.update!(access_role: viewer)
    expect(described_class.new(account: account, user: other, grant: Access::Grant.for(au.reload)).call[:modules]).to eq([])
  end
end
