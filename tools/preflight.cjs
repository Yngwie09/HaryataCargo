'use strict';
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),errors=[];
const check=(ok,message)=>{if(!ok)errors.push(message);};
const configArg=process.argv.find(x=>x.startsWith('--config='));
let config;
try{config=JSON.parse(fs.readFileSync(path.resolve(root,configArg?configArg.slice(9):'config/local.json'),'utf8'));}
catch{errors.push('config/local.json belum tersedia / JSON tidak valid.');}
if(config){
  let url;try{url=new URL(config.API_BASE_URL);}catch{}
  check(url&&['https:','http:'].includes(url.protocol)&&!url.username&&!url.password&&!url.search&&!url.hash&&['','/'].includes(url.pathname),'Isi API_BASE_URL dengan alamat root API PostgreSQL, tanpa /v1 atau kredensial.');
  if(url&&url.protocol==='http:')check(/^(localhost|127\.0\.0\.1|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)/.test(url.hostname),'Server publik wajib HTTPS.');
  const key=process.argv.includes('--android')?'GOOGLE_MAPS_ANDROID_API_KEY':'GOOGLE_MAPS_WEB_API_KEY';
  check(typeof config[key]==='string'&&/^AIza[0-9A-Za-z_-]{35}$/.test(config[key]),`${key} belum valid / belum diisi.`);
}
if(process.argv.includes('--android')&&!process.argv.includes('--debug'))check(fs.existsSync(path.join(root,'android/key.properties')),'Signing release belum dikonfigurasi.');
if(process.argv.includes('--web')){
  check(!fs.existsSync(path.join(root,'build/web/PREVIEW_ONLY')),'Artefak hanya pratinjau. Build ulang dengan API PostgreSQL.');
  const html=path.join(root,'build/web/index.html');
  check(fs.existsSync(path.join(root,'build/web/maps-loader.js')),'Loader Maps belum masuk build web.');
  check(fs.existsSync(html),'Build web belum tersedia.');
  if(fs.existsSync(html))check(!fs.readFileSync(html,'utf8').includes('__GOOGLE_MAPS_WEB_API_KEY__'),'Placeholder Maps belum diganti. Gunakan tools/local.ps1.');
}
if(errors.length){console.error(errors.map(x=>'- '+x).join('\n'));process.exitCode=1;}
else console.log('Konfigurasi API PostgreSQL dan Maps lulus pemeriksaan awal.');
