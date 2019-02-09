defmodule TestBackend.Cldr do
  use Cldr, locales: ["en", "de"], default_locale: "en", providers: [Cldr.Currency]

end