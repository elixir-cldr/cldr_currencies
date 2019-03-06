if Mix.env() in [:dev] do
  defmodule MyApp.Cldr do
    use Cldr,
      locales: ["en", "de", "th"],
      default_locale: "en",
      providers: [Cldr.Currency]
  end
end