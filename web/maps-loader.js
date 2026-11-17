'use strict';
(() => {
  const key = document.currentScript?.dataset.apiKey || '';
  window.cargoMapsState = 'loading';
  if (!key || key.includes('__GOOGLE_MAPS') || key.includes('YOUR_')) {
    window.cargoMapsState = 'missing-key';
    return;
  }
  const timeout = setTimeout(() => {
    if (window.cargoMapsState === 'loading') window.cargoMapsState = 'network-error';
  }, 25000);
  window.gm_authFailure = () => { clearTimeout(timeout); window.cargoMapsState = 'auth-error'; };
  window.cargoMapsReady = () => {
    clearTimeout(timeout);
    if (window.cargoMapsState !== 'auth-error') window.cargoMapsState = 'ready';
  };
  const script = document.createElement('script');
  script.src = 'https://maps.googleapis.com/maps/api/js?' + new URLSearchParams({ key, loading: 'async', callback: 'cargoMapsReady' });
  script.async = true;
  script.onerror = () => { clearTimeout(timeout); window.cargoMapsState = 'network-error'; };
  document.head.appendChild(script);
})();
