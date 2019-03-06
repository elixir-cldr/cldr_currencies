if Mix.env() in [:dev] do
  require Cldr.Currency.Backend

  defmodule MyApp.Cldr do
    use Cldr,
      locales: ["en", "de", "th"],
      default_locale: "en",
      providers: [Cldr.Currency]
  end
end