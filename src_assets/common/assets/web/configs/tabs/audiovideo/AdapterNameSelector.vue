<script setup>
import { ref } from 'vue'
import PlatformLayout from '../../../PlatformLayout.vue'

const props = defineProps([
'platform',
'config'
])

const config = ref(props.config)

const gpuOptions = [
{ value: '', label: 'Auto Select (Recommended)' },
{ value: '/dev/dri/renderD128', label: '/dev/dri/renderD128 — GPU 1' },
{ value: '/dev/dri/renderD129', label: '/dev/dri/renderD129 — GPU 2' }
]
</script>

<template>
<div class="mb-3" v-if="platform !== 'macos'">
    <label for="adapter_name" class="form-label">Streaming GPU</label>

    <select id="adapter_name" class="form-select" v-model="config.adapter_name">
      <option
        v-for="gpu in gpuOptions"
        :key="gpu.value"
        :value="gpu.value"
      >
        {{ gpu.label }}
      </option>
    </select>

    <div class="form-text">
      Choose which GPU Apollo should use for capture and encoding. Auto Select is recommended unless you need a specific GPU.
      <br>
      <PlatformLayout :platform="platform">
        <template #linux>
          <pre style="white-space: pre-line;">
            Auto Select: Apollo chooses the best available GPU.
            /dev/dri/renderD128: First render device
            /dev/dri/renderD129: Second render device
          </pre>
        </template>
        <template #windows>
          Choose the GPU Apollo should use for capture and encoding.
        </template>
      </PlatformLayout>
    </div>
  </div>
</template>
