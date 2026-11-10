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

test('contribution records are staff-only and cannot be deleted by a treasurer', async () => {
  const path = `${B}/importItems/x_C2`;
  await assertSucceeds(setDoc(doc(as('admin2'), path), { originalText: '100' }));
  await assertSucceeds(getDoc(doc(as('treasurer'), path)));
  await assertSucceeds(setDoc(doc(as('treasurer'), path), { editedText: '200' }, { merge: true }));
  await assertFails(deleteDoc(doc(as('treasurer'), path)));
  await assertFails(setDoc(doc(as('resident'), path), { editedText: '1' }));
  await assertFails(getDoc(doc(anon(), path)));
  await assertFails(getDoc(doc(as('stranger'), path)));
  await assertFails(getDoc(doc(as('resident'), path)));
});

test('transactions: staff record, nobody deletes, only admins touch the opening balance', async () => {
  await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), `${B}/transactions/opening`), { type: 'opening', amount: 285000, createdBy: 'setup' }));
  const t = as('treasurer');
  await assertSucceeds(setDoc(doc(t, `${B}/transactions/e1`), { type: 'expense', amount: 25000, createdBy: 'treasurer' }));
  await assertFails(setDoc(doc(t, `${B}/transactions/e2`), { type: 'expense', amount: 25000, createdBy: 'owner' }));
  await assertFails(setDoc(doc(t, `${B}/transactions/e3`), { type: 'expense', amount: -5, createdBy: 'treasurer' }));
  await assertFails(setDoc(doc(t, `${B}/transactions/o2`), { type: 'opening', amount: 1, createdBy: 'treasurer' }));
  await assertSucceeds(updateDoc(doc(t, `${B}/transactions/e1`), { amount: 30000 }));
  await assertSucceeds(updateDoc(doc(t, `${B}/transactions/e1`), { voided: true }));
  await assertFails(updateDoc(doc(t, `${B}/transactions/e1`), { type: 'income' }));
  await assertFails(deleteDoc(doc(t, `${B}/transactions/e1`)));
  await assertFails(deleteDoc(doc(as('owner'), `${B}/transactions/e1`)));
  await assertFails(updateDoc(doc(t, `${B}/transactions/opening`), { amount: 1 }));
  await assertSucceeds(updateDoc(doc(as('owner'), `${B}/transactions/opening`), { amount: 290000 }));
  for (const db of [anon(), as('stranger'), as('resident')]) {
    await assertFails(getDoc(doc(db, `${B}/transactions/e1`)));
  }
});

test('subscription locks: a month can be paid once, and only by a matching payment', async () => {
  const t = as('treasurer');
  const pay = (id, periods, extra = {}) => ({
    type: 'subscription', amount: periods.length * 10000, createdBy: 'treasurer', apartmentNumber: 4,
    periods, allocations: periods.map((p) => ({ period: p, amount: 10000 })), voided: false, ...extra,
  });
  const lock = (period, txId, apt = 4) => ({ period, apartmentNumber: apt, txId });
  const batchOf = async (db, writes) => {
    const { writeBatch } = await import('firebase/firestore');
    const b = writeBatch(db);
    for (const [path, data, op] of writes) op === 'delete' ? b.delete(doc(db, path)) : b.set(doc(db, path), data);
    return b.commit();
  };

  // Six months paid in one payment.
  const six = ['2027-01', '2027-02', '2027-03', '2027-04', '2027-05', '2027-06'];
  await assertSucceeds(batchOf(t, [
    [`${B}/transactions/r1`, pay('r1', six)],
    ...six.map((p) => [`${B}/subscriptionLocks/${p}_4`, lock(p, 'r1')]),
  ]));

  // A second payment overlapping March is refused as a whole.
  await assertFails(batchOf(t, [
    [`${B}/transactions/r2`, pay('r2', ['2027-03', '2027-07'])],
    [`${B}/subscriptionLocks/2027-03_4`, lock('2027-03', 'r2')],
    [`${B}/subscriptionLocks/2027-07_4`, lock('2027-07', 'r2')],
  ]));
  const { getDoc: g } = await import('firebase/firestore');
  await assertFails(g(doc(anon(), `${B}/subscriptionLocks/2027-03_4`)));

  // A lock must belong to a payment that covers that month and apartment.
  await assertFails(setDoc(doc(t, `${B}/subscriptionLocks/2027-08_4`), lock('2027-08', 'r1')));
  await assertFails(setDoc(doc(t, `${B}/subscriptionLocks/2027-08_5`), lock('2027-08', 'r1', 5)));
  await assertFails(setDoc(doc(t, `${B}/subscriptionLocks/x`), lock('2027-01', 'r1')));

  // Locks of an active payment cannot be removed on their own.
  await assertFails(deleteDoc(doc(t, `${B}/subscriptionLocks/2027-01_4`)));

  // Cancelling the payment releases all its months.
  await assertSucceeds(batchOf(t, [
    [`${B}/transactions/r1`, pay('r1', six, { voided: true })],
    ...six.map((p) => [`${B}/subscriptionLocks/${p}_4`, null, 'delete']),
  ]));
  await assertSucceeds(batchOf(t, [
    [`${B}/transactions/r2`, pay('r2', ['2027-03'])],
    [`${B}/subscriptionLocks/2027-03_4`, lock('2027-03', 'r2')],
  ]));
});

test('projects: admins create and edit, treasurers read and collect, nobody deletes', async () => {
  const project = { name: 'دهان السلم', icon: 'paint', total: 60000, shares: { '4': 30000, '7': 30000 } };
  await assertSucceeds(setDoc(doc(as('owner'), `${B}/projects/p1`), project));
  await assertFails(setDoc(doc(as('treasurer'), `${B}/projects/p2`), project));
  await assertFails(setDoc(doc(as('owner'), `${B}/projects/p3`), { ...project, total: 0 }));
  await assertSucceeds(getDoc(doc(as('treasurer'), `${B}/projects/p1`)));
  await assertFails(getDoc(doc(anon(), `${B}/projects/p1`)));
  await assertFails(deleteDoc(doc(as('owner'), `${B}/projects/p1`)));
  await assertSucceeds(setDoc(doc(as('treasurer'), `${B}/transactions/prj_p1_4`), {
    type: 'project', amount: 30000, projectId: 'p1', apartmentNumber: 4, createdBy: 'treasurer', voided: false,
  }));
});
