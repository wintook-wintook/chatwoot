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
    expect(result[:modules].pluck(:key)).to eq(%w[cuenta perfil conversaciones contactos casos])
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

  describe 'configuración (se revisa en vivo con cómo está la cuenta)' do
    it 'se marca solo, aunque lo haya hecho otro y antes de entrar' do
      expect(step('cuenta', 'equipo')[:status]).to eq('pending')
      other # otro usuario en la cuenta
      expect(step('cuenta', 'equipo')).to include(status: 'done', level: 'required')
    end

    it 'cada quien con su rol: no cuenta el de por omisión' do
      au = account.account_users.find_by(user: other)
      expect(check('cuenta', 'roles')).to include(found: false, message: include('rol de por omisión'))
      au.update!(access_role: AccessRole.for_account(account).find { |r| r.key == 'viewer' })
      expect(check('cuenta', 'roles')[:found]).to be(true)
    end

    it 'una bandeja sin agentes no está lista' do
      inbox = create(:inbox, account: account)
      expect(step('cuenta', 'bandejas')[:status]).not_to eq('done')
      create(:inbox_member, inbox: inbox, user: user)
      expect(step('cuenta', 'bandejas')[:status]).to eq('done')
    end

    it 'lo de fábrica se acepta a mano, vale para la cuenta y se puede deshacer' do
      board.confirm('cuenta', 'etapas')
      otro_admin = create(:user, account: account, role: :administrator)
      other_board = described_class.new(account: account, user: otro_admin, grant: admin)
      etapas = other_board.call[:modules].first[:steps].find { |s| s[:key] == 'etapas' }
      expect(etapas).to include(status: 'done', confirmed_by: 'Ana Ruiz')

      other_board.confirm('cuenta', 'etapas', undo: true)
      expect(step('cuenta', 'etapas')[:status]).not_to eq('done')
    end

    it 'cambiar las etapas cuenta como hecho' do
      CaseType.ensure_defaults_for(account)
      expect(step('cuenta', 'etapas')[:status]).not_to eq('done')
      travel 1.hour do
        CaseTypeColumn.where(account_id: account.id).first.update!(label: 'Propuesta enviada')
        expect(described_class.new(account: account, user: user, grant: admin).call[:modules].first[:steps]
          .find { |s| s[:key] == 'etapas' }[:status]).to eq('done')
      end
    end

    it 'un paso sin «Así me sirve» no se acepta a mano' do
      expect { board.confirm('cuenta', 'bandejas') }.to raise_error(Academy::Board::NotFound)
    end

    it 'Tu perfil es de cada quien' do
      user.update!(message_signature: 'Ana · Ventas')
      expect(step('perfil', 'firma')[:status]).to eq('done')
      other_keys = described_class.new(account: account, user: other, grant: admin).call[:modules]
      expect(other_keys.find { |m| m[:key] == 'perfil' }[:steps].find { |s| s[:key] == 'firma' }[:status]).to eq('pending')
    end
  end

  it 'cada rol ve solo los módulos de sus áreas' do
    role = AccessRole.for_account(account).find { |r| r.key == 'technician' } # conversaciones, clientes, servicio
    au = account.account_users.find_by(user: other)
    au.update!(access_role: role)
    keys = described_class.new(account: account, user: other, grant: Access::Grant.for(au)).call[:modules].pluck(:key)
    expect(keys).to eq(%w[perfil conversaciones contactos casos]) # «Configura tu cuenta» es de administradores

    viewer = AccessRole.for_account(account).find { |r| r.key == 'viewer' }
    au.update!(access_role: viewer)
    expect(described_class.new(account: account, user: other, grant: Access::Grant.for(au.reload)).call[:modules].pluck(:key)).to eq(%w[perfil])
  end
end
