// ---------- IndexedDB ----------
const DB_NAME = 'troupeCallingScanDB';
const DB_VERSION = 1;
let db;

function openDB(){
  return new Promise((resolve, reject)=>{
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = (e)=>{
      const d = e.target.result;
      if(!d.objectStoreNames.contains('roster')) d.createObjectStore('roster', { keyPath: 'qrToken' });
      if(!d.objectStoreNames.contains('attendance')){
        const store = d.createObjectStore('attendance', { keyPath: 'id' });
        store.createIndex('byDate', 'date', { unique: false });
      }
      if(!d.objectStoreNames.contains('settings')) d.createObjectStore('settings', { keyPath: 'key' });
    };
    req.onsuccess = (e)=> resolve(e.target.result);
    req.onerror = (e)=> reject(e.target.error);
  });
}
function tx(store, mode){ return db.transaction(store, mode).objectStore(store); }
function p(req){ return new Promise((resolve, reject)=>{ req.onsuccess=()=>resolve(req.result); req.onerror=()=>reject(req.error); }); }

async function getSetting(key, fallback){ const r = await p(tx('settings','readonly').get(key)); return r ? r.value : fallback; }
async function setSetting(key, value){ await p(tx('settings','readwrite').put({ key, value })); }

async function getRoster(){
  const all = await p(tx('roster','readonly').getAll());
  return all.sort((a,b)=> a.nom.localeCompare(b.nom, 'fr'));
}
async function replaceRoster(scouts){
  const store = tx('roster','readwrite');
  await new Promise((resolve, reject)=>{
    const clearReq = store.clear();
    clearReq.onsuccess = resolve;
    clearReq.onerror = ()=>reject(clearReq.error);
  });
  const store2 = tx('roster','readwrite');
  for(const s of scouts){ store2.put(s); }
}

async function getAttendanceForDate(date){
  return new Promise((resolve, reject)=>{
    const idx = tx('attendance','readonly').index('byDate');
    const req = idx.getAll(IDBKeyRange.only(date));
    req.onsuccess = ()=> resolve(req.result);
    req.onerror = ()=> reject(req.error);
  });
}
async function markAttendance(date, qrToken, time){
  await p(tx('attendance','readwrite').put({ id: date+'::'+qrToken, date, qrToken, time }));
}
async function unmarkAttendance(date, qrToken){
  await p(tx('attendance','readwrite').delete(date+'::'+qrToken));
}

// ---------- State ----------
let roster = [];
let attendanceMap = {};
let stream = null;
let scanning = false;
let scanCameraActive = false;
let lastScanId = null;
let lastScanTime = 0;

