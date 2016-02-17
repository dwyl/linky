import test                from 'tape';

import reducer, { initialState } from '../../../../src/js/reducers/template.js';
import { CHANGE_TEMPLATE }       from '../../../../src/js/action_types';

test('template initialState', t => {
  let actual, expected;

  actual   = initialState;
  expected = ['STATE', 'IS', 'A', 'LIST'];
  t.deepEqual(actual, expected, 'initialState is as expected');

  t.end();
});

test('template reducer', t => {
  let actual, expected;

  actual   = reducer(['test'], {type: CHANGE_TEMPLATE, change: 'ed'});
  expected = ['test', 'ed'];
  t.deepEqual(actual, expected, 'on CHANGE_TEMPLATE appends change');

  t.end();
});
