if Mix.env() in [:dev] do
  require Cldr.Currency.Backend

  defmodule MyApp.Cldr do
    use Cldr,
      locales: ["en", "de", "th", "fr", "fr-CH", "pt-CV", "ar-MA", "ru"],
      default_locale: "en",
      providers: [Cldr.Currency]
  end
end