function todayStr(){ const d=new Date(); return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0'); }
function toast(msg){
  const t = document.getElementById('toast');
  t.textContent = msg; t.classList.add('show');
  clearTimeout(t._timer);
  t._timer = setTimeout(()=>t.classList.remove('show'), 2200);
}
function displayName(s){ return (s.prenom + ' ' + s.nom).trim(); }

// ---------- Navigation ----------
document.querySelectorAll('.nav-btn').forEach(btn=>{
  btn.addEventListener('click', ()=>{
    document.querySelectorAll('.nav-btn').forEach(b=>b.classList.remove('active'));
    btn.classList.add('active');
    document.querySelectorAll('.view').forEach(v=>v.classList.remove('active'));
    document.getElementById('view-'+btn.dataset.view).classList.add('active');
    if(btn.dataset.view === 'scan'){ refreshScanView(); startScan(); }
    else stopScan();
    if(btn.dataset.view === 'historique') refreshHistorique();
    if(btn.dataset.view === 'roster') renderRosterList();
  });
});

// ---------- Import trombinoscope ----------
document.getElementById('fileInput').addEventListener('change', (e)=>{
  const file = e.target.files[0];
  if(!file) return;
  const reader = new FileReader();
  reader.onload = ()=> { document.getElementById('jsonPaste').value = reader.result; };
  reader.readAsText(file);
});

document.getElementById('importBtn').addEventListener('click', async ()=>{
  const raw = document.getElementById('jsonPaste').value.trim();
  if(!raw){ toast('Colle ou sélectionne un fichier JSON d\'abord.'); return; }
  let data;
  try{ data = JSON.parse(raw); }
  catch(e){ toast('Fichier JSON invalide.'); return; }

  const scouts = Array.isArray(data.scouts) ? data.scouts : (Array.isArray(data) ? data : null);
  if(!scouts){ toast('Format inattendu : aucune liste "scouts" trouvée.'); return; }

  const cleaned = scouts
    .filter(s => s && s.qrToken && (s.nom || s.prenom))
    .map(s => ({
      qrToken: s.qrToken,
      nom: s.nom || '',
      prenom: s.prenom || '',
      statut: s.statut || 'actif',
      patrouille: s.patrouille || null,
      patrouilleCouleur: s.patrouilleCouleur || null,
      role: s.role || 'membre',
    }));

  if(cleaned.length === 0){ toast('Aucun scout valide dans ce fichier.'); return; }

  await replaceRoster(cleaned);
  if(data.troupe){ await setSetting('troopName', data.troupe); document.getElementById('troopTitle').textContent = data.troupe; }
  roster = await getRoster();
  document.getElementById('jsonPaste').value = '';
  document.getElementById('fileInput').value = '';
  renderRosterList();
  refreshScanView();
  toast(cleaned.length + ' scout(s) importé(s).');
});

function renderRosterList(){
  const status = document.getElementById('rosterStatus');
  const list = document.getElementById('rosterList');
  list.innerHTML = '';
  if(roster.length === 0){
    status.textContent = 'Aucun trombinoscope importé.';
    return;
  }
  status.textContent = roster.length + ' scout(s) — dernière importation.';

  const groups = {};
  roster.forEach(s=>{
    const key = s.patrouille || 'Sans patrouille';
    if(!groups[key]) groups[key] = [];
    groups[key].push(s);
  });

  Object.keys(groups).sort().forEach(groupName=>{
    const h = document.createElement('div');
    h.className = 'roster-group';
    h.innerHTML = `<h3>${groupName}</h3>`;
    groups[groupName].forEach(s=>{
      const row = document.createElement('div');
      row.className = 'scan-row';
      const roleTag = s.role && s.role !== 'membre' ? ` (${s.role === 'chef' ? 'CP' : 'SP'})` : '';
      row.innerHTML = `<span>${displayName(s)}${roleTag}</span>`;
      h.appendChild(row);
    });
    list.appendChild(h);
  });
}

// ---------- Appel ----------
document.getElementById('appelDate').value = todayStr();
document.getElementById('appelDate').addEventListener('change', refreshScanView);

async function refreshScanView(){
  const noRoster = document.getElementById('noRosterMsg');
  const scanArea = document.getElementById('scanArea');
  if(roster.length === 0){
    noRoster.style.display = 'block';
    scanArea.style.display = 'none';
    return;
  }
  noRoster.style.display = 'none';
  scanArea.style.display = 'block';

  const date = document.getElementById('appelDate').value || todayStr();
  const records = await getAttendanceForDate(date);
  attendanceMap = {};
  records.forEach(r=> attendanceMap[r.qrToken] = r);
  document.getElementById('totalCount').textContent = roster.length;
  document.getElementById('presentCount').textContent = records.length;
  document.getElementById('dateSubtitle').textContent = new Date(date+'T00:00:00').toLocaleDateString('fr-FR', { weekday:'long', day:'numeric', month:'long' });
  renderScanList();
}

function renderScanList(){
  const list = document.getElementById('scanList');
  list.innerHTML = '';
  roster.forEach(s=>{
    const present = !!attendanceMap[s.qrToken];
    const row = document.createElement('div');
    row.className = 'scan-row';
    const patrouilleTag = s.patrouille ? `<span class="patrouille-tag">${s.patrouille}</span>` : '';
    row.innerHTML = `<span>${displayName(s)}${patrouilleTag}</span>`;
    const badge = document.createElement('span');
    badge.className = 'badge ' + (present ? 'present' : 'absent');
    badge.textContent = present ? 'présent' : 'absent';
    badge.onclick = async ()=>{
      const date = document.getElementById('appelDate').value || todayStr();
      if(attendanceMap[s.qrToken]){
        await unmarkAttendance(date, s.qrToken);
        delete attendanceMap[s.qrToken];
      } else {
        const time = new Date().toISOString();
        await markAttendance(date, s.qrToken, time);
        attendanceMap[s.qrToken] = { qrToken: s.qrToken, date, time };
      }
      document.getElementById('presentCount').textContent = Object.keys(attendanceMap).length;
      renderScanList();
    };
    row.appendChild(badge);
    list.appendChild(row);
  });
}

async function startScan(){
  if(scanCameraActive || roster.length === 0) return;
  const video = document.getElementById('video');
  const msg = document.getElementById('scanMsg');
  try{
    stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: "environment" } });
    video.srcObject = stream;
    await video.play();
    scanCameraActive = true;
    scanning = true;
    msg.textContent = "Vise le badge QR d'un jeune";
    requestAnimationFrame(scanLoop);
  }catch(e){
    msg.textContent = 'Caméra indisponible. Pointe manuellement ci-dessous.';
  }
}
function stopScan(){
  scanning = false;
  scanCameraActive = false;
  if(stream){ stream.getTracks().forEach(t=>t.stop()); stream = null; }
}
function scanLoop(){
  if(!scanning) return;
  const video = document.getElementById('video');
  const canvas = document.getElementById('canvas');
  if(video.readyState === video.HAVE_ENOUGH_DATA){
    canvas.width = video.videoWidth; canvas.height = video.videoHeight;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
    const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
    const code = jsQR(imageData.data, imageData.width, imageData.height);
    if(code && code.data) handleScan(code.data);
  }
  requestAnimationFrame(scanLoop);
}

