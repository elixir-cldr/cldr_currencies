require Cldr.Currency.Backend

defmodule MyApp.Cldr do
  use Cldr,
    locales: ["en", "fr", "de", "zh"],
    default_locale: "en",
    # data_dir: "../cldr/priv/cldr",
    providers: [Cldr.Currency]
end

defmodule NoDoc.Cldr do
  use Cldr, generate_docs: false, providers: [Cldr.Currency]
end
