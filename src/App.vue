<template>
  <DashboardApp v-if="session && profile?.verification_status === 'verified'" :session="session" :profile="profile" @logout="handleLogout" />
  <VerificationStatus v-else-if="session" :session="session" :profile="profile" :loading="profileLoading" @refresh="loadProfile" @logout="handleLogout" />
  <q-layout v-else class="auth-layout">
    <q-page-container><q-page class="auth-page">
      <section class="auth-shell">
        <aside class="brand-panel">
          <div class="glow glow-one"></div><div class="glow glow-two"></div>
          <div class="brand-mark">
            <div class="brand-icon"><q-icon name="mosque" size="29px" /></div>
            <div><div class="brand-name">DKM MASJID</div><div class="brand-caption">Sistem Manajemen Masjid</div></div>
          </div>
          <div class="brand-copy">
            <span class="eyebrow">SATU PUSAT, SEMUA TERHUBUNG</span>
            <h1>Kelola masjid dengan lebih <em>tenang.</em></h1>
            <p>Administrasi, kegiatan, dan pelayanan jamaah dalam satu ruang kerja yang aman dan mudah digunakan.</p>
          </div>
          <div class="features">
            <div><q-icon name="verified_user" /> Data tersimpan dengan aman</div>
            <div><q-icon name="auto_awesome" /> Pengelolaan lebih sederhana</div>
          </div>
          <div class="brand-footer">© {{ currentYear }} DKM Masjid</div>
        </aside>

        <main class="form-panel">
          <div class="mobile-brand brand-mark">
            <div class="brand-icon"><q-icon name="mosque" size="25px" /></div>
            <div><div class="brand-name">DKM MASJID</div><div class="brand-caption">Sistem Manajemen Masjid</div></div>
          </div>

          <div class="form-wrap">
            <div v-if="session" class="success-state">
              <div class="success-icon"><q-icon name="check" size="32px" /></div>
              <span class="eyebrow eyebrow-green">AKUN AKTIF</span>
              <h2>Assalamu'alaikum, {{ displayName }}</h2>
              <p>Anda telah berhasil masuk ke Sistem Manajemen Masjid.</p>
              <div class="account-card">
                <q-icon name="account_circle" size="40px" />
                <div><span>Akun yang digunakan</span><strong>{{ session.user.email }}</strong></div>
              </div>
              <q-btn unelevated no-caps class="primary-button" label="Keluar dari akun" icon-right="logout" :loading="isLoading" @click="handleLogout" />
            </div>

            <template v-else>
              <header class="auth-header">
                <span class="eyebrow eyebrow-green">{{ isRegister ? 'MULAI SEKARANG' : 'SELAMAT DATANG' }}</span>
                <h2>{{ isRegister ? 'Buat akun baru' : 'Masuk ke akun Anda' }}</h2>
                <p>{{ isRegister ? 'Lengkapi data berikut untuk mulai mengelola masjid.' : 'Silakan masukkan detail akun untuk melanjutkan.' }}</p>
              </header>

              <div v-if="configError" class="notice"><q-icon name="info" size="20px" /><span>Supabase belum dikonfigurasi. Isi file <strong>.env</strong> untuk mengaktifkan autentikasi.</span></div>

              <q-form v-if="!isRegister" class="auth-form" @submit.prevent="handleLogin">
                <label>Alamat email</label>
                <q-input v-model.trim="loginForm.email" type="email" placeholder="nama@email.com" outlined autocomplete="email" lazy-rules :rules="emailRules">
                  <template #prepend><q-icon name="mail_outline" size="20px" /></template>
                </q-input>
                <label>Password</label>
                <q-input v-model="loginForm.password" :type="showLoginPassword ? 'text' : 'password'" placeholder="Masukkan password" outlined autocomplete="current-password" lazy-rules :rules="passwordRules">
                  <template #prepend><q-icon name="lock_outline" size="20px" /></template>
                  <template #append><q-icon :name="showLoginPassword ? 'visibility_off' : 'visibility'" class="password-toggle" size="20px" @click="showLoginPassword = !showLoginPassword" /></template>
                </q-input>
                <div class="login-options">
                  <q-checkbox v-model="rememberEmail" dense label="Ingat email saya" />
                  <button type="button" class="text-button" @click="handleForgotPassword">Lupa password?</button>
                </div>
                <q-btn type="submit" unelevated no-caps class="primary-button" label="Masuk ke dashboard" icon-right="arrow_forward" :loading="isLoading" :disable="configError" />
              </q-form>

              <q-form v-else class="auth-form" @submit.prevent="handleRegister">
                <div class="name-row">
                  <div><label>Nama depan</label><q-input v-model.trim="registerForm.firstName" placeholder="Ahmad" outlined lazy-rules :rules="requiredRules" /></div>
                  <div><label>Nama belakang</label><q-input v-model.trim="registerForm.lastName" placeholder="Fauzi" outlined lazy-rules :rules="requiredRules" /></div>
                </div>
                <label>Alamat email</label>
                <q-input v-model.trim="registerForm.email" type="email" placeholder="nama@email.com" outlined autocomplete="email" lazy-rules :rules="emailRules"><template #prepend><q-icon name="mail_outline" size="20px" /></template></q-input>
                <label>ID masjid</label>
                <q-input v-model.trim="registerForm.masjidId" placeholder="UUID dari administrator masjid" outlined lazy-rules :rules="requiredRules">
                  <template #prepend><q-icon name="mosque" size="20px" /></template>
                  <template #hint>Minta ID masjid kepada administrator Anda.</template>
                </q-input>
                <label>Password</label>
                <q-input v-model="registerForm.password" :type="showRegisterPassword ? 'text' : 'password'" placeholder="Minimal 8 karakter" outlined autocomplete="new-password" lazy-rules :rules="registerPasswordRules">
                  <template #prepend><q-icon name="lock_outline" size="20px" /></template><template #append><q-icon :name="showRegisterPassword ? 'visibility_off' : 'visibility'" class="password-toggle" size="20px" @click="showRegisterPassword = !showRegisterPassword" /></template>
                </q-input>
                <label>Konfirmasi password</label>
                <q-input v-model="registerForm.confirmPassword" :type="showConfirmPassword ? 'text' : 'password'" placeholder="Ulangi password" outlined autocomplete="new-password" lazy-rules :rules="confirmPasswordRules">
                  <template #prepend><q-icon name="lock_outline" size="20px" /></template><template #append><q-icon :name="showConfirmPassword ? 'visibility_off' : 'visibility'" class="password-toggle" size="20px" @click="showConfirmPassword = !showConfirmPassword" /></template>
                </q-input>
                <q-checkbox v-model="acceptTerms" dense class="terms"><span>Saya menyetujui <button type="button" class="inline-link">Syarat & Ketentuan</button> dan <button type="button" class="inline-link">Kebijakan Privasi</button>.</span></q-checkbox>
                <q-btn type="submit" unelevated no-caps class="primary-button" label="Buat akun saya" icon-right="arrow_forward" :loading="isLoading" :disable="configError" />
              </q-form>

              <div class="mode-switch"><span>{{ isRegister ? 'Sudah punya akun?' : 'Belum memiliki akun?' }}</span><button type="button" class="text-button bold" @click="toggleAuthMode">{{ isRegister ? 'Masuk sekarang' : 'Daftar sekarang' }}</button></div>
            </template>
          </div>
          <div class="form-footer">Keamanan data Anda adalah prioritas kami <q-icon name="lock" size="12px" /></div>
        </main>
      </section>
    </q-page></q-page-container>
  </q-layout>
