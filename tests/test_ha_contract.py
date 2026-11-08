"""Check mappings against the supplied HA export without accessing credentials."""
import json
from pathlib import Path
import unittest

import yaml  # Installed with ESPHome.


ROOT = Path(__file__).resolve().parents[1]


class HomeAssistantContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        export = json.loads((ROOT / "wallbox-entities.json").read_text(encoding="utf-8"))
        cls.entities = {entity["entity_id"]: entity for entity in export["entities"]}
        cls.imports = yaml.safe_load(
            (ROOT / "packages/homeassistant.yaml").read_text(encoding="utf-8")
        )

    def test_imported_entities_exist_and_remain_internal(self):
        for component in ("sensor", "text_sensor"):
            for entity in self.imports[component]:
                with self.subTest(entity=entity["entity_id"]):
                    self.assertIn(entity["entity_id"], self.entities)
                    self.assertTrue(entity["internal"])

    def test_power_and_session_energy_are_not_apparent_units(self):
        for sensor_id, unit in (("wb_power", "kW"), ("wb_energy", "kWh")):
            mapping = next(e for e in self.imports["sensor"] if e["id"] == sensor_id)
            self.assertEqual(
                self.entities[mapping["entity_id"]]["attributes"]["unit_of_measurement"], unit
            )

    def test_current_choices_match_existing_helper(self):
        helper = self.entities["input_select.wallbox_max_current_buttons"]
        self.assertEqual(helper["attributes"]["options"], ["0A", "6A", "10A", "12A", "16A"])
        ui = (ROOT / "packages/display/ui.yaml").read_text(encoding="utf-8")
        for option in helper["attributes"]["options"]:
            self.assertIn(f"option: {option},", ui)


if __name__ == "__main__":
    unittest.main()
