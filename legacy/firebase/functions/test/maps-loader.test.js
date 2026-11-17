'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const path=require('node:path');
const source=fs.readFileSync(path.resolve(__dirname,'../../web/maps-loader.js'),'utf8');
function boot(key) {
  const scripts=[];let timeout;
  const window={};
  const context={window,URLSearchParams,setTimeout:fn=>{timeout=fn;return 1;},clearTimeout:()=>{},
    document:{currentScript:{dataset:{apiKey:key}},createElement:()=>({}),head:{appendChild:s=>scripts.push(s)}}};
  vm.runInNewContext(source,context);
  return {window,scripts,timeout:()=>timeout?.()};
}
test('Maps tanpa key tidak memanggil API Google',()=>{
  const r=boot('__GOOGLE_MAPS_WEB_API_KEY__');assert.equal(r.window.cargoMapsState,'missing-key');assert.equal(r.scripts.length,0);
});
test('Maps memuat SDK asinkron dan siap setelah callback Google',()=>{
  const r=boot('test-key');assert.equal(r.scripts.length,1);assert.equal(r.scripts[0].async,true);
  assert.match(r.scripts[0].src,/maps.googleapis.com/);assert.match(r.scripts[0].src,/callback=cargoMapsReady/);
  assert.equal(r.window.cargoMapsState,'loading');r.window.cargoMapsReady();assert.equal(r.window.cargoMapsState,'ready');
});
test('error jaringan tidak menghentikan bootstrap aplikasi',()=>{
  const r=boot('test-key');r.scripts[0].onerror();assert.equal(r.window.cargoMapsState,'network-error');
});
test('key/billing/domain ditolak tetap error meski callback siap datang terlambat',()=>{
  const r=boot('test-key');r.window.gm_authFailure();r.window.cargoMapsReady();assert.equal(r.window.cargoMapsState,'auth-error');
});
test('SDK macet menjadi error; koneksi terlambat yang pulih dapat menjadi siap',()=>{
  const r=boot('test-key');r.timeout();assert.equal(r.window.cargoMapsState,'network-error');r.window.cargoMapsReady();assert.equal(r.window.cargoMapsState,'ready');
});
