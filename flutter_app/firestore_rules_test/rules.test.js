// Security rule tests for ../firestore.rules. Run with `npm test`, which
// starts the Firestore emulator (needs Java) and runs these with node:test.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

let env;

const hour = 60 * 60 * 1000;
const inHours = (h) => Timestamp.fromMillis(Date.now() + h * hour);

const event = (overrides = {}) => ({
  type: 'diaper',
  startTime: Timestamp.now(),
  endTime: Timestamp.now(),
  data: { diaperKind: 'wet' },
  note: null,
  createdAt: Timestamp.now(),
  ...overrides,
});

const db = (uid) =>
  uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();

/** Seed data with rules off: family f1 with alice, and invite codes. */
async function seed() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const admin = ctx.firestore();
    await setDoc(doc(admin, 'families/f1'), {
      members: ['alice'],
      createdBy: 'alice',
      createdAt: Timestamp.now(),
    });
    await setDoc(doc(admin, 'families/f1/events/e1'), event());
    await setDoc(doc(admin, 'families/f1/meta/profile'), { name: 'Miya' });
    await setDoc(doc(admin, 'families/f2'), {
      members: ['carol'],
      createdBy: 'carol',
      createdAt: Timestamp.now(),
    });
    await setDoc(doc(admin, 'inviteCodes/GOOD1234'), {
      familyId: 'f1',
      createdBy: 'alice',
      expiresAt: inHours(24),
    });
    await setDoc(doc(admin, 'inviteCodes/OLD12345'), {
      familyId: 'f1',
      createdBy: 'alice',
      expiresAt: inHours(-1),
    });
    await setDoc(doc(admin, 'inviteCodes/F2CODE99'), {
      familyId: 'f2',
      createdBy: 'carol',
      expiresAt: inHours(24),
    });
  });
}

/** The update a joining user sends: append their uid, name the code. */
const join = (uid, code, members = ['alice']) =>
  updateDoc(doc(db(uid), 'families/f1'), {
    members: [...members, uid],
    joinCode: code,
  });

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-miya-baby',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});

beforeEach(async () => {
  await env.clearFirestore();
  await seed();
});

after(async () => {
  await env.cleanup();
});

describe('families', () => {
  test('members can read their family; others and signed-out users cannot', async () => {
    await assertSucceeds(getDoc(doc(db('alice'), 'families/f1')));
    await assertFails(getDoc(doc(db('bob'), 'families/f1')));
    await assertFails(getDoc(doc(db(null), 'families/f1')));
  });

  test('a user can create a family with only themselves as member', async () => {
    const family = { members: ['bob'], createdBy: 'bob', createdAt: Timestamp.now() };
    await assertSucceeds(setDoc(doc(db('bob'), 'families/fb'), family));
  });

  test('a new family cannot list other members or another creator', async () => {
    await assertFails(
      setDoc(doc(db('bob'), 'families/fb'), {
        members: ['bob', 'alice'],
        createdBy: 'bob',
        createdAt: Timestamp.now(),
      }),
    );
    await assertFails(
      setDoc(doc(db('bob'), 'families/fb'), {
        members: ['bob'],
        createdBy: 'alice',
        createdAt: Timestamp.now(),
      }),
    );
    await assertFails(
      setDoc(doc(db(null), 'families/fb'), {
        members: [],
        createdBy: null,
        createdAt: Timestamp.now(),
      }),
    );
  });
});

