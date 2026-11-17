import axios from 'axios';
import ApiClient from './ApiClient';

class PortalCustomers extends ApiClient {
  constructor() {
    super('portal_customers', { accountScoped: true });
  }

  get(params) {
    return axios.get(this.url, { params });
  }

  performAction(id, action) {
    return axios.post(`${this.url}/${id}/${action}`);
  }
}

export default new PortalCustomers();
