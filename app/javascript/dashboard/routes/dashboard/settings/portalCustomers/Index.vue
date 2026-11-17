<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import PortalCustomers from 'dashboard/api/portalCustomers';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';

const { t } = useI18n();
const customers = ref([]);
const name = ref('');
const email = ref('');
const locale = ref('en');
const page = ref(1);
const busy = ref(false);
const error = ref('');
const notice = ref('');
const PAGE_SIZE = 25;

async function fetchCustomers() {
  const { data } = await PortalCustomers.get({ page: page.value });
  customers.value = data;
}

async function loadPage(nextPage) {
  busy.value = true;
  error.value = '';
  const previousPage = page.value;
  try {
    page.value = nextPage;
    await fetchCustomers();
  } catch {
    page.value = previousPage;
    error.value = t('PORTAL_CUSTOMERS.ERROR');
  } finally {
    busy.value = false;
  }
}

async function invite() {
  busy.value = true;
  error.value = '';
  notice.value = '';
  try {
    await PortalCustomers.create({
      portal_customer: {
        name: name.value,
        email: email.value,
        locale: locale.value,
      },
    });
    name.value = '';
    email.value = '';
    page.value = 1;
    await fetchCustomers();
    notice.value = t('PORTAL_CUSTOMERS.INVITED');
  } catch (exception) {
    error.value =
      exception.response?.data?.message || t('PORTAL_CUSTOMERS.ERROR');
  } finally {
    busy.value = false;
  }
}

async function performAction(customer, action) {
  busy.value = true;
  error.value = '';
  notice.value = '';
  try {
    await PortalCustomers.performAction(customer.id, action);
    await fetchCustomers();
    notice.value = t('PORTAL_CUSTOMERS.UPDATED');
  } catch {
    error.value = t('PORTAL_CUSTOMERS.ERROR');
  } finally {
    busy.value = false;
  }
}

onMounted(() => loadPage(1));
</script>

<template>
  <SettingsLayout>
    <template #header>
      <BaseSettingsHeader :title="t('PORTAL_CUSTOMERS.TITLE')" />
    </template>
    <template #body>
      <p class="mb-6 text-n-slate-11">
        {{ t('PORTAL_CUSTOMERS.DESCRIPTION') }}
      </p>
      <p v-if="error" role="alert" class="mb-4 text-n-ruby-9">{{ error }}</p>
      <p v-if="notice" role="status" class="mb-4 text-n-teal-10">
        {{ notice }}
      </p>
      <form class="mb-8 flex flex-col gap-4" @submit.prevent="invite">
        <Input v-model="name" :label="t('PORTAL_CUSTOMERS.NAME')" />
        <Input
          v-model="email"
          type="email"
          :label="t('PORTAL_CUSTOMERS.EMAIL')"
        />
        <label class="flex flex-col gap-2">
          {{ t('PORTAL_CUSTOMERS.LANGUAGE') }}
          <select
            v-model="locale"
            class="rounded-lg border border-n-weak bg-n-background p-2"
          >
            <option value="en">{{ t('PORTAL_CUSTOMERS.ENGLISH') }}</option>
            <option value="vi">{{ t('PORTAL_CUSTOMERS.VIETNAMESE') }}</option>
          </select>
        </label>
        <Button
          type="submit"
          :disabled="busy || !name.trim() || !email.trim()"
          :label="t('PORTAL_CUSTOMERS.INVITE')"
        />
      </form>
      <ul class="flex flex-col gap-4">
        <li
          v-for="customer in customers"
          :key="customer.id"
          class="rounded-lg border border-n-weak p-4"
        >
          <p class="font-medium">{{ customer.name }} ({{ customer.email }})</p>
          <p class="mb-3 text-n-slate-11">
            {{ t(`PORTAL_CUSTOMERS.STATUS.${customer.status}`) }}
          </p>
          <div class="flex flex-wrap gap-2">
            <Button
              v-if="customer.status === 'invited'"
              :disabled="busy"
              :label="t('PORTAL_CUSTOMERS.RESEND')"
              @click="performAction(customer, 'invitation')"
            />
            <Button
              v-if="customer.status === 'active'"
              :disabled="busy"
              :label="t('PORTAL_CUSTOMERS.RESET')"
              @click="performAction(customer, 'password_reset')"
            />
            <Button
              v-if="customer.status !== 'suspended'"
              :disabled="busy"
              :label="t('PORTAL_CUSTOMERS.SUSPEND')"
              @click="performAction(customer, 'suspend')"
            />
            <Button
              v-else
              :disabled="busy"
              :label="t('PORTAL_CUSTOMERS.REACTIVATE')"
              @click="performAction(customer, 'reactivate')"
            />
          </div>
        </li>
      </ul>
      <p v-if="!busy && !customers.length">{{ t('PORTAL_CUSTOMERS.EMPTY') }}</p>
      <div class="mt-6 flex gap-3">
        <Button
          :disabled="busy || page === 1"
          :label="t('PORTAL_CUSTOMERS.PREVIOUS')"
          @click="loadPage(page - 1)"
        />
        <Button
          :disabled="busy || customers.length < PAGE_SIZE"
          :label="t('PORTAL_CUSTOMERS.NEXT')"
          @click="loadPage(page + 1)"
        />
      </div>
    </template>
  </SettingsLayout>
</template>