function showFlash(type, text){
  const flash = document.getElementById('flash');
  const txt = document.getElementById('flashText');
  flash.className = 'flash show ' + type;
  txt.textContent = text;
  clearTimeout(flash._timer);
  flash._timer = setTimeout(()=> flash.classList.remove('show'), 900);
}

async function handleScan(scannedId){
  const now = Date.now();
  if(scannedId === lastScanId && (now - lastScanTime) < 1800) return;
  lastScanId = scannedId; lastScanTime = now;

  const scout = roster.find(s => s.qrToken === scannedId);
  if(!scout){ showFlash('err', 'QR non reconnu'); return; }

  const date = document.getElementById('appelDate').value || todayStr();
  if(attendanceMap[scout.qrToken]){ showFlash('dup', displayName(scout) + '\ndéjà pointé(e)'); return; }

  const time = new Date().toISOString();
  await markAttendance(date, scout.qrToken, time);
  attendanceMap[scout.qrToken] = { qrToken: scout.qrToken, date, time };
  showFlash('ok', '✓ ' + displayName(scout));
  document.getElementById('presentCount').textContent = Object.keys(attendanceMap).length;
  renderScanList();
  if(navigator.vibrate) navigator.vibrate(60);
}

// ---------- Historique ----------
document.getElementById('histDate').value = todayStr();
document.getElementById('histDate').addEventListener('change', refreshHistorique);

async function refreshHistorique(){
  const date = document.getElementById('histDate').value || todayStr();
  const records = await getAttendanceForDate(date);
  const byToken = {};
  records.forEach(r=> byToken[r.qrToken] = r);
  const wrap = document.getElementById('histTableWrap');
  if(roster.length === 0){ wrap.innerHTML = '<p class="empty">Aucun trombinoscope importé.</p>'; return; }

  let presentN = 0;
  const rows = roster.map(s=>{
    const rec = byToken[s.qrToken];
    if(rec) presentN++;
    const heure = rec ? new Date(rec.time).toLocaleTimeString('fr-FR', {hour:'2-digit',minute:'2-digit'}) : '—';
    return `<tr><td>${displayName(s)}</td><td>${rec ? 'Présent' : 'Absent'}</td><td>${heure}</td></tr>`;
  }).join('');

  wrap.innerHTML = `
    <div class="stat-row">
      <div class="stat"><b>${presentN}</b><span>présents</span></div>
      <div class="stat"><b>${roster.length - presentN}</b><span>absents</span></div>
    </div>
    <table><tr><th>Nom</th><th>Statut</th><th>Heure</th></tr>${rows}</table>`;
}

document.getElementById('exportCsvBtn').addEventListener('click', async ()=>{
  const date = document.getElementById('histDate').value || todayStr();
  const records = await getAttendanceForDate(date);
  const byToken = {};
  records.forEach(r=> byToken[r.qrToken] = r);
  let csv = 'Nom,Statut,Heure\n';
  roster.forEach(s=>{
    const rec = byToken[s.qrToken];
    const heure = rec ? new Date(rec.time).toLocaleTimeString('fr-FR') : '';
    csv += `"${displayName(s)}","${rec ? 'Présent' : 'Absent'}","${heure}"\n`;
  });
  const blob = new Blob([csv], {type:'text/csv;charset=utf-8;'});
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url; a.download = 'presence-' + date + '.csv'; a.click();
  URL.revokeObjectURL(url);
});

// ---------- Init ----------
(async function init(){
  db = await openDB();
  const troopName = await getSetting('troopName', '');
  if(troopName) document.getElementById('troopTitle').textContent = troopName;
  roster = await getRoster();
  renderRosterList();
  await refreshScanView();
  if(roster.length > 0) startScan();

  if('serviceWorker' in navigator){
    navigator.serviceWorker.register('sw.js').catch(()=>{});
  }
})();
