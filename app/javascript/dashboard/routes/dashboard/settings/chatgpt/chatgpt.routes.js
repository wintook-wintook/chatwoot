// import { frontendURL } from '../../../../helper/URLHelper';
// const SettingsWrapper = () => import('../SettingsWrapper.vue');
// const ChatGPTHome = () => import('./Index.vue');

// export default {
//   routes: [
//     {
//       path: frontendURL('accounts/:accountId/settings/chatgpt'),
//       component: SettingsWrapper,
//       children: [
//         {
//           path: '',
//           redirect: 'list',
//         },
//         {
//           path: 'list',
//           name: 'chatgpt_list',
//           meta: {
//             permissions: ['administrator', 'agent'],
//           },
//           component: ChatGPTHome,
//         },
//       ],
//     },
//   ],
// };

import { frontendURL } from '../../../../helper/URLHelper';
import {
  ROLES,
  CONVERSATION_PERMISSIONS,
} from 'dashboard/constants/permissions.js';
const SettingsWrapper = () => import('../SettingsWrapper.vue');
const ChatGPTHome = () => import('./Index.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/chatgpt'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          redirect: 'list',
        },
        {
          path: 'list',
          name: 'chatgpt_list',
          meta: {
            permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
          },
          component: ChatGPTHome,
        },
      ],
    },
  ],
};
