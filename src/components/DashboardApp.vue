<template>
  <q-layout view="hHh Lpr lFf" class="dashboard-layout">
    <q-header class="topbar">
      <q-toolbar>
        <q-btn flat round dense icon="menu" class="mobile-menu" @click="drawerOpen = !drawerOpen" />
        <div class="top-title"><span>{{ activeMenu.label }}</span><small>Sistem Manajemen Masjid</small></div>
        <q-space />
        <q-btn flat round dense icon="notifications_none"><q-badge floating rounded color="amber-7" /></q-btn>
        <div class="user-chip">
          <div class="avatar">{{ initials }}</div>
          <div><strong>{{ userName }}</strong><span>{{ session.user.email }}</span></div>
          <q-btn flat round dense icon="expand_more" size="sm"><q-menu anchor="bottom right" self="top right"><q-list style="min-width:170px"><q-item clickable v-close-popup @click="$emit('logout')"><q-item-section avatar><q-icon name="logout" /></q-item-section><q-item-section>Keluar</q-item-section></q-item></q-list></q-menu></q-btn>
        </div>
      </q-toolbar>
    </q-header>

    <q-drawer v-model="drawerOpen" show-if-above :width="246" :breakpoint="850" class="sidebar">
      <div class="sidebar-brand"><div class="logo"><q-icon name="mosque" size="25px" /></div><div><strong>DKM MASJID</strong><span>Management System</span></div></div>
      <q-list class="nav-list">
        <template v-for="item in menu" :key="item.id">
          <div v-if="item.header" class="nav-label">{{ item.header }}</div>
          <q-item v-else clickable v-ripple :active="page === item.id" active-class="nav-active" @click="navigate(item.id)">
            <q-item-section avatar><q-icon :name="item.icon" size="20px" /></q-item-section>
            <q-item-section>{{ item.label }}</q-item-section>
            <q-item-section v-if="item.id !== 'home'" side><q-icon name="chevron_right" size="16px" /></q-item-section>
          </q-item>
        </template>
      </q-list>
      <div class="sidebar-bottom"><q-btn flat no-caps icon="logout" label="Keluar" class="logout-btn" @click="$emit('logout')" /><span>DKM Masjid · v1.0</span></div>
    </q-drawer>

    <q-page-container><q-page class="dashboard-page">
      <div v-if="page === 'home'" class="landing">
        <section class="welcome-banner">
          <div><span class="welcome-kicker">ASSALAMU'ALAIKUM</span><h1>Selamat datang, {{ firstName }}.</h1><p>Kelola seluruh data dan aktivitas masjid dari satu dashboard yang terintegrasi.</p></div>
          <div class="banner-art"><q-icon name="mosque" size="100px" /></div>
        </section>

        <section class="stats-grid">
          <article v-for="stat in stats" :key="stat.label" class="stat-card">
            <div class="stat-icon" :class="stat.color"><q-icon :name="stat.icon" size="23px" /></div>
            <div><span>{{ stat.label }}</span><strong>{{ loadingCounts ? '–' : stat.value }}</strong><small>{{ stat.note }}</small></div>
          </article>
        </section>

        <section class="landing-grid">
          <q-card flat class="quick-card">
            <div class="section-head"><div><span>AKSES CEPAT</span><h2>Kelola master data</h2></div></div>
            <div class="quick-grid">
              <button v-for="item in masterMenu" :key="item.id" @click="navigate(item.id)">
                <div class="quick-icon"><q-icon :name="item.icon" size="23px" /></div><div><strong>{{ item.label }}</strong><span>{{ item.description }}</span></div><q-icon name="arrow_forward" />
              </button>
            </div>
          </q-card>
          <q-card flat class="info-card">
            <div class="info-icon"><q-icon name="tips_and_updates" size="25px" /></div><h3>Mulai dari data masjid</h3><p>Tambahkan master masjid terlebih dahulu sebelum memetakan user, majelis, dan anggota.</p><q-btn flat no-caps label="Tambah masjid" icon-right="arrow_forward" @click="navigate('masjid')" />
          </q-card>
        </section>
      </div>

      <MasterCrud
        v-else-if="!['quran', 'learning', 'evaluation', 'absensi'].includes(page)" :key="page" :table="currentConfig.table" :title="currentConfig.title" :singular="currentConfig.singular"
        :subtitle="currentConfig.subtitle" :icon="currentConfig.icon" :columns="currentConfig.columns" :fields="currentConfig.fields"
        :options="lookupOptions" :display-field="currentConfig.displayField || 'name'"
        :allow-create="page !== 'users'" :allow-delete="page !== 'users'" @changed="refreshAll"
      />
      <QuranMurajaah v-else-if="page === 'quran'" :profile="profile" />
      <LearningProgram v-else-if="page === 'learning'" :profile="profile" />
      <EvaluationRanking v-else-if="page === 'evaluation'" :profile="profile" />
      <AttendanceApp v-else :profile="profile" />
    </q-page></q-page-container>
  </q-layout>
