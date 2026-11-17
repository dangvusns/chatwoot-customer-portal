import { frontendURL } from 'dashboard/helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import PortalCustomers from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/portal-customers'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'portal_customers_index',
          meta: { permissions: ['administrator'] },
          component: PortalCustomers,
        },
      ],
    },
  ],
};
