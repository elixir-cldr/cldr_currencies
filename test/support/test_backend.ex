require Cldr.Currency.Backend

defmodule Test.Cldr do
  use Cldr,
    locales: ["en", "de", "zh", "fr"],
    default_locale: "en",
    providers: [Cldr.Currency]
end
