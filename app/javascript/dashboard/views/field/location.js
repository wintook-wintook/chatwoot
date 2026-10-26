// Plan-Trabajo-Campo R2 — la ubicación del celular solo al llegar y al terminar
// (no se rastrea). Si el técnico no da permiso o tarda, se sigue sin ubicación.
export const currentLocation = () =>
  new Promise(resolve => {
    if (!navigator.geolocation) {
      resolve({});
      return;
    }
    navigator.geolocation.getCurrentPosition(
      ({ coords }) =>
        resolve({
          lat: coords.latitude,
          lng: coords.longitude,
          accuracy: coords.accuracy,
        }),
      () => resolve({}),
      { enableHighAccuracy: true, timeout: 10000, maximumAge: 60000 }
    );
  });

export const mapsUrl = address =>
  `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(
    address || ''
  )}`;

export const whatsappUrl = phone =>
  `https://wa.me/${String(phone || '').replace(/\D/g, '')}`;