</template>

<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import MasterCrud from './MasterCrud.vue'
import QuranMurajaah from './QuranMurajaah.vue'
import AttendanceApp from './AttendanceApp.vue'
import EvaluationRanking from './EvaluationRanking.vue'
import LearningProgram from './LearningProgram.vue'
import { supabase } from '../lib/supabase'

const props = defineProps({ session: { type: Object, required: true }, profile: { type: Object, required: true } })
defineEmits(['logout'])
const page = ref('home'), drawerOpen = ref(false), loadingCounts = ref(true)
const counts = reactive({ masjids: 0, app_users: 0, majelis: 0, anggota: 0 })
const lookupOptions = reactive({ masjids: [], majelis: [] })
const allMenu = [
  { id: 'home', label: 'Dashboard', icon: 'space_dashboard' }, { header: 'MASTER DATA' },
  { id: 'masjid', label: 'Master Masjid', icon: 'mosque', description: 'Data dan informasi masjid' },
  { id: 'users', label: 'Master User', icon: 'manage_accounts', description: 'User dan akses masjid' },
  { id: 'majelis', label: 'Master Majelis', icon: 'local_library', description: 'TPQ dan Majelis Taklim' },
  { id: 'anggota', label: 'Master Anggota', icon: 'groups', description: 'Pengajar dan murid' },
  { header: 'PEMBELAJARAN' },
  { id: 'learning', label: 'Program Pembelajaran', icon: 'school', description: 'Program, bab, materi, dan berkas' },
  { id: 'quran', label: 'Al-Qur’an & Murojaah', icon: 'menu_book', description: 'Hafalan dan murojaah santri' },
  { id: 'evaluation', label: 'Evaluasi & Ranking', icon: 'leaderboard', description: 'Soal, attempt, progres, dan ranking' },
  { header: 'OPERASIONAL' },
  { id: 'absensi', label: 'Absensi Berjamaah', icon: 'qr_code_scanner', description: 'QR, sesi, dan rekap kehadiran' },
]
const allowedPages = computed(() => ({ super_administrator: ['home', 'masjid', 'users', 'majelis', 'anggota', 'learning', 'quran', 'evaluation', 'absensi'], administrator: ['home', 'masjid', 'users', 'majelis', 'anggota', 'learning', 'quran', 'evaluation', 'absensi'], pengurus: ['home', 'majelis', 'anggota', 'learning', 'quran', 'evaluation', 'absensi'], operator: ['home', 'anggota', 'learning', 'quran', 'evaluation', 'absensi'] }[props.profile.role] || ['home']))
const menu = computed(() => allMenu.filter((item) => item.header || allowedPages.value.includes(item.id)))
const masterMenu = computed(() => menu.value.filter((item) => item.id && item.id !== 'home'))
const activeMenu = computed(() => menu.value.find((item) => item.id === page.value) || menu.value[0])
const userName = computed(() => props.profile.full_name || props.session.user.user_metadata?.full_name || props.session.user.email.split('@')[0])
const firstName = computed(() => userName.value.split(' ')[0])
const initials = computed(() => userName.value.split(' ').slice(0, 2).map((part) => part[0]?.toUpperCase()).join(''))
const stats = computed(() => [
  { label: 'Total Masjid', value: counts.masjids, icon: 'mosque', color: 'green', note: 'Terdaftar dalam sistem' },
  { label: 'Total User', value: counts.app_users, icon: 'manage_accounts', color: 'blue', note: 'User pengelola' },
  { label: 'Total Majelis', value: counts.majelis, icon: 'local_library', color: 'amber', note: 'TPQ & Majelis Taklim' },
  { label: 'Total Anggota', value: counts.anggota, icon: 'groups', color: 'purple', note: 'Pengajar & murid' },
])

