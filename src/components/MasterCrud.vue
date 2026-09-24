<template>
  <section class="master-page">
    <header class="page-heading">
      <div>
        <div class="page-kicker">MASTER DATA</div>
        <h1>{{ title }}</h1>
        <p>{{ subtitle }}</p>
      </div>
      <q-btn v-if="allowCreate" unelevated no-caps icon="add" :label="`Tambah ${singular}`" class="add-btn" @click="openCreate" />
    </header>

    <q-card flat class="data-card">
      <div class="table-toolbar">
        <q-input v-model="search" dense outlined clearable placeholder="Cari data..." class="search-input">
          <template #prepend><q-icon name="search" size="19px" /></template>
        </q-input>
        <div class="record-count">{{ filteredRows.length }} data</div>
      </div>

      <q-table
        flat dense :rows="filteredRows" :columns="columns" row-key="id" :loading="loading"
        :pagination="{ rowsPerPage: 10 }" class="master-table" no-data-label="Belum ada data"
        rows-per-page-label="Baris per halaman"
      >
        <template #body-cell-index="props"><q-td :props="props">{{ props.rowIndex + 1 }}</q-td></template>
        <template #body-cell-active="props">
          <q-td :props="props"><q-badge rounded :color="props.value ? 'green-1' : 'grey-3'" :text-color="props.value ? 'green-9' : 'grey-8'" :label="props.value ? 'Aktif' : 'Nonaktif'" /></q-td>
        </template>
        <template #body-cell-actions="props">
          <q-td :props="props" class="actions-cell">
            <q-btn round flat dense icon="edit" size="sm" color="primary" @click="openEdit(props.row)"><q-tooltip>Edit</q-tooltip></q-btn>
            <q-btn v-if="allowDelete" round flat dense icon="delete_outline" size="sm" color="negative" @click="confirmDelete(props.row)"><q-tooltip>Hapus</q-tooltip></q-btn>
          </q-td>
        </template>
        <template #no-data>
          <div class="empty-state"><q-icon :name="icon" size="44px" /><strong>Belum ada {{ title.toLowerCase() }}</strong><span>Klik tombol tambah untuk membuat data pertama.</span></div>
        </template>
      </q-table>
    </q-card>

    <q-dialog v-model="dialogOpen" persistent>
      <q-card class="form-dialog">
        <q-card-section class="dialog-head">
          <div><span>{{ editingId ? 'PERBARUI DATA' : 'DATA BARU' }}</span><h2>{{ editingId ? `Edit ${singular}` : `Tambah ${singular}` }}</h2></div>
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>
        <q-separator />
        <q-form @submit.prevent="save">
          <q-card-section class="form-grid">
            <div v-for="field in fields" :key="field.name" :class="{ 'field-full': field.full }">
              <label>{{ field.label }} <i v-if="field.required">*</i></label>
              <q-select
                v-if="field.type === 'select'" v-model="form[field.name]" outlined dense emit-value map-options
                :options="resolveOptions(field)" :option-label="field.optionLabel || 'label'" :option-value="field.optionValue || 'value'"
                :placeholder="field.placeholder" :rules="field.required ? requiredRules : []" clearable
              />
              <q-toggle v-else-if="field.type === 'toggle'" v-model="form[field.name]" color="primary" :label="form[field.name] ? 'Aktif' : 'Nonaktif'" />
              <q-input
                v-else v-model="form[field.name]" outlined dense :type="field.type || 'text'" :placeholder="field.placeholder"
                :rules="fieldRules(field)" :autogrow="field.type === 'textarea'"
              />
            </div>
          </q-card-section>
          <q-separator />
          <q-card-actions align="right" class="dialog-actions">
            <q-btn flat no-caps label="Batal" color="grey-7" v-close-popup />
            <q-btn unelevated no-caps type="submit" label="Simpan data" color="primary" :loading="saving" />
          </q-card-actions>
        </q-form>
      </q-card>
    </q-dialog>

    <q-dialog v-model="deleteOpen">
      <q-card class="delete-dialog">
        <q-card-section><div class="delete-icon"><q-icon name="delete_outline" size="28px" /></div><h3>Hapus data?</h3><p>Data <strong>{{ deleteTarget?.[displayField] }}</strong> akan dihapus permanen.</p></q-card-section>
        <q-card-actions align="right"><q-btn flat no-caps label="Batal" v-close-popup /><q-btn unelevated no-caps label="Ya, hapus" color="negative" :loading="saving" @click="remove" /></q-card-actions>
      </q-card>
    </q-dialog>
  </section>
