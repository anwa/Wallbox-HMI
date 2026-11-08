#include "trend_buffer.h"

#include <cassert>
#include <iostream>
#include <limits>

using wallbox_ui::TrendBuffer;

static TrendBuffer::Sample sample(float value) {
  TrendBuffer::Sample result;
  for (size_t i = 0; i < result.size(); ++i) result[i] = value + i;
  return result;
}

int main() {
  TrendBuffer partial;
  assert(std::isnan(partial.at(360, 0)));
  partial.push(sample(10), 10000);
  assert(std::isnan(partial.at(359, 0)));
  for (size_t channel = 0; channel < 8; ++channel)
    assert(partial.at(360, channel) == 10 + channel);
  partial.push(sample(20), 20000);
  assert(partial.at(359, 0) == 10);
  assert(partial.at(360, 0) == 20);
  assert(std::isnan(partial.at(361, 0)));
  assert(std::isnan(partial.at(360, 8)));

  TrendBuffer wrapped;
  for (uint32_t i = 0; i < 400; ++i) wrapped.push(sample(i), i * 10000);
  assert(wrapped.at(0, 0) == 39);
  assert(wrapped.at(360, 0) == 399);

  TrendBuffer gaps;
  gaps.push(sample(1), 10000);
  gaps.push(sample(2), 40000);
  assert(gaps.at(357, 0) == 1);
  assert(std::isnan(gaps.at(358, 0)));
  assert(std::isnan(gaps.at(359, 0)));
  assert(gaps.at(360, 0) == 2);
  auto missing = sample(3);
  missing[0] = NAN;
  gaps.push(missing, 50000);
  assert(std::isnan(gaps.at(360, 0)));
  assert(gaps.at(360, 1) == 4);
  gaps.push(sample(4), 50000 + 4000000);
  assert(std::isnan(gaps.at(359, 0)));
  assert(gaps.at(360, 0) == 4);

  TrendBuffer rollover;
  const uint32_t before = std::numeric_limits<uint32_t>::max() - 4999;
  rollover.push(sample(1), before);
  rollover.push(sample(2), before + uint32_t(10000));
  assert(rollover.at(359, 0) == 1);
  assert(rollover.at(360, 0) == 2);
  std::cout << "Trend buffer tests passed\n";
}
