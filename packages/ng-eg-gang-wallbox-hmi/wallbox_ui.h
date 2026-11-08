#pragma once

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdio>
#include <string>
#include "lvgl.h"
#include "trend_buffer.h"

namespace wallbox_ui {

inline bool valid_text(const std::string &text) {
  return !text.empty() && text != "unknown" && text != "unavailable";
}

inline void value_label(lv_obj_t *label, float value, unsigned decimals, const char *unit) {
  if (!std::isfinite(value)) {
    lv_label_set_text_fmt(label, "-- %s", unit);
    return;
  }
  char text[64];
  std::snprintf(text, sizeof(text), "%.*f %s", static_cast<int>(decimals), value, unit);
  // German decimal separator; leave units and UTF-8 unchanged.
  for (char *p = text; *p; ++p)
    if (*p == '.') *p = ',';
  lv_label_set_text(label, text);
}

// 361 points include both endpoints of a 60-minute window at 10-second cadence.
// Only RAM is used; missing/offline samples remain gaps, never synthetic zeroes.
class Trends {
 public:
  static constexpr size_t POINTS = TrendBuffer::POINTS;
  using Sample = TrendBuffer::Sample;

  void push(const Sample &sample, uint32_t now) {
    buffer_.push(sample, now);
  }

  void render(lv_obj_t *host, int selection, lv_obj_t *title,
              lv_obj_t *axis_top, lv_obj_t *axis_bottom, lv_obj_t *legend) {
    if (chart_ == nullptr) create(host);
    selection = std::max(0, std::min(3, selection));
    static const char *titles[] = {
      "Leistung (kW)", "Spannung (V)", "Strom (A)", "PCB-Temperatur (°C)"
    };
    const size_t first = selection == 0 ? 0 : selection == 1 ? 1 : selection == 2 ? 4 : 7;
    const size_t series_count = selection == 1 || selection == 2 ? 3 : 1;
    float low = selection == 1 ? 210.0f : 0.0f;
    float high = selection == 0 ? 12.0f : selection == 1 ? 250.0f : selection == 2 ? 18.0f : 80.0f;
    size_t valid_points = 0;
    for (size_t s = 0; s < 3; ++s) {
      lv_chart_hide_series(chart_, series_[s], s >= series_count);
      for (size_t p = 0; p < POINTS; ++p) {
        const float value = s < series_count ? buffer_.at(p, first + s) : NAN;
        const bool valid = std::isfinite(value);
        // Bound conversion to avoid undefined float-to-int overflow on bad input.
        const bool drawable = valid && std::abs(value) < 1000000.0f;
        lv_chart_set_series_value_by_id(chart_, series_[s], p,
          drawable ? static_cast<int32_t>(std::lround(value * 100)) : LV_CHART_POINT_NONE);
        if (drawable) {
          low = std::min(low, std::floor(value));
          high = std::max(high, std::ceil(value) + 1.0f);
          ++valid_points;
        }
      }
    }
    lv_chart_set_axis_range(chart_, LV_CHART_AXIS_PRIMARY_Y,
      static_cast<int32_t>(low * 100), static_cast<int32_t>(high * 100));
    lv_label_set_text(title, titles[selection]);
    lv_label_set_text_fmt(axis_top, "%.0f", high);
    lv_label_set_text_fmt(axis_bottom, "%.0f", low);
    lv_label_set_text(legend, valid_points == 0 ? "Warte auf Messwerte – keine Historie vorhanden" :
      series_count == 3 ? "L1: Türkis     L2: Grün     L3: Orange" : "Türkis: Messwert");
    lv_chart_refresh(chart_);
  }

 private:
  void create(lv_obj_t *host) {
    chart_ = lv_chart_create(host);
    lv_obj_set_pos(chart_, 58, 40);
    lv_obj_set_size(chart_, 690, 160);
    lv_chart_set_type(chart_, LV_CHART_TYPE_LINE);
    lv_chart_set_point_count(chart_, POINTS);
    lv_chart_set_div_line_count(chart_, 5, 7);
    lv_obj_remove_flag(chart_, LV_OBJ_FLAG_SCROLLABLE);
    lv_obj_set_style_bg_color(chart_, lv_color_hex(0x11171C), LV_PART_MAIN);
    lv_obj_set_style_bg_opa(chart_, LV_OPA_COVER, LV_PART_MAIN);
    lv_obj_set_style_border_width(chart_, 0, LV_PART_MAIN);
    lv_obj_set_style_pad_all(chart_, 0, LV_PART_MAIN);
    lv_obj_set_style_line_color(chart_, lv_color_hex(0x303D48), LV_PART_MAIN);
    lv_obj_set_style_line_width(chart_, 2, LV_PART_ITEMS);
    lv_obj_set_style_size(chart_, 0, 0, LV_PART_INDICATOR);
    const uint32_t colors[] = {0x4DD9E8, 0x68E0A0, 0xFFB65C};
    for (size_t i = 0; i < 3; ++i) {
      series_[i] = lv_chart_add_series(chart_, lv_color_hex(colors[i]), LV_CHART_AXIS_PRIMARY_Y);
      lv_chart_set_all_values(chart_, series_[i], LV_CHART_POINT_NONE);
    }
  }

  TrendBuffer buffer_;
  lv_obj_t *chart_ = nullptr;
  lv_chart_series_t *series_[3]{};
};

inline Trends &trends() {
  static Trends instance;
  return instance;
}

}  // namespace wallbox_ui
