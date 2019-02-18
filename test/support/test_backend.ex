require Cldr.Currency.Backend

defmodule Test.Cldr do
  use Cldr,
    locales: :all,
    default_locale: "en",
    providers: [Cldr.Currency]
end