const common = { align: 'left', sortable: true }
const configs = {
  masjid: {
    table: 'masjids', title: 'Master Masjid', singular: 'Masjid', subtitle: 'Kelola identitas dan informasi seluruh masjid.', icon: 'mosque',
    columns: [{ name: 'index', label: '#', field: 'index', align: 'left' }, { name: 'name', label: 'Nama Masjid', field: 'name', ...common }, { name: 'phone', label: 'Telepon', field: 'phone', ...common }, { name: 'address', label: 'Alamat', field: 'address', ...common }, { name: 'actions', label: 'Aksi', field: 'actions', align: 'right' }],
    fields: [{ name: 'name', label: 'Nama masjid', placeholder: 'Contoh: Masjid Al-Ikhlas', required: true, full: true }, { name: 'phone', label: 'Nomor telepon', placeholder: '08xxxxxxxxxx' }, { name: 'address', label: 'Alamat lengkap', placeholder: 'Alamat masjid', type: 'textarea', required: true, full: true }],
  },
  users: {
    table: 'app_users', title: 'Master User', singular: 'User', subtitle: 'Kelola data pengguna dan pemetaan masjid.', icon: 'manage_accounts', displayField: 'full_name',
    columns: [{ name: 'index', label: '#', field: 'index' }, { name: 'full_name', label: 'Nama User', field: 'full_name', ...common }, { name: 'email', label: 'Email', field: 'email', ...common }, { name: 'masjid_name', label: 'Masjid', field: (row) => optionLabel('masjids', row.masjid_id), ...common }, { name: 'role', label: 'Role', field: 'role', ...common }, { name: 'verification_status', label: 'Verifikasi', field: 'verification_status', ...common }, { name: 'actions', label: 'Aksi', field: 'actions', align: 'right' }],
    fields: [{ name: 'full_name', label: 'Nama lengkap', placeholder: 'Nama user', required: true }, { name: 'phone', label: 'Nomor telepon', placeholder: '08xxxxxxxxxx' }, { name: 'masjid_id', label: 'Masjid', type: 'select', optionsKey: 'masjids', required: true }, { name: 'role', label: 'Role akses', type: 'select', options: [{ label: 'Administrator', value: 'administrator' }, { label: 'Pengurus', value: 'pengurus' }, { label: 'Operator', value: 'operator' }], required: true, default: 'operator' }, { name: 'verification_status', label: 'Status verifikasi', type: 'select', options: [{ label: 'Menunggu', value: 'pending' }, { label: 'Terverifikasi', value: 'verified' }, { label: 'Ditolak', value: 'rejected' }, { label: 'Nonaktif', value: 'inactive' }], required: true, default: 'pending' }, { name: 'rejection_reason', label: 'Catatan verifikasi', type: 'textarea', full: true }],
  },
  majelis: {
    table: 'majelis', title: 'Master Majelis', singular: 'Majelis', subtitle: 'Kelola TPQ dan Majelis Taklim yang terhubung ke masjid.', icon: 'local_library',
    columns: [{ name: 'index', label: '#', field: 'index' }, { name: 'name', label: 'Nama Majelis', field: 'name', ...common }, { name: 'type', label: 'Jenis', field: 'type', ...common }, { name: 'masjid_name', label: 'Masjid', field: (row) => optionLabel('masjids', row.masjid_id), ...common }, { name: 'leader', label: 'Penanggung Jawab', field: 'leader', ...common }, { name: 'actions', label: 'Aksi', field: 'actions', align: 'right' }],
    fields: [{ name: 'name', label: 'Nama TPQ / majelis', placeholder: 'Nama majelis', required: true }, { name: 'type', label: 'Jenis', type: 'select', options: [{ label: 'TPQ', value: 'TPQ' }, { label: 'Majelis Taklim', value: 'Majelis Taklim' }], required: true }, { name: 'masjid_id', label: 'Masjid', type: 'select', optionsKey: 'masjids', required: true }, { name: 'leader', label: 'Penanggung jawab', placeholder: 'Nama penanggung jawab' }, { name: 'description', label: 'Keterangan', type: 'textarea', placeholder: 'Keterangan tambahan', full: true }],
  },
  anggota: {
    table: 'anggota', title: 'Master Anggota', singular: 'Anggota', subtitle: 'Kelola data pengajar dan murid beserta pemetaannya.', icon: 'groups',
    columns: [{ name: 'index', label: '#', field: 'index' }, { name: 'name', label: 'Nama Anggota', field: 'name', ...common }, { name: 'gender', label: 'Jenis Kelamin', field: 'gender', ...common }, { name: 'member_role', label: 'Peran', field: 'member_role', ...common }, { name: 'membership_status', label: 'Status Keanggotaan', field: 'membership_status', ...common }, { name: 'majelis_name', label: 'Majelis', field: (row) => optionLabel('majelis', row.majelis_id), ...common }, { name: 'actions', label: 'Aksi', field: 'actions', align: 'right' }],
    fields: [{ name: 'name', label: 'Nama anggota', placeholder: 'Nama lengkap', required: true }, { name: 'birth_date', label: 'Tanggal lahir', type: 'date', required: true }, { name: 'gender', label: 'Jenis kelamin', type: 'select', options: [{ label: 'Laki-laki', value: 'Laki-laki' }, { label: 'Perempuan', value: 'Perempuan' }], required: true }, { name: 'member_role', label: 'Peran anggota', type: 'select', options: [{ label: 'Pengajar', value: 'pengajar' }, { label: 'Murid', value: 'murid' }], required: true }, { name: 'membership_status', label: 'Status keanggotaan', type: 'select', options: [{ label: 'Aktif', value: 'active' }, { label: 'Nonaktif', value: 'inactive' }, { label: 'Lulus', value: 'graduated' }], required: true, default: 'active' }, { name: 'masjid_id', label: 'Masjid', type: 'select', optionsKey: 'masjids', required: true }, { name: 'majelis_id', label: 'Majelis / TPQ', type: 'select', optionsKey: 'majelis', dependsOn: 'masjid_id', filterKey: 'masjid_id', required: true }, { name: 'address', label: 'Alamat', type: 'textarea', placeholder: 'Alamat lengkap', required: true, full: true }],
  },
}
const currentConfig = computed(() => configs[page.value])
function optionLabel(key, id) { return lookupOptions[key].find((item) => item.value === id)?.label || '–' }
function navigate(id) { page.value = id; if (window.innerWidth < 850) drawerOpen.value = false }
async function loadLookups() {
  const [masjids, majelis] = await Promise.all([supabase.from('masjids').select('id,name').order('name'), supabase.from('majelis').select('id,name,masjid_id').order('name')])
  lookupOptions.masjids = (masjids.data || []).map((item) => ({ value: item.id, label: item.name }))
  lookupOptions.majelis = (majelis.data || []).map((item) => ({ value: item.id, label: item.name, masjid_id: item.masjid_id }))
}
async function loadCounts() {
  loadingCounts.value = true
  await Promise.all(Object.keys(counts).map(async (table) => { const { count } = await supabase.from(table).select('*', { count: 'exact', head: true }); counts[table] = count || 0 }))
  loadingCounts.value = false
}
async function refreshAll() { await Promise.all([loadLookups(), loadCounts()]) }
onMounted(refreshAll)
</script>

