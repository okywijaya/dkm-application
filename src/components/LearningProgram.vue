<template>
  <div class="learning-page">
    <header class="learning-head">
      <div>
        <span class="learning-kicker">PUSAT PEMBELAJARAN</span>
        <h1>{{ isAdminView ? 'Program pembelajaran' : 'Kelas saya' }}</h1>
        <p>{{ isAdminView ? 'Susun kurikulum, materi, dan berkas dalam satu tempat.' : 'Lanjutkan materi dan pantau progres belajarmu.' }}</p>
      </div>
      <div class="view-switch" aria-label="Pilih tampilan">
        <button :class="{ active: isAdminView }" @click="view = 'admin'"><q-icon name="admin_panel_settings" /> Admin</button>
        <button :class="{ active: !isAdminView }" @click="view = 'student'"><q-icon name="school" /> Murid</button>
      </div>
    </header>

    <template v-if="isAdminView">
      <section class="summary-row">
        <article><q-icon name="auto_stories" /><div><strong>{{ programs.length }}</strong><span>Program</span></div></article>
        <article><q-icon name="format_list_numbered" /><div><strong>{{ chapterCount }}</strong><span>Bab</span></div></article>
        <article><q-icon name="play_lesson" /><div><strong>{{ lessonCount }}</strong><span>Materi</span></div></article>
        <article><q-icon name="cloud_done" /><div><strong>{{ fileCount }}</strong><span>Berkas</span></div></article>
      </section>

      <section class="admin-grid">
        <aside class="program-panel surface">
          <div class="panel-title"><div><span>DAFTAR PROGRAM</span><h2>Kurikulum aktif</h2></div><q-btn round unelevated color="teal-8" icon="add" size="sm" aria-label="Tambah program" @click="openProgramDialog" /></div>
          <div class="search-box"><q-icon name="search" /><input v-model="query" placeholder="Cari program" /></div>
          <button v-for="program in filteredPrograms" :key="program.id" class="program-item" :class="{ selected: program.id === selectedId }" @click="selectedId = program.id">
            <span class="program-icon"><q-icon :name="program.icon || 'menu_book'" /></span>
            <span class="program-copy"><strong>{{ program.title }}</strong><small>{{ program.level }} · {{ program.chapters.length }} bab</small></span>
            <q-icon name="chevron_right" />
          </button>
          <div v-if="!filteredPrograms.length" class="empty-mini"><q-icon name="search_off" /><span>Program tidak ditemukan.</span></div>
        </aside>

        <main v-if="selectedProgram" class="curriculum-panel surface">
          <div class="program-hero">
            <div class="hero-icon"><q-icon :name="selectedProgram.icon || 'menu_book'" /></div>
            <div><q-badge :label="selectedProgram.status === 'published' ? 'Dipublikasikan' : 'Draf'" :color="selectedProgram.status === 'published' ? 'green-7' : 'grey-6'" /><h2>{{ selectedProgram.title }}</h2><p>{{ selectedProgram.description }}</p></div>
            <q-btn flat round icon="more_horiz"><q-menu><q-list dense><q-item clickable v-close-popup @click="editProgram"><q-item-section>Edit program</q-item-section></q-item><q-item clickable v-close-popup @click="togglePublish"><q-item-section>{{ selectedProgram.status === 'published' ? 'Jadikan draf' : 'Publikasikan' }}</q-item-section></q-item></q-list></q-menu></q-btn>
          </div>
          <div class="curriculum-bar"><div><strong>Struktur program</strong><span>Urutkan pembelajaran dari dasar hingga tuntas</span></div><q-btn outline no-caps color="teal-8" icon="add" label="Tambah bab" @click="addChapter" /></div>

          <div class="chapter-list">
            <article v-for="(chapter, chapterIndex) in selectedProgram.chapters" :key="chapter.id" class="chapter-card">
              <div class="chapter-head"><span class="chapter-number">{{ String(chapterIndex + 1).padStart(2, '0') }}</span><div><strong>{{ chapter.title }}</strong><small>{{ chapter.lessons.length }} materi · {{ chapter.duration }}</small></div><q-btn flat round dense icon="add" aria-label="Tambah materi" @click="addLesson(chapter)" /></div>
              <div class="lesson-list">
                <div v-for="lesson in chapter.lessons" :key="lesson.id" class="lesson-row">
                  <span class="lesson-type"><q-icon :name="typeIcon(lesson.type)" /></span>
                  <div><strong>{{ lesson.title }}</strong><small>{{ lesson.type }} · {{ lesson.duration }}</small></div>
                  <q-chip v-if="lesson.file" dense icon="attach_file">{{ lesson.file }}</q-chip>
                  <q-btn flat round dense icon="more_vert" />
                </div>
                <button v-if="!chapter.lessons.length" class="empty-lesson" @click="addLesson(chapter)"><q-icon name="add_circle_outline" /> Tambahkan materi pertama</button>
              </div>
            </article>
          </div>
        </main>
      </section>
    </template>

    <template v-else>
      <section class="student-hero">
        <div><span>ASSALAMU'ALAIKUM, {{ studentName }}</span><h2>Teruskan langkah baikmu hari ini.</h2><p>Materi berikutnya sudah siap. Sedikit demi sedikit, insyaAllah menjadi ilmu yang melekat.</p></div>
        <div class="progress-ring"><strong>68%</strong><span>progres</span></div>
      </section>
      <section class="student-grid">
        <main>
          <div class="student-section-title"><div><span>SEDANG DIPELAJARI</span><h2>Lanjutkan belajar</h2></div></div>
          <article v-if="selectedProgram" class="continue-card">
            <div class="continue-cover"><q-icon :name="selectedProgram.icon || 'menu_book'" size="45px" /><span>{{ selectedProgram.level }}</span></div>
            <div class="continue-copy"><q-badge color="amber-8" label="Materi berikutnya" /><h3>{{ selectedProgram.title }}</h3><p>{{ nextLesson.title }}</p><div class="progress-track"><i style="width:68%"></i></div><small>8 dari 12 materi selesai</small></div>
            <q-btn unelevated no-caps color="teal-8" icon-right="arrow_forward" label="Lanjut belajar" @click="openLesson" />
          </article>
          <div class="student-section-title compact"><div><span>PROGRAM SAYA</span><h2>Semua pembelajaran</h2></div></div>
          <div class="course-grid">
            <article v-for="(program, index) in publishedPrograms" :key="program.id" class="course-card" @click="selectedId = program.id">
              <div class="course-symbol" :class="`tone-${index % 3}`"><q-icon :name="program.icon || 'menu_book'" /></div>
              <q-chip dense>{{ program.level }}</q-chip><h3>{{ program.title }}</h3><p>{{ program.description }}</p>
              <div class="course-meta"><span><q-icon name="play_lesson" /> {{ program.chapters.reduce((n, c) => n + c.lessons.length, 0) }} materi</span><span>{{ 35 + index * 18 }}%</span></div>
              <q-linear-progress rounded size="6px" :value="(35 + index * 18) / 100" color="teal-7" track-color="grey-3" />
            </article>
          </div>
        </main>
        <aside class="student-side">
          <section class="achievement surface"><span class="medal"><q-icon name="emoji_events" /></span><small>PENCAPAIAN MINGGU INI</small><strong>4 materi selesai</strong><p>Pertahankan konsistensimu!</p></section>
          <section class="schedule surface"><div class="student-section-title"><div><span>JADWAL</span><h2>Pertemuan berikutnya</h2></div></div><div class="date-block"><strong>27</strong><span>SEP<br/>2026</span></div><div><strong>Tahsin bersama Ustadz Ahmad</strong><span>Ahad · 08.00 WIB</span></div></section>
        </aside>
      </section>
    </template>

    <q-dialog v-model="programDialog"><q-card class="learning-dialog"><q-card-section><div class="text-h6">{{ editingProgram ? 'Edit program' : 'Program baru' }}</div><div class="text-caption text-grey-7">Isi informasi utama program pembelajaran.</div></q-card-section><q-card-section class="q-gutter-md"><q-input v-model="programForm.title" outlined label="Nama program" autofocus /><q-input v-model="programForm.description" outlined type="textarea" label="Deskripsi" /><div class="dialog-row"><q-select v-model="programForm.level" outlined label="Tingkat" :options="['Pemula','Menengah','Lanjutan']" /><q-select v-model="programForm.status" outlined label="Status" emit-value map-options :options="[{label:'Draf',value:'draft'},{label:'Dipublikasikan',value:'published'}]" /></div></q-card-section><q-card-actions align="right"><q-btn flat no-caps label="Batal" v-close-popup /><q-btn unelevated no-caps color="teal-8" label="Simpan program" @click="saveProgram" /></q-card-actions></q-card></q-dialog>

    <q-dialog v-model="lessonDialog"><q-card class="learning-dialog"><q-card-section><div class="text-h6">Materi baru</div><div class="text-caption text-grey-7">Tambahkan video, dokumen, audio, atau latihan.</div></q-card-section><q-card-section class="q-gutter-md"><q-input v-model="lessonForm.title" outlined label="Judul materi" autofocus /><div class="dialog-row"><q-select v-model="lessonForm.type" outlined label="Jenis" :options="['Video','Dokumen','Audio','Latihan']" /><q-input v-model="lessonForm.duration" outlined label="Durasi" placeholder="12 menit" /></div><q-file v-model="lessonForm.upload" outlined label="Unggah ke Storage" accept=".pdf,.mp3,.mp4,.doc,.docx"><template #prepend><q-icon name="cloud_upload" /></template></q-file></q-card-section><q-card-actions align="right"><q-btn flat no-caps label="Batal" v-close-popup /><q-btn unelevated no-caps color="teal-8" label="Tambahkan materi" @click="saveLesson" /></q-card-actions></q-card></q-dialog>
  </div>
