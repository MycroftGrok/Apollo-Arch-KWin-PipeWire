<script setup>
import { ref } from 'vue'
import PlatformLayout from '../../../PlatformLayout.vue'

const props = defineProps([
'platform',
'config'
])

const config = ref(props.config)

const displayOptions = [
{ value: '', label: 'Virtual Display (Recommended)' },
{ value: 'HDMI-A-2', label: 'HDMI-A-2 — Hisense Electric Co., Ltd. HISENSE-TV' },
{ value: 'HDMI-A-1', label: 'HDMI-A-1 — WEM WH22FA9600' }
]
</script>

<template>
<div class="mb-3">
<label for="output_name" class="form-label">Streaming Display</label>

<select id="output_name" class="form-select" v-model="config.output_name">
<option
v-for="display in displayOptions"
:key="display.value"
:value="display.value"
>
{{ display.label }}
</option>
</select>

<div class="form-text">
Choose which display Apollo should stream to the client. Virtual Display is recommended for handheld streaming.
<br>
<PlatformLayout :platform="platform">
<template #linux>
<pre style="white-space: pre-line;">
Virtual Display: Apollo creates a temporary display for the client.
HDMI-A-2: Hisense Electric Co., Ltd. HISENSE-TV
HDMI-A-1: WEM WH22FA9600
</pre>
</template>
</PlatformLayout>
</div>
</div>
</template>