</template>

<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref } from 'vue'
import { useQuasar } from 'quasar'
import DashboardApp from './components/DashboardApp.vue'
import VerificationStatus from './components/VerificationStatus.vue'
import { isSupabaseConfigured, supabase } from './lib/supabase'

const $q = useQuasar()
const isRegister = ref(false), isLoading = ref(false), session = ref(null)
const profile = ref(null), profileLoading = ref(false)
const showLoginPassword = ref(false), showRegisterPassword = ref(false), showConfirmPassword = ref(false)
const rememberEmail = ref(false), acceptTerms = ref(false)
const configError = !isSupabaseConfigured
const loginForm = reactive({ email: '', password: '' })
const registerForm = reactive({ firstName: '', lastName: '', email: '', masjidId: '', password: '', confirmPassword: '' })
const currentYear = new Date().getFullYear()
let authSubscription

const displayName = computed(() => session.value?.user?.user_metadata?.full_name || session.value?.user?.email?.split('@')[0] || 'Pengguna')
const requiredRules = [(v) => Boolean(v?.trim()) || 'Field wajib diisi']
const emailRules = [(v) => Boolean(v) || 'Email wajib diisi', (v) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v) || 'Format email tidak valid']
const passwordRules = [(v) => Boolean(v) || 'Password wajib diisi']
const registerPasswordRules = [...passwordRules, (v) => v.length >= 8 || 'Password minimal 8 karakter']
const confirmPasswordRules = [(v) => Boolean(v) || 'Konfirmasi password wajib diisi', (v) => v === registerForm.password || 'Password tidak sama']

