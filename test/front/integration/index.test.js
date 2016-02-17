import test from 'tape';

require('../../../src/js');

test('Render react content into container in html', t => {
  let actual;
  /*global document */
  const content = document.getElementById('react_content');

  actual = content;
  t.ok(actual, 'we find something');

  t.end();
});
