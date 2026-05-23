import { readFileSync, writeFileSync } from 'fs';

let html = readFileSync('./healthforcehub-pm.html', 'utf8');

const SB_CONSTS = `
/* -- SUPABASE -- */
const SB_URL='https://kzyjrooaehubmkrfvpob.supabase.co';
const SB_KEY='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt6eWpyb29hZWh1Ym1rcmZ2cG9iIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk0Nzg2MzUsImV4cCI6MjA5NTA1NDYzNX0.IqJTSaUWSfybX8kd2UbPYfXrJsbsN_I1YPm8EPyzywo';
let sb=null, sbMode='local', _channelActive=false;
`;

const PERSISTENCE_NEW = `
/* -- MAPPERS -- */
function toDbTask(t){
  return {id:t.id,title:t.title,description:t.desc||null,module:t.module||null,
    status:t.status||'backlog',priority:t.priority||'Medium',assignee:t.assignee||null,
    due_date:t.due||null,progress:t.progress||0,story_points:parseInt(t.storyPoints)||0,
    sprint_id:t.sprintId||null,project_id:t.projectId||null,notes:t.notes||null,
    blocked_by:t.blockedBy||[],comments:t.comments||[]};
}
function fromDbTask(r){
  return normalizeTask({id:r.id,title:r.title,desc:r.description||'',module:r.module||'',
    status:r.status||'backlog',priority:r.priority||'Medium',assignee:r.assignee||'',
    due:r.due_date||'',progress:r.progress||0,storyPoints:r.story_points||0,
    sprintId:r.sprint_id||'',projectId:r.project_id||'',notes:r.notes||'',
    blockedBy:r.blocked_by||[],comments:r.comments||[]});
}
function toDbMember(m){
  return {id:m.id,name:m.name,role:m.role||null,email:m.email||null,phone:m.phone||null,
    dept:m.dept||null,status:m.status||'active',skills:m.skills||null,
    notes:m.notes||null,color:m.color||'#4f8ef7'};
}
function fromDbMember(r){
  return {id:r.id,name:r.name,role:r.role||'',email:r.email||'',phone:r.phone||'',
    dept:r.dept||'',status:r.status||'active',skills:r.skills||'',
    notes:r.notes||'',color:r.color||'#4f8ef7'};
}
function toDbProject(p){
  return {id:p.id,name:p.name,description:p.desc||null,color:p.color||'#4f8ef7',
    icon:p.icon||null,status:p.status||'active',start_date:p.start||null,
    end_date:p.end||null,owner:p.owner||null,notes:p.notes||null};
}
function fromDbProject(r){
  return {id:r.id,name:r.name,desc:r.description||'',color:r.color||'#4f8ef7',
    icon:r.icon||'',status:r.status||'active',start:r.start_date||'',
    end:r.end_date||'',owner:r.owner||'',notes:r.notes||''};
}
/* -- DB STATUS -- */
function setDbStatus(mode,label){
  sbMode=mode;
  const dot=document.getElementById('storage-dot');
  const lbl=document.getElementById('storage-label');
  if(dot)dot.style.background=mode==='cloud'?'var(--green)':mode==='connecting'?'var(--yellow)':'var(--muted)';
  if(lbl)lbl.textContent=label||mode;
}
/* -- SUPABASE REALTIME -- */
function setupRealtime(){
  if(_channelActive||!sb)return;
  _channelActive=true;
  sb.channel('board').on('postgres_changes',{event:'*',schema:'public',table:'tasks'},()=>{
    sb.from('tasks').select('*').then(({data})=>{if(data){tasks=data.map(fromDbTask);renderAll();}});
  }).subscribe();
}
/* -- SAVE (optimistic: local + async cloud) -- */
function save(){
  localStorage.setItem(STORAGE_KEYS.tasks,JSON.stringify(tasks));
  if(sbMode==='cloud')
    sb.from('tasks').upsert(tasks.map(toDbTask),{onConflict:'id'})
      .then(({error})=>{if(error)console.error('save tasks:',error);});
}
function saveMembers(){
  localStorage.setItem(STORAGE_KEYS.members,JSON.stringify(members));
  if(sbMode==='cloud')
    sb.from('members').upsert(members.map(toDbMember),{onConflict:'id'})
      .then(({error})=>{if(error)console.error('save members:',error);});
}
function saveProjects(){
  localStorage.setItem(STORAGE_KEYS.projects,JSON.stringify(projects));
  if(sbMode==='cloud')
    sb.from('projects').upsert(projects.map(toDbProject),{onConflict:'id'})
      .then(({error})=>{if(error)console.error('save projects:',error);});
}
function saveCfg(){persistJSON(STORAGE_KEYS.sprintCfg,sprintCfg);}
function saveEvents(){persistJSON(STORAGE_KEYS.events,events);}
function saveAgentRuns(){persistJSON(STORAGE_KEYS.agentRuns,agentRuns);}
function saveAll(){
  save();saveMembers();saveProjects();saveCfg();saveEvents();saveAgentRuns();
  localStorage.setItem(STORAGE_KEYS.hist,histRaw);
  localStorage.setItem(STORAGE_KEYS.user,currentUser);
}
function recordEvent(entityType,entityId,action,beforeState,afterState,metadata={}){
  events.unshift({id:uid(),entityType,entityId,action,actorType:'user',actorName:currentUser,
    beforeState:beforeState?clone(beforeState):null,afterState:afterState?clone(afterState):null,
    metadata,createdAt:isoNow()});
  events=events.slice(0,500);
  saveEvents();
}
function recordAgentRun(task,runType,summary){
  const run={id:uid(),agentType:runType,trigger:'manual',status:'pending',
    taskId:task.id,projectId:task.projectId||'',userName:currentUser,summary,createdAt:isoNow()};
  agentRuns.unshift(run);agentRuns=agentRuns.slice(0,200);saveAgentRuns();return run;
}
/* -- LOAD LOCAL (localStorage fallback) -- */
function loadLocal(){
  tasks=(loadJSON(STORAGE_KEYS.tasks,[])||[]).map(normalizeTask);
  members=loadJSON(STORAGE_KEYS.members,[])||[];
  projects=loadJSON(STORAGE_KEYS.projects,[])||[];
  events=loadJSON(STORAGE_KEYS.events,[])||[];
  agentRuns=loadJSON(STORAGE_KEYS.agentRuns,[])||[];
  if(!members.length)seedMembers();
  if(!tasks.length)seedData();
  if(!projects.length)seedProjects();
  tasks=tasks.map(normalizeTask);
  if(!events.length)recordEvent('system','board','created',null,{mode:'local'},{source:'bootstrap'});
}
/* -- LOAD DATA (Supabase) -- */
async function loadData(){
  setDbStatus('connecting','Connecting...');
  try{
    sb=supabase.createClient(SB_URL,SB_KEY);
    const [tr,mr,pr]=await Promise.all([
      sb.from('tasks').select('*'),
      sb.from('members').select('*'),
      sb.from('projects').select('*'),
    ]);
    if(tr.error||mr.error||pr.error)throw tr.error||mr.error||pr.error;
    tasks=(tr.data||[]).map(fromDbTask);
    members=(mr.data||[]).map(fromDbMember);
    projects=(pr.data||[]).map(fromDbProject);
    if(!tasks.length&&!members.length){seedMembers();seedData();seedProjects();}
    tasks=tasks.map(normalizeTask);
    sbMode='cloud';setDbStatus('cloud','Supabase');setupRealtime();
  }catch(err){
    console.warn('Supabase unavailable, using local:',err);
    loadLocal();setDbStatus('local','Local');
  }
  renderAll();
}
function bootstrapState(){loadLocal();}`;

