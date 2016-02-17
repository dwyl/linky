import test from 'tape';

import { changeTemplate }  from '../../../../src/js/actions/template.js';
import { CHANGE_TEMPLATE } from '../../../../src/js/action_types';

test('changeTemplate action creator', t => {
  let actual, expected;

  actual   = changeTemplate('change');
  expected = {type: CHANGE_TEMPLATE, change: 'change' };
  t.deepEqual(actual, expected, 'correct action object created');

  t.end();
});