const notify = (type, message) => $q.notify({ type, message, position: 'top', timeout: 3500 })
function readableError(error) {
  return ({
    'Invalid login credentials': 'Email atau password tidak sesuai.',
    'Email not confirmed': 'Email belum dikonfirmasi. Silakan periksa kotak masuk Anda.',
    'User already registered': 'Email ini sudah terdaftar. Silakan masuk.',
  })[error?.message] || error?.message || 'Terjadi kesalahan. Silakan coba lagi.'
}
function toggleAuthMode() { isRegister.value = !isRegister.value; isLoading.value = false }

async function handleLogin() {
  isLoading.value = true
  try {
    const { error } = await supabase.auth.signInWithPassword({ email: loginForm.email, password: loginForm.password })
    if (error) throw error
    if (rememberEmail.value) localStorage.setItem('dkm-remembered-email', loginForm.email)
    else localStorage.removeItem('dkm-remembered-email')
    notify('positive', 'Berhasil masuk. Selamat datang kembali!')
  } catch (error) { notify('negative', readableError(error)) }
  finally { isLoading.value = false }
}

async function handleRegister() {
  if (!acceptTerms.value) return notify('warning', 'Silakan setujui Syarat & Ketentuan terlebih dahulu.')
  isLoading.value = true
  try {
    const fullName = `${registerForm.firstName} ${registerForm.lastName}`.trim()
    const { data, error } = await supabase.auth.signUp({
      email: registerForm.email, password: registerForm.password,
      options: { emailRedirectTo: window.location.origin, data: { first_name: registerForm.firstName, last_name: registerForm.lastName, full_name: fullName, masjid_id: registerForm.masjidId } },
    })
    if (error) throw error
    if (data.session) notify('positive', 'Akun berhasil dibuat dan Anda sudah masuk.')
    else {
      notify('positive', 'Akun berhasil dibuat. Periksa email untuk konfirmasi akun.')
      loginForm.email = registerForm.email
      Object.assign(registerForm, { firstName: '', lastName: '', email: '', masjidId: '', password: '', confirmPassword: '' })
      acceptTerms.value = false; isRegister.value = false
    }
  } catch (error) { notify('negative', readableError(error)) }
  finally { isLoading.value = false }
}

async function handleForgotPassword() {
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(loginForm.email)) return notify('warning', 'Masukkan alamat email yang valid terlebih dahulu.')
  isLoading.value = true
  try {
    const { error } = await supabase.auth.resetPasswordForEmail(loginForm.email, { redirectTo: window.location.origin })
    if (error) throw error
    notify('positive', 'Tautan pemulihan password telah dikirim ke email Anda.')
  } catch (error) { notify('negative', readableError(error)) }
  finally { isLoading.value = false }
}

async function handleLogout() {
  isLoading.value = true
  try { const { error } = await supabase.auth.signOut(); if (error) throw error; loginForm.password = ''; notify('positive', 'Anda berhasil keluar dari akun.') }
  catch (error) { notify('negative', readableError(error)) }
  finally { isLoading.value = false }
}