</template>

<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useQuasar } from 'quasar'
import { supabase } from '../lib/supabase'

const props = defineProps({
  table: { type: String, required: true }, title: { type: String, required: true }, singular: { type: String, required: true },
  subtitle: { type: String, required: true }, icon: { type: String, default: 'folder_open' },
  columns: { type: Array, required: true }, fields: { type: Array, required: true },
  options: { type: Object, default: () => ({}) }, displayField: { type: String, default: 'name' },
  allowCreate: { type: Boolean, default: true }, allowDelete: { type: Boolean, default: true },
})
const emit = defineEmits(['changed'])
const $q = useQuasar()
const rows = ref([]), loading = ref(false), saving = ref(false), search = ref('')
const dialogOpen = ref(false), deleteOpen = ref(false), editingId = ref(null), deleteTarget = ref(null)
const form = reactive({})
const requiredRules = [(v) => (v !== null && v !== undefined && String(v).trim() !== '') || 'Field wajib diisi']
const emailRule = (v) => !v || /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v) || 'Format email tidak valid'

const filteredRows = computed(() => {
  const needle = (search.value || '').toLowerCase()
  return !needle ? rows.value : rows.value.filter((row) => Object.values(row).some((value) => String(value ?? '').toLowerCase().includes(needle)))
})

function resolveOptions(field) {
  const list = props.options[field.optionsKey] || field.options || []
  if (!field.dependsOn) return list
  return list.filter((item) => !form[field.dependsOn] || item[field.filterKey] === form[field.dependsOn])
}
function fieldRules(field) { return [...(field.required ? requiredRules : []), ...(field.type === 'email' ? [emailRule] : [])] }
function blankForm() { props.fields.forEach((field) => { form[field.name] = field.default ?? (field.type === 'toggle' ? true : null) }) }
function openCreate() { editingId.value = null; blankForm(); dialogOpen.value = true }
function openEdit(row) { editingId.value = row.id; props.fields.forEach((field) => { form[field.name] = row[field.name] ?? field.default ?? null }); dialogOpen.value = true }
function confirmDelete(row) { deleteTarget.value = row; deleteOpen.value = true }

async function load() {
  loading.value = true
  const { data, error } = await supabase.from(props.table).select('*').order('created_at', { ascending: false })
  if (error) $q.notify({ type: 'negative', message: `Gagal memuat data: ${error.message}` })
  else rows.value = data
  loading.value = false
}
async function save() {
  saving.value = true
  const payload = Object.fromEntries(props.fields.map((field) => [field.name, form[field.name] === '' ? null : form[field.name]]))
  const query = editingId.value ? supabase.from(props.table).update(payload).eq('id', editingId.value) : supabase.from(props.table).insert(payload)
  const { error } = await query
  if (error) $q.notify({ type: 'negative', message: `Data gagal disimpan: ${error.message}` })
  else { $q.notify({ type: 'positive', message: 'Data berhasil disimpan.' }); dialogOpen.value = false; await load(); emit('changed') }
  saving.value = false
}
async function remove() {
  saving.value = true
  const { error } = await supabase.from(props.table).delete().eq('id', deleteTarget.value.id)
  if (error) $q.notify({ type: 'negative', message: `Data gagal dihapus: ${error.message}` })
  else { $q.notify({ type: 'positive', message: 'Data berhasil dihapus.' }); deleteOpen.value = false; await load(); emit('changed') }
  saving.value = false
}

