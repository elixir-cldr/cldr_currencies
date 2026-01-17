{:module, _code} = Code.ensure_compiled(Cldr.Currency.Backend)

defmodule MyApp.Cldr do
  use Cldr,
    locales: ["en", "aa", "fr", "de", "zh", "ar-MA", "ru"],
    default_locale: "en",
    providers: [Cldr.Currency]
end

defmodule NoDoc.Cldr do
  use Cldr, generate_docs: false, providers: [Cldr.Currency]
end
