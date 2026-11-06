# -*- coding: utf-8 -*-
import unittest
from poly_shell import i18n


class I18nTests(unittest.TestCase):
    def setUp(self):
        i18n.clear_cache()

    def test_supported_locales(self):
        supported = i18n.supported_locales()
        self.assertIn("en", supported)
        self.assertIn("vi", supported)
        self.assertIn("ru", supported)
        self.assertIn("es", supported)

    def test_translation_english_default(self):
        label = i18n.tr("power.charging", "en")
        self.assertEqual(label, "Charging")

    def test_translation_spanish(self):
        label = i18n.tr("power.charging", "es")
        self.assertEqual(label, "Cargando")

    def test_translation_vietnamese(self):
        label = i18n.tr("power.charging", "vi")
        self.assertEqual(label, "Đang sạc")

    def test_translation_russian(self):
        label = i18n.tr("power.charging", "ru")
        self.assertEqual(label, "Заряжается")

    def test_interpolation(self):
        result_en = i18n.tr("audio.volume", "en", percent=75)
        self.assertEqual(result_en, "Volume · 75%")

        result_vi = i18n.tr("audio.volume", "vi", percent=75)
        self.assertEqual(result_vi, "Âm lượng · 75%")

    def test_fallback_to_english_baseline(self):
        # A nonexistent key returns the key itself
        self.assertEqual(i18n.tr("nonexistent.key.xyz", "vi"), "nonexistent.key.xyz")

    def test_settings_validation(self):
        self.assertEqual(i18n.locale_for_settings({"locale": "vi"}), "vi")
        self.assertEqual(i18n.locale_for_settings({"locale": "en"}), "en")
        self.assertEqual(i18n.locale_for_settings({"locale": "ru"}), "ru")
        self.assertEqual(i18n.locale_for_settings({"locale": "invalid"}), "en")
        self.assertEqual(i18n.locale_for_settings({}), "en")

    def test_all_locales_have_matching_keys(self):
        en = i18n._load("en")
        vi = i18n._load("vi")
        ru = i18n._load("ru")
        es = i18n._load("es")
        self.assertGreater(len(en), 200)
        self.assertEqual(set(en.keys()), set(vi.keys()))
        self.assertEqual(set(en.keys()), set(ru.keys()))
        self.assertEqual(set(en.keys()), set(es.keys()))


if __name__ == "__main__":
    unittest.main()