watch(() => props.table, load)
onMounted(load)
defineExpose({ load })
</script>

<style scoped>
.master-page{max-width:1400px;margin:auto}.page-heading{display:flex;justify-content:space-between;align-items:flex-end;gap:20px;margin-bottom:22px}.page-kicker{color:#168066;font-size:10px;font-weight:800;letter-spacing:1.8px}.page-heading h1{margin:4px 0;color:#183c32;font:600 29px Georgia,serif}.page-heading p{margin:0;color:#7c8d87;font-size:12px}.add-btn{height:40px;padding:0 17px;border-radius:9px;background:#116b54;color:#fff;font-size:11px;font-weight:700;box-shadow:0 8px 18px rgba(17,107,84,.18)}.data-card{overflow:hidden;border:1px solid #e2e9e6;border-radius:14px;box-shadow:0 8px 30px rgba(32,64,54,.05)}.table-toolbar{display:flex;align-items:center;justify-content:space-between;padding:14px 16px;border-bottom:1px solid #e8eeeb}.search-input{width:min(320px,75%)}.search-input :deep(.q-field__control){height:38px;border-radius:9px}.record-count{color:#8d9995;font-size:10px}.master-table{color:#40564f}.master-table :deep(th){height:42px;color:#70807a;background:#f8faf9;font-size:9px;font-weight:800;letter-spacing:.5px;text-transform:uppercase}.master-table :deep(td){height:47px;font-size:11px;border-color:#edf1ef}.actions-cell{white-space:nowrap}.empty-state{width:100%;display:flex;flex-direction:column;align-items:center;padding:65px 20px;color:#b0bbb7}.empty-state strong{margin-top:10px;color:#6e8079;font-size:12px}.empty-state span{margin-top:4px;font-size:10px}.form-dialog{width:min(620px,calc(100vw - 30px));border-radius:16px}.dialog-head{display:flex;align-items:center;justify-content:space-between;padding:19px 22px}.dialog-head span{color:#168066;font-size:9px;font-weight:800;letter-spacing:1.4px}.dialog-head h2{margin:3px 0 0;color:#203f36;font:600 21px Georgia,serif}.form-grid{display:grid;grid-template-columns:1fr 1fr;gap:2px 14px;padding:20px 22px}.field-full{grid-column:1/-1}.form-grid label{display:block;margin:0 0 6px 2px;color:#41574f;font-size:10px;font-weight:700}.form-grid label i{color:#c64b50;font-style:normal}.form-grid :deep(.q-field){margin-bottom:7px;font-size:11px}.form-grid :deep(.q-field__control){min-height:40px;border-radius:8px}.form-grid :deep(.q-field__bottom){padding-top:3px;font-size:9px}.dialog-actions{padding:13px 20px}.dialog-actions .q-btn{min-width:90px;border-radius:8px;font-size:11px}.terms{font-size:10px}.delete-dialog{width:min(390px,calc(100vw - 30px));padding:13px;border-radius:15px;text-align:center}.delete-icon{width:52px;height:52px;display:grid;place-items:center;margin:5px auto 12px;border-radius:15px;color:#bd4149;background:#fff0f1}.delete-dialog h3{margin:0;color:#27443b;font-size:17px}.delete-dialog p{margin:8px 0 0;color:#7d8b86;font-size:11px}.delete-dialog .q-card__actions{padding:12px}.delete-dialog .q-btn{font-size:11px}
@media(max-width:650px){.page-heading{align-items:flex-start;flex-direction:column}.add-btn{width:100%}.page-heading h1{font-size:25px}.form-grid{grid-template-columns:1fr}.field-full{grid-column:auto}.data-card{border-radius:12px}.master-table{max-width:100%;overflow:auto}.table-toolbar{padding:12px}.form-dialog{max-height:92vh;overflow:auto}}
</style>
