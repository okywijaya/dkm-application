<template>
  <q-layout class="verification-layout">
    <q-page-container>
      <q-page class="verification-page">
        <q-card flat class="verification-card">
          <div class="status-icon" :class="status"><q-icon :name="statusIcon" size="38px" /></div>
          <span class="kicker">STATUS AKUN</span>
          <h1>{{ title }}</h1>
          <p>{{ description }}</p>
          <div class="account"><q-icon name="person_outline" /><div><small>Akun terdaftar</small><strong>{{ session.user.email }}</strong></div></div>
          <div v-if="profile?.rejection_reason" class="reason"><strong>Catatan administrator</strong>{{ profile.rejection_reason }}</div>
          <div class="actions">
            <q-btn outline no-caps color="primary" icon="refresh" label="Periksa ulang" :loading="loading" @click="$emit('refresh')" />
            <q-btn flat no-caps color="grey-7" icon="logout" label="Keluar" @click="$emit('logout')" />
          </div>
        </q-card>
      </q-page>
    </q-page-container>
  </q-layout>
</template>

<script setup>
import { computed } from 'vue'
const props = defineProps({ session: { type: Object, required: true }, profile: { type: Object, default: null }, loading: Boolean })
defineEmits(['refresh', 'logout'])
const status = computed(() => props.profile?.verification_status || 'pending')
const statusIcon = computed(() => ({ rejected: 'block', inactive: 'lock', pending: 'hourglass_top' }[status.value] || 'hourglass_top'))
const title = computed(() => ({ rejected: 'Verifikasi ditolak', inactive: 'Akun dinonaktifkan', pending: 'Akun sedang diverifikasi' }[status.value] || 'Profil belum tersedia'))
const description = computed(() => ({
  rejected: 'Permohonan Anda belum dapat disetujui. Hubungi administrator masjid bila membutuhkan bantuan.',
  inactive: 'Akses dashboard untuk akun ini sedang dinonaktifkan oleh administrator masjid.',
  pending: 'Administrator masjid akan memeriksa identitas dan hak akses Anda. Dashboard dapat digunakan setelah akun disetujui.',
}[status.value] || 'Profil aplikasi belum berhasil dibuat. Coba periksa ulang beberapa saat lagi.'))
</script>

<style scoped>
.verification-layout{min-height:100vh;background:radial-gradient(circle at top,#e7f3ee,#f5f7f6 50%)}.verification-page{min-height:100vh;display:grid;place-items:center;padding:24px}.verification-card{width:min(480px,100%);padding:48px;text-align:center;border:1px solid #dfe9e5;border-radius:24px;box-shadow:0 24px 70px rgba(31,76,62,.12)}.status-icon{width:76px;height:76px;display:grid;place-items:center;margin:0 auto 24px;border-radius:23px;color:#9b7020;background:#fff3d5}.status-icon.rejected{color:#b34349;background:#fff0f1}.status-icon.inactive{color:#697872;background:#edf1ef}.kicker{color:#13705a;font-size:10px;font-weight:800;letter-spacing:2px}.verification-card h1{margin:10px 0;color:#183c32;font:600 30px Georgia,serif}.verification-card>p{margin:0 auto 25px;max-width:360px;color:#71817b;font-size:13px;line-height:1.7}.account{display:flex;align-items:center;gap:12px;padding:14px;text-align:left;border-radius:12px;background:#f5f8f7}.account .q-icon{color:#16715b;font-size:24px}.account div{display:flex;min-width:0;flex-direction:column}.account small{color:#8a9893}.account strong{overflow:hidden;color:#345148;font-size:12px;text-overflow:ellipsis}.reason{margin-top:12px;padding:13px;text-align:left;color:#7e595b;font-size:12px;border-radius:10px;background:#fff5f5}.reason strong{display:block;margin-bottom:4px}.actions{display:flex;justify-content:center;gap:8px;margin-top:25px}.actions .q-btn{font-size:11px}@media(max-width:520px){.verification-card{padding:34px 22px}}
</style>
