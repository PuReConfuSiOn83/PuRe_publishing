const app = document.getElementById('app');
const state = { data: null, docs: [], locations: [], current: null, type: null, editing: null, toastTimer: null, bookPages: null, bookSpread: 0, bookTurning: false };
const typeNames = { newspaper: 'Zeitungsausgabe', menu: 'Speisekarte', wanted: 'Fahndung' };
const icons = { newspaper: '▤', menu: '☷', wanted: '◎' };
const nui = (name, data={}) => fetch(`https://${GetParentResourceName()}/${name}`, {method:'POST',headers:{'Content-Type':'application/json; charset=UTF-8'},body:JSON.stringify(data)}).then(r=>r.json());
const esc = value => String(value ?? '').replace(/[&<>"']/g, c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function toast(message, error=false){const el=document.getElementById('toast');el.textContent=message;el.style.background=error?'#a92431':'#202328';el.classList.add('show');clearTimeout(state.toastTimer);state.toastTimer=setTimeout(()=>el.classList.remove('show'),2600)}
function show(){app.classList.add('visible');app.setAttribute('aria-hidden','false')}
function hide(){app.classList.remove('visible');app.setAttribute('aria-hidden','true');nui('close')}
function editor(data){state.data=data;state.docs=data.documents||[];state.locations=data.locations||[];document.getElementById('editorView').classList.remove('hidden');document.getElementById('readerView').classList.add('hidden');document.querySelectorAll('.nav').forEach(n=>n.classList.remove('hidden'));document.querySelectorAll('.nav[data-type]').forEach(n=>n.classList.toggle('hidden',!data.types?.[n.dataset.type]));document.querySelector('.admin-only').style.display=data.canManageLocations?'block':'none';renderDocs();renderLocations();show();page('dashboard')}
function page(name){document.querySelectorAll('.page').forEach(p=>p.classList.add('hidden'));const target=document.getElementById(name==='dashboard'?'dashboardPage':name==='locations'?'locationsPage':'formPage');target.classList.remove('hidden');document.querySelectorAll('.nav').forEach(n=>n.classList.toggle('active',n.dataset.page===name))}
function renderDocs(){const list=document.getElementById('documentList');list.innerHTML='';document.getElementById('docCount').textContent=state.docs.length;document.getElementById('publishedCount').textContent=state.docs.filter(d=>d.status==='published').length;document.getElementById('locationCount').textContent=state.locations.length;document.getElementById('emptyDocs').classList.toggle('hidden',state.docs.length>0);state.docs.forEach(doc=>{const row=document.createElement('div');row.className='doc-row';row.innerHTML=`<div class="doc-icon">${icons[doc.type]||'▤'}</div><div class="doc-info"><strong>${esc(doc.title)}</strong><small>${typeNames[doc.type]} · ${esc(doc.author||'Redaktion')}</small></div><span class="status ${doc.status==='published'?'published':''}">${doc.status==='published'?'VERÖFFENTLICHT':doc.status==='archived'?'ARCHIVIERT':'ENTWURF'}</span><button class="row-action">Bearbeiten</button>`;row.querySelector('button').onclick=()=>openForm(doc.type,doc);list.appendChild(row)})}
function field(label,key,value='',kind='input',placeholder=''){return `<div class="field"><label>${label}</label>${kind==='textarea'?`<textarea data-key="${key}" placeholder="${placeholder}">${esc(value)}</textarea>`:`<input data-key="${key}" value="${esc(value)}" placeholder="${placeholder}" ${kind==='number'?'type="number" min="0"':''}>`}</div>`}
function card(title,inner){return `<section class="field-card"><h3>${title}</h3>${inner}</section>`}
function openForm(type,doc=null){state.type=type;state.editing=doc;state.current=doc?JSON.parse(JSON.stringify(doc)):null;document.getElementById('formEyebrow').textContent=typeNames[type].toUpperCase();document.getElementById('formTitle').textContent=doc?doc.title:'Neues Dokument';document.getElementById('formHint').textContent='Inhalte bearbeiten und vor der Veröffentlichung prüfen.';document.getElementById('archiveBtn').classList.toggle('hidden',!doc);document.getElementById('publishBtn').textContent=type==='newspaper'?'Ausgabe veröffentlichen':'Veröffentlichen';document.getElementById('dynamicForm').innerHTML=buildForm(type,doc);document.querySelectorAll('#dynamicForm input,#dynamicForm textarea').forEach(el=>el.addEventListener('input',updatePreview));wireRepeaters();updatePreview();page(type)}
function buildForm(type,doc){const c=doc?.content||{};let html=card('Dokumentdaten',`<div class="field-grid">${field('Titel','title',doc?.title||'')}${field('Untertitel','subtitle',doc?.subtitle||'')}</div>${field('Titelbild (HTTPS-Bildlink)','coverUrl',c.coverUrl||'','','https://...')}`);
if(type==='newspaper'){html+=`<div id="items">${(c.articles?.length?c.articles:[{}]).map((a,i)=>articleCard(a,i)).join('')}</div><button class="small-button" id="addItem">＋ Artikel hinzufügen</button>`}
if(type==='menu'){html+=`<div id="items">${(c.entries?.length?c.entries:[{}]).map((a,i)=>menuCard(a,i)).join('')}</div><button class="small-button" id="addItem">＋ Speisekarteneintrag</button>`}
if(type==='wanted'){html+=card('Fahndungsdetails',`<div class="field-grid">${field('Gesuchte Person','subject',c.subject||'')}${field('Belohnung ($)','reward',c.reward||0,'number')}</div>${field('Beschreibung','description',c.description||'','textarea','Aussehen, Hinweise, Kennzeichen …')}${field('Zuletzt gesehen','lastSeen',c.lastSeen||'')}${field('Foto (HTTPS-Bildlink)','photoUrl',c.photoUrl||'')}${field('Ablauf nach Tagen','expiresInDays',c.expiresInDays||7,'number')}`)}return html}
function articleCard(a,i){return `<div class="subcard item-card"><div class="subcard-head"><span>Artikel ${i+1}</span><button class="remove-btn">Entfernen</button></div>${field('Überschrift','articleTitle',a.title||'')}${field('Artikeltext','articleBody',a.body||'','textarea','Artikeltext …')}${field('Bild (HTTPS-Bildlink)','articleImage',a.imageUrl||'')}</div>`}
function menuCard(a,i){return `<div class="subcard item-card"><div class="subcard-head"><span>Eintrag ${i+1}</span><button class="remove-btn">Entfernen</button></div><div class="field-grid">${field('Name','entryName',a.name||'')}${field('Preis ($)','entryPrice',a.price||0,'number')}</div>${field('Kategorie','entryCategory',a.category||'')}${field('Beschreibung','entryDescription',a.description||'')}</div>`}
function wireRepeaters(){const add=document.getElementById('addItem');if(!add)return;add.onclick=()=>{const items=document.getElementById('items');const i=items.children.length;items.insertAdjacentHTML('beforeend',state.type==='newspaper'?articleCard({},i):menuCard({},i));wireRepeaters();document.querySelectorAll('#dynamicForm input,#dynamicForm textarea').forEach(el=>el.addEventListener('input',updatePreview));updatePreview()};document.querySelectorAll('.remove-btn').forEach(btn=>btn.onclick=()=>{const cards=[...document.querySelectorAll('.item-card')];if(cards.length<=1){toast('Mindestens ein Eintrag ist erforderlich.',true);return}btn.closest('.item-card').remove();document.querySelectorAll('.item-card .subcard-head span').forEach((s,i)=>s.textContent=(state.type==='newspaper'?'Artikel ':'Eintrag ')+(i+1));updatePreview()})}
function readForm(){const val=k=>document.querySelector(`[data-key="${k}"]`)?.value||'';const result={id:state.editing?.id,type:state.type,title:val('title'),subtitle:val('subtitle'),content:{coverUrl:val('coverUrl')}};if(state.type==='newspaper')result.content.articles=[...document.querySelectorAll('.item-card')].map(e=>({title:e.querySelector('[data-key="articleTitle"]').value,body:e.querySelector('[data-key="articleBody"]').value,imageUrl:e.querySelector('[data-key="articleImage"]').value}));if(state.type==='menu')result.content.entries=[...document.querySelectorAll('.item-card')].map(e=>({name:e.querySelector('[data-key="entryName"]').value,price:e.querySelector('[data-key="entryPrice"]').value,category:e.querySelector('[data-key="entryCategory"]').value,description:e.querySelector('[data-key="entryDescription"]').value}));if(state.type==='wanted')Object.assign(result.content,{subject:val('subject'),reward:val('reward'),description:val('description'),lastSeen:val('lastSeen'),photoUrl:val('photoUrl'),expiresInDays:val('expiresInDays')});return result}
function updatePreview(){
  if(!document.getElementById('title'))return;
  const d=readForm(),c=d.content;
  let html='';
  if(d.type==='newspaper'){
    const articles=c.articles||[], lead=articles[0]||{}, leadImage=c.coverUrl||lead.imageUrl||'';
    html=`<div class="mini-paper"><div class="mini-paper-kicker">SAN ANDREAS · AKTUELLE AUSGABE</div><h2>${esc(d.title||'Zeitungstitel')}</h2><div class="mini-paper-rule"></div><div class="mini-paper-meta">${esc(d.subtitle||'Ausgabe und Datum')} · ${esc(state.data?.author||'Redaktion')}</div><section class="mini-paper-lead"><small>TITELTHEMA</small><h3>${esc(lead.title||'Titelgeschichte')}</h3>${leadImage?`<img src="${esc(leadImage)}" onerror="this.style.display='none'">`:''}<p>${esc(lead.body||'Der Text des ersten Artikels erscheint hier.')}</p></section>${articles.slice(1).map(a=>`<div class="mini-paper-story"><b>${esc(a.title||'Weitere Meldung')}</b><p>${esc(a.body||'Artikeltext erscheint hier.')}</p></div>`).join('')}</div>`;
  } else {
    html=`<h2>${esc(d.title||'Dokumenttitel')}</h2><div class="sub">${esc(d.subtitle||typeNames[d.type])}</div>`;
    if(c.coverUrl)html+=`<img src="${esc(c.coverUrl)}" onerror="this.style.display='none'">`;
    if(d.type==='menu')html+=(c.entries||[]).map(a=>`<div class="preview-entry"><div><b>${esc(a.name||'Gericht')}</b><p>${esc(a.category||'')}${a.description?' · '+esc(a.description):''}</p></div><strong>${esc(a.price||'0')} $</strong></div>`).join('');
    if(d.type==='wanted')html+=`<div class="wanted-card"><strong>${esc(c.subject||'Name der gesuchten Person')}</strong>${c.photoUrl?`<img src="${esc(c.photoUrl)}" onerror="this.style.display='none'">`:''}<p>${esc(c.description||'Beschreibung')}</p><p>Zuletzt gesehen: ${esc(c.lastSeen||'–')} · Belohnung: ${esc(c.reward||0)} $</p></div>`;
  }
  document.getElementById('previewContent').innerHTML=html;
}
async function save(publish=false){const data=readForm();const result=await nui('saveDocument',data);if(!result.ok){toast(result.error||'Speichern fehlgeschlagen.',true);return}data.id=result.id;state.editing=data;if(publish){const r=await nui('publishDocument',{id:data.id});if(!r.ok){toast(r.error||'Veröffentlichung fehlgeschlagen.',true);return}toast(r.message);await reloadEditor()}else{toast(result.message);await reloadEditor();openForm(data.type,state.docs.find(d=>d.id===data.id))}}
async function reloadEditor(){await requestRefresh()}
function renderLocations(){const select=document.getElementById('locationDocument');if(!select)return;select.innerHTML='<option value="">Dokument auswählen …</option>'+state.docs.filter(d=>d.status!=='archived').map(d=>`<option value="${esc(d.id)}">${esc(d.title)} · ${typeNames[d.type]}</option>`).join('');const list=document.getElementById('locationList');list.innerHTML=state.locations.map(l=>`<div class="location-row"><span>⌖ ${esc(l.label)} <small class="muted">· ${esc(state.docs.find(d=>d.id===l.documentId)?.title||l.documentId)}</small></span><button class="row-action" data-del="${esc(l.id)}">Entfernen</button></div>`).join('')||'<div class="empty-state">Noch keine Anzeigeorte angelegt.</div>';list.querySelectorAll('[data-del]').forEach(b=>b.onclick=async()=>{const r=await nui('deleteLocation',{id:b.dataset.del});toast(r.message||r.error,!r.ok);requestRefresh()})}
async function requestRefresh(){const data=await nui('refreshEditor');if(data?.allowed)editor(data)}
window.addEventListener('message',e=>{const {action,data}=e.data||{};if(action==='show')show();if(action==='hide'){app.classList.remove('visible');app.setAttribute('aria-hidden','true')}if(action==='editor')editor(data);if(action==='document')renderReader(data);if(action==='refresh')editor(data);if(action==='refreshRequest')requestRefresh()});
function formatPublicationDate(value){
  if(!value)return 'AKTUELLE AUSGABE';
  const parts=String(value).slice(0,10).split('-');
  return parts.length===3?`${parts[2]}.${parts[1]}.${parts[0]}`:String(value);
}
function renderReader(d){
  document.getElementById('editorView').classList.add('hidden');
  const readerView=document.getElementById('readerView');
  readerView.classList.remove('hidden');
  readerView.classList.toggle('newspaper-mode',d.type==='newspaper');
  const c=d.content||{};
  const controls=document.getElementById('bookControls');
  if(d.type==='newspaper'){
    const articles=c.articles||[];
    const lead=articles[0]||{};
    const leadImage=c.coverUrl||lead.imageUrl||'';
    const cover=`<header class="book-masthead"><span class="newspaper-kicker">SAN ANDREAS · STADT UND REGION</span><h1>${esc(d.title||'Tageszeitung')}</h1><p>${esc(d.subtitle||'UNABHÄNGIG · LOKAL · NAH DRAN')}</p></header><div class="book-date"><span>${formatPublicationDate(d.publishedAt)}</span><span>AKTUELLE AUSGABE</span></div><section class="book-lead"><span class="story-label">TITELTHEMA</span><h2>${esc(lead.title||'Willkommen zur Ausgabe')}</h2>${leadImage?`<img class="book-hero" src="${esc(leadImage)}" alt="Titelbild" onerror="this.style.display='none'">`:''}<p>${esc(lead.body||'Die wichtigsten Nachrichten aus San Andreas – kompakt und unabhängig.')}</p><span class="book-byline">${esc(d.author||'Redaktion')}</span></section>`;
    state.bookPages=[cover,...articles.slice(1).map((a,i)=>`<article class="book-story"><span class="story-label">${i===0?'AUS DER STADT':'WEITERE MELDUNG'}</span><h2>${esc(a.title||'Weitere Meldung')}</h2>${a.imageUrl?`<img src="${esc(a.imageUrl)}" alt="Artikelbild" onerror="this.style.display='none'">`:''}<p>${esc(a.body||'')}</p><span class="book-byline">${esc(d.author||'Redaktion')}</span></article>` )];
    state.bookSpread=0;
    state.bookTurning=false;
    controls.classList.remove('hidden');
    document.getElementById('readerContent').innerHTML='<div class="book-stage"><div id="bookSpread" class="book-spread"></div><div id="turnSheet" class="turn-sheet hidden"><div class="turn-face turn-front"></div><div class="turn-face turn-back"></div></div></div><div class="book-hint">Mit den Pfeilen oder den Pfeiltasten blättern</div>';
    drawBookSpread();
    document.getElementById('bookPrev').onclick=()=>turnBook(-1);
    document.getElementById('bookNext').onclick=()=>turnBook(1);
  } else {
    state.bookPages=null;
    controls.classList.add('hidden');
    let html=`<p class="eyebrow">${esc(typeNames[d.type]||'Dokument')}</p><h1>${esc(d.title)}</h1><div class="reader-sub">${esc(d.subtitle||'')} · ${esc(d.author||'Redaktion')}</div>`;
    if(c.coverUrl)html+=`<img src="${esc(c.coverUrl)}">`;
    if(d.type==='menu')html+=(c.entries||[]).map(a=>`<section class="reader-entry"><header><span>${esc(a.name)}</span><span>${esc(a.price)} $</span></header><p>${esc(a.category)}${a.description?' · '+esc(a.description):''}</p></section>`).join('');
    if(d.type==='wanted')html+=`<div class="wanted-card"><strong>${esc(c.subject)}</strong>${c.photoUrl?`<img src="${esc(c.photoUrl)}">`:''}<p>${esc(c.description)}</p><p>Zuletzt gesehen: ${esc(c.lastSeen||'–')}</p><p>Belohnung: ${esc(c.reward||0)} $</p></div>`;
    document.getElementById('readerContent').innerHTML=html;
  }
  show();
}
function bookSpreadIndices(spread){
  return spread===0?[-1,0]:[1+(spread-1)*2,2+(spread-1)*2];
}
function bookPageMarkup(index){
  if(index<0||index>=state.bookPages.length)return '<div class="book-blank"><span>PURe · SAN ANDREAS</span></div>';
  const pageNo=index+1;
  const content=index===0?`<div class="book-cover">${state.bookPages[index]}</div>`:state.bookPages[index];
  return `<div class="paper-inner">${content}<footer class="paper-folio"><span>${esc(state.data?.author||'PuRe Publishing')}</span><b>${pageNo}</b></footer></div>`;
}
function drawBookSpread(){
  if(!state.bookPages)return;
  const spread=document.getElementById('bookSpread');
  const [leftIndex,rightIndex]=bookSpreadIndices(state.bookSpread);
  spread.innerHTML=`<section class="paper-page paper-left">${bookPageMarkup(leftIndex)}</section><section class="paper-page paper-right">${bookPageMarkup(rightIndex)}</section>`;
  const maxSpread=Math.ceil((state.bookPages.length-1)/2);
  const visible=[leftIndex,rightIndex].filter(i=>i>=0&&i<state.bookPages.length).map(i=>i+1);
  document.getElementById('bookPageLabel').textContent=visible.length>1?`Seite ${visible[0]}–${visible[1]} von ${state.bookPages.length}`:`Seite ${visible[0]||1} von ${state.bookPages.length}`;
  document.getElementById('bookPrev').disabled=state.bookSpread===0||state.bookTurning;
  document.getElementById('bookNext').disabled=state.bookSpread>=maxSpread||state.bookTurning;
}
function turnBook(direction){
  if(!state.bookPages||state.bookTurning)return;
  const maxSpread=Math.ceil((state.bookPages.length-1)/2);
  const target=state.bookSpread+direction;
  if(target<0||target>maxSpread)return;
  const turn=document.getElementById('turnSheet');
  const [currentLeft,currentRight]=bookSpreadIndices(state.bookSpread);
  const [nextLeft,nextRight]=bookSpreadIndices(target);
  const forward=direction>0;
  const frontIndex=forward?currentRight:currentLeft;
  const backIndex=forward?nextLeft:nextRight;
  turn.classList.remove('hidden','turn-forward','turn-backward');
  turn.classList.add(forward?'turn-forward':'turn-backward');
  turn.querySelector('.turn-front').innerHTML=bookPageMarkup(frontIndex);
  turn.querySelector('.turn-back').innerHTML=bookPageMarkup(backIndex);
  state.bookTurning=true;
  drawBookSpread();
  turn.addEventListener('animationend',()=>{
    state.bookSpread=target;
    state.bookTurning=false;
    turn.classList.add('hidden');
    drawBookSpread();
  },{once:true});
}
document.getElementById('closeBtn').onclick=hide;document.getElementById('readerClose').onclick=hide;document.getElementById('backBtn').onclick=()=>page('dashboard');document.getElementById('locationBack').onclick=()=>page('dashboard');document.getElementById('newDocBtn').onclick=()=>{const available=Object.keys(state.data?.types||{});if(!available.length){toast('Keine Dokumenttypen freigeschaltet.',true);return}openForm(available[0])};document.getElementById('saveBtn').onclick=()=>save(false);document.getElementById('publishBtn').onclick=()=>save(true);document.getElementById('archiveBtn').onclick=async()=>{if(!state.editing)return;const r=await nui('deleteDocument',{id:state.editing.id});toast(r.message||r.error,!r.ok);if(r.ok)requestRefresh()};document.getElementById('saveLocationBtn').onclick=async()=>{const r=await nui('saveLocation',{name:document.getElementById('locationName').value,documentId:document.getElementById('locationDocument').value});toast(r.message||r.error,!r.ok);if(r.ok){document.getElementById('locationName').value='';requestRefresh()}};document.querySelectorAll('.nav').forEach(b=>b.onclick=()=>{if(b.dataset.type)openForm(b.dataset.type);else page(b.dataset.page)});document.addEventListener('keydown',e=>{if(e.key==='Escape'&&app.classList.contains('visible'))hide();if(state.bookPages&&app.classList.contains('visible')&&document.getElementById('readerView').classList.contains('newspaper-mode')){if(e.key==='ArrowRight'){e.preventDefault();turnBook(1)}if(e.key==='ArrowLeft'){e.preventDefault();turnBook(-1)}}});
