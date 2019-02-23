require Cldr.Currency.Backend

defmodule MyApp.Cldr do
  use Cldr,
    locales: :all,
    default_locale: "en",
    providers: [Cldr.Currency]
end
