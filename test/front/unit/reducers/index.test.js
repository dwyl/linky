import test from 'tape';

import reducer from '../../../../src/js/reducers/';

test('combined reducer', t => {
  let actual, expected;

  actual   = Object.keys(reducer(undefined, {type: null}));
  expected = ['template', 'routeReducer'];
  t.deepEqual(actual, expected, 'correct initial state keys');

  t.end();
});