// 1. Add SB constants after systemMode line (only if not already present)
if(!html.includes('SB_URL=')) {
  html = html.replace("const systemMode='local-first';", "const systemMode='local-first';" + SB_CONSTS);
  console.log('1. Applied SB constants');
} else {
  console.log('1. SB constants already present');
}

// 2. Replace old persistence section
const OLD_SAVE_START = "function save(){persistJSON(STORAGE_KEYS.tasks,tasks);}";
const OLD_BOOTSTRAP_MARKER = "function bootstrapState(){";

if(html.includes(OLD_SAVE_START)) {
  const startIdx = html.indexOf(OLD_SAVE_START);
  const bootstrapStart = html.indexOf(OLD_BOOTSTRAP_MARKER, startIdx);
  // find the closing } of bootstrapState
  let braceDepth = 0, endIdx = bootstrapStart, foundOpen = false;
  for(let i = bootstrapStart; i < html.length; i++){
    if(html[i]==='{'){braceDepth++;foundOpen=true;}
    else if(html[i]==='}'){braceDepth--;if(foundOpen&&braceDepth===0){endIdx=i+1;break;}}
  }
  html = html.slice(0,startIdx) + PERSISTENCE_NEW + html.slice(endIdx);
  console.log('2. Replaced persistence section');
} else if(html.includes('function toDbTask')) {
  console.log('2. Persistence already replaced');
} else {
  console.log('2. WARNING: Could not find old save() function');
}

// 3. Remove Firebase overlay and modal
const fbStart = html.indexOf('<!-- FIREBASE LOADING OVERLAY -->');
const bodyClose = html.lastIndexOf('</body>');
if(fbStart > -1 && bodyClose > fbStart){
  html = html.slice(0,fbStart) + '\n</body>' + html.slice(bodyClose+7);
  console.log('3. Removed Firebase overlay and modal');
} else {
  console.log('3. Firebase overlay not found (already removed or not present)');
}

// 4. Fix header storage status to use correct IDs
if(html.includes('id="fb-status"') || html.includes('openFbSetup')) {
  html = html.replace(/openFbSetup\(\)/g, 'openSystemModal()');
  html = html.replace(/id="fb-status"/g, 'id="storage-status"');
  console.log('4. Fixed FB status IDs');
}

writeFileSync('./healthforcehub-pm.html', html, 'utf8');
console.log('\nDone. File written successfully.');
