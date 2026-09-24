import { createApp } from 'vue'
import { Notify, Quasar } from 'quasar'
import App from './App.vue'

import '@quasar/extras/material-icons/material-icons.css'
import 'quasar/src/css/index.sass'
import './assets/main.css'

const app = createApp(App)

app.use(Quasar, {
  plugins: { Notify },
  config: {
    brand: { primary: '#116b54', positive: '#13705a', negative: '#b53f46', warning: '#b7882f' },
  },
})

app.mount('#app')
