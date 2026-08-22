/**
 * @file src/capture_diagnostics.h
 * @brief Small thread-safe runtime snapshot used by the Web UI diagnostics page.
 */

#pragma once

#include <cstdint>
#include <mutex>

namespace capture_diagnostics {

  enum class buffer_type_e : std::uint8_t {
    unknown = 0,
    memory,
    dmabuf,
  };

  struct state_t {
    std::uint32_t requested_width {0};
    std::uint32_t requested_height {0};
    std::uint32_t requested_fps {0};
    buffer_type_e buffer_type {buffer_type_e::unknown};
    std::uint32_t egl_dmabuf_formats {0};
    std::uint32_t advertised_dmabuf_formats {0};
  };

  inline std::mutex state_mutex;
  inline state_t state;

  inline void set_requested_resolution(std::uint32_t width, std::uint32_t height) {
    std::scoped_lock lock {state_mutex};
    state.requested_width = width;
    state.requested_height = height;
  }

  inline void set_requested_fps(std::uint32_t fps) {
    std::scoped_lock lock {state_mutex};
    state.requested_fps = fps;
  }

  inline void set_buffer_type(buffer_type_e type) {
    std::scoped_lock lock {state_mutex};
    state.buffer_type = type;
  }

  inline void set_egl_dmabuf_formats(std::uint32_t count) {
    std::scoped_lock lock {state_mutex};
    state.egl_dmabuf_formats = count;
  }

  inline void set_advertised_dmabuf_formats(std::uint32_t count) {
    std::scoped_lock lock {state_mutex};
    state.advertised_dmabuf_formats = count;
  }

  inline state_t snapshot() {
    std::scoped_lock lock {state_mutex};
    return state;
  }

  inline const char *buffer_type_name(buffer_type_e type) {
    switch (type) {
      case buffer_type_e::memory:
        return "memory";
      case buffer_type_e::dmabuf:
        return "dma-buf";
      default:
        return "unknown";
    }
  }

}  // namespace capture_diagnostics
