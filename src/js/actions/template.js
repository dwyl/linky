import { CHANGE_TEMPLATE } from '../action_types.js';

export const changeTemplate = (change) => {
  return {type: CHANGE_TEMPLATE, change };
};