</template>

<script setup>
import { computed, reactive, ref } from 'vue'
import { useQuasar } from 'quasar'
import { supabase } from '../lib/supabase'

const props = defineProps({ profile: { type: Object, required: true } })
const $q = useQuasar()
const view = ref('admin'), query = ref(''), selectedId = ref('tajwid'), programDialog = ref(false), lessonDialog = ref(false)
const editingProgram = ref(null), activeChapter = ref(null)
const programForm = reactive({ title: '', description: '', level: 'Pemula', status: 'draft' })
const lessonForm = reactive({ title: '', type: 'Video', duration: '', upload: null })
const programs = ref([
  { id: 'tajwid', title: 'Dasar-dasar Ilmu Tajwid', description: 'Belajar membaca Al-Qur’an dengan makhraj dan kaidah tajwid yang tepat.', level: 'Pemula', status: 'published', icon: 'auto_stories', chapters: [
    { id: 'c1', title: 'Pengenalan Tajwid', duration: '28 menit', lessons: [{ id: 'l1', title: 'Mengapa belajar tajwid?', type: 'Video', duration: '08 menit' }, { id: 'l2', title: 'Hukum membaca Al-Qur’an', type: 'Dokumen', duration: '10 menit', file: 'panduan-tajwid.pdf' }] },
    { id: 'c2', title: 'Makharijul Huruf', duration: '45 menit', lessons: [{ id: 'l3', title: 'Tempat keluar huruf hijaiyah', type: 'Video', duration: '14 menit' }, { id: 'l4', title: 'Latihan pelafalan', type: 'Latihan', duration: '20 menit' }] },
    { id: 'c3', title: 'Nun Mati dan Tanwin', duration: '52 menit', lessons: [{ id: 'l5', title: 'Izhar, idgham, iqlab, dan ikhfa', type: 'Video', duration: '18 menit' }] },
  ]},
  { id: 'shalat', title: 'Fiqih Shalat', description: 'Panduan lengkap memahami syarat, rukun, dan tata cara shalat.', level: 'Pemula', status: 'published', icon: 'mosque', chapters: [{ id: 'c4', title: 'Bersuci', duration: '40 menit', lessons: [{ id: 'l6', title: 'Wudhu yang sempurna', type: 'Video', duration: '12 menit' }] }] },
  { id: 'adab', title: 'Adab Muslim Sehari-hari', description: 'Membiasakan akhlak mulia dalam keseharian.', level: 'Menengah', status: 'draft', icon: 'volunteer_activism', chapters: [{ id: 'c5', title: 'Adab kepada orang tua', duration: '32 menit', lessons: [] }] },
])

