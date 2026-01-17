if Mix.env() in [:dev] do
  {:nodule, _code} = Code.ensure_compiled(Cldr.Currency.Backend)

  defmodule MyApp.Cldr do
    use Cldr,
      locales: ["en", "de", "th", "fr", "fr-CH", "pt-CV", "ar-MA", "ru"],
      default_locale: "en",
      providers: [Cldr.Currency]
  end
end