<style>
.dashboard-layout{min-height:100vh;background:#f4f7f5}.topbar{color:#334c44;background:rgba(255,255,255,.96);border-bottom:1px solid #e4ebe8;box-shadow:none}.topbar .q-toolbar{height:64px;padding:0 24px}.mobile-menu{display:none}.top-title{display:flex;flex-direction:column}.top-title span{font-size:13px;font-weight:750}.top-title small{color:#98a49f;font-size:9px}.user-chip{display:flex;align-items:center;gap:9px;margin-left:13px;padding-left:15px;border-left:1px solid #e7ecea}.avatar{width:34px;height:34px;display:grid;place-items:center;border-radius:10px;color:#fff;background:linear-gradient(145deg,#116b54,#24947a);font-size:10px;font-weight:800}.user-chip>div:nth-child(2){display:flex;flex-direction:column;max-width:170px}.user-chip strong{font-size:10px}.user-chip span{overflow:hidden;color:#8d9a95;font-size:8px;text-overflow:ellipsis}.sidebar{color:#d8e8e2;background:linear-gradient(180deg,#0b493b,#0d5e4b)}.sidebar-brand{height:86px;display:flex;align-items:center;gap:12px;padding:0 22px;border-bottom:1px solid rgba(255,255,255,.1)}.logo{width:42px;height:42px;display:grid;place-items:center;border-radius:13px;color:#0d5e4b;background:linear-gradient(145deg,#f6dfa0,#d4b361)}.sidebar-brand>div:last-child{display:flex;flex-direction:column}.sidebar-brand strong{font-size:13px;letter-spacing:1.3px}.sidebar-brand span{color:rgba(255,255,255,.5);font-size:8px}.nav-list{padding:18px 12px}.nav-label{padding:20px 12px 8px;color:rgba(255,255,255,.35);font-size:8px;font-weight:800;letter-spacing:1.4px}.nav-list .q-item{min-height:43px;margin:3px 0;padding:0 12px;border-radius:9px;color:rgba(255,255,255,.68);font-size:10px}.nav-list .q-item__section--avatar{min-width:36px}.nav-active{color:#fff!important;background:rgba(255,255,255,.12)}.nav-active:before{content:'';position:absolute;left:0;width:3px;height:20px;border-radius:0 3px 3px 0;background:#e0bf68}.sidebar-bottom{position:absolute;right:15px;bottom:18px;left:15px;display:flex;flex-direction:column;align-items:center}.logout-btn{width:100%;justify-content:flex-start;border-top:1px solid rgba(255,255,255,.1);color:rgba(255,255,255,.7);font-size:10px}.sidebar-bottom span{margin-top:12px;color:rgba(255,255,255,.25);font-size:8px}.dashboard-page{padding:28px}.landing{max-width:1400px;margin:auto}.welcome-banner{position:relative;overflow:hidden;display:flex;align-items:center;min-height:190px;padding:35px 40px;border-radius:18px;color:#fff;background:linear-gradient(120deg,#0c5544,#14735c);box-shadow:0 14px 35px rgba(17,94,75,.16)}.welcome-banner:after{content:'';position:absolute;right:-80px;width:330px;height:330px;border:1px solid rgba(255,255,255,.12);border-radius:50%;box-shadow:0 0 0 55px rgba(255,255,255,.04),0 0 0 110px rgba(255,255,255,.025)}.welcome-kicker{color:#e4c879;font-size:9px;font-weight:800;letter-spacing:2px}.welcome-banner h1{margin:8px 0 7px;font:500 31px Georgia,serif}.welcome-banner p{margin:0;color:rgba(255,255,255,.68);font-size:11px}.banner-art{z-index:1;margin-left:auto;margin-right:40px;color:rgba(235,207,132,.75)}.stats-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin:18px 0}.stat-card{display:flex;align-items:center;gap:13px;padding:18px;border:1px solid #e1e9e6;border-radius:13px;background:#fff}.stat-icon{width:43px;height:43px;display:grid;place-items:center;flex:none;border-radius:12px}.stat-icon.green{color:#137159;background:#e7f5ef}.stat-icon.blue{color:#3672ad;background:#ebf3fb}.stat-icon.amber{color:#ad7d27;background:#fff5dd}.stat-icon.purple{color:#7756a5;background:#f3edfb}.stat-card>div:last-child{display:flex;flex-direction:column}.stat-card span{color:#84928d;font-size:9px}.stat-card strong{margin:1px 0;color:#24433a;font-size:21px}.stat-card small{color:#a0aaa6;font-size:8px}.landing-grid{display:grid;grid-template-columns:1fr 280px;gap:16px}.quick-card,.info-card{border:1px solid #e1e9e6;border-radius:14px}.quick-card{padding:20px}.section-head span{color:#168066;font-size:8px;font-weight:800;letter-spacing:1.5px}.section-head h2{margin:3px 0 15px;color:#28463d;font:600 18px Georgia,serif}.quick-grid{display:grid;grid-template-columns:1fr 1fr;gap:9px}.quick-grid button{display:flex;align-items:center;gap:11px;padding:13px;border:1px solid #e6ece9;border-radius:10px;text-align:left;background:#fbfcfc;cursor:pointer;transition:.2s}.quick-grid button:hover{border-color:#8bc1b1;background:#f5fbf8;transform:translateY(-1px)}.quick-icon{width:38px;height:38px;display:grid;place-items:center;flex:none;border-radius:10px;color:#166d58;background:#e8f4ef}.quick-grid button>div:nth-child(2){display:flex;flex:1;flex-direction:column}.quick-grid strong{color:#334f46;font-size:10px}.quick-grid span{margin-top:2px;color:#97a29e;font-size:8px}.quick-grid button>.q-icon{color:#9aaaa4}.info-card{padding:24px;background:linear-gradient(155deg,#fffcf5,#fff)}.info-icon{width:46px;height:46px;display:grid;place-items:center;border-radius:13px;color:#9a7022;background:#fff1ca}.info-card h3{margin:17px 0 8px;color:#314b43;font-size:14px}.info-card p{margin:0;color:#87948f;font-size:10px;line-height:1.7}.info-card .q-btn{margin:15px 0 0 -10px;color:#116b54;font-size:10px;font-weight:700}
@media(max-width:1100px){.stats-grid{grid-template-columns:1fr 1fr}.landing-grid{grid-template-columns:1fr}.info-card{display:none}}
@media(max-width:850px){.mobile-menu{display:inline-flex}.topbar .q-toolbar{padding:0 14px}.dashboard-page{padding:20px}.user-chip>div:nth-child(2){display:none}.welcome-banner{padding:30px}.banner-art{margin-right:0}.quick-grid{grid-template-columns:1fr 1fr}}
@media(max-width:560px){.dashboard-page{padding:15px}.top-title small{display:none}.welcome-banner{min-height:175px;padding:25px}.welcome-banner h1{font-size:25px}.welcome-banner p{max-width:260px}.banner-art{display:none}.stats-grid{grid-template-columns:1fr 1fr;gap:9px}.stat-card{gap:9px;padding:13px}.stat-icon{width:36px;height:36px}.stat-card strong{font-size:18px}.stat-card small{display:none}.quick-grid{grid-template-columns:1fr}.quick-card{padding:15px}}
</style>
