#pragma once

#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>

namespace wallbox_ui {

// No ESPHome/LVGL dependencies: the history timeline can be tested on a host PC.
class TrendBuffer {
 public:
  static constexpr size_t POINTS = 361;
  static constexpr size_t CHANNELS = 8;
  using Sample = std::array<float, CHANNELS>;

  void push(const Sample &sample, uint32_t now) {
    if (has_sample_) {
      // Unsigned subtraction also handles the millis() rollover.
      const uint32_t steps = (now - last_sample_ms_) / 10000;
      const size_t gaps = std::min<size_t>(steps > 0 ? steps - 1 : 0, POINTS);
      Sample empty;
      empty.fill(NAN);
      for (size_t i = 0; i < gaps; ++i) append(empty);
    }
    append(sample);
    last_sample_ms_ = now;
    has_sample_ = true;
  }

  float at(size_t point, size_t channel) const {
    if (point >= POINTS || channel >= CHANNELS || point < POINTS - count_) return NAN;
    const size_t offset = point - (POINTS - count_);
    return samples_[(write_ + POINTS - count_ + offset) % POINTS][channel];
  }

 private:
  void append(const Sample &sample) {
    samples_[write_] = sample;
    write_ = (write_ + 1) % POINTS;
    count_ = std::min(count_ + 1, POINTS);
  }

  std::array<Sample, POINTS> samples_{};
  size_t write_ = 0;
  size_t count_ = 0;
  uint32_t last_sample_ms_ = 0;
  bool has_sample_ = false;
};

}  // namespace wallbox_ui
