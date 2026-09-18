# frozen_string_literal: true

require 'rails_helper'

# proyecto@predefinidas_prompt — docs/predefinidas_prompt_plan.md §3.7
RSpec.describe KnowledgeBase::CannedPrompt do
  let(:account) { create(:account) }
  let(:source)  { create(:knowledge_source, account: account, source_type: 'canned_response') }

  def canned(**attrs)
    create(:canned_response, account: account, short_code: 'COTIZACION', content: 'Equipos Dell y HP.', **attrs)
  end

  def item_for(canned_response)
    build(:knowledge_item, account: account, knowledge_source: source, source_type: 'canned_response',
                           source_id: canned_response.id, title: canned_response.short_code)
  end

  describe '.detect' do
    it 'el mensaje es el prompt aunque también tenga Prompt de Contenido' do
      prompt = described_class.detect(account, [item_for(canned(content_is_prompt: true, content_prompts: 'otra cosa'))])

      expect(prompt.mode).to eq(:message_is_prompt)
      expect(prompt.instructions).to eq('Equipos Dell y HP.')
      expect(prompt.information).to eq('')
    end

    it 'con Prompt de Contenido, el mensaje es la información' do
      prompt = described_class.detect(account, [item_for(canned(content_prompts: 'Pedí la cantidad.'))])

      expect(prompt.mode).to eq(:content_prompt)
      expect(prompt.instructions).to eq('Pedí la cantidad.')
      expect(prompt.information).to eq('Equipos Dell y HP.')
    end

    it 'sin prompt (o solo espacios), como siempre' do
      expect(described_class.detect(account, [item_for(canned)])).to be_nil
      expect(described_class.detect(account, [item_for(canned(short_code: 'ESPACIOS', content_prompts: "  \n"))])).to be_nil
    end

    it 'solo cuenta la primera: el prompt de la segunda no aplica' do
      items = [item_for(canned), item_for(canned(short_code: 'OTRA', content_is_prompt: true))]

      expect(described_class.detect(account, items)).to be_nil
    end

    it 'no aplica a otras fuentes ni a respuestas de otra cuenta' do
      article = build(:knowledge_item, account: account, knowledge_source: source, source_type: 'article', source_id: 1)
      ajena   = create(:canned_response, content_is_prompt: true)

      expect(described_class.detect(account, [article])).to be_nil
      expect(described_class.detect(account, [item_for(ajena)])).to be_nil
      expect(described_class.detect(account, [])).to be_nil
    end
  end

  describe '#leaks?' do
    let(:prompt) do
      described_class.new(:content_prompt, canned(content_prompts: <<~TXT))
        Esta es la respuesta que darás si alguien te pregunta por el precio de equipo de cómputo.
        Respondé: "Con gusto te preparo una cotización con los equipos que necesitas hoy mismo"
      TXT
    end

    it 'descarta la respuesta que copia las instrucciones (sin importar tildes ni mayúsculas)' do
      expect(prompt.leaks?('Claro. ESTA ES LA RESPUESTA QUE DARAS si alguien te pregunta por el precio.')).to be(true)
    end

    it 'lo que va entre comillas es para decirlo: copiarlo no es filtrar' do
      expect(prompt.leaks?('Hola Ana, con gusto te preparo una cotización con los equipos que necesitas hoy mismo.'))
        .to be(false)
    end

    it 'una respuesta propia no es filtración' do
      expect(prompt.leaks?('¿Qué equipo necesitas y cuántas unidades?')).to be(false)
    end
  end

  describe '.resume' do
    let(:conversation) { create(:conversation, account: account) }
    let(:guion) { canned(content_is_prompt: true) }

    def en_curso(**over)
      state = { 'id' => guion.id, 'route' => 'comercial', 'turns' => 2, 'at' => Time.current.iso8601 }.merge(over)
      conversation.update!(additional_attributes: { 'kb_canned_prompt' => state })
    end

    it 'retoma el guion, aunque el mensaje haya caído en otra ruta' do
      en_curso
      prompt = described_class.resume(account, conversation, [])

      expect(prompt.canned).to eq(guion)
      expect(prompt).to be_continuing
    end

    it 'lo suelta si llegó al tope de mensajes, venció o la respuesta ya no tiene prompt' do
      en_curso('turns' => described_class::MAX_TURNS)
      expect(described_class.resume(account, conversation, [])).to be_nil

      en_curso('at' => 25.hours.ago.iso8601)
      expect(described_class.resume(account, conversation, [])).to be_nil

      en_curso
      guion.update!(content_is_prompt: false)
      expect(described_class.resume(account, conversation, [])).to be_nil
    end

    it 'recuerda y olvida sin tocar el resto de los atributos' do
      conversation.update!(additional_attributes: { 'kb_history' => [1] })
      prompt = described_class.detect(account, [item_for(guion)])

      prompt.remember!(conversation, 'comercial')
      expect(conversation.reload.additional_attributes['kb_canned_prompt']).to include('id' => guion.id, 'turns' => 1)

      described_class.forget!(conversation)
      expect(conversation.reload.additional_attributes).to eq('kb_history' => [1])
    end
  end

  describe '#closes?' do
    it 'cierra con una etiqueta que el guion nombra, sin importar mayúsculas' do
      prompt = described_class.new(:message_is_prompt, canned(content: 'Al final usa #solicita_cotizacion.'))

      expect(prompt.closes?("Listo.\n#Solicita_Cotizacion")).to be(true)
      expect(prompt.closes?("Listo.\n#comercial2")).to be(false)
      expect(prompt.closes?('¿Qué equipo necesitas?')).to be(false)
    end
  end
end