async function loadProfile() {
  if (!session.value || !supabase) { profile.value = null; return }
  profileLoading.value = true
  const { data, error } = await supabase.from('app_users').select('*').eq('auth_user_id', session.value.user.id).maybeSingle()
  profile.value = error ? null : data
  if (error) notify('negative', `Profil gagal dimuat: ${error.message}`)
  profileLoading.value = false
}

onMounted(async () => {
  const remembered = localStorage.getItem('dkm-remembered-email')
  if (remembered) { loginForm.email = remembered; rememberEmail.value = true }
  if (!supabase) return
  const { data } = await supabase.auth.getSession(); session.value = data.session; await loadProfile()
  authSubscription = supabase.auth.onAuthStateChange((_event, value) => { session.value = value; setTimeout(loadProfile, 0) }).data.subscription
})
onBeforeUnmount(() => authSubscription?.unsubscribe())
</script>

<style scoped>
.auth-layout{min-height:100vh;background:#f3f6f2}.auth-page{min-height:100vh;display:grid;place-items:center;padding:32px}.auth-shell{width:min(1080px,100%);min-height:680px;display:grid;grid-template-columns:46% 54%;overflow:hidden;border:1px solid rgba(24,68,54,.08);border-radius:30px;background:#fff;box-shadow:0 35px 90px rgba(25,57,47,.14)}
.brand-panel{position:relative;isolation:isolate;overflow:hidden;display:flex;flex-direction:column;padding:48px;color:#fff;background:linear-gradient(145deg,#0b4437,#0c5b49 55%,#126d56)}.brand-panel:after{content:'';position:absolute;z-index:-1;inset:0;opacity:.13;background-image:linear-gradient(30deg,transparent 12%,rgba(255,255,255,.22) 12.5%,transparent 13%),linear-gradient(150deg,transparent 12%,rgba(255,255,255,.16) 12.5%,transparent 13%);background-size:42px 72px}.glow{position:absolute;z-index:-1;border-radius:50%;background:#d7b96e;opacity:.16}.glow-one{width:310px;height:310px;top:-180px;right:-120px}.glow-two{width:250px;height:250px;bottom:-150px;left:-100px}
.brand-mark{display:flex;align-items:center;gap:13px}.brand-icon{width:49px;height:49px;display:grid;place-items:center;flex:none;border-radius:15px;color:#0c5b49;background:linear-gradient(145deg,#f9e6ad,#d6b566);box-shadow:0 10px 30px rgba(0,0,0,.15)}.brand-name{font-size:15px;font-weight:800;letter-spacing:1.7px}.brand-caption{margin-top:2px;font-size:10px;opacity:.68}.brand-copy{margin:auto 0;max-width:370px}.eyebrow{display:block;margin-bottom:17px;font-size:10px;font-weight:800;letter-spacing:2.1px;color:#e2c77d}.eyebrow-green{color:#13705a}.brand-copy h1{margin:0;font-family:Georgia,serif;font-size:clamp(37px,4vw,53px);font-weight:500;line-height:1.08;letter-spacing:-1.7px}.brand-copy h1 em{color:#e3c477}.brand-copy p{margin:24px 0 0;color:rgba(255,255,255,.72);font-size:13px;line-height:1.8}.features{display:flex;flex-direction:column;gap:11px;font-size:11px;color:rgba(255,255,255,.75)}.features div{display:flex;align-items:center;gap:9px}.features .q-icon{color:#e2c77d}.brand-footer{margin-top:30px;font-size:9px;color:rgba(255,255,255,.37)}
.form-panel{display:flex;flex-direction:column;padding:48px clamp(40px,6vw,76px) 28px;background:#fff}.mobile-brand{display:none}.form-wrap{width:100%;max-width:410px;margin:auto}.auth-header{margin-bottom:28px}.auth-header .eyebrow{margin-bottom:11px}.auth-header h2,.success-state h2{margin:0;color:#173a30;font-family:Georgia,serif;font-size:33px;font-weight:600;letter-spacing:-.7px}.auth-header p,.success-state>p{margin:9px 0 0;color:#7c8b85;font-size:12px;line-height:1.65}.auth-form{display:flex;flex-direction:column}.auth-form label{margin:0 0 7px 2px;color:#314e45;font-size:11px;font-weight:700}.auth-form :deep(.q-field){margin-bottom:9px;font-size:12px}.auth-form :deep(.q-field__control){min-height:49px;border-radius:11px;background:#fcfdfc}.auth-form :deep(.q-field--outlined .q-field__control:before){border-color:#dce5e1}.auth-form :deep(.q-field--focused .q-field__control:after){border-width:1px;color:#13705a}.auth-form :deep(.q-field__prepend),.auth-form :deep(.q-field__append){color:#87948f}.auth-form :deep(.q-field__bottom){padding:5px 10px 0;font-size:10px}.password-toggle{cursor:pointer}.password-toggle:hover{color:#13705a}
.login-options{display:flex;align-items:center;justify-content:space-between;margin:-2px 0 21px}.login-options :deep(.q-checkbox__label),.terms{color:#6f7e79;font-size:10px}.text-button,.inline-link{border:0;padding:0;color:#13705a;background:transparent;cursor:pointer;font:inherit}.text-button{font-size:10px;font-weight:650}.text-button:hover,.inline-link:hover{text-decoration:underline}.bold{font-size:11px;font-weight:800}.primary-button{width:100%;height:49px;border-radius:11px;color:#fff;background:linear-gradient(120deg,#0e5d49,#14725a);font-size:12px;font-weight:700;box-shadow:0 12px 25px rgba(17,103,81,.22)}.primary-button:hover{filter:brightness(.96);transform:translateY(-1px)}.mode-switch{display:flex;justify-content:center;gap:5px;margin-top:25px;color:#899690;font-size:11px}.name-row{display:grid;grid-template-columns:1fr 1fr;gap:11px}.name-row>div{display:flex;flex-direction:column}.terms{margin:1px 0 15px}.inline-link{font-weight:700}.notice{display:flex;gap:9px;margin:-9px 0 20px;padding:11px 13px;border:1px solid #eadbaf;border-radius:10px;color:#735f24;background:#fffaf0;font-size:10px;line-height:1.5}.form-footer{margin-top:auto;padding-top:24px;text-align:center;color:#a3ada9;font-size:9px}
.success-state{text-align:center}.success-icon{width:70px;height:70px;display:grid;place-items:center;margin:0 auto 25px;border-radius:22px;color:#fff;background:linear-gradient(145deg,#116b54,#159170);box-shadow:0 16px 35px rgba(17,107,84,.2)}.success-state .eyebrow{margin-bottom:10px}.account-card{display:flex;align-items:center;gap:12px;margin:27px 0 20px;padding:15px;border:1px solid #e1e9e6;border-radius:13px;text-align:left;color:#16654f;background:#f8fbf9}.account-card div{min-width:0;display:flex;flex-direction:column}.account-card span{color:#8a9792;font-size:9px}.account-card strong{overflow:hidden;margin-top:2px;color:#314e45;font-size:11px;text-overflow:ellipsis}
@media(max-width:800px){.auth-page{padding:20px}.auth-shell{min-height:auto;grid-template-columns:1fr;max-width:570px}.brand-panel{display:none}.form-panel{min-height:calc(100vh - 40px);padding:34px clamp(24px,8vw,60px) 24px}.mobile-brand{display:flex;margin-bottom:46px}.mobile-brand .brand-name{color:#173a30}.mobile-brand .brand-caption{color:#71827b}.form-wrap{margin:auto}}
@media(max-width:480px){.auth-page{padding:0}.auth-shell{min-height:100vh;border:0;border-radius:0}.form-panel{min-height:100vh;padding:27px 20px 20px}.mobile-brand{margin-bottom:38px}.mobile-brand .brand-icon{width:43px;height:43px;border-radius:13px}.auth-header h2,.success-state h2{font-size:29px}.name-row{grid-template-columns:1fr;gap:0}}
</style>
