// Run with NODE_PATH pointing to a temporary linkedom installation.
const {parseHTML} = require('linkedom');
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const html = fs.readFileSync('healthforcehub-pm.html','utf8');
const {window} = parseHTML(html);
// Linkedom has no select.value setter; emulate that browser API for form tests.
Object.defineProperty(window.HTMLSelectElement.prototype,'value',{
  get(){return this.querySelector('option[selected]')?.value || this.querySelector('option')?.value || '';},
  set(value){this.querySelectorAll('option').forEach(o=>{if(o.value===value)o.setAttribute('selected','');else o.removeAttribute('selected');});},
  configurable:true
});
const cache=new Map([['emr-tasks','[]'],['emr-members','[]'],['emr-projects','[]']]);
const alerts=[];
const context=vm.createContext({document:window.document,window,navigator:{clipboard:{writeText:async()=>{}}},URL,console,setTimeout:()=>{},clearTimeout:()=>{},alert:m=>alerts.push(m),confirm:()=>true,localStorage:{getItem:k=>cache.get(k)||null,setItem:(k,v)=>cache.set(k,v)}});
const scripts=[...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)].map(m=>m[1]).join('\n');
vm.runInContext(scripts,context);
const run=code=>vm.runInContext(code,context);
const doc=window.document;
run("switchTab('hierarchy')");
assert.equal(doc.getElementById('hierarchy-view').style.display,'block');
run("openModal(); document.getElementById('f-title').value='Test epic'; document.getElementById('f-project').value=projects[0].id; document.getElementById('d-type').value='epic'; refreshParentOptions(); saveTask();");
assert.equal(run("tasks.at(-1).delivery.type"),'epic');
const epicId=run('tasks.at(-1).id');
run(`openModal(); document.getElementById('f-title').value='Test feature'; document.getElementById('f-project').value=projects[0].id; document.getElementById('d-type').value='feature'; refreshParentOptions('${epicId}'); saveTask();`);
assert.equal(run('tasks.at(-1).delivery.parentId'),epicId);
run("openModal(); document.getElementById('f-title').value='Reviewable task'; document.getElementById('d-reviewer').value=members[0].id; document.getElementById('d-criteria').value='All checks pass'; document.getElementById('d-evidence-text').value='Unit tests pass'; addEvidence(); submitWorkReview();");
assert.equal(run('tasks.at(-1).delivery.reviewStatus'),'pending');
const taskId=run('tasks.at(-1).id');
run(`currentUser=members[0].name; decideReview('${taskId}','approved','Verified tests and criteria'); openModal('${taskId}'); document.getElementById('f-status').value='done'; saveTask();`);
assert.equal(run('tasks.at(-1).status'),'done');
assert.ok(run('tasks.at(-1).delivery.approval'));
run(`openModal('${taskId}'); document.getElementById('f-title').value='Changed after approval'; saveTask();`);
assert.equal(run('tasks.at(-1).title'),'Reviewable task');
assert.match(alerts.at(-1),/Done requires/);
run("openStakeholder(); document.getElementById('s-name').value='Client'; document.getElementById('s-email').checkValidity=()=>true;");
const checks=doc.querySelectorAll('#s-projects input');checks[0].setAttribute('checked','');checks[1].setAttribute('checked','');
run('saveStakeholder()');
assert.equal(run('stakeholders.at(-1).projectIds.length'),2);
assert.match(cache.get('emr-stakeholders'),/Client/);
assert.match(cache.get('emr-tasks'),/Reviewable task/);
run("deliveryCloudReady=true; deliveryPending={}; globalThis.cloudRoundTrip=fromDbTask(toDbTask(tasks.at(-1))); deliveryCloudReady=false;");
assert.equal(run('cloudRoundTrip.delivery.reviewStatus'),'approved');
assert.equal(run('cloudRoundTrip.delivery.evidence.length'),1);
run("markDeliveryPending(tasks.at(-1)); globalThis.stale=toDbTask(tasks.at(-1)); stale.delivery={}; globalThis.protectedTask=fromDbTask(stale);");
assert.equal(run('protectedTask.delivery.reviewStatus'),'approved');
run("tasks=[];loadLocal();");
assert.ok(run("tasks.some(t=>t.title==='Reviewable task'&&t.delivery.approval)"));
run("openStakeholder(stakeholders.at(-1).id);deleteStakeholder();");
assert.equal(run('stakeholders.at(-1).deleted'),true);
assert.equal(run('stakeholders.at(-1).projectIds.length'),0);
run("switchTab('reviews');switchTab('stakeholders');switchTab('board');");
assert.equal(doc.getElementById('board-view').style.display,'block');
console.log('Passed: offline startup, hierarchy forms, review lifecycle, completion gate, approval invalidation, stakeholder assignment/removal, cloud mapper roundtrip, stale-cloud protection, reload persistence, and navigation.');
