import helper from '../DashboardAudioNotificationHelper';

// diag/llamadas_whatsapp — la burbuja de una llamada no dispara la alerta de mensaje nuevo
// (taparía el timbre que eligió la bandeja).
describe('Alerta de mensaje nuevo', () => {
  beforeEach(() => {
    window.playAudioAlert = vi.fn();
    helper.isUserHasConversationPermission = () => true;
    helper.isMessageFromCurrentUser = () => false;
    helper.shouldNotifyOnMessage = () => true;
    helper.isMessageFromCurrentConversation = () => false;
    helper.playAudioEvery30Seconds = vi.fn();
    helper.playAlertOnlyWhenHidden = false;
  });

  it('un mensaje entrante suena', () => {
    helper.onNewMessage({ message_type: 0, content_type: 'text' });
    expect(window.playAudioAlert).toHaveBeenCalled();
  });

  it('la burbuja de una llamada no suena (la llamada tiene su timbre)', () => {
    helper.onNewMessage({ message_type: 0, content_type: 'voice_call' });
    expect(window.playAudioAlert).not.toHaveBeenCalled();
    expect(helper.playAudioEvery30Seconds).not.toHaveBeenCalled();
  });
});
