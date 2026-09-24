# DKM Masjid

## Supabase

1. Isi `VITE_SUPABASE_URL` dan `VITE_SUPABASE_PUBLISHABLE_KEY` pada `.env`.
2. Jalankan [`supabase/schema.sql`](./supabase/schema.sql) di SQL Editor Supabase.
3. Buat akun pertama dari halaman daftar dengan UUID masjid yang sesuai.
4. Bootstrap super administrator pertama sekali saja dari SQL Editor:

```sql
update public.app_users
set role = 'super_administrator', verification_status = 'verified'
where email = 'admin@contoh.id';
```

Jika akun Auth dibuat sebelum skema dipasang dan belum mempunyai profil, jalankan skema terbaru terlebih dahulu. Bagian backfill akan membuat `app_users` untuk seluruh akun Auth lama secara otomatis.

Pendaftaran berikutnya otomatis membuat profil `app_users` berstatus `pending`. Super administrator dapat memverifikasi seluruh masjid; administrator biasa hanya dapat memverifikasi pengguna dari masjidnya sendiri. Role super administrator sengaja tidak tersedia di form aplikasi dan hanya dapat diberikan melalui SQL Editor. RLS tetap menjadi pengaman utama meskipun UI dimanipulasi.

This template should help get you started developing with Vue 3 in Vite.

## Recommended IDE Setup

[VS Code](https://code.visualstudio.com/) + [Vue (Official)](https://marketplace.visualstudio.com/items?itemName=Vue.volar) (and disable Vetur).

## Recommended Browser Setup

- Chromium-based browsers (Chrome, Edge, Brave, etc.):
  - [Vue.js devtools](https://chromewebstore.google.com/detail/vuejs-devtools/nhdogjmejiglipccpnnnanhbledajbpd)
  - [Turn on Custom Object Formatter in Chrome DevTools](http://bit.ly/object-formatters)
- Firefox:
  - [Vue.js devtools](https://addons.mozilla.org/en-US/firefox/addon/vue-js-devtools/)
  - [Turn on Custom Object Formatter in Firefox DevTools](https://fxdx.dev/firefox-devtools-custom-object-formatters/)

## Customize configuration

See [Vite Configuration Reference](https://vite.dev/config/).

## Project Setup

```sh
npm install
```

### Compile and Hot-Reload for Development

```sh
npm run dev
```

### Compile and Minify for Production

```sh
npm run build
```

### Run Unit Tests with [Vitest](https://vitest.dev/)

```sh
npm run test:unit
```

### Lint with [ESLint](https://eslint.org/)

```sh
npm run lint
```