describe('joining', () => {
  test('a valid invite code lets a user join', async () => {
    await assertSucceeds(join('bob', 'GOOD1234'));
    await assertSucceeds(getDoc(doc(db('bob'), 'families/f1/events/e1')));
  });

  test('more than two members can join', async () => {
    await assertSucceeds(join('bob', 'GOOD1234'));
    await assertSucceeds(join('dan', 'GOOD1234', ['alice', 'bob']));
  });

  test('an expired, wrong-family or missing code is rejected', async () => {
    await assertFails(join('bob', 'OLD12345'));
    await assertFails(join('bob', 'F2CODE99'));
    await assertFails(join('bob', 'NOPE0000'));
  });

  test('a join cannot remove members, add someone else, or change other fields', async () => {
    await assertFails(
      updateDoc(doc(db('bob'), 'families/f1'), { members: ['bob'], joinCode: 'GOOD1234' }),
    );
    await assertFails(
      updateDoc(doc(db('bob'), 'families/f1'), {
        members: ['alice', 'bob', 'eve'],
        joinCode: 'GOOD1234',
      }),
    );
    await assertFails(
      updateDoc(doc(db('bob'), 'families/f1'), {
        members: ['alice', 'bob'],
        joinCode: 'GOOD1234',
        createdBy: 'bob',
      }),
    );
  });
});

describe('events', () => {
  test('members can read, write and delete events', async () => {
    const alice = db('alice');
    await assertSucceeds(getDocs(collection(alice, 'families/f1/events')));
    await assertSucceeds(setDoc(doc(alice, 'families/f1/events/e2'), event()));
    await assertSucceeds(
      updateDoc(doc(alice, 'families/f1/events/e2'), { 'data.active': false }),
    );
    await assertSucceeds(deleteDoc(doc(alice, 'families/f1/events/e2')));
  });

  test('non-members and signed-out users get nothing', async () => {
    for (const other of [db('bob'), db(null)]) {
      await assertFails(getDoc(doc(other, 'families/f1/events/e1')));
      await assertFails(getDocs(collection(other, 'families/f1/events')));
      await assertFails(setDoc(doc(other, 'families/f1/events/e3'), event()));
      await assertFails(deleteDoc(doc(other, 'families/f1/events/e1')));
    }
  });

  test('events must have a known type and timestamp times', async () => {
    const alice = db('alice');
    await assertFails(setDoc(doc(alice, 'families/f1/events/x1'), event({ type: 'bath' })));
    await assertFails(
      setDoc(doc(alice, 'families/f1/events/x2'), event({ startTime: '2026-10-24T10:00:00Z' })),
    );
    await assertFails(setDoc(doc(alice, 'families/f1/events/x3'), event({ createdAt: null })));
  });
});

describe('profile', () => {
  test('only members can read and write the profile', async () => {
    await assertSucceeds(getDoc(doc(db('alice'), 'families/f1/meta/profile')));
    await assertSucceeds(setDoc(doc(db('alice'), 'families/f1/meta/profile'), { name: 'Kai' }));
    await assertFails(getDoc(doc(db('bob'), 'families/f1/meta/profile')));
    await assertFails(setDoc(doc(db('bob'), 'families/f1/meta/profile'), { name: 'Eve' }));
  });
});

describe('invite codes', () => {
  test('any signed-in user can get a code, but nobody can list them', async () => {
    await assertSucceeds(getDoc(doc(db('bob'), 'inviteCodes/GOOD1234')));
    await assertFails(getDoc(doc(db(null), 'inviteCodes/GOOD1234')));
    await assertFails(getDocs(collection(db('bob'), 'inviteCodes')));
    await assertFails(getDocs(collection(db('alice'), 'inviteCodes')));
  });

  test('only members can create codes for their family', async () => {
    const code = { familyId: 'f1', createdBy: 'alice', expiresAt: inHours(24 * 7) };
    await assertSucceeds(setDoc(doc(db('alice'), 'inviteCodes/NEW12345'), code));
    await assertFails(
      setDoc(doc(db('bob'), 'inviteCodes/BOB12345'), { ...code, createdBy: 'bob' }),
    );
    await assertFails(
      setDoc(doc(db('alice'), 'inviteCodes/F2STEAL1'), { ...code, familyId: 'f2' }),
    );
  });

  test('members can delete their family\'s codes; others cannot', async () => {
    await assertFails(deleteDoc(doc(db('bob'), 'inviteCodes/GOOD1234')));
    await assertSucceeds(deleteDoc(doc(db('alice'), 'inviteCodes/GOOD1234')));
  });
});
