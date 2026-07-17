<script setup>
import { ref } from "vue"

const props = defineProps([
  "platform",
  "config",
])

const config = ref(props.config)

const fixedResolutionOptions = [
  { value: "3840x2160x60", label: "3840 × 2160 @ 60 Hz" },
  { value: "2560x1440x60", label: "2560 × 1440 @ 60 Hz" },
  { value: "1920x1080x120", label: "1920 × 1080 @ 120 Hz" },
  { value: "1920x1080x60", label: "1920 × 1080 @ 60 Hz" },
  { value: "1280x720x60", label: "1280 × 720 @ 60 Hz" }
]

const resolutionOptions = [
  { value: "", label: "Auto / Client Requested (Recommended)" },
  ...fixedResolutionOptions
]
</script>

<template>
  <div class="mb-3">
    <label for="fallback_mode" class="form-label">
      {{ platform === "linux"
        ? "Default KWin Virtual Display Mode"
        : "Streaming Display Resolution" }}
    </label>

    <select
      id="fallback_mode"
      class="form-select"
      v-model="config.fallback_mode"
    >
      <option
        v-for="mode in (
          platform === `linux`
            ? fixedResolutionOptions
            : resolutionOptions
        )"
        :key="mode.value"
        :value="mode.value"
      >
        {{ mode.label }}
      </option>
    </select>

    <div class="form-text">
      Choose the default resolution Apollo uses when creating the
      virtual streaming display.
    </div>
  </div>

  <div class="mb-3">
    <label for="max_bitrate" class="form-label">
      {{ $t("config.max_bitrate") }}
    </label>
    <input
      type="number"
      class="form-control"
      id="max_bitrate"
      placeholder="0"
      v-model="config.max_bitrate"
    />
    <div class="form-text">
      {{ $t("config.max_bitrate_desc") }}
    </div>
  </div>

  <div class="mb-3">
    <label for="minimum_fps_target" class="form-label">
      {{ $t("config.minimum_fps_target") }}
    </label>
    <input
      type="number"
      min="0"
      max="1000"
      class="form-control"
      id="minimum_fps_target"
      placeholder="0"
      v-model="config.minimum_fps_target"
    />
    <div class="form-text">
      {{ $t("config.minimum_fps_target_desc") }}
    </div>
  </div>
</template>
