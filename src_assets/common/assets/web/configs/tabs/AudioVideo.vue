<script setup>
import {ref, computed, inject} from 'vue'
import {$tp} from '../../platform-i18n'
import PlatformLayout from '../../PlatformLayout.vue'
import AdapterNameSelector from './audiovideo/AdapterNameSelector.vue'
import DisplayOutputSelector from './audiovideo/DisplayOutputSelector.vue'
import DisplayDeviceOptions from "./audiovideo/DisplayDeviceOptions.vue";
import DisplayModesSettings from "./audiovideo/DisplayModesSettings.vue";
import Checkbox from "../../Checkbox.vue";

const $t = inject('i18n').t;

const props = defineProps([
  'platform',
  'config',
  'vdisplay',
  'min_fps_factor',
])

const sudovdaStatus = {
  '1': 'Unknown',
  '0': 'Ready',
  '-1': 'Uninitialized',
  '-2': 'Version Incompatible',
  '-3': 'Watchdog Failed'
}

const currentDriverStatus = computed(() => sudovdaStatus[props.vdisplay])

const config = ref(props.config)

const validateFallbackMode = (event) => {
  const value = event.target.value;
  if (!value.match(/^\d+x\d+x\d+(\.\d+)?$/)) {
    event.target.setCustomValidity($t('config.fallback_mode_error'));
  } else {
    event.target.setCustomValidity('');
  }

  event.target.reportValidity();
}
</script>

<template>
  <div id="audio-video" class="config-page">
    <!-- Audio Sink -->
    <div class="mb-3">
      <label for="audio_sink" class="form-label">{{ $t('config.audio_sink') }}</label>
      <input type="text" class="form-control" id="audio_sink"
             :placeholder="$tp('config.audio_sink_placeholder', 'alsa_output.pci-0000_09_00.3.analog-stereo')"
             v-model="config.audio_sink" />
      <div class="form-text pre-wrap">
        {{ $tp('config.audio_sink_desc') }}<br>
        <PlatformLayout :platform="platform">
          <template #windows>
            <pre>tools\audio-info.exe</pre>
          </template>
          <template #linux>
            <pre>pacmd list-sinks | grep "name:"</pre>
            <pre>pactl info | grep Source</pre>
          </template>
          <template #macos>
            <a href="https://github.com/mattingalls/Soundflower" target="_blank">Soundflower</a><br>
            <a href="https://github.com/ExistentialAudio/BlackHole" target="_blank">BlackHole</a>.
          </template>
        </PlatformLayout>
      </div>
    </div>

    <PlatformLayout :platform="platform">
      <template #windows>
        <!-- Virtual Sink -->
        <div class="mb-3">
          <label for="virtual_sink" class="form-label">{{ $t('config.virtual_sink') }}</label>
          <input type="text" class="form-control" id="virtual_sink" :placeholder="$t('config.virtual_sink_placeholder')"
                 v-model="config.virtual_sink" />
          <div class="form-text pre-wrap">{{ $t('config.virtual_sink_desc') }}</div>
        </div>
        <!-- Install Steam Audio Drivers -->
        <Checkbox class="mb-3"
                  id="install_steam_audio_drivers"
                  locale-prefix="config"
                  v-model="config.install_steam_audio_drivers"
                  default="true"
        ></Checkbox>

        <Checkbox class="mb-3"
                  id="keep_sink_default"
                  locale-prefix="config"
                  v-model="config.keep_sink_default"
                  default="true"
        ></Checkbox>

        <Checkbox class="mb-3"
                  id="auto_capture_sink"
                  locale-prefix="config"
                  v-model="config.auto_capture_sink"
                  default="true"
        ></Checkbox>
      </template>
    </PlatformLayout>

    <!-- Disable Audio -->
    <Checkbox class="mb-3"
              id="stream_audio"
              locale-prefix="config"
              v-model="config.stream_audio"
              default="true"
    ></Checkbox>

    <AdapterNameSelector
        :platform="platform"
        :config="config"
    />

    <DisplayOutputSelector
      :platform="platform"
      :config="config"
    />

    <div class="form-check mb-3">
      <input
        class="form-check-input"
        type="checkbox"
        id="preserve_physical_display"
        :checked="config.preserve_physical_display === `enabled`"
        @change="config.preserve_physical_display = $event.target.checked ? `enabled` : `disabled`"
      />
      <label class="form-check-label" for="preserve_physical_display">
        Preserve Physical Display
      </label>
      <div class="form-text">
        Stream the selected physical display while Apollo virtual display is active. Turn this off when you want Apollo to stream only the virtual display.
      </div>
    </div>

    <!-- KWin virtual-display controls: begin -->
    <div class="form-check mb-3">
      <input
        class="form-check-input"
        type="checkbox"
        id="kwin_virtual_display_client_override"
        :checked="config.kwin_virtual_display_client_override === `enabled`"
        @change="config.kwin_virtual_display_client_override = $event.target.checked ? `enabled` : `disabled`"
      />
      <label
        class="form-check-label"
        for="kwin_virtual_display_client_override"
      >
        Allow client to override the KWin virtual-display resolution
      </label>
      <div class="form-text">
        When enabled, Apollo recreates Virtual-Apollo-Display using the
        resolution requested by the streaming client.
      </div>
    </div>

    <div class="mb-3">
      <label for="dd_hdr_option_linux" class="form-label">
        HDR request handling
      </label>

      <select
        id="dd_hdr_option_linux"
        class="form-select"
        v-model="config.dd_hdr_option"
      >
        <option value="disabled">
          Do not change HDR settings
        </option>
        <option value="auto">
          Follow the HDR state requested by the client
        </option>
      </select>

      <div class="alert alert-warning mt-2 mb-0">
        The current krfb/KWin virtual output reports HDR as incapable.
        Apollo can save the client HDR preference, but actual HDR requires
        an HDR-capable virtual-display backend.
      </div>
    </div>
    <!-- KWin virtual-display controls: end -->

    <DisplayDeviceOptions
      :platform="platform"
      :config="config"
    />

    <!-- Display Modes -->
    <DisplayModesSettings
        :platform="platform"
        :config="config"
    />

    <!-- Headless Mode -->
    <Checkbox class="mb-3"
              id="headless_mode"
              locale-prefix="config"
              v-model="config.headless_mode"
              default="false"
              v-if="platform === 'windows'"
    ></Checkbox>

    <!-- Double Refreshrate -->
    <Checkbox class="mb-3"
              id="double_refreshrate"
              locale-prefix="config"
              v-model="config.double_refreshrate"
              default="false"
              v-if="platform === 'windows'"
    ></Checkbox>

    <!-- Isolated Virtual Display -->
    <Checkbox class="mb-3"
              id="isolated_virtual_display_option"
              locale-prefix="config"
              v-model="config.isolated_virtual_display_option"
              default="false"
              v-if="platform === 'windows'"
    ></Checkbox>

    <!-- SudoVDA Driver Status -->
    <div class="alert" :class="[vdisplay ? 'alert-warning' : 'alert-success']" v-if="platform === 'windows'">
      <i class="fa-solid fa-xl fa-circle-info"></i> SudoVDA Driver status: {{currentDriverStatus}}
    </div>
    <div class="form-text" v-if="platform === 'windows' && vdisplay">Please ensure SudoVDA driver is installed to the latest version and enabled properly.</div>

  </div>
</template>

<style scoped>
</style>