const isAdminView = computed(() => view.value === 'admin')
const selectedProgram = computed(() => programs.value.find((item) => item.id === selectedId.value) || programs.value[0])
const filteredPrograms = computed(() => programs.value.filter((item) => item.title.toLowerCase().includes(query.value.toLowerCase())))
const publishedPrograms = computed(() => programs.value.filter((item) => item.status === 'published'))
const chapterCount = computed(() => programs.value.reduce((n, item) => n + item.chapters.length, 0))
const lessonCount = computed(() => programs.value.reduce((n, item) => n + item.chapters.reduce((m, chapter) => m + chapter.lessons.length, 0), 0))
const fileCount = computed(() => programs.value.reduce((n, item) => n + item.chapters.reduce((m, chapter) => m + chapter.lessons.filter((lesson) => lesson.file).length, 0), 0))
const studentName = computed(() => (props.profile.full_name || 'Murid').split(' ')[0])
const nextLesson = computed(() => selectedProgram.value?.chapters.flatMap((chapter) => chapter.lessons)[0] || { title: 'Materi akan segera tersedia' })
const typeIcon = (type) => ({ Video: 'play_circle', Dokumen: 'description', Audio: 'headphones', Latihan: 'quiz' })[type] || 'article'
function openProgramDialog() { editingProgram.value = null; Object.assign(programForm, { title: '', description: '', level: 'Pemula', status: 'draft' }); programDialog.value = true }
function editProgram() { editingProgram.value = selectedProgram.value; Object.assign(programForm, selectedProgram.value); programDialog.value = true }
function saveProgram() { if (!programForm.title.trim()) return $q.notify({ type: 'warning', message: 'Nama program wajib diisi.' }); if (editingProgram.value) Object.assign(editingProgram.value, programForm); else { const item = { id: `program-${Date.now()}`, ...programForm, icon: 'menu_book', chapters: [] }; programs.value.unshift(item); selectedId.value = item.id }; programDialog.value = false; $q.notify({ type: 'positive', message: 'Program berhasil disimpan.' }) }
function togglePublish() { selectedProgram.value.status = selectedProgram.value.status === 'published' ? 'draft' : 'published'; $q.notify({ type: 'positive', message: 'Status program diperbarui.' }) }
function addChapter() { selectedProgram.value.chapters.push({ id: `chapter-${Date.now()}`, title: `Bab ${selectedProgram.value.chapters.length + 1}`, duration: '0 menit', lessons: [] }); $q.notify({ type: 'positive', message: 'Bab baru ditambahkan.' }) }
function addLesson(chapter) { activeChapter.value = chapter; Object.assign(lessonForm, { title: '', type: 'Video', duration: '', upload: null }); lessonDialog.value = true }
async function saveLesson() {
  if (!lessonForm.title.trim()) return $q.notify({ type: 'warning', message: 'Judul materi wajib diisi.' })
  let fileName = lessonForm.upload?.name
  if (lessonForm.upload && supabase && props.profile.masjid_id) {
    const safeName = lessonForm.upload.name.replace(/[^a-zA-Z0-9._-]/g, '-')
    const storagePath = `${props.profile.masjid_id}/${selectedProgram.value.id}/${Date.now()}-${safeName}`
    const { error } = await supabase.storage.from('learning-materials').upload(storagePath, lessonForm.upload)
    if (error) return $q.notify({ type: 'negative', message: `Berkas gagal diunggah: ${error.message}` })
    fileName = safeName
  }
  activeChapter.value.lessons.push({ id: `lesson-${Date.now()}`, title: lessonForm.title, type: lessonForm.type, duration: lessonForm.duration || '10 menit', file: fileName })
  lessonDialog.value = false
  $q.notify({ type: 'positive', message: lessonForm.upload ? 'Materi dan berkas berhasil ditambahkan.' : 'Materi berhasil ditambahkan.' })
}
function openLesson() { $q.notify({ type: 'positive', message: `Membuka: ${nextLesson.value.title}` }) }
</script>

