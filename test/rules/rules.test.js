import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  addDoc, collection, deleteDoc, doc, getDoc, getDocs, setDoc, updateDoc,
} from 'firebase/firestore';

const B = 'buildings/b45';
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-home-system',
    firestore: { rules: readFileSync('../../firestore.rules', 'utf8') },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, B), { name: 'عمارة', ownerUid: 'owner' });
    await setDoc(doc(db, `${B}/members/owner`), { role: 'admin', active: true });
    await setDoc(doc(db, `${B}/members/admin2`), { role: 'admin', active: true });
    await setDoc(doc(db, `${B}/members/treasurer`), { role: 'treasurer', active: true });
    await setDoc(doc(db, `${B}/members/stopped`), { role: 'treasurer', active: false });
    await setDoc(doc(db, `${B}/members/resident`), { role: 'resident', active: true });
    await setDoc(doc(db, `${B}/apartments/1`), { number: 1, contacts: [{ name: 'س', phone: '010' }] });
    await setDoc(doc(db, `${B}/auditLog/a1`), { by: 'owner', action: 'x' });
    await setDoc(doc(db, `${B}/public/summary`), { sections: {} });
    await setDoc(doc(db, `${B}/accessRequests/stranger`), { name: 'غريب' });
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

test('anonymous visitors read only the published summary', async () => {
  await assertSucceeds(getDoc(doc(anon(), `${B}/public/summary`)));
  await assertFails(setDoc(doc(anon(), `${B}/public/summary`), { x: 1 }));
  await assertFails(getDoc(doc(anon(), B)));
  await assertFails(getDocs(collection(anon(), `${B}/apartments`)));
  await assertFails(getDocs(collection(anon(), `${B}/members`)));
  await assertFails(getDocs(collection(anon(), `${B}/auditLog`)));
});

test('signed-in non-members cannot read or write private data', async () => {
  for (const uid of ['stranger', 'stopped', 'resident']) {
    await assertFails(getDocs(collection(as(uid), `${B}/apartments`)));
    await assertFails(setDoc(doc(as(uid), `${B}/apartments/1`), { number: 1 }));
    await assertFails(getDocs(collection(as(uid), `${B}/members`)));
    await assertFails(getDocs(collection(as(uid), `${B}/auditLog`)));
    await assertFails(setDoc(doc(as(uid), `${B}/public/summary`), { x: 1 }));
  }
});

test('a stranger cannot make themselves a member or take over the building', async () => {
  const db = as('stranger');
  await assertFails(setDoc(doc(db, `${B}/members/stranger`), { role: 'admin', active: true }));
  await assertFails(setDoc(doc(db, `${B}/members/stranger`), { role: 'treasurer', active: true }));
  await assertFails(setDoc(doc(db, B), { name: 'x', ownerUid: 'stranger' }));
  await assertFails(updateDoc(doc(db, B), { ownerUid: 'stranger' }));
});

test('a stranger can see whether the building exists and manage only their own request', async () => {
  const db = as('stranger');
  await assertSucceeds(getDoc(doc(db, B)));
  await assertSucceeds(getDoc(doc(db, `${B}/members/stranger`)));
  await assertSucceeds(getDoc(doc(db, `${B}/accessRequests/stranger`)));
  await assertFails(getDoc(doc(db, `${B}/accessRequests/other`)));
  await assertFails(setDoc(doc(db, `${B}/accessRequests/other`), { name: 'x' }));
  await assertFails(getDocs(collection(db, `${B}/accessRequests`)));
});

test('first-time setup: creator owns the building and becomes admin', async () => {
  await env.clearFirestore();
  const db = as('first');
  await assertFails(setDoc(doc(db, B), { name: 'ع', ownerUid: 'someone-else' }));
  await assertSucceeds(setDoc(doc(db, B), { name: 'ع', ownerUid: 'first' }));
  await assertFails(setDoc(doc(as('second'), `${B}/members/second`), { role: 'admin', active: true }));
  await assertSucceeds(setDoc(doc(db, `${B}/members/first`), { role: 'admin', active: true }));
  await assertSucceeds(setDoc(doc(db, `${B}/apartments/1`), { number: 1 }));
});

test('treasurer manages apartments but not users or settings', async () => {
  const db = as('treasurer');
  await assertSucceeds(getDocs(collection(db, `${B}/apartments`)));
  await assertSucceeds(setDoc(doc(db, `${B}/apartments/1`), { number: 1, notes: 'x' }));
  await assertFails(deleteDoc(doc(db, `${B}/apartments/1`)));
  await assertFails(setDoc(doc(db, `${B}/members/stranger`), { role: 'treasurer', active: true }));
  await assertFails(updateDoc(doc(db, `${B}/members/treasurer`), { role: 'admin' }));
  await assertFails(getDocs(collection(db, `${B}/accessRequests`)));
  await assertFails(setDoc(doc(db, `${B}/settings/publish`), { x: 1 }));
  await assertFails(updateDoc(doc(db, B), { name: 'y' }));
  await assertSucceeds(setDoc(doc(db, `${B}/public/summary`), { sections: {} }));
});

test('admin manages users, but nobody can change the owner', async () => {
  const db = as('admin2');
  await assertSucceeds(getDocs(collection(db, `${B}/accessRequests`)));
  await assertSucceeds(setDoc(doc(db, `${B}/members/stranger`), { role: 'treasurer', active: true }));
  await assertSucceeds(deleteDoc(doc(db, `${B}/accessRequests/stranger`)));
  await assertSucceeds(updateDoc(doc(db, `${B}/members/treasurer`), { active: false }));
  await assertFails(updateDoc(doc(db, `${B}/members/owner`), { active: false }));
  await assertFails(updateDoc(doc(db, B), { ownerUid: 'admin2' }));
  await assertSucceeds(updateDoc(doc(db, B), { name: 'اسم جديد' }));
  await assertFails(deleteDoc(doc(db, `${B}/members/treasurer`)));
});

test('audit log is append-only and signed by its author', async () => {
  const db = as('treasurer');
  await assertSucceeds(addDoc(collection(db, `${B}/auditLog`), { by: 'treasurer', action: 'x' }));
  await assertFails(addDoc(collection(db, `${B}/auditLog`), { by: 'owner', action: 'x' }));
  await assertFails(updateDoc(doc(db, `${B}/auditLog/a1`), { action: 'y' }));
  await assertFails(deleteDoc(doc(db, `${B}/auditLog/a1`)));
  await assertFails(deleteDoc(doc(as('owner'), `${B}/auditLog/a1`)));
});

test('imported sheet cells are staff-readable and admin-writable only', async () => {
  const path = `${B}/importItems/x_C2`;
  await assertSucceeds(setDoc(doc(as('admin2'), path), { originalText: '100' }));
  await assertSucceeds(getDoc(doc(as('treasurer'), path)));
  await assertFails(setDoc(doc(as('treasurer'), path), { originalText: '200' }));
  await assertFails(getDoc(doc(anon(), path)));
  await assertFails(getDoc(doc(as('stranger'), path)));
  await assertFails(getDoc(doc(as('resident'), path)));
});
