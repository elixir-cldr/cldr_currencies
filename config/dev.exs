# In test mode we compile and test all locales
use Mix.Config

config :ex_cldr,
  default_locale: "en",
  locales: ["en", "fr", "de", "zh"]