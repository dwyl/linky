'use strict';

import { CHANGE_TEMPLATE } from '../action_types.js';

export const initialState = ['STATE', 'IS', 'A', 'LIST'];

export default function (state = initialState, action ) {
  switch(action.type) {
    case 'CHANGE_TEMPLATE':
      return state.concat([action.change]);
    default:
      return state;
  }
}