<style scoped>
.learning-page{max-width:1420px;margin:auto;color:#263f37}.learning-head{display:flex;align-items:flex-end;justify-content:space-between;margin-bottom:22px}.learning-kicker,.student-section-title span{color:#168066;font-size:9px;font-weight:800;letter-spacing:1.7px}.learning-head h1{margin:4px 0 3px;font:600 29px Georgia,serif}.learning-head p{margin:0;color:#84918c;font-size:12px}.view-switch{display:flex;padding:4px;border:1px solid #dfe8e4;border-radius:12px;background:#fff}.view-switch button{display:flex;align-items:center;gap:6px;border:0;padding:9px 14px;border-radius:9px;color:#71817b;background:transparent;font-size:11px;font-weight:700;cursor:pointer}.view-switch button.active{color:#fff;background:#126c56;box-shadow:0 6px 14px rgba(18,108,86,.2)}.summary-row{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:15px}.summary-row article{display:flex;align-items:center;gap:12px;padding:15px 18px;border:1px solid #e1e9e6;border-radius:13px;background:#fff}.summary-row .q-icon{width:37px;height:37px;display:grid;place-items:center;border-radius:10px;color:#146c56;background:#e9f5f0;font-size:20px}.summary-row article div{display:flex;flex-direction:column}.summary-row strong{font-size:18px}.summary-row span{color:#8a9692;font-size:9px}.admin-grid{display:grid;grid-template-columns:300px 1fr;gap:15px}.surface{border:1px solid #e0e9e5;border-radius:15px;background:#fff}.program-panel{padding:17px}.panel-title,.curriculum-bar{display:flex;align-items:center;justify-content:space-between}.panel-title span{color:#168066;font-size:8px;font-weight:800;letter-spacing:1.3px}.panel-title h2{margin:2px 0;font:600 18px Georgia,serif}.search-box{display:flex;align-items:center;gap:8px;margin:15px 0 10px;padding:9px 11px;border:1px solid #e1e8e5;border-radius:9px;color:#96a19d;background:#fafcfb}.search-box input{min-width:0;width:100%;border:0;outline:0;color:#344e45;background:transparent;font-size:11px}.program-item{width:100%;display:flex;align-items:center;gap:10px;margin:4px 0;border:1px solid transparent;padding:10px;border-radius:11px;text-align:left;background:transparent;cursor:pointer}.program-item:hover{background:#f5f9f7}.program-item.selected{border-color:#b8d9ce;background:#eef8f4}.program-icon{width:38px;height:38px;display:grid;place-items:center;flex:none;border-radius:10px;color:#146d57;background:#e8f4ef}.program-copy{min-width:0;display:flex;flex:1;flex-direction:column}.program-copy strong{overflow:hidden;font-size:10px;text-overflow:ellipsis;white-space:nowrap}.program-copy small{margin-top:3px;color:#94a09b;font-size:8px}.program-item>.q-icon{color:#9aa7a2}.empty-mini{display:flex;flex-direction:column;align-items:center;gap:7px;padding:28px;color:#9aa7a2;font-size:10px}.curriculum-panel{overflow:hidden}.program-hero{display:grid;grid-template-columns:auto 1fr auto;gap:15px;align-items:start;padding:22px;border-bottom:1px solid #e8eeeb}.hero-icon{width:55px;height:55px;display:grid;place-items:center;border-radius:15px;color:#fff;background:linear-gradient(145deg,#0f674f,#2b967b);font-size:27px}.program-hero h2{margin:7px 0 4px;font:600 21px Georgia,serif}.program-hero p{margin:0;color:#82908b;font-size:10px}.program-hero .q-badge{font-size:8px}.curriculum-bar{padding:16px 22px}.curriculum-bar div{display:flex;flex-direction:column}.curriculum-bar strong{font-size:12px}.curriculum-bar span{margin-top:2px;color:#97a29e;font-size:9px}.curriculum-bar .q-btn{font-size:10px}.chapter-list{padding:0 22px 22px}.chapter-card{margin-bottom:10px;border:1px solid #e1e9e6;border-radius:12px}.chapter-head{display:flex;align-items:center;gap:11px;padding:12px 14px;background:#f8faf9}.chapter-number{color:#af842e;font:600 17px Georgia,serif}.chapter-head>div{display:flex;flex:1;flex-direction:column}.chapter-head strong{font-size:10px}.chapter-head small{color:#95a09c;font-size:8px}.lesson-list{padding:3px 13px}.lesson-row{display:flex;align-items:center;gap:10px;padding:9px 2px;border-bottom:1px solid #edf1ef}.lesson-row:last-child{border:0}.lesson-type{width:31px;height:31px;display:grid;place-items:center;border-radius:8px;color:#367c68;background:#edf7f3}.lesson-row>div{display:flex;flex:1;flex-direction:column}.lesson-row strong{font-size:9px}.lesson-row small{margin-top:2px;color:#96a19d;font-size:8px}.lesson-row .q-chip{font-size:8px}.empty-lesson{width:100%;display:flex;justify-content:center;gap:6px;border:0;padding:12px;color:#168066;background:transparent;font-size:9px;cursor:pointer}.student-hero{position:relative;overflow:hidden;display:flex;align-items:center;justify-content:space-between;min-height:180px;margin-bottom:20px;padding:32px 38px;border-radius:18px;color:#fff;background:linear-gradient(120deg,#0b5543,#19745d)}.student-hero:after{content:'';position:absolute;right:10%;width:230px;height:230px;border:1px solid rgba(255,255,255,.1);border-radius:50%;box-shadow:0 0 0 45px rgba(255,255,255,.035)}.student-hero>div:first-child{z-index:1}.student-hero span{color:#e8ce83;font-size:9px;font-weight:800;letter-spacing:1.5px}.student-hero h2{margin:8px 0;font:500 27px Georgia,serif}.student-hero p{max-width:550px;margin:0;color:rgba(255,255,255,.68);font-size:11px}.progress-ring{z-index:1;width:96px;height:96px;display:flex;flex-direction:column;align-items:center;justify-content:center;border:8px solid rgba(255,255,255,.18);border-top-color:#e2c576;border-radius:50%}.progress-ring strong{font-size:18px}.progress-ring span{color:rgba(255,255,255,.55);font-size:8px;letter-spacing:0}.student-grid{display:grid;grid-template-columns:1fr 270px;gap:18px}.student-section-title h2{margin:3px 0 12px;font:600 18px Georgia,serif}.student-section-title.compact{margin-top:22px}.continue-card{display:grid;grid-template-columns:150px 1fr auto;gap:18px;align-items:center;padding:16px;border:1px solid #e0e8e5;border-radius:15px;background:#fff}.continue-cover{height:115px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:13px;border-radius:12px;color:#fff;background:linear-gradient(145deg,#b47f2b,#d6aa50)}.continue-cover span{font-size:9px}.continue-copy h3{margin:6px 0 3px;font-size:14px}.continue-copy p{margin:0 0 12px;color:#7f8d88;font-size:10px}.continue-copy .q-badge{font-size:8px}.progress-track{height:5px;overflow:hidden;border-radius:5px;background:#e7ecea}.progress-track i{display:block;height:100%;border-radius:5px;background:#16755d}.continue-copy small{color:#97a19d;font-size:8px}.continue-card>.q-btn{font-size:10px}.course-grid{display:grid;grid-template-columns:repeat(2,1fr);gap:12px}.course-card{padding:17px;border:1px solid #e0e8e5;border-radius:14px;background:#fff;cursor:pointer;transition:.2s}.course-card:hover{transform:translateY(-2px);box-shadow:0 12px 28px rgba(35,72,61,.08)}.course-symbol{width:43px;height:43px;display:grid;place-items:center;margin-bottom:12px;border-radius:12px;color:#fff;background:#17725b;font-size:22px}.course-symbol.tone-1{background:#b4842f}.course-symbol.tone-2{background:#5578a0}.course-card .q-chip{float:right;margin-top:-52px;font-size:8px}.course-card h3{margin:0 0 6px;font-size:12px}.course-card p{min-height:31px;margin:0 0 12px;color:#87938e;font-size:9px;line-height:1.6}.course-meta{display:flex;justify-content:space-between;margin-bottom:7px;color:#83908b;font-size:8px}.student-side{display:flex;flex-direction:column;gap:13px}.achievement{display:flex;flex-direction:column;align-items:center;padding:24px;text-align:center}.medal{width:55px;height:55px;display:grid;place-items:center;margin-bottom:13px;border-radius:50%;color:#9a6d1e;background:#fff1c9;font-size:26px}.achievement small{color:#a27d32;font-size:8px;font-weight:800;letter-spacing:1px}.achievement strong{margin-top:5px;font:600 17px Georgia,serif}.achievement p{margin:5px 0 0;color:#89958f;font-size:9px}.schedule{padding:18px}.date-block{display:inline-flex;align-items:center;gap:8px;margin:5px 0 12px;padding:10px;border-radius:10px;color:#fff;background:#176d58}.date-block strong{font-size:22px}.date-block span{font-size:7px;line-height:1.4}.schedule>div:last-child{display:flex;flex-direction:column}.schedule>div:last-child strong{font-size:10px}.schedule>div:last-child span{margin-top:4px;color:#929e99;font-size:8px}.learning-dialog{width:min(520px,94vw);border-radius:16px}.dialog-row{display:grid;grid-template-columns:1fr 1fr;gap:12px}
@media(max-width:1050px){.admin-grid{grid-template-columns:250px 1fr}.student-grid{grid-template-columns:1fr}.student-side{display:grid;grid-template-columns:1fr 1fr}.continue-card{grid-template-columns:130px 1fr}.continue-card>.q-btn{grid-column:2;justify-self:start}}
@media(max-width:760px){.learning-head{align-items:flex-start;gap:16px}.summary-row{grid-template-columns:1fr 1fr}.admin-grid{grid-template-columns:1fr}.program-panel{max-height:330px;overflow:auto}.student-hero{padding:26px}.progress-ring{display:none}.continue-card{grid-template-columns:1fr}.continue-cover{height:90px}.continue-card>.q-btn{grid-column:1}.course-grid{grid-template-columns:1fr}}
@media(max-width:520px){.learning-head{flex-direction:column}.view-switch{width:100%}.view-switch button{flex:1;justify-content:center}.summary-row{gap:8px}.summary-row article{padding:12px}.program-hero{grid-template-columns:auto 1fr}.program-hero>.q-btn{display:none}.curriculum-bar{align-items:flex-start;gap:12px}.student-side{grid-template-columns:1fr}.dialog-row{grid-template-columns:1fr}}
</style>
