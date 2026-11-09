// Portal de Dali — avisos push en este teléfono (también con la app cerrada).
// El permiso se pide al tocar un botón (iPhone lo exige, y solo con Dali instalado en
// la pantalla de inicio). La suscripción va a assistant/push_subscription.
import AssistantAPI from 'dashboard/api/platformAssistant';
import { getPushSubscriptionPayload } from './pushHelper';

const KEY = 'kontrolya.dali.push';

const read = () => {
  try {
    return window.localStorage.getItem(KEY);
  } catch {
    return null;
  }
};

const write = value => {
  try {
    window.localStorage.setItem(KEY, value);
  } catch {
    // Sin almacenamiento: se vuelve a ofrecer la próxima vez.
  }
};

export const pushSupported = () =>
  'serviceWorker' in navigator &&
  'PushManager' in window &&
  'Notification' in window &&
  !!window.chatwootConfig?.vapidPublicKey;

// unsupported | denied | on (activado aquí desde Dali) | off (falta activarlo)
export const daliPushState = () => {
  if (!pushSupported()) return 'unsupported';
  if (Notification.permission === 'denied') return 'denied';
  if (Notification.permission === 'granted' && read() === 'on') return 'on';
  return 'off';
};

// «Ahora no» en el ofrecimiento: no se vuelve a ofrecer solo (sigue en el menú).
export const offerDismissed = () => read() === 'dismissed';
export const dismissOffer = () => write('dismissed');

// → 'on' | 'denied' | 'unsupported'. Lanza si el servidor no la guarda.
export const enableDaliPush = async () => {
  if (!pushSupported()) return 'unsupported';
  const permission = await Notification.requestPermission();
  if (permission !== 'granted') return 'denied';
  await navigator.serviceWorker.register('/sw.js');
  const registration = await navigator.serviceWorker.ready;
  const subscription =
    (await registration.pushManager.getSubscription()) ||
    (await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: window.chatwootConfig.vapidPublicKey,
    }));
  const { subscription_attributes: keys } =
    getPushSubscriptionPayload(subscription);
  await AssistantAPI.pushSubscription(keys);
  write('on');
  return 'on';
};

// El globito con el número en el ícono instalado (Android y iPhone con la app instalada).
export const setAppBadge = count => {
  try {
    if (count > 0) navigator.setAppBadge?.(count);
    else navigator.clearAppBadge?.();
  } catch {
    // No soportado: no pasa nada.
  }
};
